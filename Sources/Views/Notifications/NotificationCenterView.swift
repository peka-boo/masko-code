import SwiftUI

struct NotificationCenterView: View {
    @Environment(AppStore.self) var appStore
    @Environment(ViewClock.self) var clock
    @State private var showClearAllConfirmation = false

    var body: some View {
        let _ = clock.tick
        let isEmpty = appStore.notificationStore.notifications.isEmpty
        let hasUnread = appStore.notificationStore.unreadCount > 0

        VStack(spacing: 0) {
            HStack {
                Text("Notifications")
                    .font(Constants.fontTitle)
                    .foregroundColor(Constants.textPrimary)
                Spacer()
                Button("Mark All Read") {
                    appStore.notificationStore.markAllAsRead()
                }
                .buttonStyle(.plain)
                .font(Constants.fontBody)
                .foregroundColor(hasUnread ? Constants.orangePrimary : Constants.textMuted)
                .disabled(!hasUnread)

                Button("Clear All") {
                    showClearAllConfirmation = true
                }
                .buttonStyle(.plain)
                .font(Constants.fontBody)
                .foregroundColor(isEmpty ? Constants.textMuted : Constants.destructiveRed)
                .disabled(isEmpty)
            }
            .padding(.horizontal, Constants.contentPaddingH)
            .padding(.vertical, Constants.spacingNormal)

            Divider().overlay(Constants.border)

            if isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "bell")
                        .font(.system(size: 36))
                        .foregroundColor(Constants.textMuted)
                    Text("No Notifications")
                        .font(Constants.fontTitle)
                        .foregroundColor(Constants.textPrimary)
                    Text("Notifications from Claude Code and Codex will appear here")
                        .font(Constants.fontBody)
                        .foregroundColor(Constants.textMuted)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Constants.darkBackground)
            } else {
                List(appStore.notificationStore.notifications) { notification in
                    NotificationRow(notification: notification)
                        .onTapGesture {
                            appStore.notificationStore.markAsRead(notification.id)
                        }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
                .background(Constants.darkBackground)
            }
        }
        .background(Constants.darkBackground)
        .overlay {
            if showClearAllConfirmation {
                ClearAllConfirmationDialog(
                    onConfirm: {
                        appStore.notificationStore.clearAll()
                        showClearAllConfirmation = false
                    },
                    onCancel: {
                        showClearAllConfirmation = false
                    }
                )
            }
        }
    }
}

// MARK: - Clear All Confirmation Dialog

private struct ClearAllConfirmationDialog: View {
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.white.opacity(0.08)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }

            VStack(spacing: 16) {
                Image(systemName: "trash")
                    .font(.system(size: 28))
                    .foregroundColor(Constants.destructiveRed)

                Text("Clear All Notifications")
                    .font(Constants.fontTitle)
                    .foregroundColor(Constants.textPrimary)

                Text("This will permanently delete all notifications.")
                    .font(Constants.fontBody)
                    .foregroundColor(Constants.textMuted)
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    Button("Cancel") { onCancel() }
                        .buttonStyle(.plain)
                        .font(Constants.fontBody)
                        .foregroundColor(Constants.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Constants.spacingTight)
                        .background(
                            RoundedRectangle(cornerRadius: Constants.cornerRadiusSmall)
                                .stroke(Constants.border, lineWidth: 1)
                        )

                    Button("Clear All") { onConfirm() }
                        .buttonStyle(.plain)
                        .font(Constants.fontBody)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Constants.spacingTight)
                        .background(
                            RoundedRectangle(cornerRadius: Constants.cornerRadiusSmall)
                                .fill(Constants.destructiveRed)
                        )
                }
            }
            .padding(Constants.spacingSection)
            .frame(width: 320)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Constants.surfaceWhite)
                    .shadow(color: Color.white.opacity(0.08), radius: 20, y: 8)
            )
        }
    }
}

struct NotificationRow: View {
    let notification: AppNotification
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(notification.isRead ? Color.clear : Constants.orangePrimary)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(notification.title)
                    .font(notification.isRead
                        ? Constants.fontSubheadline
                        : Constants.fontHeadline)
                    .foregroundColor(Constants.textPrimary)

                if let body = notification.body {
                    Text(body)
                        .font(Constants.fontFootnote)
                        .foregroundColor(Constants.textMuted)
                        .lineLimit(compact ? 1 : 2)
                }

                if !compact {
                    HStack {
                        Text(notification.category.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(Constants.fontSubheadline)
                            .foregroundColor(Constants.orangePrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Constants.chip, in: Capsule())

                        Spacer()

                        Text(relativeTimeString(from: notification.createdAt))
                            .font(Constants.fontSubheadline)
                            .foregroundColor(Constants.textMuted)
                    }
                }
            }
        }
        .padding(.vertical, compact ? 2 : 4)
        .opacity(notification.isRead ? 0.7 : 1)
    }
}
