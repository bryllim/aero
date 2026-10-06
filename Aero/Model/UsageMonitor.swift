import Foundation
import Security

enum UsageProvider: String, Codable, CaseIterable, Identifiable {
    case claude, codex
    var id: String { rawValue }

    var title: String {
        switch self {
        case .claude: "Claude"
        case .codex: "ChatGPT Codex"
        }
    }

    var boardName: String {
        switch self {
        case .claude: "CLAUDE"
        case .codex: "CODEX"
        }
    }
}

struct UsageWindow: Equatable {
    /// Short label for the board, e.g. "5H" or "7D".
    var label: String
    /// Fraction of the allowance still available, 0...1.
    var remaining: Double
    var resetsAt: Date?
}

struct ProviderUsage: Equatable {
    var windows: [UsageWindow]
    var plan: String?
    var updated: Date
}

struct UsageSnapshot: Equatable {
    var providers: [UsageProvider: ProviderUsage] = [:]
    var errors: [UsageProvider: String] = [:]
    var updated: Date?
}

/// Polls the usage endpoints of locally signed-in AI coding tools.
@MainActor
final class UsageMonitor: ObservableObject {
    @Published private(set) var snapshot = UsageSnapshot()
    @Published private(set) var isRefreshing = false

    private var enabled: Set<UsageProvider> = []
    private var allowClaudeRefresh = false
    private var timer: Timer?
    private var claudeToken: (value: String, expires: Date)?

    private static let interval: TimeInterval = 5 * 60

    func configure(settings: AeroSettings) {
        var wanted: Set<UsageProvider> = []
        if settings.usageClaude { wanted.insert(.claude) }
        if settings.usageCodex { wanted.insert(.codex) }
        let changed = wanted != enabled || allowClaudeRefresh != settings.usageClaudeRefresh
        enabled = wanted
        allowClaudeRefresh = settings.usageClaudeRefresh

        var snapshot = snapshot
        for provider in UsageProvider.allCases where !wanted.contains(provider) {
            snapshot.providers[provider] = nil
            snapshot.errors[provider] = nil
        }
        self.snapshot = snapshot

        timer?.invalidate()
        timer = nil
        guard !wanted.isEmpty else { return }
        timer = Timer.scheduledTimer(withTimeInterval: Self.interval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        if changed { Task { await refresh() } }
    }

    func refresh() async {
        guard !enabled.isEmpty, !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        // Providers are fetched side by side, so a keychain prompt for one doesn't hold up the other.
        let results = await withTaskGroup(of: (UsageProvider, Result<ProviderUsage, Error>).self) { group in
            for provider in UsageProvider.allCases where enabled.contains(provider) {
                group.addTask { @MainActor in
                    do { return (provider, .success(try await self.fetch(provider))) } catch { return (provider, .failure(error)) }
                }
            }
            var results: [(UsageProvider, Result<ProviderUsage, Error>)] = []
            for await result in group {
                results.append(result)
                self.apply(result.0, result.1)  // show each provider as soon as it answers
            }
            return results
        }
        _ = results
        snapshot.updated = Date()
    }

    private func apply(_ provider: UsageProvider, _ result: Result<ProviderUsage, Error>) {
        switch result {
        case .success(let usage):
            snapshot.providers[provider] = usage
            snapshot.errors[provider] = nil
        case .failure(let error):
            snapshot.errors[provider] = (error as? UsageError)?.message ?? error.localizedDescription
        }
    }

    private func fetch(_ provider: UsageProvider) async throws -> ProviderUsage {
        switch provider {
        case .claude: try await fetchClaude()
        case .codex: try await fetchCodex()
        }
    }

    // MARK: Claude Code

    nonisolated private static let claudeService = "Claude Code-credentials"
    private static let claudeClientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"

    private func fetchClaude() async throws -> ProviderUsage {
        let token = try await claudeAccessToken()
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let json = try await Self.json(for: request, provider: .claude)

        var windows: [UsageWindow] = []
        for (key, label) in [("five_hour", "5H"), ("seven_day", "7D")] {
            guard let window = json[key] as? [String: Any],
                  let utilization = Self.number(window["utilization"]) else { continue }
            windows.append(UsageWindow(label: label, remaining: max(0, min(1, 1 - utilization / 100)),
                                       resetsAt: Self.isoDate(window["resets_at"])))
        }
        guard !windows.isEmpty else { throw UsageError("Claude returned no usage windows.") }
        return ProviderUsage(windows: windows, plan: nil, updated: Date())
    }

    /// The access token Claude Code keeps in the keychain, refreshed if allowed and needed.
    private func claudeAccessToken() async throws -> String {
        if let claudeToken, claudeToken.expires > Date().addingTimeInterval(60) { return claudeToken.value }

        // Keychain access can block on a permission dialog; keep it off the main thread.
        let stored = try await Task.detached(priority: .utility) { try Self.readClaudeCredentials() }.value
        guard var credentials = stored,
              var oauth = credentials["claudeAiOauth"] as? [String: Any] else {
            throw UsageError("Claude Code isn't signed in on this Mac.")
        }
        let token = oauth["accessToken"] as? String ?? ""
        let expires = Date(timeIntervalSince1970: (Self.number(oauth["expiresAt"]) ?? 0) / 1000)
        if !token.isEmpty, expires > Date().addingTimeInterval(60) {
            claudeToken = (token, expires)
            return token
        }

        let refreshToken = oauth["refreshToken"] as? String ?? ""
        guard !token.isEmpty || !refreshToken.isEmpty else {
            // Claude Code run from the Claude desktop app leaves this entry empty; only the Terminal CLI fills it.
            throw UsageError("Claude Code's keychain entry holds no sign-in. In Terminal, run `claude`, then `/login`; Aero picks it up on the next refresh.")
        }
        guard allowClaudeRefresh else {
            throw UsageError("Claude Code's sign-in has expired. Run `claude` in Terminal, or let Aero refresh it below.")
        }
        guard !refreshToken.isEmpty else {
            throw UsageError("Claude Code's sign-in can't be refreshed. In Terminal, run `claude`, then `/login`.")
        }

        var request = URLRequest(url: URL(string: "https://platform.claude.com/v1/oauth/token")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "grant_type": "refresh_token", "refresh_token": refreshToken, "client_id": Self.claudeClientID,
        ])
        let json = try await Self.json(for: request, provider: .claude)
        guard let access = json["access_token"] as? String else { throw UsageError("Claude sign-in refresh failed.") }
        let lifetime = Self.number(json["expires_in"]) ?? 3600
        let newExpiry = Date().addingTimeInterval(lifetime)

        // Keep Claude Code signed in: hand the rotated tokens back to its keychain item.
        oauth["accessToken"] = access
        oauth["expiresAt"] = Int(newExpiry.timeIntervalSince1970 * 1000)
        if let rotated = json["refresh_token"] as? String { oauth["refreshToken"] = rotated }
        credentials["claudeAiOauth"] = oauth
        let updated = credentials
        try await Task.detached(priority: .utility) { try Self.writeClaudeCredentials(updated) }.value

        claudeToken = (access, newExpiry)
        return access
    }

