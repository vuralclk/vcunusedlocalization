import Foundation

protocol ProjectAnalyzing {
    func analyzeProject(at path: String) async throws
}

final class ProjectAnalyzer {
    private enum ProjectAnalyzer: Error {
        case analyzeFailed
    }

    private let fileScanner: FileScanning
    private let consoleLogger: ConsoleLogging
    private let startTime = Date()

    init(
        fileScanner: FileScanning,
        consoleLogger: ConsoleLogging
    ) {
        self.fileScanner = fileScanner
        self.consoleLogger = consoleLogger
    }

    func analyzeProject(at path: String) async throws {
        do {
            try await fileScanner.scan(at: path)
        } catch {
            consoleLogger.logKey(
                text: "Error analyzing project: \(error.localizedDescription)"
            )
            throw ProjectAnalyzer.analyzeFailed
        }

        let totalTime = Date().timeIntervalSince(startTime)

        consoleLogger.logProgress(
            prefix: "Completed in:",
            text: String(format: "%.1f", totalTime),
            suffix: "s"
        )
    }
}
