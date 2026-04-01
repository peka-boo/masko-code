import Foundation

/// Display mode for permission content - compact (speech bubble) or expanded (fullscreen panel).
enum PermissionDisplayMode {
    case compact
    case expanded
}

/// Global auto-allow default setting (persisted)
@Observable
final class AutoAllowSettings {
    static let shared = AutoAllowSettings()

    private let defaultsKey = "autoAllowEnabledByDefault"

    var enabledByDefault: Bool {
        get { UserDefaults.standard.bool(forKey: defaultsKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: defaultsKey)
            // Post notification for observers
            NotificationCenter.default.post(name: .autoAllowDefaultChanged, object: nil)
        }
    }

    private init() {}
}

extension Notification.Name {
    static let autoAllowDefaultChanged = Notification.Name("autoAllowDefaultChanged")
}

/// Shared mutable state for interacting with a pending permission.
/// Stored in PendingPermissionStore, keyed by permission UUID.
/// Both compact and expanded views read/write the same instance.
@Observable
final class PermissionInteractionState {
    // Plan mode (ExitPlanMode)
    var selectedOption: Int = 1
    var feedbackText: String = ""

    // Question mode (AskUserQuestion)
    var selections: [String: String] = [:]
    var multiSelections: [String: Set<String>] = [:]
    var customInputs: [String: String] = [:]
    var usingCustom: Set<String> = []
    var currentQuestionIndex: Int = 0

    // Standard permission
    var isContentExpanded: Bool = false

    // Auto-allow (initialized from global setting)
    var autoAllowEnabled: Bool = AutoAllowSettings.shared.enabledByDefault
    var autoAllowRemainingSeconds: Double = 5.0
    var autoAllowTimer: Timer?
    var autoAllowStartDate: Date?

    /// Build answers dict from current question state.
    func buildAnswers(for questions: [ParsedQuestion]) -> [String: String] {
        var answers: [String: String] = [:]
        for q in questions {
            if usingCustom.contains(q.question) {
                answers[q.question] = customInputs[q.question] ?? ""
            } else if q.multiSelect {
                answers[q.question] = (multiSelections[q.question] ?? []).sorted().joined(separator: ", ")
            } else {
                answers[q.question] = selections[q.question] ?? ""
            }
        }
        return answers
    }

    /// Check if all questions have been answered.
    func allAnswered(for questions: [ParsedQuestion]) -> Bool {
        questions.allSatisfy { q in
            if usingCustom.contains(q.question) {
                return !(customInputs[q.question] ?? "").isEmpty
            }
            if q.multiSelect {
                return !(multiSelections[q.question] ?? []).isEmpty
            }
            return selections[q.question] != nil
        }
    }
}
