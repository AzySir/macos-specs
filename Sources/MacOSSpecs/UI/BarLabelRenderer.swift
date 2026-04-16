import AppKit

enum BarLabelRenderer {
    static func render(_ snap: Snapshot, settings: AppSettings) -> NSAttributedString {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        let dotFont = NSFont.systemFont(ofSize: 13, weight: .bold)
        let result = NSMutableAttributedString()

        var first = true
        func separator() {
            if !first {
                result.append(NSAttributedString(string: "  ", attributes: [.font: font]))
            }
            first = false
        }

        if settings.showCPU {
            separator()
            appendDot(result, nsColor: settings.cpuColor.nsColor, font: dotFont)
            append(result, " CPU \(Int(snap.cpu.rounded()))%", color: .labelColor, font: font)
        }
        if settings.showMemory {
            separator()
            appendDot(result, nsColor: settings.memoryColor.nsColor, font: dotFont)
            let memGB = Double(snap.memoryUsedBytes) / 1_073_741_824
            append(result, String(format: " RAM %.1fG", memGB), color: .labelColor, font: font)
        }
        if settings.showGPU {
            separator()
            appendDot(result, nsColor: settings.gpuColor.nsColor, font: dotFont)
            append(result, " GPU \(Int(snap.gpu.rounded()))%", color: .labelColor, font: font)
        }
        if settings.showThermal {
            separator()
            let thermalColor = settings.color(for: settings.severity(for: snap.thermal))
            appendDot(result, nsColor: NSColor(thermalColor), font: dotFont)
            if let t = snap.temperatureCelsius {
                append(result, String(format: " %.0f°C", t), color: .labelColor, font: font)
            } else {
                append(result, " \(thermalShort(snap.thermal))", color: .labelColor, font: font)
            }
        }

        if result.length == 0 {
            return NSAttributedString(string: "MacOSSpecs", attributes: [.font: font])
        }
        return result
    }

    private static func append(_ s: NSMutableAttributedString, _ text: String, color: NSColor, font: NSFont) {
        s.append(NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color
        ]))
    }

    private static func appendDot(_ s: NSMutableAttributedString, nsColor: NSColor, font: NSFont) {
        s.append(NSAttributedString(string: "●", attributes: [
            .font: font,
            .foregroundColor: nsColor
        ]))
    }

    private static func thermalShort(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "OK"
        case .fair: return "Fair"
        case .serious: return "Hot"
        case .critical: return "CRIT"
        @unknown default: return ""
        }
    }
}

extension RGB {
    var nsColor: NSColor { NSColor(srgbRed: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1) }
}
