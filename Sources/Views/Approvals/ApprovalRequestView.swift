import SwiftUI

struct ApprovalRequestView: View {
    @Environment(AppStore.self) var appStore
    @Environment(ViewClock.self) var clock

    var body: some View {
        let _ = clock.tick
        let pendingItems = appStore.pendingPermissionStore.pending
        let historyItems = appStore.approvalHistoryStore.history

        VStack(spacing: 0) {
            if pendingItems.isEmpty && historyItems.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "hand.raised")
                        .font(.system(size: 36))
                        .foregroundColor(Constants.textMuted)
                    Text("No Approvals")
                        .font(Constants.fontTitle.weight(.semibold))
                        .foregroundColor(Constants.textPrimary)
                    Text("Permission requests from supported assistants will appear here")
                        .font(Constants.fontBody)
                        .foregroundColor(Constants.textMuted)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Constants.lightBackground)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        // Pending section
                        if !pendingItems.isEmpty {
                            sectionHeader("Pending", count: pendingItems.count)
                            ForEach(pendingItems) { permission in
                                PendingApprovalRow(permission: permission)
                                    .environment(appStore)
                                Divider().overlay(Constants.border)
                            }
                        }

                        // History section
                        if !historyItems.isEmpty {
                            sectionHeader("History", count: historyItems.count)
                            ForEach(historyItems) { record in
                                HistoryApprovalRow(record: record)
                                Divider().overlay(Constants.border)
                            }
                        }
                    }
                }
                .background(Constants.lightBackground)
            }
        }
        .background(Constants.lightBackground)
        .navigationTitle("Approvals")
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(Constants.fontSubheadline.weight(.semibold))
                .foregroundColor(Constants.textMuted)
                .textCase(.uppercase)
            Text("\(count)")
                .font(Constants.fontSubheadline.weight(.medium))
                .foregroundColor(Constants.textMuted)
            Spacer()
        }
        .padding(.horizontal, Constants.contentPaddingH)
        .padding(.top, Constants.contentPaddingH)
        .padding(.bottom, Constants.spacingTight)
    }
}

// MARK: - Pending Approval Row

private struct PendingApprovalRow: View {
    @Environment(AppStore.self) var appStore
    let permission: PendingPermission

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundColor(Constants.orangePrimary)
                .frame(width: 24)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(permission.toolName)
                        .font(Constants.fontHeadline.weight(.semibold))
                        .foregroundColor(Constants.textPrimary)
                    Spacer()
                }

                if let projectName = permission.event.projectName {
                    Text(projectName)
                        .font(Constants.fontBody)
                        .foregroundColor(Constants.textMuted)
                        .lineLimit(2)
                }

                HStack {
                    Text(relativeTimeString(from: permission.event.receivedAt))
                        .font(Constants.fontSubheadline)
                        .foregroundColor(Constants.textMuted)

                    Text("·")
                        .foregroundColor(Constants.textMuted)
                    Text(permission.event.assistantDisplayName)
                        .font(Constants.fontSubheadline)
                        .foregroundColor(Constants.textMuted)

                    Spacer()

                    Button("Deny") {
                        appStore.pendingPermissionStore.resolve(id: permission.id, decision: .deny)
                    }
                    .buttonStyle(BrandGhostButton(color: Constants.destructiveRed))
                }
            }
        }
        .padding(.horizontal, Constants.contentPaddingH)
        .padding(.vertical, 10)
    }
}

// MARK: - History Approval Row

private struct HistoryApprovalRow: View {
    let record: ApprovalRecord

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: outcomeIcon)
                .font(.system(size: 14))
                .foregroundColor(outcomeColor)
                .frame(width: 24)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(record.toolName)
                        .font(Constants.fontHeadline.weight(.semibold))
                        .foregroundColor(Constants.textPrimary)
                    Spacer()
                    outcomeBadge
                }

                if let summary = record.toolInputSummary {
                    Text(summary)
                        .font(Constants.fontBody)
                        .foregroundColor(Constants.textMuted)
                        .lineLimit(2)
                }

                HStack {
                    Text(relativeTimeString(from: record.createdAt))
                        .font(Constants.fontSubheadline)
                        .foregroundColor(Constants.textMuted)

                    Text("·")
                        .foregroundColor(Constants.textMuted)
                    Text("resolved ")
                        .font(Constants.fontSubheadline)
                        .foregroundColor(Constants.textMuted)
                    + Text(relativeTimeString(from: record.resolvedAt))
                        .font(Constants.fontSubheadline)
                        .foregroundColor(Constants.textMuted)

                    Spacer()
                }
            }
        }
        .padding(.horizontal, Constants.contentPaddingH)
        .padding(.vertical, 10)
    }

    // MARK: - Outcome helpers

    private var outcomeIcon: String {
        switch record.outcome {
        case .allowed: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .expired: return "clock.fill"
        case .unknown: return "questionmark.circle"
        case .pending: return "exclamationmark.triangle.fill"
        }
    }

    private var outcomeColor: Color {
        switch record.outcome {
        case .allowed: return Color(.sRGB, red: 22/255, green: 163/255, blue: 74/255)
        case .denied: return Constants.destructiveRed
        case .expired: return Constants.textMuted
        case .unknown: return Constants.textMuted
        case .pending: return Constants.orangePrimary
        }
    }

    @ViewBuilder
    private var outcomeBadge: some View {
        let (label, color) = badgeConfig
        Text(label)
            .font(Constants.fontSubheadline.weight(.medium))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.10), in: Capsule())
    }

    private var badgeConfig: (String, Color) {
        switch record.outcome {
        case .allowed:
            return ("Allowed", Color(.sRGB, red: 22/255, green: 163/255, blue: 74/255))
        case .denied:
            return ("Denied", Constants.destructiveRed)
        case .expired:
            return ("Expired", Constants.textMuted)
        case .unknown:
            return ("Terminal", Constants.textMuted)
        case .pending:
            return ("Pending", Constants.orangePrimary)
        }
    }
}
