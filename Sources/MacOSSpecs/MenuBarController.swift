import AppKit
import Combine
import SwiftUI

@MainActor
final class MenuBarController {
    private let statusItem: NSStatusItem
    private let panel: NSPanel
    private let sampler: MetricsSampler
    private let settings: AppSettings
    private var cancellables: Set<AnyCancellable> = []
    private var outsideClickMonitor: Any?
    private var resignNotification: NSObjectProtocol?

    init(sampler: MetricsSampler, settings: AppSettings) {
        self.sampler = sampler
        self.settings = settings
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let viewModel = SnapshotViewModel(sampler: sampler)
        let hosting = NSHostingView(rootView: PopoverView(viewModel: viewModel, settings: settings))
        hosting.frame = NSRect(x: 0, y: 0, width: 380, height: 560)
        hosting.wantsLayer = true
        hosting.layer?.cornerRadius = 12
        hosting.layer?.masksToBounds = true
        hosting.layer?.borderWidth = 0.5
        hosting.layer?.borderColor = NSColor.separatorColor.cgColor

        let panel = NSPanel(
            contentRect: hosting.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hosting
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .statusBar
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.panel = panel

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePanel(_:))
            button.attributedTitle = BarLabelRenderer.render(.zero, settings: settings)
        }

        sampler.$snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snap in self?.render(snap) }
            .store(in: &cancellables)

        settings.$refreshInterval
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] interval in self?.sampler.restart(interval: interval) }
            .store(in: &cancellables)

        let voidPublishers: [AnyPublisher<Void, Never>] = [
            settings.$showCPU.map { _ in () }.eraseToAnyPublisher(),
            settings.$showMemory.map { _ in () }.eraseToAnyPublisher(),
            settings.$showGPU.map { _ in () }.eraseToAnyPublisher(),
            settings.$showThermal.map { _ in () }.eraseToAnyPublisher(),
            settings.$cpuColor.map { _ in () }.eraseToAnyPublisher(),
            settings.$memoryColor.map { _ in () }.eraseToAnyPublisher(),
            settings.$gpuColor.map { _ in () }.eraseToAnyPublisher()
        ]
        Publishers.MergeMany(voidPublishers)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self = self else { return }
                self.render(self.sampler.snapshot)
            }
            .store(in: &cancellables)
    }

    private func render(_ snap: Snapshot) {
        guard let button = statusItem.button else { return }
        button.attributedTitle = BarLabelRenderer.render(snap, settings: settings)
    }

    @objc private func togglePanel(_ sender: Any?) {
        if panel.isVisible { hidePanel() } else { showPanel() }
    }

    private func showPanel() {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }
        let buttonFrame = buttonWindow.convertToScreen(button.frame)
        let panelWidth = panel.frame.width
        let panelHeight = panel.frame.height

        let screen = button.window?.screen ?? NSScreen.main
        let screenFrame = screen?.visibleFrame ?? .zero

        var origin = NSPoint(
            x: buttonFrame.midX - panelWidth / 2,
            y: buttonFrame.minY - panelHeight - 2
        )
        if origin.x + panelWidth > screenFrame.maxX - 4 {
            origin.x = screenFrame.maxX - panelWidth - 4
        }
        if origin.x < screenFrame.minX + 4 {
            origin.x = screenFrame.minX + 4
        }

        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()

        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.hidePanel() }
        }
        resignNotification = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.hidePanel() }
        }
    }

    private func hidePanel() {
        if panel.isVisible { panel.orderOut(nil) }
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
        if let observer = resignNotification {
            NotificationCenter.default.removeObserver(observer)
            resignNotification = nil
        }
    }
}
