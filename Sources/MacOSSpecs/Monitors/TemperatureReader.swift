import Foundation

// Private IOKit symbols exposed at runtime via the IOKit framework. These are
// used by macOS utilities (Stats, TG Pro, Menu Meters, etc.) to read the
// CPU/GPU temperature sensors on Apple Silicon.

@_silgen_name("IOHIDEventSystemClientCreate")
private func IOHIDEventSystemClientCreate(_ allocator: CFAllocator?) -> CFTypeRef?

@_silgen_name("IOHIDEventSystemClientSetMatching")
private func IOHIDEventSystemClientSetMatching(_ client: CFTypeRef, _ matching: CFDictionary) -> Int32

@_silgen_name("IOHIDEventSystemClientCopyServices")
private func IOHIDEventSystemClientCopyServices(_ client: CFTypeRef) -> CFArray?

@_silgen_name("IOHIDServiceClientCopyProperty")
private func IOHIDServiceClientCopyProperty(_ service: CFTypeRef, _ key: CFString) -> CFTypeRef?

@_silgen_name("IOHIDServiceClientCopyEvent")
private func IOHIDServiceClientCopyEvent(_ service: CFTypeRef, _ type: Int64, _ options: Int32, _ timestamp: Int64) -> CFTypeRef?

@_silgen_name("IOHIDEventGetFloatValue")
private func IOHIDEventGetFloatValue(_ event: CFTypeRef, _ field: Int32) -> Double

enum TemperatureReader {
    static func cpuTemperature() -> Double? {
        let matching: [String: Any] = [
            "PrimaryUsagePage": NSNumber(value: 0xff00),
            "PrimaryUsage":     NSNumber(value: 0x0005)
        ]
        guard let client = IOHIDEventSystemClientCreate(kCFAllocatorDefault) else { return nil }
        _ = IOHIDEventSystemClientSetMatching(client, matching as CFDictionary)
        guard let services = IOHIDEventSystemClientCopyServices(client) as? [CFTypeRef] else { return nil }

        let eventType: Int64 = 15                 // kIOHIDEventTypeTemperature
        let field: Int32 = Int32(15 << 16)        // kIOHIDEventFieldTemperatureLevel

        var temps: [Double] = []
        for service in services {
            let product = (IOHIDServiceClientCopyProperty(service, "Product" as CFString) as? String) ?? ""
            guard isCPUSensor(product) else { continue }
            guard let event = IOHIDServiceClientCopyEvent(service, eventType, 0, 0) else { continue }
            let temp = IOHIDEventGetFloatValue(event, field)
            if temp > 5 && temp < 150 { temps.append(temp) }
        }
        guard !temps.isEmpty else { return nil }
        return temps.reduce(0, +) / Double(temps.count)
    }

    private static func isCPUSensor(_ product: String) -> Bool {
        let upper = product.uppercased()
        return upper.contains("CPU") ||
               upper.contains("PACC") ||   // Apple Silicon perf cluster
               upper.contains("EACC") ||   // Apple Silicon efficiency cluster
               upper.contains("TCAL") ||
               upper.hasPrefix("PMGR")
    }
}
