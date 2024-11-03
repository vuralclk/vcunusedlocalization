import Foundation

final class PartialLocalizationManager {
    // MARK: - Basic Keys
    let basicKey = NSLocalizedString("basic.key", comment: "")
    let basicUnderscoreKey = NSLocalizedString("basic_key", comment: "")

    // MARK: - Special Cases
    let multilineKey = NSLocalizedString("multiline.key", comment: "")
    let emojiValue = NSLocalizedString("emoji.value", comment: "")

    // MARK: - Formatted
    let placeholderValue = String(format: NSLocalizedString("placeholder.value", comment: ""), "Alice")
}
