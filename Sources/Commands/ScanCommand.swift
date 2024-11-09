import ArgumentParser
import Foundation

@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
struct ScanCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "scan",
        abstract: "Scans all files in the project to detect unused localization keys"
    )

    @Option(name: .shortAndLong, help: "Project directory path")
    var path: String = FileManager.default.currentDirectoryPath

    func run() async throws {
        let consoleLogger = ConsoleLogger()

        do {
            let localizationParser = try await LocalizationParser(
                consoleLogger: consoleLogger
            )
            let fileScanner = FileScanner(
                localizationParser: localizationParser,
                consoleLogger: consoleLogger,
                fileManager: .default
            )
            let analyzer = ProjectAnalyzer(
                fileScanner: fileScanner,
                consoleLogger: consoleLogger
            )

            try await analyzer.analyzeProject(at: path)
        } catch {
            await consoleLogger.logError(
                prefix: "Error:",
                with: error
            )
            throw error
        }
    }
}