    nonisolated private static func readClaudeCredentials() throws -> [String: Any]? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: claudeService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        if status == errSecUserCanceled || status == errSecAuthFailed {
            throw UsageError("Aero wasn't allowed to read Claude Code's keychain item.")
        }
        guard status == errSecSuccess, let data = item as? Data else {
            throw UsageError("Couldn't read Claude Code's keychain item (\(status)).")
        }
        return try JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    nonisolated private static func writeClaudeCredentials(_ credentials: [String: Any]) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: claudeService,
        ]
        let data = try JSONSerialization.data(withJSONObject: credentials)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        guard status == errSecSuccess else { throw UsageError("Couldn't update Claude Code's keychain item (\(status)).") }
    }

    // MARK: ChatGPT Codex

    private func fetchCodex() async throws -> ProviderUsage {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/auth.json")
        guard let data = try? Data(contentsOf: url),
              let auth = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = auth["tokens"] as? [String: Any],
              let token = tokens["access_token"] as? String else {
            throw UsageError("Codex isn't signed in on this Mac. Run `codex login` in Terminal.")
        }
        let account = tokens["account_id"] as? String
            ?? Self.jwtClaim(tokens["id_token"] as? String, path: ["https://api.openai.com/auth", "chatgpt_account_id"])

        var request = URLRequest(url: URL(string: "https://chatgpt.com/backend-api/wham/usage")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let account { request.setValue(account, forHTTPHeaderField: "ChatGPT-Account-Id") }
        let json = try await Self.json(for: request, provider: .codex)

        var windows: [UsageWindow] = []
        let limits = json["rate_limit"] as? [String: Any] ?? json
        for key in ["primary_window", "secondary_window"] {
            guard let window = limits[key] as? [String: Any], let used = Self.number(window["used_percent"]) else { continue }
            let seconds = Self.number(window["limit_window_seconds"]) ?? 0
            let label = seconds >= 86_400 ? "\(Int((seconds / 86_400).rounded()))D" : "\(Int((seconds / 3600).rounded()))H"
            var resets: Date?
            if let at = Self.number(window["reset_at"]) {
                resets = Date(timeIntervalSince1970: at)
            } else if let after = Self.number(window["reset_after_seconds"]) {
                resets = Date().addingTimeInterval(after)
            }
            windows.append(UsageWindow(label: label, remaining: max(0, min(1, 1 - used / 100)), resetsAt: resets))
        }
        guard !windows.isEmpty else { throw UsageError("Codex returned no usage windows.") }
        return ProviderUsage(windows: windows, plan: json["plan_type"] as? String, updated: Date())
    }

    // MARK: Helpers

    private static func json(for request: URLRequest, provider: UsageProvider) async throws -> [String: Any] {
        var request = request
        request.setValue("Aero/1.0 (macOS)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            if status == 401 || status == 403 {
                throw UsageError("\(provider.title) rejected the saved sign-in. Sign in again in Terminal.")
            }
            throw UsageError("\(provider.title) replied with HTTP \(status).")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UsageError("\(provider.title) sent an unexpected reply.")
        }
        return json
    }

    private static func number(_ value: Any?) -> Double? {
        switch value {
        case let n as NSNumber: n.doubleValue
        case let s as String: Double(s)
        default: nil
        }
    }

    private static func isoDate(_ value: Any?) -> Date? {
        guard let text = value as? String else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }

    private static func jwtClaim(_ jwt: String?, path: [String]) -> String? {
        guard let jwt else { return nil }
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload),
              var node = try? JSONSerialization.jsonObject(with: data) else { return nil }
        for key in path {
            guard let dict = node as? [String: Any], let next = dict[key] else { return nil }
            node = next
        }
        return node as? String
    }
}

struct UsageError: Error {
    let message: String
    init(_ message: String) { self.message = message }
}
