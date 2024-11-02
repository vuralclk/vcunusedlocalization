import ArgumentParser
import Foundation

struct VCUnusedLocalization: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "vcunusedlocalization", 
        abstract: "Scans all files in the project to detect unused localization keys",
        subcommands: [ScanCommand.self]
    )
}

struct ScanCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "scan",
        abstract: "Scans all files in the project to detect unused localization keys"
    )

    @Option(name: .shortAndLong, help: "Project directory path")
    var path: String = FileManager.default.currentDirectoryPath

    func run() throws {
        do {
            let progressTracker = ProgressTracker()
            let localizationParser = LocalizationParser(
                progressTracker: progressTracker
            )
            let fileScanner = FileScanner(
                progressTracker: progressTracker,
                localizationParser: localizationParser
            )
            let analyzer = LocalizationAnalyzer(
                fileScanner: fileScanner,
                progressTracker: progressTracker
            )
            try analyzer.analyzeProject(at: path)
        } catch {
            print("Error: \(error.localizedDescription)")
            throw error
        }
    }
}

protocol ProgressTracking {
    func updateProgress(_ current: Int, total: Int, step: String)
}

final class ProgressTracker: ProgressTracking {
    private var currentStep: String = ""
    private var currentProgress: Int = 0
    private var totalProgress: Int = 0

    func updateProgress(_ current: Int, total: Int, step: String) {
        if step != currentStep {
            currentStep = step
            currentProgress = 0
            totalProgress = total
            print("\n\(step) started...")
        }
        
        currentProgress = current
        let progress = Float(currentProgress) / Float(totalProgress)
        let width = 50
        let filled = Int(Float(width) * progress)
        let empty = width - filled
        
        let bar = String(repeating: "=", count: filled) + String(repeating: " ", count: empty)
        print("\r\(step) [\(bar)] \(Int(progress * 100))%", terminator: "")
        fflush(stdout)
        
        if currentProgress == totalProgress {
            print("\n\(step) completed.")
        }
    }
}

protocol FileScanning {
    func scan(at path: String) throws
}

final class FileScanner: FileScanning {
    private let progressTracker: ProgressTracking
    private let localizationParser: LocalizationParsing

    private var swiftFileUrls = Set<URL>()
    private var localizationKeys = Set<LocalizationKey>()

    init(
        progressTracker: ProgressTracking,
        localizationParser: LocalizationParsing
    ) {
        self.progressTracker = progressTracker
        self.localizationParser = localizationParser
    }

    func scan(at path: String) throws {
        do {
            try findFileUrls(at: path)
            findUnusedKeys()
        } catch {
            print("Error scanning files: \(error.localizedDescription)")
            throw error
        }
    }

    private func findFileUrls(at path: String) throws {
        print("\n🔍 Searching for .strings file...")
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.pathExtension.lowercased() == "strings" && fileURL.path.contains("tr.lproj") && fileURL.path.contains("InfoPlist.strings") == false {
                print("Found .strings file: \(fileURL.path)")
                do {
                    let keys = try self.localizationParser.parseStringsFile(at: fileURL)
                    self.localizationKeys.formUnion(keys)
                } catch {
                    print("Error: \(error.localizedDescription)")
                }
            } else if fileURL.pathExtension.lowercased() == "swift" {
                swiftFileUrls.insert(fileURL)
            }
        }
    }
    
    private func findUnusedKeys() {
        print("\n🔍 Searching for unused keys...")
        
        let totalOperations = localizationKeys.count
        var currentOperation = 0
        let startTime = Date()

        print("\n- Found total \(localizationKeys.count) localization keys.")
        print("\n- Found total \(swiftFileUrls.count) swift files.")

        var combinedSwiftContent = ""
        let totalFiles = swiftFileUrls.count
        var currentFile = 0

        for fileURL in swiftFileUrls {
            currentFile += 1
            do {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                combinedSwiftContent += content.lowercased()
            } catch {
                print("\n⚠️ Could not read file: \(fileURL.lastPathComponent)")
            }

            let fileProgress = Double(currentFile) / Double(totalFiles)
            let fileElapsedTime = Date().timeIntervalSince(startTime)
            let fileEstimatedTotalTime = fileElapsedTime / fileProgress
            let fileRemainingTime = fileEstimatedTotalTime - fileElapsedTime
            let fileEstimatedEndTime = Date(timeIntervalSinceNow: fileRemainingTime)

            let fileRemainingMinutes = Int(fileRemainingTime) / 60
            let fileRemainingSeconds = Int(fileRemainingTime) % 60

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "HH:mm:ss"

            print("\rFile \(currentFile)/\(totalFiles) (%\(Int(fileProgress * 100))) - Estimated time remaining: \(fileRemainingMinutes) minutes \(fileRemainingSeconds) seconds (Estimated completion: \(dateFormatter.string(from: fileEstimatedEndTime)))", terminator: "")
            fflush(stdout)
        }

        for localizationKey in localizationKeys {
            currentOperation += 1

            if combinedSwiftContent.contains(localizationKey.key.lowercased()) {
                localizationKey.isUsed = true
            }

            let progress = Double(currentOperation) / Double(totalOperations)
            let elapsedTime = Date().timeIntervalSince(startTime)
            let estimatedTotalTime = elapsedTime / progress
            let remainingTime = estimatedTotalTime - elapsedTime
            let estimatedEndTime = Date(timeIntervalSinceNow: remainingTime)

            let remainingMinutes = Int(remainingTime) / 60
            let remainingSeconds = Int(remainingTime) % 60

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "HH:mm:ss"

            print("\rOperation \(currentOperation)/\(totalOperations) (%\(Int(progress * 100))) - Estimated time remaining: \(remainingMinutes) minutes \(remainingSeconds) seconds (Estimated completion: \(dateFormatter.string(from: estimatedEndTime)))", terminator: "")
            fflush(stdout)
        }

        print("\n")

        if self.localizationKeys.isEmpty {
            print("\n⚠️ No localization keys found.")
        } else {
            print("\n📝 All Localization Keys:")
            self.localizationKeys.forEach { key in
                if key.isUsed == false {
                    print("Key: \(key.key), File: \(key.file), Line: \(key.lineNumber), Unused")
                }
            }
        }
    }
}

