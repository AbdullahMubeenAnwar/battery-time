import Foundation

struct ProcessSampler {
    func topProcesses(limit: Int = 5, appPIDs: Set<Int>? = nil) -> [ProcessSample] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/top")
        process.arguments = [
            "-o", "power",
            "-l", "1",
            "-n", "\(max(limit + 3, 8))",
            "-stats", "pid,command,power,cpu"
        ]

        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()

        let sema = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in sema.signal() }

        do {
            try process.run()
        } catch {
            return []
        }

        guard sema.wait(timeout: .now() + 5) != .timedOut else {
            process.terminate()
            return []
        }

        guard process.terminationStatus == 0 else {
            return []
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else {
            return []
        }

        var results = processRows(from: text)
            .compactMap(parseLine)
            .filter { $0.energyImpact > 0 && $0.name != "top" }

        if let appPIDs {
            results = results.filter { appPIDs.contains($0.pid) }
        }

        return Array(results.prefix(limit))
    }

    private func parseLine(_ line: Substring) -> ProcessSample? {
        let columns = line.split(separator: " ", omittingEmptySubsequences: true)
        guard columns.count >= 4,
              let pid = Int(columns[0]),
              let energyImpact = Double(columns[columns.count - 2]),
              let cpuPercent = Double(columns[columns.count - 1]) else {
            return nil
        }

        let name = columns.dropFirst().dropLast(2).joined(separator: " ")

        return ProcessSample(
            pid: pid,
            name: name,
            energyImpact: energyImpact,
            cpuPercent: cpuPercent
        )
    }

    private func processRows(from output: String) -> [Substring] {
        let lines = output.split(separator: "\n")
        guard let lastHeaderIndex = lines.lastIndex(where: { $0.hasPrefix("PID") }) else {
            return []
        }

        return Array(lines.dropFirst(lastHeaderIndex + 1))
    }
}
