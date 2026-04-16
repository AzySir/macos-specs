import SwiftUI
import Combine
import AppKit

enum MetricKind: Hashable {
    case cpu, memory, gpu

    var activityMonitorLabel: String {
        switch self {
        case .cpu:    return "View all CPU usage in Activity Monitor"
        case .memory: return "View all memory usage in Activity Monitor"
        case .gpu:    return "View all GPU usage in Activity Monitor"
        }
    }

    var activityMonitorTab: ActivityMonitorTab? {
        switch self {
        case .cpu:    return .cpu
        case .memory: return .memory
        case .gpu:    return nil
        }
    }
}

enum ActivityMonitorTab: Int {
    case cpu = 1
    case memory = 2
    case energy = 3
    case disk = 4
    case network = 5
}

enum NativeShortcuts {
    private static let amBundleID = "com.apple.ActivityMonitor"

    static func openActivityMonitor(tab: ActivityMonitorTab? = nil) {
        if let tab {
            UserDefaults(suiteName: amBundleID)?.set(tab.rawValue - 1, forKey: "SelectedTab")
        }

        let running = NSRunningApplication.runningApplications(withBundleIdentifier: amBundleID)

        if !running.isEmpty && tab != nil {
            running.forEach { $0.terminate() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                launchActivityMonitor()
            }
        } else {
            launchActivityMonitor()
        }
    }

    private static func launchActivityMonitor() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: amBundleID) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            return
        }
        let fallback = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
        NSWorkspace.shared.openApplication(at: fallback, configuration: NSWorkspace.OpenConfiguration())
    }
}

@MainActor
final class SnapshotViewModel: ObservableObject {
    @Published var snap: Snapshot
    @Published var cpuHistory: [Double] = []
    @Published var memoryHistory: [Double] = []
    @Published var gpuHistory: [Double] = []
    @Published var topByMemory: [ProcessRow] = []
    @Published var topByCPU: [ProcessRow] = []

    private let maxSamples = 60
    private var snapshotCancellable: AnyCancellable?
    private var processTimer: Timer?

    init(sampler: MetricsSampler) {
        self.snap = sampler.snapshot
        self.snapshotCancellable = sampler.$snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snap in
                guard let self = self else { return }
                self.snap = snap
                self.record(snap)
            }
    }

    func startProcessRefresh() {
        processTimer?.invalidate()
        refreshProcesses()
        processTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refreshProcesses() }
        }
    }

    func stopProcessRefresh() {
        processTimer?.invalidate()
        processTimer = nil
    }

    private func record(_ snap: Snapshot) {
        append(snap.cpu / 100.0, to: &cpuHistory)
        append(snap.memoryPressure, to: &memoryHistory)
        append(snap.gpu / 100.0, to: &gpuHistory)
    }

    private func append(_ value: Double, to array: inout [Double]) {
        array.append(value)
        if array.count > maxSamples {
            array.removeFirst(array.count - maxSamples)
        }
    }

    private func refreshProcesses() {
        Task.detached(priority: .utility) { [weak self] in
            let byMem = ProcessLister.topByMemory(limit: 6)
            let byCPU = ProcessLister.topByCPU(limit: 6)
            await MainActor.run { [weak self] in
                self?.topByMemory = byMem
                self?.topByCPU = byCPU
            }
        }
    }
}

struct PopoverView: View {
    @ObservedObject var viewModel: SnapshotViewModel
    @ObservedObject var settings: AppSettings
    @State private var showingSettings = false

