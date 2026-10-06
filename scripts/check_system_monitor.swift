import Foundation

@main
struct SystemMonitorChecks {
    @MainActor
    static func main() async throws {
        let baseline = CPUTicks(user: 10, system: 20, idle: 70, nice: 0)
        assert(CPUTicks(user: 20, system: 30, idle: 100, nice: 0).busyFraction(since: baseline) == 0.4)
        assert(baseline.busyFraction(since: baseline) == nil)
        assert(CPUTicks(user: 10, system: 20, idle: 100, nice: 0).busyFraction(since: baseline) == 0)
        assert(CPUTicks(user: 20, system: 20, idle: 70, nice: 0).busyFraction(since: baseline) == 1)
        let wrapped = CPUTicks(user: 4, system: 0, idle: 90, nice: 0)
        assert(wrapped.busyFraction(since: CPUTicks(user: UInt32.max - 5, system: 0, idle: 0, nice: 0)) == 0.1)

        let monitor = SystemMonitor()
        assert(!monitor.isSampling)
        monitor.configure(enabled: true)
        assert(monitor.isSampling)
        assert(monitor.snapshot.cpuFraction == nil)
        assert(monitor.snapshot.memoryUsedBytes != nil && monitor.snapshot.swapUsedBytes != nil)
        try await Task.sleep(for: .seconds(1))
        monitor.sample()
        guard let cpu = monitor.snapshot.cpuFraction, let memory = monitor.snapshot.memoryUsedBytes else {
            fatalError("Live kernel readings unavailable")
        }
        assert((0...1).contains(cpu))
        assert(memory > 0 && memory <= monitor.snapshot.physicalMemoryBytes)
        assert(monitor.snapshot.swapUsedBytes! <= monitor.snapshot.swapTotalBytes!)

        monitor.configure(enabled: false)
        assert(!monitor.isSampling)
        let stopped = monitor.snapshot
        try await Task.sleep(for: .seconds(2.5))
        assert(monitor.snapshot == stopped && stopped.memoryUsedBytes == nil)
        print("System monitor checks passed: CPU deltas, counter wrap, live readings, and sampling shutdown.")
    }
}
