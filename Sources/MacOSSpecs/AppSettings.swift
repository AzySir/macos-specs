import AppKit
import Combine
import Foundation
import SwiftUI

enum Severity: Int, CaseIterable {
    case ok, warn, high, critical
}

struct RGB: Codable, Hashable {
    var r: Double
    var g: Double
    var b: Double

    var color: Color { Color(red: r, green: g, blue: b) }

    init(r: Double, g: Double, b: Double) {
        self.r = r; self.g = g; self.b = b
    }

    init?(_ color: Color) {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
        self.r = Double(ns.redComponent)
        self.g = Double(ns.greenComponent)
        self.b = Double(ns.blueComponent)
    }

    static let defaultOK       = RGB(r: 0.10, g: 0.80, b: 0.95)  // electric cyan
    static let defaultWarn     = RGB(r: 1.00, g: 0.65, b: 0.00)  // amber
    static let defaultHigh     = RGB(r: 0.95, g: 0.27, b: 0.66)  // magenta
    static let defaultCritical = RGB(r: 1.00, g: 0.30, b: 0.35)  // coral red

    static let defaultCPU    = RGB(r: 0.10, g: 0.80, b: 0.95)  // cyan
    static let defaultMemory = RGB(r: 1.00, g: 0.55, b: 0.00)  // amber/orange
    static let defaultGPU    = RGB(r: 0.75, g: 0.40, b: 0.95)  // violet
}

final class AppSettings: ObservableObject {
    enum Keys {
        static let refresh = "refresh.interval"
        static let warnT = "threshold.warn"
        static let highT = "threshold.high"
        static let critT = "threshold.critical"
        static let colOK = "color.ok"
        static let colWarn = "color.warn"
        static let colHigh = "color.high"
        static let colCrit = "color.critical"
        static let showCPU = "show.cpu"
        static let showMem = "show.memory"
        static let showGPU = "show.gpu"
        static let showTherm = "show.thermal"
        static let cpuColor = "color.cpu"
        static let memColor = "color.memory"
        static let gpuColor = "color.gpu"
    }

    @Published var refreshInterval: Double { didSet { saveDouble(Keys.refresh, refreshInterval) } }
    @Published var warnThreshold: Double   { didSet { saveDouble(Keys.warnT, warnThreshold) } }
    @Published var highThreshold: Double   { didSet { saveDouble(Keys.highT, highThreshold) } }
    @Published var criticalThreshold: Double { didSet { saveDouble(Keys.critT, criticalThreshold) } }
    @Published var colorOK: RGB       { didSet { saveRGB(Keys.colOK, colorOK) } }
    @Published var colorWarn: RGB     { didSet { saveRGB(Keys.colWarn, colorWarn) } }
    @Published var colorHigh: RGB     { didSet { saveRGB(Keys.colHigh, colorHigh) } }
    @Published var colorCritical: RGB { didSet { saveRGB(Keys.colCrit, colorCritical) } }
    @Published var showCPU: Bool      { didSet { saveBool(Keys.showCPU, showCPU) } }
    @Published var showMemory: Bool   { didSet { saveBool(Keys.showMem, showMemory) } }
    @Published var showGPU: Bool      { didSet { saveBool(Keys.showGPU, showGPU) } }
    @Published var showThermal: Bool  { didSet { saveBool(Keys.showTherm, showThermal) } }
    @Published var cpuColor: RGB      { didSet { saveRGB(Keys.cpuColor, cpuColor) } }
    @Published var memoryColor: RGB   { didSet { saveRGB(Keys.memColor, memoryColor) } }
    @Published var gpuColor: RGB      { didSet { saveRGB(Keys.gpuColor, gpuColor) } }

    init() {
        let d = UserDefaults.standard
        refreshInterval   = (d.object(forKey: Keys.refresh) as? Double) ?? 1.5
        warnThreshold     = (d.object(forKey: Keys.warnT) as? Double) ?? 40
        highThreshold     = (d.object(forKey: Keys.highT) as? Double) ?? 70
        criticalThreshold = (d.object(forKey: Keys.critT) as? Double) ?? 90
        colorOK           = Self.loadRGB(Keys.colOK) ?? .defaultOK
        colorWarn         = Self.loadRGB(Keys.colWarn) ?? .defaultWarn
        colorHigh         = Self.loadRGB(Keys.colHigh) ?? .defaultHigh
        colorCritical     = Self.loadRGB(Keys.colCrit) ?? .defaultCritical
        showCPU           = (d.object(forKey: Keys.showCPU) as? Bool) ?? true
        showMemory        = (d.object(forKey: Keys.showMem) as? Bool) ?? true
        showGPU           = (d.object(forKey: Keys.showGPU) as? Bool) ?? true
        showThermal       = (d.object(forKey: Keys.showTherm) as? Bool) ?? true
        cpuColor          = Self.loadRGB(Keys.cpuColor) ?? .defaultCPU
        memoryColor       = Self.loadRGB(Keys.memColor) ?? .defaultMemory
        gpuColor          = Self.loadRGB(Keys.gpuColor) ?? .defaultGPU
    }

    func severity(forPercent p: Double) -> Severity {
        if p >= criticalThreshold { return .critical }
        if p >= highThreshold { return .high }
        if p >= warnThreshold { return .warn }
        return .ok
    }

    func severity(for thermal: ProcessInfo.ThermalState) -> Severity {
        switch thermal {
        case .nominal: return .ok
        case .fair: return .warn
        case .serious: return .high
        case .critical: return .critical
        @unknown default: return .ok
        }
    }

    func color(for severity: Severity) -> Color {
        switch severity {
        case .ok: return colorOK.color
        case .warn: return colorWarn.color
        case .high: return colorHigh.color
        case .critical: return colorCritical.color
        }
    }

    func resetToDefaults() {
        refreshInterval = 1.5
        warnThreshold = 40
        highThreshold = 70
        criticalThreshold = 90
        colorOK = .defaultOK
        colorWarn = .defaultWarn
        colorHigh = .defaultHigh
        colorCritical = .defaultCritical
        showCPU = true
        showMemory = true
        showGPU = true
        showThermal = true
        cpuColor = .defaultCPU
        memoryColor = .defaultMemory
        gpuColor = .defaultGPU
    }

    func colorBinding(_ keyPath: ReferenceWritableKeyPath<AppSettings, RGB>) -> Binding<Color> {
        Binding(
            get: { self[keyPath: keyPath].color },
            set: { newColor in
                if let rgb = RGB(newColor) { self[keyPath: keyPath] = rgb }
            }
        )
    }

    private func saveDouble(_ key: String, _ value: Double) {
        UserDefaults.standard.set(value, forKey: key)
    }
    private func saveBool(_ key: String, _ value: Bool) {
        UserDefaults.standard.set(value, forKey: key)
    }
    private func saveRGB(_ key: String, _ rgb: RGB) {
        if let data = try? JSONEncoder().encode(rgb) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    private static func loadRGB(_ key: String) -> RGB? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(RGB.self, from: data)
    }
}
