import Foundation
import Darwin.Mach

struct SystemResourceSnapshot: Equatable, Sendable {
    let cpuUsagePercent: Double
    let memoryUsedBytes: UInt64
    let memoryTotalBytes: UInt64
}

final class SystemResourceMonitor {
    var onSnapshotChange: ((SystemResourceSnapshot) -> Void)?

    private let queue = DispatchQueue(label: "CodexPet.system-resource-monitor")
    private let interval: DispatchTimeInterval = .seconds(2)
    private var timer: DispatchSourceTimer?
    private var lastCPUTicks: host_cpu_load_info?

    func start() {
        queue.async { [weak self] in
            guard let self, self.timer == nil else { return }
            self.poll()
            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now() + self.interval, repeating: self.interval)
            timer.setEventHandler { [weak self] in
                self?.poll()
            }
            self.timer = timer
            timer.resume()
        }
    }

    func stop() {
        queue.async { [weak self] in
            self?.timer?.cancel()
            self?.timer = nil
        }
    }

    private func poll() {
        guard let cpuUsagePercent = currentCPUUsagePercent(),
              let memoryUsedBytes = currentMemoryUsedBytes()
        else {
            return
        }

        onSnapshotChange?(
            SystemResourceSnapshot(
                cpuUsagePercent: cpuUsagePercent,
                memoryUsedBytes: memoryUsedBytes,
                memoryTotalBytes: ProcessInfo.processInfo.physicalMemory
            )
        )
    }

    private func currentCPUUsagePercent() -> Double? {
        var load = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &load) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return nil
        }

        defer {
            lastCPUTicks = load
        }

        guard let lastCPUTicks else {
            return 0
        }

        let user = Double(load.cpu_ticks.0 - lastCPUTicks.cpu_ticks.0)
        let system = Double(load.cpu_ticks.1 - lastCPUTicks.cpu_ticks.1)
        let idle = Double(load.cpu_ticks.2 - lastCPUTicks.cpu_ticks.2)
        let nice = Double(load.cpu_ticks.3 - lastCPUTicks.cpu_ticks.3)
        let total = user + system + idle + nice

        guard total > 0 else {
            return 0
        }

        return ((user + system + nice) / total) * 100
    }

    private func currentMemoryUsedBytes() -> UInt64? {
        var pageSize: vm_size_t = 0
        guard host_page_size(mach_host_self(), &pageSize) == KERN_SUCCESS else {
            return nil
        }

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return nil
        }

        let usedPages = UInt64(stats.active_count + stats.wire_count + stats.compressor_page_count)
        return usedPages * UInt64(pageSize)
    }
}
