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
            await consoleLogger.logError(
                prefix: "Error scanning files: ",
                with: error
            )
            throw error
        }
    }

    private func scanFileUrls(at path: String) async throws {
        await consoleLogger.logProgress(
            text: "Searching for Localization Keys in .strings files..."
        )
        let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

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
            while let fileUrl = enumerator?.nextObject() as? URL {
                group.addTask(priority: .userInitiated) {
                    switch true {
                    case PathExtensionType.strings.rawValue == fileUrl.pathExtension.lowercased(),
                         fileUrl.path.contains(UnwantedPathComponentType.infoPlist.rawValue) == false,
                         fileUrl.path.contains(UnwantedPathComponentType.pods.rawValue) == false:
                        do {
                            let keys = try await self.localizationParser.parseStringsFile(at: fileUrl)
                            return .init(
                                stringsFilePath: fileUrl.path,
                                localizationKeys: keys,
                                swiftFileUrl: nil
                            )
                        } catch let error {
                            await self.consoleLogger.logError(
                                prefix: "Error: ",
                                with: error
                            )
                            return .init()
                        }
                    case PathExtensionType.swift.rawValue == fileUrl.pathExtension.lowercased():
                        return .init(
                            stringsFilePath: nil,
                            localizationKeys: nil,
                            swiftFileUrl: fileUrl
                        )
                    default:
                        return .init()
                    }
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
        await consoleLogger.logProgress(
            prefix: "Total",
            count: localizationKeys.count,
            suffix: "localization keys found."
        )
        await consoleLogger.logProgress(
            prefix: "Total",
            count: swiftFileUrls.count,
            suffix: "swift files found."
        )
        await consoleLogger.logProgress(
            text: "Searching for unused keys..."
        )

        await visitSwiftFiles()

        await consoleLogger.logProgress(
            text: "Unused Localization Keys:"
        )

        await logUnusedKeys()
    }

    private func logUnusedKeys() async {
        var unusedKeyCount = 0

        for localizationKey in localizationKeys {
            if stringLiterals.contains(localizationKey.key) == false {
                await consoleLogger.logKey(text: localizationKey.key)
                unusedKeyCount += 1
            }
        }

        await consoleLogger.logProgress(
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
                        await self.consoleLogger.logError(
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
