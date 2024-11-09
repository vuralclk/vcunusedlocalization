import Foundation

protocol LocalizationParsing {
    func parseStringsFile(
        at url: URL
    ) async throws -> Set<LocalizationKey>
}

extension LocalizationParser {
    private static let absoluteKeyPattern = #"""
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
        """#
}

final class LocalizationParser: LocalizationParsing {
    private enum LocalizationParserError: Error {
        case couldNotReadFile
    }

    private let consoleLogger: ConsoleLogging
    private let keyPattern: NSRegularExpression

    init(
        consoleLogger: ConsoleLogging,
        keyPattern: String = absoluteKeyPattern
    ) async throws {
        self.consoleLogger = consoleLogger
        do {
            self.keyPattern = try NSRegularExpression(
                pattern: keyPattern,
                options: [.allowCommentsAndWhitespace, .dotMatchesLineSeparators]
            )
        } catch let error {
            await consoleLogger.logError(
                text: "Regex pattern error: \(error.localizedDescription)"
            )
            throw error
        }
    }

    func parseStringsFile(at url: URL) async throws -> Set<LocalizationKey> {
        let fileContent = try await extractFileContent(at: url)

        return extractLocalizationKeys(using: fileContent)
    }

    private func extractLocalizationKeys(
        using fileContent: String
    ) -> Set<LocalizationKey> {
        let range = NSRange(location: 0, length: fileContent.utf16.count)
        let matches = keyPattern.matches(in: fileContent, options: [], range: range)

        var localizationKeys = Set<LocalizationKey>()

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

    private func extractFileContent(at url: URL) async throws -> String {
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

        guard let content else {
            await consoleLogger.logError(
                text: "Could not read file: \(url.lastPathComponent)"
            )
            throw LocalizationParserError.couldNotReadFile
        }

        return content
    }
}
