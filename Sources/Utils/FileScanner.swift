import Foundation
import SwiftParser

/// Protocol defining a file scanning task to be performed asynchronously.
protocol FileScanning: Actor {
  /// Scans files at a given path.
  /// - Parameter path: The path of the directory to scan.
  func scan(at path: String) async throws
}

/// A class that scans files for localization keys and identifies unused keys in Swift files.
final actor FileScanner: FileScanning {
  /// Data model for handling tasks in the task group while scanning files.
  private struct ScanFileUrlsTaskGroupModel: Sendable {
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
  
  private let localizationParser: LocalizationParsing
  private let consoleLogger: ConsoleLogging
  private let fileManagerActor: FileManaging
  
  private var swiftFileUrls = Set<URL>()
  private var localizationKeys = Set<LocalizationKey>()
  private var stringLiterals = Set<String>()
  
  init(
    localizationParser: LocalizationParsing,
    consoleLogger: ConsoleLogging,
    fileManagerActor: FileManaging
  ) {
    self.localizationParser = localizationParser
    self.consoleLogger = consoleLogger
    self.fileManagerActor = fileManagerActor
  }
  
  /// Scans files for localization keys and Swift files, then identifies unused keys.
  /// - Parameter path: The root directory path to begin scanning.
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
  
  /// Scans the directory for .strings files and Swift files and collects relevant information.
  /// - Parameter path: The path to scan.
  private func scanFileUrls(
    at path: String
  ) async throws {
    await consoleLogger.logProgress(
      text: "Searching for Localization Keys in .strings files..."
    )
    
    let fileUrls = try await fileManagerActor.enumerateFiles(at: path)
    
    await withTaskGroup(
      of: ScanFileUrlsTaskGroupModel.self
    ) { group in
      for fileUrl in fileUrls {
        group.addTask(priority: .userInitiated) {
          await self.fileUrlTaskGroupModel(for: fileUrl)
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
      
      await group.waitForAll()
    }
  }
  
  /// Identifies the file type (either .strings or Swift) and processes accordingly.
  /// - Parameter fileUrl: The file URL to check.
  /// - Returns: A model containing file path, localization keys, or Swift file URL.
  private func fileUrlTaskGroupModel(
    for fileUrl: URL
  ) async -> ScanFileUrlsTaskGroupModel {
    if PathExtensionType.strings.rawValue == fileUrl.pathExtension.lowercased(),
       fileUrl.path.contains(UnwantedPathComponentType.infoPlist.rawValue) == false,
       fileUrl.path.contains(UnwantedPathComponentType.pods.rawValue) == false {
      do {
        let keys = try await self.localizationParser.parseStringsFile(
          at: fileUrl
        )
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
    } else if PathExtensionType.swift.rawValue == fileUrl.pathExtension.lowercased() {
      return .init(
        stringsFilePath: nil,
        localizationKeys: nil,
        swiftFileUrl: fileUrl
      )
    } else {
      return .init()
    }
  }
  
  /// Logs and identifies unused localization keys by comparing against string literals in Swift files.
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
  
  /// Logs any unused localization keys that were not found in Swift string literals.
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
  
  /// Iterates over Swift files and collects all string literals used.
  private func visitSwiftFiles() async {
    var allStringLiterals = Set<String>()
    
    await withTaskGroup(
      of: Set<String>.self
    ) { group in
      for fileUrl in swiftFileUrls {
        group.addTask(priority: .userInitiated) {
          await self.visitSwiftFile(for: fileUrl)
        }
      }
      
      for await literals in group {
        allStringLiterals.formUnion(literals)
      }
    }
    
    stringLiterals = allStringLiterals
  }
  
  /// Parses a Swift file for string literals and returns them as a set.
  /// - Parameter fileUrl: The URL of the Swift file to parse.
  /// - Returns: A set of string literals found within the file.
  private func visitSwiftFile(for fileUrl: URL) async -> Set<String> {
    do {
      let sourceFile = try Parser.parse(
        source: String(
          contentsOf: fileUrl,
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