    var body: some View {
        Group {
            if showingSettings {
                SettingsView(settings: settings, onBack: { showingSettings = false })
            } else {
                MainView(viewModel: viewModel,
                         settings: settings,
                         onOpenSettings: { showingSettings = true })
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct MainView: View {
    @ObservedObject var viewModel: SnapshotViewModel
    @ObservedObject var settings: AppSettings
    let onOpenSettings: () -> Void
    @State private var expanded: MetricKind? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            Divider()
            metricSection(
                kind: .cpu,
                label: "CPU",
                value: String(format: "%.0f%%", viewModel.snap.cpu),
                history: viewModel.cpuHistory,
                fill: viewModel.snap.cpu,
                color: settings.cpuColor.color,
                processes: viewModel.topByCPU,
                processValue: { String(format: "%.1f%%", $0.cpuPercent) }
            )
            metricSection(
                kind: .memory,
                label: "Memory",
                value: formatGB(used: viewModel.snap.memoryUsedBytes, total: viewModel.snap.memoryTotalBytes),
                history: viewModel.memoryHistory,
                fill: memoryFillPercent,
                color: settings.memoryColor.color,
                processes: viewModel.topByMemory,
                processValue: { formatMemory($0.memoryBytes) }
            )
            metricSection(
                kind: .gpu,
                label: "GPU",
                value: String(format: "%.0f%%", viewModel.snap.gpu),
                history: viewModel.gpuHistory,
                fill: viewModel.snap.gpu,
                color: settings.gpuColor.color,
                processes: nil,
                processValue: { _ in "" }
            )
            thermalRow
            if let rpm = viewModel.snap.fanRPM {
                HStack {
                    Text("Fan").foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.0f RPM", rpm))
                        .font(.system(.body, design: .monospaced))
                }
            }
            Divider()
            footer
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .frame(width: 380)
        .onAppear { viewModel.startProcessRefresh() }
        .onDisappear { viewModel.stopProcessRefresh() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "speedometer")
                .font(.title2)
                .foregroundStyle(.tint)
            Text("MacOSSpecs").font(.title2).fontWeight(.semibold)
            Spacer()
            Button(action: onOpenSettings) {
                Image(systemName: "gearshape").font(.title3)
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
    }

    private func metricSection(
        kind: MetricKind,
        label: String,
        value: String,
        history: [Double],
        fill: Double,
        color: Color,
        processes: [ProcessRow]?,
        processValue: @escaping (ProcessRow) -> String
    ) -> some View {
        let canExpand = processes != nil
        let isExpanded = expanded == kind

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Donut(percent: fill, color: color, lineWidth: 5, diameter: 38)
                Text(label)
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(.secondary)
                Sparkline(values: history, color: color)
                    .frame(height: 28)
                    .layoutPriority(-1)
                Text(value)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(color)
                if canExpand {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard canExpand else { return }
                expanded = (expanded == kind) ? nil : kind
            }

            if isExpanded, let processes = processes {
                processList(processes, color: color, valueFor: processValue, kind: kind)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isExpanded)
    }

    private func processList(_ rows: [ProcessRow], color: Color, valueFor: @escaping (ProcessRow) -> String, kind: MetricKind) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if rows.isEmpty {
                Text("Loading…")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(rows.prefix(5)) { p in
                    HStack {
                        Circle().fill(color.opacity(0.6)).frame(width: 6, height: 6)
                        Text(p.name)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Text(valueFor(p))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                Button {
                    NativeShortcuts.openActivityMonitor(tab: kind.activityMonitorTab)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.forward.square")
                        Text(kind.activityMonitorLabel)
                    }
                    .font(.caption)
                    .foregroundStyle(color)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(.leading, 50)
        .padding(.bottom, 4)
    }

    private var thermalRow: some View {
        let sev = settings.severity(for: viewModel.snap.thermal)
        let color = settings.color(for: sev)
        let tempString: String = {
            if let t = viewModel.snap.temperatureCelsius {
                return String(format: "%.0f°C", t)
            }
            return thermalLabel(viewModel.snap.thermal)
        }()
        let fillPercent = viewModel.snap.temperatureCelsius.map { min(max(($0 - 30) / 70 * 100, 0), 100) } ?? 0

        return HStack(spacing: 12) {
            Donut(percent: fillPercent, color: color, lineWidth: 5, diameter: 38)
            Text("Thermal")
                .font(.system(.title3, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer(minLength: 6)
            HStack(spacing: 8) {
                Circle().fill(color).frame(width: 10, height: 10)
                Text(tempString)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(color)
                Text(thermalLabel(viewModel.snap.thermal))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text("Every \(formatInterval(settings.refreshInterval))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                NativeShortcuts.openActivityMonitor()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.doc.horizontal")
                    Text("Activity Monitor")
                }
            }
            .help("Open Activity Monitor (⌘A)")
            .keyboardShortcut("a")
            Button("Quit") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
    }

    private var memoryFillPercent: Double {
        let total = Double(viewModel.snap.memoryTotalBytes)
        guard total > 0 else { return 0 }
        return Double(viewModel.snap.memoryUsedBytes) / total * 100
    }

    private func formatGB(used: UInt64, total: UInt64) -> String {
        let u = Double(used) / 1_073_741_824
        let t = Double(total) / 1_073_741_824
        return String(format: "%.1f / %.1f GB", u, t)
    }

    private func formatMemory(_ bytes: UInt64) -> String {
        let mb = Double(bytes) / 1_048_576
        if mb >= 1024 { return String(format: "%.2f GB", mb / 1024) }
        return String(format: "%.0f MB", mb)
    }

    private func formatInterval(_ v: Double) -> String {
        v == floor(v) ? String(format: "%.0fs", v) : String(format: "%.1fs", v)
    }

    private func thermalLabel(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
}
