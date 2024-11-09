import Foundation

protocol ConsoleLogging {
    func logError(
        prefix: String,
        with error: Error
    )

    func logError(text: String)

    func logProgress(text: String)

    func logProgress(
        prefix: String,
        count: Int,
        suffix: String
    )

    func logProgress(
        prefix: String,
        text: String,
        suffix: String
    )

    func logKey(text: String)
}

final class ConsoleLogger: ConsoleLogging {
    func logError(
        prefix: String,
        with error: Error
    ) {
        print(prefix, error.localizedDescription)
    }

    func logError(text: String) {
        print(text)
    }

    func logProgress(text: String) {
        print("\n\u{001B}[93m\(text)\u{001B}[0m")
    }

    func logProgress(
        prefix: String,
        count: Int,
        suffix: String
    ) {
        print("\n\u{001B}[93m\(prefix) \u{001B}[32m\(count) \u{001B}[93m \(suffix)\u{001B}[0m")
    }

    func logProgress(
        prefix: String,
        text: String,
        suffix: String
    ) {
        print("\n\u{001B}[93m\(prefix) \u{001B}[32m\(text) \u{001B}[93m \(suffix)\u{001B}[0m")
    }

    func logKey(text: String) {
        print("\u{001B}[31m\(text)\u{001B}[0m")
    }
}