protocol LocalizationParsing {
    func parseStringsFile(at url: URL) throws -> Set<LocalizationKey>
}

class LocalizationKey: Hashable {
    static func == (lhs: LocalizationKey, rhs: LocalizationKey) -> Bool {
        lhs.key == rhs.key
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(key)
    }

    let key: String
    let file: String
    let lineNumber: Int
    var isUsed: Bool

    init(
        key: String,
        file: String,
        lineNumber: Int,
        isUsed: Bool
    ) {
        self.key = key
        self.file = file
        self.lineNumber = lineNumber
        self.isUsed = isUsed
    }
}

final class LocalizationParser: LocalizationParsing {
    private let keyPattern: NSRegularExpression = {
        do {
            return try NSRegularExpression(
                pattern: #"""
                "([^"]+)"                                  
                \s*=\s*
                "(?:[^"\\]|\\.|\n)*"                      
                \s*;                                       
                """#,
                options: [.allowCommentsAndWhitespace, .dotMatchesLineSeparators]
            )
        } catch {
            print("Regex pattern error: \(error.localizedDescription)")
            exit(1)
        }
    }()
    private let progressTracker: ProgressTracking

    init(
        progressTracker: ProgressTracking
    ) {
        self.progressTracker = progressTracker
    }

    func parseStringsFile(at url: URL) throws -> Set<LocalizationKey> {
        var content: String? = nil
        let encodings: [String.Encoding] = [
            .utf8,
            .utf16,
            .utf16BigEndian,
            .utf16LittleEndian
        ]

        for encoding in encodings {
            if let fileContent = try? String(contentsOf: url, encoding: encoding) {
                content = fileContent
                break
            }
        }
        
        guard let content = content else {
            print("Could not read file: \(url.lastPathComponent)")
            throw NSError(domain: "LocalizationParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not read file: \(url.lastPathComponent)"])
        }
        
        print("\n📄 Analyzing file: \(url.lastPathComponent)")
        
        let range = NSRange(location: 0, length: content.utf16.count)
        let matches = keyPattern.matches(in: content, options: [], range: range)
        
        var localizationKeys = Set<LocalizationKey>()

        for (index, match) in matches.enumerated() {
            progressTracker.updateProgress(index + 1, total: matches.count, step: "Analyzing file")
            
            if let keyRange = Range(match.range(at: 1), in: content) {
                let key = String(content[keyRange])
                let lineNumber = content.prefix(through: content.index(content.startIndex, offsetBy: match.range.location))
                    .components(separatedBy: .newlines)
                    .count
                
                localizationKeys.insert(LocalizationKey(
                    key: key,
                    file: url.lastPathComponent,
                    lineNumber: lineNumber,
                    isUsed: false
                ))
            }
        }
        
        return localizationKeys
    }
}

final class LocalizationAnalyzer {
    private let fileScanner: FileScanning
    private let progressTracker: ProgressTracking
    private var startTime: Date?
    
    init(
        fileScanner: FileScanning,
        progressTracker: ProgressTracking
    ) {
        self.fileScanner = fileScanner
        self.progressTracker = progressTracker
    }
    
    func analyzeProject(at path: String) throws {
        startTime = Date()

        do {
            try fileScanner.scan(at: path)
        } catch {
            print("Error analyzing project: \(error.localizedDescription)")
            throw error
        }

        let totalTime = Date().timeIntervalSince(startTime ?? Date())
        print("\nCompleted in: \(String(format: "%.1f", totalTime))s")
    }
}

VCUnusedLocalization.main()
