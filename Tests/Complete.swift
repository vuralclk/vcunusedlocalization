import Foundation

final class CompleteLocalizationManager {
    // MARK: - Basic Keys
    let basicKey = NSLocalizedString("basic.key", comment: "")
    let basicUnderscoreKey = NSLocalizedString("basic_key", comment: "")
    let basicCamelKey = NSLocalizedString("basicKey", comment: "")

    // MARK: - Multiline and Escaped
    let multilineKey = NSLocalizedString("multiline.key", comment: "")
    let escapedQuotes = NSLocalizedString("escaped.quotes", comment: "")
    let escapedCharacters = NSLocalizedString("escaped.characters", comment: "")

    // MARK: - Unicode
    let unicodeBullet = NSLocalizedString("unicode.bullet", comment: "")
    let unicodeEmoji = NSLocalizedString("unicode.emoji", comment: "")
    let unicodeText = NSLocalizedString("unicode.text", comment: "")

    // MARK: - Spacing Variations
    let noSpaces = NSLocalizedString("no.spaces", comment: "")
    let manySpaces = NSLocalizedString("many.spaces", comment: "")
    let tabSpaces = NSLocalizedString("tab.spaces", comment: "")

    // MARK: - Comment Related
    let afterComment = NSLocalizedString("after.comment", comment: "")
    let afterMultilineComment = NSLocalizedString("after.multiline.comment", comment: "")
    let inlineComment = NSLocalizedString("inline.comment", comment: "")

    // MARK: - Special Characters
    let keyWithDots = NSLocalizedString("key.with.dots", comment: "")
    let keyWithUnderscore = NSLocalizedString("key_with_underscore", comment: "")
    let keyWithDash = NSLocalizedString("key-with-dash", comment: "")
    let keyWithSpaces = NSLocalizedString("key with spaces", comment: "")
    let keyWithSlashes = NSLocalizedString("key/with/slashes", comment: "")
    let keyWithPlus = NSLocalizedString("key+with+plus", comment: "")
    let keyWithAmpersand = NSLocalizedString("key&with&ampersand", comment: "")
    let keyWithHash = NSLocalizedString("key#with#hash", comment: "")
    let keyWithAt = NSLocalizedString("key@with@at", comment: "")

    // MARK: - Semicolons and Empty
    let semicolonInValue = NSLocalizedString("semicolon.in.value", comment: "")
    let multipleSemicolons = NSLocalizedString("multiple.semicolons", comment: "")
    let emptyValue = NSLocalizedString("empty.value", comment: "")
    let emptyValueWithSpaces = NSLocalizedString("empty.value.with.spaces", comment: "")

    // MARK: - Complex and Error Cases
    let complexValue = NSLocalizedString("complex.value", comment: "")
    let trailingSpaces = NSLocalizedString("trailing.spaces", comment: "")
    let doubleSemicolon = NSLocalizedString("double.semicolon", comment: "")
    let missingSemicolon = NSLocalizedString("missing.semicolon", comment: "")
    let missingValue = NSLocalizedString("missing.value", comment: "")
    let missingEqualsSign = NSLocalizedString("missing.equals.sign", comment: "")
    let missingQuotes = NSLocalizedString("missing.quotes", comment: "")

    // MARK: - Special Content
    let htmlValue = NSLocalizedString("html.value", comment: "")
    let jsonValue = NSLocalizedString("json.value", comment: "")
    let urlValue = NSLocalizedString("url.value", comment: "")
    let regexValue = NSLocalizedString("regex.value", comment: "")

    // MARK: - Math
    let mathValue = NSLocalizedString("math.value", comment: "")
    let formulaValue = NSLocalizedString("formula.value", comment: "")

    // MARK: - Different Languages
    let chineseValue = NSLocalizedString("chinese.value", comment: "")
    let japaneseValue = NSLocalizedString("japanese.value", comment: "")
    let koreanValue = NSLocalizedString("korean.value", comment: "")
    let russianValue = NSLocalizedString("russian.value", comment: "")
    let arabicValue = NSLocalizedString("arabic.value", comment: "")

    // MARK: - Special Types
    let emojiValue = NSLocalizedString("emoji.value", comment: "")
    let placeholderValue = String(format: NSLocalizedString("placeholder.value", comment: ""), "John")
    let formatValue = String(format: NSLocalizedString("format.value", comment: ""), 42, "John", 3.14)
    let base64Value = NSLocalizedString("base64.value", comment: "")
}
