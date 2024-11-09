struct LocalizationKey: Hashable {
    let key: String
    let isUsed: Bool

    static func == (lhs: LocalizationKey, rhs: LocalizationKey) -> Bool {
        lhs.key == rhs.key
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(key)
    }
}
