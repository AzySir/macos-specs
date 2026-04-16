import Darwin
import Foundation

struct MemoryReading {
    var pressure: Double
    var usedBytes: UInt64
    var totalBytes: UInt64
}

final class MemoryMonitor {
    private let pageSize: UInt64 = UInt64(vm_kernel_page_size)
    private let totalBytes: UInt64 = {
        var size: UInt64 = 0
        var len = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &size, &len, nil, 0)
        return size
    }()

    func sample() -> MemoryReading {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &stats) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, reboundPtr, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            return MemoryReading(pressure: 0, usedBytes: 0, totalBytes: totalBytes)
        }

        let wired = UInt64(stats.wire_count) * pageSize
        let active = UInt64(stats.active_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let used = wired + active + compressed
        let pressure = totalBytes > 0 ? min(1.0, Double(wired + compressed) / Double(totalBytes)) : 0
        return MemoryReading(pressure: pressure, usedBytes: used, totalBytes: totalBytes)
    }
}
