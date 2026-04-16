import Foundation
import IOKit

final class GPUMonitor {
    func sample() -> Double {
        var iterator: io_iterator_t = 0
        guard let matching = IOServiceMatching("IOAccelerator") else { return 0 }
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return 0
        }
        defer { IOObjectRelease(iterator) }

        var maxUtil: Double = 0
        var service = IOIteratorNext(iterator)
        while service != 0 {
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dict = props?.takeRetainedValue() as? [String: Any],
               let perf = dict["PerformanceStatistics"] as? [String: Any] {
                if let util = (perf["Device Utilization %"] as? NSNumber)?.doubleValue {
                    maxUtil = max(maxUtil, util)
                } else if let util = (perf["GPU Activity(%)"] as? NSNumber)?.doubleValue {
                    maxUtil = max(maxUtil, util)
                }
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return maxUtil
    }
}
