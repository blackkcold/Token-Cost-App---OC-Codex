import Foundation

public struct OpenCodeZenBalanceChecker: BalanceChecker {
    public var providerKind: BalanceProviderKind { .opencodeZen }

    public init() {}

    public func fetch(authToken: String) async -> BalanceSnapshot {
        guard let binaryURL = Self.locateBinary() else {
            return .unavailable(.opencodeZen, reason: "未找到 opencode CLI")
        }

        let process = Process()
        process.executableURL = binaryURL
        process.arguments = ["stats", "--days", "90", "--models"]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        var launchError: Error?

        let workItem = DispatchWorkItem {
            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                launchError = error
            }
        }

        let queue = DispatchQueue(label: "com.tokencost.opencode-zen")
        queue.async(execute: workItem)

        if workItem.wait(timeout: .now() + 60) == .timedOut {
            workItem.cancel()
            process.terminate()
            return .unavailable(.opencodeZen, reason: "opencode CLI 超时")
        }

        if let error = launchError {
            return .unavailable(.opencodeZen, reason: "无法启动 opencode: \(error.localizedDescription)")
        }

        guard process.terminationStatus == 0 else {
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let stderr = String(data: stderrData, encoding: .utf8) ?? "未知错误"
            return .unavailable(.opencodeZen, reason: "opencode CLI 失败: \(stderr)")
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: stdoutData, encoding: .utf8) ?? ""

        guard let rawTotal = Self.parseTotalCost(from: output) else {
            return .unavailable(.opencodeZen, reason: "无法解析费用数据")
        }

        let goCosts = OpenCodeGoBalanceChecker.parseGoModelCosts(from: output)
        let goSum = goCosts.values.reduce(0, +)
        let zenCost = max(0, rawTotal - goSum)

        let avgCostPerDay = Self.parseAvgCostPerDay(from: output)

        return BalanceSnapshot(
            provider: .opencodeZen,
            fetchedAt: Date(),
            isAvailable: true,
            totalCostUSD: zenCost,
            avgCostPerDayUSD: avgCostPerDay
        )
    }
}

// MARK: - Binary discovery

extension OpenCodeZenBalanceChecker {
    private static func locateBinary() -> URL? {
        // Try PATH via `which opencode`
        let which = Process()
        which.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        which.arguments = ["which", "opencode"]
        let outPipe = Pipe()
        which.standardOutput = outPipe
        do {
            try which.run()
            which.waitUntilExit()
            if which.terminationStatus == 0 {
                let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                let path = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !path.isEmpty {
                    return URL(fileURLWithPath: path)
                }
            }
        } catch {}

        // Fallback paths
        let candidates = [
            "/opt/homebrew/bin/opencode",
            "/usr/local/bin/opencode",
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".opencode/bin/opencode").path,
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".local/bin/opencode").path
        ]

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }

        return nil
    }
}

// MARK: - Parsing

extension OpenCodeZenBalanceChecker {
    private static func parseTotalCost(from output: String) -> Double? {
        parseDollarValue(pattern: #"│Total Cost\s+\$([0-9.]+)"#, in: output)
    }

    private static func parseAvgCostPerDay(from output: String) -> Double? {
        parseDollarValue(pattern: #"│Avg Cost/Day\s+\$([0-9.]+)"#, in: output)
    }

    private static func parseDollarValue(pattern: String, in output: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: output)
        else { return nil }
        return Double(output[captureRange])
    }
}
