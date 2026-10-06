import Foundation
import Combine
import Darwin

struct SystemSnapshot: Equatable {
    /// CPU busy time across all cores, normalized to 0...1.
    var cpuFraction: Double?
    var memoryUsedBytes: UInt64?
    var physicalMemoryBytes: UInt64 = ProcessInfo.processInfo.physicalMemory
    var swapUsedBytes: UInt64?
    var swapTotalBytes: UInt64?

    static func gigabytes(_ bytes: UInt64) -> String {
        String(format: "%.1f", Double(bytes) / 1_073_741_824)
    }
}

/// Reads local kernel counters only while the wallpaper's system stats are enabled.
@MainActor
final class SystemMonitor: ObservableObject {
    @Published private(set) var snapshot = SystemSnapshot()
    private var timer: Timer?
    private var previousCPU: CPUTicks?

    var isSampling: Bool { timer != nil }

    func configure(enabled: Bool) {
        guard enabled != isSampling else { return }
        timer?.invalidate()
        timer = nil
        previousCPU = nil
        guard enabled else {
            snapshot = SystemSnapshot()
            return
        }
        sample()
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isSampling else { return }
                self.sample()
            }
        }
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func sample() {
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        var next = SystemSnapshot()

        var cpu = host_cpu_load_info_data_t()
        var cpuCount = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let cpuResult = withUnsafeMutablePointer(to: &cpu) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(cpuCount)) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &cpuCount)
            }
        }
        if cpuResult == KERN_SUCCESS {
            let current = CPUTicks(user: cpu.cpu_ticks.0, system: cpu.cpu_ticks.1,
                                   idle: cpu.cpu_ticks.2, nice: cpu.cpu_ticks.3)
            if let previousCPU { next.cpuFraction = current.busyFraction(since: previousCPU) }
            previousCPU = current
        } else {
            previousCPU = nil
        }

        var memory = vm_statistics64_data_t()
        var memoryCount = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let memoryResult = withUnsafeMutablePointer(to: &memory) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(memoryCount)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &memoryCount)
            }
        }
        if memoryResult == KERN_SUCCESS {
            // App memory excludes reclaimable purgeable pages and the file cache.
            let appPages = UInt64(memory.internal_page_count) - min(UInt64(memory.internal_page_count), UInt64(memory.purgeable_count))
            let usedPages = appPages + UInt64(memory.wire_count) + UInt64(memory.compressor_page_count)
            next.memoryUsedBytes = min(next.physicalMemoryBytes, usedPages * UInt64(vm_kernel_page_size))
        }

        var swap = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        let swapResult = withUnsafeMutablePointer(to: &swap) {
            sysctlbyname("vm.swapusage", $0, &swapSize, nil, 0)
        }
        if swapResult == 0 {
            next.swapUsedBytes = swap.xsu_used
            next.swapTotalBytes = swap.xsu_total
        }
        snapshot = next
    }
}

struct CPUTicks {
    var user: UInt32
    var system: UInt32
    var idle: UInt32
    var nice: UInt32

    func busyFraction(since previous: CPUTicks) -> Double? {
        // The kernel's 32-bit tick counters can wrap on long-running machines.
        let busy = UInt64(user &- previous.user) + UInt64(system &- previous.system) + UInt64(nice &- previous.nice)
        let total = busy + UInt64(idle &- previous.idle)
        guard total > 0 else { return nil }
        return min(1, max(0, Double(busy) / Double(total)))
    }
}
