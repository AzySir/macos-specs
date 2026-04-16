import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    let onBack: () -> Void

    private let intervalOptions: [Double] = [0.5, 1.0, 1.5, 2.0, 3.0, 5.0]
    @State private var launchAtLogin: Bool = LoginItem.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider()
            refreshSection
            Divider()
            startupSection
            Divider()
            menuBarSection
            Divider()
            thresholdsSection
            Divider()
            colorsSection
            Divider()
            HStack {
                Button("Reset to defaults") { settings.resetToDefaults() }
                Spacer()
            }
        }
        .padding(14)
        .frame(width: 380)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)
            Text("Settings").font(.headline)
            Spacer()
        }
    }

    private var refreshSection: some View {
        HStack {
            Text("Refresh every").foregroundStyle(.secondary)
            Spacer()
            Picker("", selection: $settings.refreshInterval) {
                ForEach(intervalOptions, id: \.self) { interval in
                    Text(formatInterval(interval)).tag(interval)
                }
            }
            .labelsHidden()
            .frame(width: 110)
        }
    }

    private var startupSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Startup").foregroundStyle(.secondary).font(.caption)
            Toggle(isOn: Binding(
                get: { launchAtLogin },
                set: { newValue in
                    if LoginItem.setEnabled(newValue) {
                        launchAtLogin = newValue
                    } else {
                        launchAtLogin = LoginItem.isEnabled
                    }
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Launch at login")
                    Text("Open MacOSSpecs automatically when you sign in.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .onAppear {
                launchAtLogin = LoginItem.isEnabled
            }
        }
    }

    private var menuBarSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Show in menu bar").foregroundStyle(.secondary).font(.caption)
            HStack(spacing: 18) {
                Toggle("CPU", isOn: $settings.showCPU)
                Toggle("Memory", isOn: $settings.showMemory)
            }
            HStack(spacing: 18) {
                Toggle("GPU", isOn: $settings.showGPU)
                Toggle("Thermal", isOn: $settings.showThermal)
            }
        }
    }

    private var thresholdsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Severity thresholds").foregroundStyle(.secondary).font(.caption)
            slider("Warn at",     value: $settings.warnThreshold,     range: 5...89,
                   cap: settings.highThreshold - 1)
            slider("High at",     value: $settings.highThreshold,     range: 10...94,
                   floor: settings.warnThreshold + 1,
                   cap: settings.criticalThreshold - 1)
            slider("Critical at", value: $settings.criticalThreshold, range: 20...99,
                   floor: settings.highThreshold + 1)
        }
    }

    private var colorsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Row colors").foregroundStyle(.secondary).font(.caption)
                colorRow("CPU",    binding: settings.colorBinding(\.cpuColor))
                colorRow("Memory", binding: settings.colorBinding(\.memoryColor))
                colorRow("GPU",    binding: settings.colorBinding(\.gpuColor))
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Thermal severity").foregroundStyle(.secondary).font(.caption)
                colorRow("OK",       binding: settings.colorBinding(\.colorOK))
                colorRow("Warn",     binding: settings.colorBinding(\.colorWarn))
                colorRow("High",     binding: settings.colorBinding(\.colorHigh))
                colorRow("Critical", binding: settings.colorBinding(\.colorCritical))
            }
        }
    }

    private func colorRow(_ label: String, binding: Binding<Color>) -> some View {
        HStack {
            Text(label)
            Spacer()
            ColorPicker("", selection: binding, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 44)
        }
    }

    private func slider(_ label: String, value: Binding<Double>, range: ClosedRange<Double>,
                        floor: Double? = nil, cap: Double? = nil) -> some View {
        let constrained = Binding<Double>(
            get: { value.wrappedValue },
            set: { proposed in
                var v = proposed
                if let f = floor { v = max(v, f) }
                if let c = cap   { v = min(v, c) }
                value.wrappedValue = v
            }
        )
        return HStack {
            Text(label).frame(width: 80, alignment: .leading)
            Slider(value: constrained, in: range, step: 1)
            Text(String(format: "%.0f%%", value.wrappedValue))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
    }

    private func formatInterval(_ v: Double) -> String {
        v == floor(v) ? String(format: "%.0fs", v) : String(format: "%.1fs", v)
    }
}
