# Aero

A desktop clock for macOS, inspired by airport displays. Dot matrix, split-flap, world clocks, Pomodoro, and live system stats on your wallpaper.

Developed by **[Bryl Lim](https://bryllim.com)**.

## Download

Get the DMG from [GitHub Releases](https://github.com/bryllim/aero/releases). Open it and drag Aero into Applications.

Requires **macOS 14 or later**. The release DMG supports **Apple silicon and Intel Macs**.

The first release is an **unnotarized preview**. It is ad hoc signed rather than Developer ID signed, so macOS may block it when downloaded. You can review the source and build it locally. There is no automatic updater; install newer releases from GitHub.

## What it does

- Dot matrix and split-flap clocks, with six themes and custom colors.
- Departures board and daylight world map, with selectable destinations.
- Pomodoro sessions, short and long breaks, notifications, and a menu bar countdown.
- Optional CPU, RAM, and swap readings directly on the wallpaper, refreshed every two seconds.
- Wallpaper placement, size, transparency, and support for multiple displays.
- Optional Claude Code and Codex usage readings.
- Launch at login and the option to keep Aero out of the Dock.

Use the menu bar dropdown for the timer and quick wallpaper controls. Open Aero for a live preview and full controls. Turn on **System Stats** in the dropdown, then choose metrics under **Settings → System**.

## Build from source

Install Xcode 16 or later, then open `Aero.xcodeproj` and run the Aero scheme. There are no third-party runtime dependencies.

Or build from Terminal:

```sh
xcodebuild -project Aero.xcodeproj -scheme Aero -configuration Release -derivedDataPath build build
open build/Build/Products/Release/Aero.app
```

`project.yml` is the project configuration. If you change it, regenerate the checked-in Xcode project with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
xcodegen generate
```

Run the regression checks:

```sh
./scripts/check_settings.sh
./scripts/check_system_monitor.sh
```

## Package a release

```sh
./scripts/package_dmg.sh
```

This builds a universal Release app and creates a DMG and SHA-256 checksum in `dist/`. It also includes the license, attribution, and installation instructions.

For Developer ID signing and notarization, configure your own certificate and notarytool Keychain profile, then run:

```sh
RELEASE_SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARYTOOL_PROFILE="your-notary-profile" \
./scripts/package_dmg.sh
```

## Data and permissions

Clock, Pomodoro, and system stats run locally. Settings and timer state stay on your Mac. Aero has no analytics or project-operated backend.

AI usage integrations are off by default. When enabled, Aero reads Claude Code's existing Keychain sign-in or the Codex CLI's `~/.codex/auth.json`, and sends usage requests directly to the respective provider. The optional Claude sign-in refresh also updates Claude Code's existing Keychain entry. These integrations depend on local CLI sign-in formats and provider endpoints that can change.

macOS may ask for access to the Claude Code Keychain entry, notification permission, or approval for launch at login. These are only used by the corresponding features.

## Contributing

Issues and pull requests are welcome. Include your macOS version, display style, and steps to reproduce a problem. Keep contributions focused and run the regression checks before opening a pull request.

## License

Source code, original artwork, and documentation are licensed under [Creative Commons Attribution 4.0 International (CC BY 4.0)](LICENSE). See [ATTRIBUTION.md](ATTRIBUTION.md) for the requested credit.

Copyright © 2026 Bryl Lim. [bryllim.com](https://bryllim.com).
