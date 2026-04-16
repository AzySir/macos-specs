import Foundation

struct ProcessRow: Identifiable, Hashable {
    var id: Int32 { pid }
    let pid: Int32
    let name: String
    let cpuPercent: Double
    let memoryBytes: UInt64
}

enum ProcessLister {
    static func listAll() -> [ProcessRow] {
        runPS(extraArgs: [])
    }

    static func topByMemory(limit: Int) -> [ProcessRow] {
        Array(runPS(extraArgs: ["-m"]).prefix(limit))
    }

    static func topByCPU(limit: Int) -> [ProcessRow] {
        Array(runPS(extraArgs: ["-r"]).prefix(limit))
    }

    private static func runPS(extraArgs: [String]) -> [ProcessRow] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-A", "-o", "pid=,pcpu=,rss=,comm="] + extraArgs

        let outPipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = errPipe

        do {
            try task.run()
        } catch {
            NSLog("[MacOSSpecs] ps launch failed: \(error)")
            return []
        }

        let data: Data
        do {
            data = try outPipe.fileHandleForReading.readToEnd() ?? Data()
        } catch {
            NSLog("[MacOSSpecs] ps pipe read failed: \(error)")
            task.terminate()
            return []
        }
        task.waitUntilExit()

        if task.terminationStatus != 0 {
            let errData = (try? errPipe.fileHandleForReading.readToEnd()) ?? Data()
            NSLog("[MacOSSpecs] ps exit \(task.terminationStatus): \(String(data: errData ?? Data(), encoding: .utf8) ?? "")")
        }

        guard let text = String(data: data, encoding: .utf8) else {
            NSLog("[MacOSSpecs] ps output not utf8 (\(data.count) bytes)")
            return []
        }

        var rows: [ProcessRow] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let trimmed = line.drop(while: { $0 == " " })
            let parts = trimmed.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
            guard parts.count >= 4,
                  let pid = Int32(parts[0]),
                  let cpu = Double(parts[1]),
                  let rssKB = UInt64(parts[2]) else { continue }
            let comm = String(parts[3])
            let name = URL(fileURLWithPath: comm).lastPathComponent
            rows.append(ProcessRow(
                pid: pid,
                name: name.isEmpty ? comm : name,
                cpuPercent: cpu,
                memoryBytes: rssKB * 1024
            ))
        }
        if rows.isEmpty {
            NSLog("[MacOSSpecs] ps returned \(data.count) bytes but parsed 0 rows")
        }
        return rows
    }
}

extension Array where Element == ProcessRow {
    func topByMemory(_ n: Int) -> [ProcessRow] {
        Array(sorted { $0.memoryBytes > $1.memoryBytes }.prefix(n))
    }
    func topByCPU(_ n: Int) -> [ProcessRow] {
        Array(sorted { $0.cpuPercent > $1.cpuPercent }.prefix(n))
    }
}
