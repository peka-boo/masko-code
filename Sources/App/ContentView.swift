import SwiftUI

struct ContentView: View {
    @Environment(AppStore.self) var appStore
    @State private var selectedSection: SidebarSection = .activityFeed

    enum SidebarSection: String, CaseIterable {
        case activityFeed = "Activity"
        case notifications = "Notifications"
        case sessions = "Sessions"
        case approvals = "Approvals"
        case masko = "Masko"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .activityFeed: "list.bullet"
            case .notifications: "bell"
            case .sessions: "terminal"
            case .approvals: "hand.raised"
            case .masko: "wand.and.stars"
            case .settings: "gear"
            }
        }
    }

    var body: some View {
        if !appStore.hasCompletedOnboarding {
            OnboardingView {
                appStore.hasCompletedOnboarding = true
                // Start services that were deferred during onboarding
                appStore.hotkeyManager.start()
                Task { await appStore.notificationService.requestPermission() }
            }
        } else {
            dashboardView
        }
    }

    private var dashboardView: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: Constants.spacingTight) {
                HStack(spacing: 8) {
                    if let url = Bundle.module.url(forResource: "logo", withExtension: "png", subdirectory: "Images"),
                       let nsImage = NSImage(contentsOf: url) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                    }
                    Text("Masko Code")
                        .font(Constants.fontTitle)
                        .foregroundColor(Constants.textPrimary)
                }
                .padding(.horizontal, Constants.contentPaddingH)
                .padding(.top, Constants.spacingNormal)
                .padding(.bottom, Constants.spacingTight)

                ForEach(SidebarSection.allCases, id: \.self) { section in
                    SidebarNavItem(
                        section: section,
                        isSelected: selectedSection == section,
                        badge: badgeCount(for: section)
                    ) {
                        selectedSection = section
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .background(Constants.surfaceDark)
            .navigationTitle("")
            .toolbar(.hidden, for: .automatic)
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 240)
        } detail: {
            switch selectedSection {
            case .activityFeed: ActivityFeedView()
            case .notifications: NotificationCenterView()
            case .sessions: SessionListView()
            case .approvals: ApprovalRequestView()
            case .masko: MaskoDashboardView()
            case .settings: SettingsView()
            }
        }
        .background(Constants.surfaceElevated)
        .onChange(of: appStore.navigateToMascotId) { _, newId in
            if newId != nil {
                selectedSection = .masko
            }
        }
    }

    private func badgeCount(for section: SidebarSection) -> Int {
        switch section {
        case .notifications: appStore.notificationStore.unreadCount
        case .approvals: appStore.pendingPermissionStore.pending.count
        default: 0
        }
    }
}

// MARK: - Sidebar Nav Item

private struct SidebarNavItem: View {
    let section: ContentView.SidebarSection
    let isSelected: Bool
    let badge: Int
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: section.icon)
                    .font(.system(size: 14))
                    .frame(width: 20)

                Text(section.rawValue)
                    .font(Constants.fontBody)

                Spacer()

                if badge > 0 {
                    Text("\(badge)")
                        .font(Constants.fontSubheadline)
                        .foregroundColor(Constants.orangePrimary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 1)
                        .background(Constants.chip, in: Capsule())
                }
            }
            .padding(.horizontal, Constants.spacingNormal)
            .padding(.vertical, 7)
            .foregroundColor(isSelected ? Constants.orangePrimary : (isHovered ? Constants.textPrimary : Constants.textMuted))
            .background(
                RoundedRectangle(cornerRadius: Constants.cornerRadiusSmall)
                    .fill(isSelected ? Constants.orangePrimaryLight : (isHovered ? Constants.chip : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
