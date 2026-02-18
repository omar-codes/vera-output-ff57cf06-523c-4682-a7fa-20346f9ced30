import AppIntents

// Full implementation in Story 6.1
struct OpenTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Task"

    func perform() async throws -> some IntentResult {
        return .result()
    }
}
