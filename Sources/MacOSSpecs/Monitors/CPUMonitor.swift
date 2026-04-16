import Darwin
import Foundation

final class CPUMonitor {
    private var previous: (user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)?

    func sample() -> Double {
        var info = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &info) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPtr in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, reboundPtr, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }

        let user = UInt32(info.cpu_ticks.0)
        let system = UInt32(info.cpu_ticks.1)
        let idle = UInt32(info.cpu_ticks.2)
        let nice = UInt32(info.cpu_ticks.3)

        defer { previous = (user, system, idle, nice) }

        guard let prev = previous else { return 0 }

        let userDiff = Double(user &- prev.user)
        let systemDiff = Double(system &- prev.system)
        let idleDiff = Double(idle &- prev.idle)
        let niceDiff = Double(nice &- prev.nice)
        let total = userDiff + systemDiff + idleDiff + niceDiff
        guard total > 0 else { return 0 }
        return ((userDiff + systemDiff + niceDiff) / total) * 100.0
    }
}
