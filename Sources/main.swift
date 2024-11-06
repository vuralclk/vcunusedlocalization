import ArgumentParser
import Foundation
import SwiftSyntax
import SwiftParser

@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
struct VCUnusedLocalization: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "vcunusedlocalization", 
        abstract: "Scans all files in the project to detect unused localization keys",
        subcommands: [ScanCommand.self]
    )
}

@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
struct ScanCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "scan",
        abstract: "Scans all files in the project to detect unused localization keys"
    )

    @Option(name: .shortAndLong, help: "Project directory path")
    var path: String = FileManager.default.currentDirectoryPath

    func run() async throws {
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
            try await analyzer.analyzeProject(at: path)
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
            print("\n\u{001B}[32m\(step)\u{001B}[0m started...")
        }
        
        currentProgress = current
        let progress = Float(currentProgress) / Float(totalProgress)
        let width = 50
        let filled = Int(Float(width) * progress)
        let empty = width - filled
        
        let bar = String(repeating: "=", count: filled) + String(repeating: " ", count: empty)
        print("\r\u{001B}[32m\(step)\u{001B}[0m [\(bar)] \u{001B}[35m\(Int(progress * 100))%\u{001B}[0m", terminator: "")
        fflush(stdout)
        
        if currentProgress == totalProgress {
            print("\n\u{001B}[93m\(step) completed.\u{001B}[0m")
        }
    }
}

protocol FileScanning {
    func scan(at path: String) async throws
}

actor FileScanner: FileScanning {
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

    func scan(at path: String) async throws {
        do {
            try await findFileUrls(at: path)
            await findUnusedKeys()
        } catch {
            print("Error scanning files: \(error.localizedDescription)")
            throw error
        }
    }

    private func findFileUrls(at path: String) async throws {
        print("\n\u{001B}[93mSearching for Localization Keys in .strings files...\u{001B}[0m")
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
        
        print("\n\u{001B}[93mFound .strings file paths:\u{001B}[0m")
        for path in stringsFilePaths {
            print("\(path)")
        }
    }
    
    private func findUnusedKeys() async {
        print("\n\u{001B}[93mSearching for unused keys...\u{001B}[0m")
        
        print("\n\u{001B}[93mTotal \u{001B}[32m\(localizationKeys.count)\u{001B}[93m localization keys found.\u{001B}[0m")
        print("\n\u{001B}[93mTotal \u{001B}[32m\(swiftFileUrls.count)\u{001B}[93m swift files found.\u{001B}[0m")

        let totalFiles = swiftFileUrls.count

        actor VisitorActor {
            private var currentFile = 0
            private var lastUpdateTime = Date()
            private var averageTimePerFile: TimeInterval = 0
            
            func getCurrentFile() -> Int {
                return currentFile
            }
            
            func incrementCurrentFile() {
                currentFile += 1
            }
            
            func getLastUpdateTime() -> Date {
                return lastUpdateTime
            }
            
            func setLastUpdateTime(_ value: Date) {
                lastUpdateTime = value
            }
            
            func getAverageTimePerFile() -> TimeInterval {
                return averageTimePerFile
            }
            
            func setAverageTimePerFile(_ value: TimeInterval) {
                averageTimePerFile = value
            }
        }

        let visitorActor = VisitorActor()
        var allStringLiterals = Set<String>()

        await withTaskGroup(of: Set<String>.self) { group in
            for fileURL in swiftFileUrls {
                group.addTask {
                    await visitorActor.incrementCurrentFile()
                    do {
                        let sourceFile = try Parser.parse(source: String(contentsOf: fileURL, encoding: .utf8))
                        let visitor = StringLiteralVisitor(viewMode: .sourceAccurate)
                        visitor.walk(sourceFile)
                        let literals = visitor.stringLiterals

                        let currentTime = Date()
                        let lastUpdateTime = await visitorActor.getLastUpdateTime()
                        let elapsedTime = currentTime.timeIntervalSince(lastUpdateTime)
                        await visitorActor.setLastUpdateTime(currentTime)

                        let currentFile = await visitorActor.getCurrentFile()
                        let averageTimePerFile = await visitorActor.getAverageTimePerFile()
                        await visitorActor.setAverageTimePerFile(
                            (
                                averageTimePerFile * Double(
                                    currentFile - 1
                                ) + elapsedTime
                            ) / Double(
                                currentFile
                            )
                        )

                        let remainingFiles = totalFiles - currentFile
                        let estimatedRemainingTime = averageTimePerFile * Double(remainingFiles)

                        let progress = Double(currentFile) / Double(totalFiles)
                        print("\rScanning file \(currentFile)/\(totalFiles) (%\(Int(progress * 100)))... Estimated time remaining: \(Int(estimatedRemainingTime))s", terminator: "")
                        fflush(stdout)

                        return literals

                    } catch {
                        print("\nCould not read file: \(fileURL.lastPathComponent)")
                        return []
                    }
                }
            }

            for await literals in group {
                allStringLiterals.formUnion(literals)
            }
        }

        stringLiterals = allStringLiterals

        print("\n\n\u{001B}[93mUnused Localization Keys:\u{001B}[0m")

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
            for key in keys {
                print("File: \u{001B}[31m\(file)\u{001B}[0m -> Unused Key: \u{001B}[31m\(key.key)\u{001B}[0m")
            }
        }
        
        let totalUnusedKeys = unusedKeysByFile.values.map { $0.count }.reduce(0, +)
        print("\n\u{001B}[93mTotal \u{001B}[31m\(totalUnusedKeys)\u{001B}[93m unused localization keys found.\u{001B}[0m")
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
                (?<!\\)"                           # Başlangıç tırnak işareti (escape edilmemiş)
                (                                  # Key yakalama grubu başlangıcı
                    [^"\\]*                       # Tırnak veya slash olmayan karakterler
                    (?:
                        \\.                       # Escape edilmiş herhangi bir karakter
                        [^"\\]*                   # Tekrar normal karakterler
                    )*
                )                                 # Key yakalama grubu sonu
                "                                 # Bitiş tırnak işareti
                \s*=\s*                          # Eşittir işareti ve opsiyonel boşluklar
                "                                 # Değer başlangıç tırnak işareti
                (?:
                    [^"\\]*                      # Tırnak veya slash olmayan karakterler
                    (?:
                        \\.                      # Escape edilmiş karakterler
                        [^"\\]*                  # Normal karakterler
                    )*
                    (?:\n[^"\\]*)*              # Çok satırlı değerler için
                )
                "                                # Değer bitiş tırnak işareti
                \s*;                             # Noktalı virgül ve opsiyonel boşluklar
                """#,
                options: [.allowCommentsAndWhitespace, .dotMatchesLineSeparators]
            )
        } catch {
            print("Regex pattern hatası: \(error.localizedDescription)")
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
    
    func analyzeProject(at path: String) async throws {
        startTime = Date()

        do {
            try await fileScanner.scan(at: path)
        } catch {
            print("Error analyzing project: \(error.localizedDescription)")
            throw error
        }

        let totalTime = Date().timeIntervalSince(startTime ?? Date())
        print("\n\u{001B}[93mCompleted in:\u{001B}[0m \u{001B}[32m\(String(format: "%.1f", totalTime))s\u{001B}[0m")
    }
}
