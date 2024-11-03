import ArgumentParser
import Foundation
import SwiftSyntax
import SwiftParser

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
    private var stringLiterals = Set<String>()

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
            print("❌ Error scanning files: \(error.localizedDescription)")
            throw error
        }
    }

    private func findFileUrls(at path: String) throws {
        print("\n🔍 Searching for Localization Keys in .strings files...")
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        
        var stringsFilePaths: [String] = []
        
        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.pathExtension.lowercased() == "strings" && fileURL.path.contains("InfoPlist.strings") == false && fileURL.path.contains("Pods") == false {
                stringsFilePaths.append(fileURL.path)
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
        
        print("\nFound .strings file paths:")
        for path in stringsFilePaths {
            print("      - \(path)")
        }
    }
    
    private func findUnusedKeys() {
        print("\n🔍 Searching for unused keys...")
        
        print("\n📊 Total \(localizationKeys.count) localization keys found.")
        print("\n📱 Total \(swiftFileUrls.count) swift files found.")
        
        let startTime = Date()
        var currentFile = 0
        let totalFiles = swiftFileUrls.count
        var lastUpdateTime = Date()
        var averageTimePerFile: TimeInterval = 0
        
        for fileURL in swiftFileUrls {
            currentFile += 1
            do {
                let sourceFile = try Parser.parse(source: String(contentsOf: fileURL, encoding: .utf8))
                let visitor = StringLiteralVisitor(viewMode: .sourceAccurate)
                visitor.walk(sourceFile)                
                stringLiterals.formUnion(visitor.stringLiterals)

                let currentTime = Date()
                let elapsedTime = currentTime.timeIntervalSince(lastUpdateTime)
                lastUpdateTime = currentTime
                
                averageTimePerFile = (averageTimePerFile * Double(currentFile - 1) + elapsedTime) / Double(currentFile)
                
                let remainingFiles = totalFiles - currentFile
                let estimatedRemainingTime = averageTimePerFile * Double(remainingFiles)
                
                let progress = Double(currentFile) / Double(totalFiles)
                print("\rScanning file \(currentFile)/\(totalFiles) (%\(Int(progress * 100)))... Estimated time remaining: \(Int(estimatedRemainingTime))s", terminator: "")
                fflush(stdout)
                
            } catch {
                print("\n⚠️ Could not read file: \(fileURL.lastPathComponent)")
            }
        }
        
        print("\n📝 Unused Localization Keys:")
        
        var unusedKeysByFile: [String: [LocalizationKey]] = [:]
        
        for key in localizationKeys {
            if !stringLiterals.contains(key.key) {
                if unusedKeysByFile[key.file] == nil {
                    unusedKeysByFile[key.file] = []
                }
                unusedKeysByFile[key.file]?.append(key)
            }
        }
        
        for (file, keys) in unusedKeysByFile {
            print("\n\(file)")
            print("    Unused Keys")
            for key in keys {
                print("        - \(key.key)")
            }
        }
        
        let totalUnusedKeys = unusedKeysByFile.values.map { $0.count }.reduce(0, +)
        print("\n📊 Total \(totalUnusedKeys) unused localization keys found.")
        
        let totalTime = Date().timeIntervalSince(startTime)
        print("\n⏱️ Scan completed in: \(String(format: "%.1f", totalTime))s")
    }
}

class StringLiteralVisitor: SyntaxVisitor {
    var stringLiterals = Set<String>()
    
    override func visit(_ node: StringLiteralExprSyntax) -> SyntaxVisitorContinueKind {
        for segment in node.segments {
            if let text = segment.as(StringSegmentSyntax.self)?.content.text {
                stringLiterals.insert(text)
            }
        }
        return .skipChildren
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

    init(progressTracker: ProgressTracking) {
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

        let range = NSRange(location: 0, length: content.utf16.count)
        let matches = keyPattern.matches(in: content, options: [], range: range)

        var localizationKeys = Set<LocalizationKey>()

        for (index, match) in matches.enumerated() {
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
        print("\n🎉 Completed in: \(String(format: "%.1f", totalTime))s")
    }
}

VCUnusedLocalization.main()
