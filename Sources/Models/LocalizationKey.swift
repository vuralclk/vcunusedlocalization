/// A structure representing a localization key, used to uniquely identify each key in a .strings file.
struct LocalizationKey: Hashable {
  /// The localization key, typically extracted from a .strings file.
  let key: String

  /// A flag indicating whether the key is used in the application.
  let isUsed: Bool

  /// Checks if two `LocalizationKey` instances are equal by comparing their `key` properties.
  /// - Parameters:
  ///   - lhs: The left-hand side `LocalizationKey`.
  ///   - rhs: The right-hand side `LocalizationKey`.
  /// - Returns: True if the keys are equal; otherwise, false.
  static func == (
    lhs: LocalizationKey,
    rhs: LocalizationKey
  ) -> Bool {
    lhs.key == rhs.key
  }

  /// Hashes the `key` property to uniquely identify each `LocalizationKey` instance in hash-based collections.
  /// - Parameter hasher: The hasher to use when combining the components of the instance.
  func hash(into hasher: inout Hasher) {
    hasher.combine(key)
  }
}
