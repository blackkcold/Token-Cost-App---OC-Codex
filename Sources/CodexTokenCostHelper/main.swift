import Foundation
import CodexTokenCostCore

enum CodexHelperMain {
    static func main() -> Int32 {
        do {
            let arguments = try parseArguments(Array(CommandLine.arguments.dropFirst()))
            let payload = try CodexSessionCollector(
                sourceRoots: arguments.sourceRoots,
                manualSourcePaths: arguments.manualSourcePaths
            ).loadPayload()

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.keyEncodingStrategy = .convertToSnakeCase
            let data = try encoder.encode(payload)
            FileHandle.standardOutput.write(data)
            FileHandle.standardOutput.write(Data([0x0A]))
            return 0
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            FileHandle.standardError.write(Data((message + "\n").utf8))
            return 1
        }
    }

    private static func parseArguments(_ arguments: [String]) throws -> ParsedArguments {
        var sourceRoots: [URL] = []
        var manualSourcePaths: [URL] = []
        var iterator = arguments.makeIterator()

        while let argument = iterator.next() {
            switch argument {
            case "--source-root":
                guard let value = iterator.next(), !value.isEmpty else {
                    throw CodexSessionCollectorError.invalidArgument("Missing value for --source-root.")
                }
                sourceRoots.append(URL(fileURLWithPath: NSString(string: value).expandingTildeInPath))
            case "--manual-source-path":
                guard let value = iterator.next(), !value.isEmpty else {
                    throw CodexSessionCollectorError.invalidArgument("Missing value for --manual-source-path.")
                }
                manualSourcePaths.append(URL(fileURLWithPath: NSString(string: value).expandingTildeInPath))
            default:
                throw CodexSessionCollectorError.invalidArgument("Unsupported helper argument: \(argument)")
            }
        }

        return ParsedArguments(sourceRoots: sourceRoots, manualSourcePaths: manualSourcePaths)
    }
}

private struct ParsedArguments {
    let sourceRoots: [URL]
    let manualSourcePaths: [URL]
}

exit(CodexHelperMain.main())
