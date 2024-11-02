import ArgumentParser
import Foundation

// MARK: - Command Line Interface
struct VCUnusedLocalization: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "vcunusedlocalization",
        abstract: "İlk .strings dosyasını tarar",
        subcommands: [ScanCommand.self]
    )
}

struct ScanCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "scan",
        abstract: "İlk .strings dosyasını tarar"
    )

    @Option(name: .shortAndLong, help: "Proje dizin yolu")
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
            print("Hata: \(error.localizedDescription)")
            throw error
        }
    }
}

// MARK: - Progress Tracking
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
            print("\n\(step) başlatıldı...")
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
            print("\n\(step) tamamlandı.")
        }
    }
}

// MARK: - File Scanning
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
            print("Dosyalar taranırken hata oluştu: \(error.localizedDescription)")
            throw error
        }
    }

    private func findFileUrls(at path: String) throws {
        print("\n🔍 .strings dosyası aranıyor...")
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.pathExtension.lowercased() == "strings" && fileURL.path.contains("tr.lproj") && fileURL.path.contains("InfoPlist.strings") == false {
                print("Bulunan .strings dosyası: \(fileURL.path)")
                do {
                    let keys = try self.localizationParser.parseStringsFile(at: fileURL)
                    self.localizationKeys.formUnion(keys)
                } catch {
                    print("Hata: \(error.localizedDescription)")
                }
            } else if fileURL.pathExtension.lowercased() == "swift" {
                swiftFileUrls.insert(fileURL)
            }
        }
    }
    
    private func findUnusedKeys() {
        print("\n🔍 Kullanılmayan key'ler aranıyor...")
        
        let totalOperations = localizationKeys.count
        var currentOperation = 0
        let startTime = Date()

        print("\n- Toplam \(localizationKeys.count) adet localizationKey bulundu.")
        print("\n- Toplam \(swiftFileUrls.count) adet swiftFile bulundu.")

        // Tüm Swift dosyalarını tek bir string olarak birleştir
        var combinedSwiftContent = ""
        let totalFiles = swiftFileUrls.count
        var currentFile = 0

        for fileURL in swiftFileUrls {
            currentFile += 1
            do {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                combinedSwiftContent += content.lowercased()
            } catch {
                print("\n⚠️ Dosya okunamadı: \(fileURL.lastPathComponent)")
            }

            // Dosya işleme ilerlemesini hesapla ve yazdır
            let fileProgress = Double(currentFile) / Double(totalFiles)
            let fileElapsedTime = Date().timeIntervalSince(startTime)
            let fileEstimatedTotalTime = fileElapsedTime / fileProgress
            let fileRemainingTime = fileEstimatedTotalTime - fileElapsedTime
            let fileEstimatedEndTime = Date(timeIntervalSinceNow: fileRemainingTime)

            let fileRemainingMinutes = Int(fileRemainingTime) / 60
            let fileRemainingSeconds = Int(fileRemainingTime) % 60

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "HH:mm:ss"

            print("\rDosya \(currentFile)/\(totalFiles) (%\(Int(fileProgress * 100))) - Tahmini kalan süre: \(fileRemainingMinutes) dakika \(fileRemainingSeconds) saniye (Tahmini bitiş: \(dateFormatter.string(from: fileEstimatedEndTime)))", terminator: "")
            fflush(stdout)
        }

        // Her bir localization key'i birleşik string içinde ara
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

            print("\rİşlem \(currentOperation)/\(totalOperations) (%\(Int(progress * 100))) - Tahmini kalan süre: \(remainingMinutes) dakika \(remainingSeconds) saniye (Tahmini bitiş: \(dateFormatter.string(from: estimatedEndTime)))", terminator: "")
            fflush(stdout)
        }

        print("\n") // Yeni satıra geç

        if self.localizationKeys.isEmpty {
            print("\n⚠️ Hiç localization key'i bulunamadı.")
        } else {
            print("\n📝 Tüm Localization Key'leri:")
            self.localizationKeys.forEach { key in
                if key.isUsed == false {
                    print("Key: \(key.key), Dosya: \(key.file), Satır: \(key.lineNumber), Kullanilmiyor")
                }
            }
        }
    }
}

// MARK: - Localization Parsing
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
            print("Regex pattern hatası: \(error.localizedDescription)")
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
            print("Dosya okunamadı: \(url.lastPathComponent)")
            throw NSError(domain: "LocalizationParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "Dosya okunamadı: \(url.lastPathComponent)"])
        }
        
        print("\n📄 Dosya analiz ediliyor: \(url.lastPathComponent)")
        
        let range = NSRange(location: 0, length: content.utf16.count)
        let matches = keyPattern.matches(in: content, options: [], range: range)
        
        var localizationKeys = Set<LocalizationKey>()

        for (index, match) in matches.enumerated() {
            progressTracker.updateProgress(index + 1, total: matches.count, step: "Dosya analiz ediliyor")
            
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

// MARK: - Main Analyzer
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
            print("Proje analiz edilirken hata oluştu: \(error.localizedDescription)")
            throw error
        }

        let totalTime = Date().timeIntervalSince(startTime ?? Date())
        print("\nTamamlandı: \(String(format: "%.1f", totalTime))s")
    }
}

VCUnusedLocalization.main()
