import Foundation
import CodexTokenCostCore

enum CodexHelperRunner {
    static func loadPayload(settings: TokenCostSettings, timeout: TimeInterval = 15) throws -> CodexDashboardPayload {
        let process = Process()
        process.executableURL = CodexAppPaths.helperBinaryURL
        process.arguments = buildArguments(for: settings)

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let timeoutItem = DispatchWorkItem {
            if process.isRunning {
                process.terminate()
            }
        }

        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + timeout, execute: timeoutItem)

        try process.run()
        process.waitUntilExit()
        timeoutItem.cancel()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let stderrText = String(data: stderrData, encoding: .utf8) ?? "Unknown helper failure."
            throw NSError(
                domain: "CodexTokenCostApp.HelperRunner",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: stderrText.isEmpty ? "Codex helper failed." : stderrText]
            )
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(CodexDashboardPayload.self, from: stdoutData)
    }

    private static func buildArguments(for settings: TokenCostSettings) -> [String] {
        var arguments: [String] = []
        for root in settings.effectiveSourceRoots {
            arguments.append(contentsOf: ["--source-root", root])
        }
        for path in settings.effectiveManualSourcePaths {
            arguments.append(contentsOf: ["--manual-source-path", path])
        }
        return arguments
    }
}
