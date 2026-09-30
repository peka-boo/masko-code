import Foundation

enum NotificationCategory: String, Codable, CaseIterable {
    case permissionRequest = "permission_request"
    case idleAlert = "idle_alert"
    case elicitationDialog = "elicitation_dialog"
    case sessionLifecycle = "session_lifecycle"
    case taskCompleted = "task_completed"
    case toolFailed = "tool_failed"
    case generationComplete = "generation_complete"
    case generationFailed = "generation_failed"
    case auth
    case system
}

extension NotificationCategory {
    var displayName: String {
        switch self {
        case .permissionRequest: "Permission Requests"
        case .idleAlert: "Idle Alerts"
        case .elicitationDialog: "Input Requests"
        case .sessionLifecycle: "Session Lifecycle"
        case .taskCompleted: "Task Completed"
        case .toolFailed: "Tool Failures"
        case .generationComplete: "Generation Complete"
        case .generationFailed: "Generation Failed"
        case .auth: "Authentication"
        case .system: "System"
        }
    }

    var detailText: String {
        switch self {
        case .permissionRequest: "Assistant needs approval to run a tool"
        case .idleAlert: "Assistant has been waiting for you"
        case .elicitationDialog: "Assistant asked a question"
        case .sessionLifecycle: "Sessions started, ended, or finished"
        case .taskCompleted: "A task finished running"
        case .toolFailed: "A tool call failed"
        case .generationComplete: "Mascot generation finished"
        case .generationFailed: "Mascot generation failed"
        case .auth: "Sign-in and authorization events"
        case .system: "App-level system messages"
        }
    }
}

enum NotificationPriority: String, Codable {
    case low, normal, high, urgent
}

enum ResolutionOutcome: String, Codable {
    case pending
    case allowed
    case denied
    case expired
    case unknown  // answered from terminal — outcome not tracked
}

struct AppNotification: Identifiable, Codable, Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    let id: UUID
    let title: String
    let body: String?
    let category: NotificationCategory
    let priority: NotificationPriority
    var isRead: Bool
    var readAt: Date?
    var resolutionOutcome: ResolutionOutcome
    var resolvedAt: Date?
    let eventId: UUID?
    let sessionId: String?
    let jobId: UUID?
    let collectionId: UUID?
    let actionUrl: String?
    let deviceName: String?
    let createdAt: Date

    init(
        title: String,
        body: String? = nil,
        category: NotificationCategory,
        priority: NotificationPriority = .normal,
        eventId: UUID? = nil,
        sessionId: String? = nil,
        jobId: UUID? = nil,
        collectionId: UUID? = nil,
        actionUrl: String? = nil,
        deviceName: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.body = body
        self.category = category
        self.priority = priority
        self.isRead = false
        self.readAt = nil
        self.resolutionOutcome = category == .permissionRequest ? .pending : .allowed
        self.resolvedAt = nil
        self.eventId = eventId
        self.sessionId = sessionId
        self.jobId = jobId
        self.collectionId = collectionId
        self.actionUrl = actionUrl
        self.deviceName = deviceName ?? Host.current().localizedName
        self.createdAt = Date()
    }
}
