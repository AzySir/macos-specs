import Foundation

struct ThermalReading {
    var state: ProcessInfo.ThermalState
    var temperatureCelsius: Double?
    var fanRPM: Double?
}

final class ThermalMonitor {
    private let smc = SMC()

    func sample() -> ThermalReading {
        let state = ProcessInfo.processInfo.thermalState
        let temp = TemperatureReader.cpuTemperature()
        let rpm = try? smc.readFan()
        return ThermalReading(state: state, temperatureCelsius: temp, fanRPM: rpm)
    }
}
