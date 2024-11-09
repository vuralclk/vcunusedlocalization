import Foundation

/// Protocol for defining a project analysis process.
protocol ProjectAnalyzing {
    /// Analyzes a project at the specified path.
    /// - Parameter path: The path of the project directory to analyze.
    func analyzeProject(at path: String) async throws
}

/// A class responsible for analyzing a project, including scanning files and logging the process.
final class ProjectAnalyzer {
    /// Enum representing errors specific to the project analysis process.
    private enum ProjectAnalyzerError: Error {
        case analyzeFailed
    }

    private let fileScanner: FileScanning
    private let consoleLogger: ConsoleLogging

    /// Records the start time of the analysis to measure duration.
    private let startTime = Date()

    /// Initializes the ProjectAnalyzer with required dependencies.
    /// - Parameters:
    ///   - fileScanner: An instance of `FileScanning` to perform file scans.
    ///   - consoleLogger: An instance of `ConsoleLogging` to handle logging.
    init(
        fileScanner: FileScanning,
        consoleLogger: ConsoleLogging
    ) {
        self.fileScanner = fileScanner
        self.consoleLogger = consoleLogger
    }

    /// Initiates the project analysis, scanning files and logging progress.
    /// - Parameter path: The path of the project directory to analyze.
    func analyzeProject(at path: String) async throws {
        do {
            try await fileScanner.scan(at: path)
        } catch {
            await consoleLogger.logKey(
                text: "Error analyzing project: \(error.localizedDescription)"
            )
            throw ProjectAnalyzerError.analyzeFailed
        }

        let totalTime = Date().timeIntervalSince(startTime)

        await consoleLogger.logProgress(
            prefix: "Completed in:",
            text: String(format: "%.1f", totalTime),
            suffix: "s"
        )
    }
}
