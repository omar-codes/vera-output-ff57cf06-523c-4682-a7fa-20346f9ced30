import AppIntents

// Full implementation in Story 6.1
struct CreateTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Task"

    func perform() async throws -> some IntentResult {
        return .result()
    }
}
