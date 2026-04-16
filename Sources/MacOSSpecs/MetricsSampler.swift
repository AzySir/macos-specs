import Foundation
import Combine

struct Snapshot: Equatable {
    var cpu: Double
    var memoryPressure: Double
    var memoryUsedBytes: UInt64
    var memoryTotalBytes: UInt64
    var gpu: Double
    var thermal: ProcessInfo.ThermalState
    var temperatureCelsius: Double?
    var fanRPM: Double?

    static let zero = Snapshot(
        cpu: 0,
        memoryPressure: 0,
        memoryUsedBytes: 0,
        memoryTotalBytes: 0,
        gpu: 0,
        thermal: .nominal,
        temperatureCelsius: nil,
        fanRPM: nil
    )
}

final class MetricsSampler: ObservableObject {
    @Published private(set) var snapshot: Snapshot = .zero

    private let cpu = CPUMonitor()
    private let memory = MemoryMonitor()
    private let gpu = GPUMonitor()
    private let thermal = ThermalMonitor()

    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "dev.macos-specs.sampler", qos: .utility)

    func start(interval: TimeInterval = 1.5) {
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(), repeating: interval, leeway: .milliseconds(150))
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        timer = t
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    func restart(interval: TimeInterval) {
        stop()
        start(interval: interval)
    }

    private func tick() {
        let cpuValue = cpu.sample()
        let memoryValue = memory.sample()
        let gpuValue = gpu.sample()
        let thermalValue = thermal.sample()

        let snap = Snapshot(
            cpu: cpuValue,
            memoryPressure: memoryValue.pressure,
            memoryUsedBytes: memoryValue.usedBytes,
            memoryTotalBytes: memoryValue.totalBytes,
            gpu: gpuValue,
            thermal: thermalValue.state,
            temperatureCelsius: thermalValue.temperatureCelsius,
            fanRPM: thermalValue.fanRPM
        )

        DispatchQueue.main.async { [weak self] in
            self?.snapshot = snap
        }
    }
}
