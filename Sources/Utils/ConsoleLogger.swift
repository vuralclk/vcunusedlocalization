import Foundation

/// Protocol defining console logging methods to handle various types of log messages such as errors and progress updates.
protocol ConsoleLogging: Actor {
  /// Logs an error with a custom prefix.
  /// - Parameters:
  ///   - prefix: A prefix to add context to the error message.
  ///   - error: The error to be logged.
  func logError(
    prefix: String,
    with error: Error
  )

  /// Logs an error message as plain text.
  /// - Parameter text: The error message to log.
  func logError(text: String)

  /// Logs a progress update message.
  /// - Parameter text: The progress message to log.
  func logProgress(text: String)

  /// Logs a progress update with a prefix, count, and suffix to provide additional context.
  /// - Parameters:
  ///   - prefix: A string to appear before the count.
  ///   - count: The current progress count.
  ///   - suffix: A string to appear after the count.
  func logProgress(
    prefix: String,
    count: Int,
    suffix: String
  )

  /// Logs a progress update with a prefix, custom text, and suffix.
  /// - Parameters:
  ///   - prefix: A string to appear before the text.
  ///   - text: Custom text representing the progress.
  ///   - suffix: A string to appear after the text.
  func logProgress(
    prefix: String,
    text: String,
    suffix: String
  )

  /// Logs a key message in a specific color format.
  /// - Parameter text: The key text to log.
  func logKey(text: String)
}

/// Implementation of the `ConsoleLogging` protocol, providing specific console log methods for error and progress messages.
final actor ConsoleLogger: ConsoleLogging {
  func logError(
    prefix: String,
    with error: Error
  ) {
    print(prefix, error.localizedDescription)
  }

  func logError(text: String) {
    print(text)
  }

  /// Logs progress messages in yellow color to highlight ongoing actions.
  func logProgress(text: String) {
    print("\n\u{001B}[93m\(text)\u{001B}[0m")
  }

  /// Logs progress with a prefix and count, using yellow and green colors for distinction.
  func logProgress(
    prefix: String,
    count: Int,
    suffix: String
  ) {
    print("\n\u{001B}[93m\(prefix) \u{001B}[32m\(count) \u{001B}[93m \(suffix)\u{001B}[0m")
  }

  /// Logs progress with a prefix, text, and suffix, formatted in yellow and green colors.
  func logProgress(
    prefix: String,
    text: String,
    suffix: String
  ) {
    print("\n\u{001B}[93m\(prefix) \u{001B}[32m\(text) \u{001B}[93m \(suffix)\u{001B}[0m")
  }

  /// Logs a key message in red color to indicate its importance or error status.
  func logKey(text: String) {
    print("\u{001B}[31m\(text)\u{001B}[0m")
  }
}
