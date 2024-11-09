import Foundation
import SwiftParser

protocol FileScanning {
    func scan(at path: String) async throws
}

actor FileScanner: FileScanning {
    private enum PathExtensionType: String {
        case swift
        case strings
    }

    private enum UnwantedPathComponentType: String {
        case infoPlist = "InfoPlist.strings"
        case pods = "Pods"
        case carthage = "Carthage"
    }

    private let localizationParser: LocalizationParsing
    private let consoleLogger: ConsoleLogging
    private let fileManager: FileManager

    private var swiftFileUrls = Set<URL>()
    private var localizationKeys = Set<LocalizationKey>()
    private var stringLiterals = Set<String>()

    init(
        localizationParser: LocalizationParsing,
        consoleLogger: ConsoleLogging,
        fileManager: FileManager
    ) {
        self.localizationParser = localizationParser
        self.consoleLogger = consoleLogger
        self.fileManager = fileManager
    }

    func scan(at path: String) async throws {
        do {
            try await scanFileUrls(at: path)
            await scanUnusedKeys()
        } catch {
            consoleLogger.logError(
                prefix: "Error scanning files: ",
                with: error
            )
            throw error
        }
    }

    private func scanFileUrls(at path: String) async throws {
        consoleLogger.logProgress(
            text: "Searching for Localization Keys in .strings files..."
        )
        let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        var stringsFilePaths = [String]()
        var localizationKeys = Set<LocalizationKey>()

        struct ReturnType: Sendable {
            let stringsFilePath: String?
            let localizationKeys: Set<LocalizationKey>?
            let swiftFileUrl: URL?

            init(
                stringsFilePath: String? = nil,
                localizationKeys: Set<LocalizationKey>? = nil,
                swiftFileUrl: URL? = nil
            ) {
                self.stringsFilePath = stringsFilePath
                self.localizationKeys = localizationKeys
                self.swiftFileUrl = swiftFileUrl
            }
        }

        await withTaskGroup(of: ReturnType.self) { group in
            while let fileURL = enumerator?.nextObject() as? URL {
                group.addTask(priority: .userInitiated) {
                    if fileURL.pathExtension.lowercased() == "strings",
                       fileURL.path.contains("InfoPlist.strings") == false,
                       fileURL.path.contains("Pods") == false {
                        do {
                            let keys = try await self.localizationParser.parseStringsFile(at: fileURL)
                            return .init(
                                stringsFilePath: fileURL.path,
                                localizationKeys: keys,
                                swiftFileUrl: nil
                            )
                        } catch {
                            print("Error: \(error.localizedDescription)")
                        }
                    } else if fileURL.pathExtension.lowercased() == "swift" {
                        return .init(
                            stringsFilePath: nil,
                            localizationKeys: nil,
                            swiftFileUrl: fileURL
                        )
                    } else {
                        return .init()
                    }
                    return  .init()
                }
            }

            for await returnType in group {
                if let localizationKeys = returnType.localizationKeys {
                    self.localizationKeys.formUnion(localizationKeys)
                }

                if let swiftFileUrl = returnType.swiftFileUrl {
                    self.swiftFileUrls.insert(swiftFileUrl)
                }
            }
        }
    }

    private func scanUnusedKeys() async {
        consoleLogger.logProgress(
            prefix: "Total",
            count: localizationKeys.count,
            suffix: "localization keys found."
        )
        consoleLogger.logProgress(
            prefix: "Total",
            count: swiftFileUrls.count,
            suffix: "swift files found."
        )
        consoleLogger.logProgress(
            text: "Searching for unused keys..."
        )

        await visitSwiftFiles()

        consoleLogger.logProgress(
            text: "Unused Localization Keys:"
        )

        logUnusedKeys()
    }

    private func logUnusedKeys() {
        var unusedKeyCount = 0

        localizationKeys.forEach {
            if stringLiterals.contains($0.key) == false {
                consoleLogger.logKey(text: $0.key)
                unusedKeyCount += 1
            }
        }

        consoleLogger.logProgress(
            prefix: "Total",
            count: unusedKeyCount,
            suffix: "unused localization keys found."
        )
    }

    private func visitSwiftFiles() async {
        var allStringLiterals = Set<String>()

        await withTaskGroup(of: Set<String>.self) { group in
            for fileURL in swiftFileUrls {
                group.addTask(priority: .userInitiated) {
                    do {
                        let sourceFile = try Parser.parse(
                            source: String(
                                contentsOf: fileURL,
                                encoding: .utf8
                            )
                        )

                        let visitor = StringLiteralVisitor(
                            viewMode: .sourceAccurate
                        )

                        visitor.walk(sourceFile)

                        return visitor.stringLiterals
                    } catch let error {
                        self.consoleLogger.logError(
                            prefix: "Could not read file:",
                            with: error
                        )
                        return []
                    }
                }
            }

            for await literals in group {
                allStringLiterals.formUnion(literals)
            }
        }

        stringLiterals = allStringLiterals
    }
}
