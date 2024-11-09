import Foundation

protocol LocalizationParsing {
    /// Parses a .strings file at the given URL and returns a set of localization keys.
    /// - Parameter url: The URL of the .strings file.
    /// - Returns: A set of localization keys extracted from the file.
    func parseStringsFile(
        at url: URL
    ) async throws -> Set<LocalizationKey>
}

extension LocalizationParser {
    /// A regular expression pattern to capture localization keys and their values in .strings files.
    /// This pattern captures keys and values in the form "key" = "value"; while supporting escaped characters.
    private static let absoluteKeyPattern = #"""
        (?<!\\)"                           # Starting quotation mark (not escaped)
        (                                  # Beginning of the key capture group
            [^"\\]*                       # Any character that is not a quotation mark or backslash
            (?:
                \\.                       # An escaped character
                [^"\\]*                   # Followed by any non-quotation/backslash characters
            )*
        )                                 # End of the key capture group
        "                                 # Ending quotation mark for the key
        \s*=\s*                           # Equal sign with optional spaces around it
        "                                 # Starting quotation mark for the value
        (?:
            [^"\\]*                       # Any character that is not a quotation mark or backslash
            (?:
                \\.                      # Escaped characters
                [^"\\]*                  # Followed by any normal characters
            )*
            (?:\n[^"\\]*)*               # Support for multi-line values
        )
        "                                 # Ending quotation mark for the value
        \s*;                              # Semicolon with optional spaces after it
        """#
}

final actor LocalizationParser: LocalizationParsing {
    private let consoleLogger: ConsoleLogging
    private let keyPattern: NSRegularExpression

    /// Initializes the LocalizationParser with a console logger and a key pattern.
    /// - Parameters:
    ///   - consoleLogger: An instance of a logger to record parsing events.
    ///   - keyPattern: A regex pattern for extracting localization keys.
    init(
        consoleLogger: ConsoleLogging,
        keyPattern: String = absoluteKeyPattern
    ) async throws {
        self.consoleLogger = consoleLogger
        do {
            // Compile the regex pattern with options to support multi-line values and whitespace comments.
            self.keyPattern = try NSRegularExpression(
                pattern: keyPattern,
                options: [
                    .allowCommentsAndWhitespace,
                    .dotMatchesLineSeparators
                ]
            )
        } catch let error {
            await consoleLogger.logError(
                text: "Regex pattern error: \(error.localizedDescription)"
            )
            throw error
        }
    }

    /// Parses a .strings file and extracts localization keys.
    /// - Parameter url: The URL of the file to parse.
    /// - Returns: A set of localization keys extracted from the file content.
    func parseStringsFile(
        at url: URL
    ) async throws -> Set<LocalizationKey> {
        let fileContent = await extractFileContent(at: url)

        guard let fileContent else {
            return Set<LocalizationKey>()
        }

        return extractLocalizationKeys(using: fileContent)
    }

    /// Uses the regular expression pattern to extract localization keys from file content.
    /// - Parameter fileContent: The content of the .strings file.
    /// - Returns: A set of localization keys extracted from the content.
    private func extractLocalizationKeys(
        using fileContent: String
    ) -> Set<LocalizationKey> {
        let range = NSRange(location: 0, length: fileContent.utf16.count)
        let matches = keyPattern.matches(in: fileContent, options: [], range: range)

        var localizationKeys = Set<LocalizationKey>()

        // Iterate through regex matches to capture keys and insert them into the set.
        matches.forEach { match in
            if let keyRange = Range(match.range(at: 1), in: fileContent) {
                let key = String(fileContent[keyRange])
                localizationKeys.insert(LocalizationKey(
                    key: key,
                    isUsed: false
                ))
            }
        }

        return localizationKeys
    }

    /// Attempts to read the content of the .strings file at the specified URL, trying multiple encodings.
    /// - Parameter url: The URL of the file to read.
    /// - Returns: The file content as a string, or nil if the content couldn't be read.
    private func extractFileContent(
        at url: URL
    ) async -> String? {
        var content: String? = nil
        let encodings: [String.Encoding] = [
            .utf8,
            .utf16,
            .utf16BigEndian,
            .utf16LittleEndian
        ]

        // Try reading file content with different encodings until successful.
        for encoding in encodings {
            if let fileContent = try? String(contentsOf: url, encoding: encoding) {
                content = fileContent
                break
            }
        }

        return content
    }
}
