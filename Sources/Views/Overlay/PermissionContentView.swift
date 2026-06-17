import MarkdownUI
import SwiftUI

/// Unified permission content view that renders in either compact (speech bubble)
/// or expanded (fullscreen panel) mode. Handles all 3 permission types:
/// ExitPlanMode (plan), AskUserQuestion, and standard permissions.
///
/// State is shared via `PendingPermissionStore.interactionState(for:)` so
/// selections and feedback survive expand/collapse transitions.
struct PermissionContentView: View {
    let permission: PendingPermission
    let mode: PermissionDisplayMode
    let onDecision: (PermissionDecision) -> Void
    let onAnswers: (([String: String]) -> Void)?
    let onFeedback: ((String) -> Void)?
    let onAllowWithPermissions: (([PermissionSuggestion]) -> Void)?
    let onLater: () -> Void
    let onToggleMode: () -> Void
    var showShortcuts: Bool = false

    @Environment(PendingPermissionStore.self) private var store
    @Environment(GlobalHotkeyManager.self) private var hotkeyManager
    @Environment(SessionStore.self) private var sessionStore

    @FocusState private var feedbackFocused: Bool
    @FocusState private var otherFieldFocused: String?

    private var state: PermissionInteractionState { store.interactionState(for: permission.id) }

    private var isPlan: Bool { permission.event.toolName == "ExitPlanMode" }
    private var isQuestion: Bool { !(permission.parsedQuestions ?? []).isEmpty }
    private var questions: [ParsedQuestion] { permission.parsedQuestions ?? [] }
    private var supportsOverlayResponses: Bool {
        let capabilities = permission.transport.capabilities
        return capabilities.contains(.permissionResponse)
            || capabilities.contains(.updatedInput)
            || capabilities.contains(.updatedPermissions)
    }
    private var isOpenTerminalFallback: Bool {
        !supportsOverlayResponses && permission.transport.capabilities.contains(.openTerminal)
    }

    private var isExpanded: Bool { mode == .expanded }

    // Sizing
    private var headerFont: Font { isExpanded ? Constants.fontTitle : Constants.fontSubheadline }
    private var bodyFont: Font { isExpanded ? Constants.fontBody : Constants.fontSubheadline }
    private var codeFont: CGFloat { isExpanded ? 13 : 10 }
    private var iconFont: CGFloat { isExpanded ? 14 : 11 }
    private var buttonFont: Font { isExpanded ? Constants.fontHeadline : Constants.fontSubheadline }
    private var optionFont: Font { isExpanded ? Constants.fontBody : Constants.fontSubheadline }
    private var hintFont: CGFloat { 8 }
    private var outerPadding: CGFloat { isExpanded ? Constants.contentPaddingH : 8 }
    private var innerSpacing: CGFloat { isExpanded ? Constants.spacingNormal : 5 }
    private var buttonPaddingH: CGFloat { isExpanded ? 20 : Constants.spacingNormal }
    private var buttonPaddingV: CGFloat { isExpanded ? Constants.spacingTight : 4 }
    private var contentMaxHeight: CGFloat? { isExpanded ? nil : (isPlan ? 160 : 300) }

    var body: some View {
        Group {
            if isExpanded {
                expandedLayout
            } else {
                compactLayout
            }
        }
        .onChange(of: state.autoAllowEnabled) { _, newValue in
            // Synced from another prompt's global toggle — start countdown if needed
            if newValue && !isPlan && !isQuestion && !state.isCountdownActive {
                startAutoAllowTimer()
            }
        }
        .onAppear {
            // Auto-start: check global auto-allow first, then session-scoped
            if !isPlan && !isQuestion && !state.isCountdownActive {
                if store.globalAutoAllow {
                    state.autoAllowEnabled = true
                    startAutoAllowTimer()
                } else if let sessionId = permission.event.sessionId,
                          store.isSessionAutoAllow(sessionId) {
                    startAutoAllowTimer()
                }
            }
        }
        .onDisappear {
            cancelAutoAllowTimer()
        }
        .onChange(of: hotkeyManager.selectedButtonIndex) { _, newIdx in
            guard showShortcuts || isExpanded, let idx = newIdx else { return }
            handleShortcutSelection(idx)
        }
        .onChange(of: hotkeyManager.confirmTrigger) { _, _ in
            guard showShortcuts || isExpanded else { return }
            handleShortcutConfirm()
        }
    }

    // MARK: - Layouts

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: innerSpacing) {
            headerSection
            contentSection
            actionsSection
            ShortcutHintBar()
        }
    }

    private var expandedLayout: some View {
        VStack(spacing: 0) {
            headerSection
                .padding(.horizontal, outerPadding)
                .padding(.vertical, Constants.contentPaddingV)
                .background(Constants.surfaceWhite)

            Divider()

            ScrollView(.vertical, showsIndicators: true) {
                contentSection
                    .padding(outerPadding)
            }
            .background(OverlayStyle.codeBg)

            Divider()

            actionsSection
                .padding(.horizontal, outerPadding)
                .padding(.vertical, Constants.contentPaddingV)
                .background(Constants.surfaceWhite)
        }
        .background(Constants.surfaceWhite)
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 8)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            // Title
            HStack(spacing: isExpanded ? 8 : 4) {
                Image(systemName: titleIcon)
                    .font(.system(size: iconFont))
                    .foregroundStyle(OverlayStyle.orange)
                Text(titleText)
                    .font(isExpanded ? Constants.fontTitle : Constants.fontSubheadline)
                    .foregroundStyle(OverlayStyle.textPrimary)
            }

            if isExpanded, let project = projectName {
                Text(project)
                    .font(.system(size: 12))
                    .foregroundStyle(OverlayStyle.textPrimary.opacity(0.4))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(OverlayStyle.textPrimary.opacity(0.05))
                    .clipShape(Capsule())
            }

            Spacer()

            // Terminal button
            headerButton(icon: "terminal.fill", badge: hotkeyManager.shortcutLabel, help: "Open terminal") {
                focusTerminal(
                    pid: permission.event.terminalPid,
                    shellPid: permission.event.shellPid,
                    projectDir: permission.event.cwd,
                    sessionId: permission.event.sessionId,
                    sessions: sessionStore.sessions
                )
            }

            // Later button
            headerButton(icon: "clock.arrow.circlepath", badge: "⌘L", help: "Handle later") {
                onLater()
            }

            // Expand/collapse button
            headerButton(
                icon: isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                badge: "⌘P",
                help: isExpanded ? "Close expanded view" : "Expand"
            ) {
                onToggleMode()
            }
        }
    }

    @ViewBuilder
    private func headerButton(icon: String, badge: String, help: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 3) {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.system(size: isExpanded ? 11 : 10))
                    .foregroundStyle(OverlayStyle.textHint)
            }
            .buttonStyle(.plain)
            .help(help)

            if showShortcuts || (isExpanded && hotkeyManager.isCmdHeld) {
                ActionBadge(label: badge)
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentSection: some View {
        if isPlan {
            planContentView
        } else if isQuestion {
            questionContentView
        } else {
            standardContentView
        }
    }

    // MARK: Plan Content

    @ViewBuilder
    private var planContentView: some View {
        if let content = permission.planFileContent {
            if isExpanded {
                Markdown(content)
                    .markdownTextStyle {
                        FontSize(isExpanded ? 13 : 11)
                        ForegroundColor(Constants.textPrimary.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if state.isContentExpanded {
                ScrollView(.vertical, showsIndicators: true) {
                    Markdown(content)
                        .markdownTextStyle {
                            FontSize(codeFont)
                            ForegroundColor(Constants.textPrimary.opacity(0.85))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 120)
                .padding(5)
                .background(OverlayStyle.codeBg)
                .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadiusSmall))
                .overlay(RoundedRectangle(cornerRadius: Constants.cornerRadiusSmall).stroke(OverlayStyle.codeBorder, lineWidth: 1))
                .contentShape(Rectangle())
                .onTapGesture { state.isContentExpanded = false }

                Text("tap to collapse")
                    .font(.system(size: 9))
                    .foregroundStyle(OverlayStyle.textHint)
            } else {
                let preview = content.split(separator: "\n", omittingEmptySubsequences: false)
                    .prefix(4)
                    .joined(separator: "\n")

                Markdown(preview)
                    .markdownTextStyle {
                        FontSize(codeFont)
                        ForegroundColor(Constants.textPrimary.opacity(0.75))
                    }
                    .lineLimit(4)
                    .padding(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(OverlayStyle.codeBg)
                    .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadiusSmall))
                    .overlay(RoundedRectangle(cornerRadius: Constants.cornerRadiusSmall).stroke(OverlayStyle.codeBorder, lineWidth: 1))
                    .contentShape(Rectangle())
                    .onTapGesture { state.isContentExpanded = true }

                Text("tap to expand full plan")
                    .font(.system(size: 9))
                    .foregroundStyle(OverlayStyle.textHint)
            }
        } else {
            Text("Plan file not found")
                .font(.system(size: codeFont))
                .foregroundStyle(OverlayStyle.textMuted)
        }
    }

    // MARK: Question Content

    private var questionContentView: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 16 : 10) {
            ForEach(Array(questions.enumerated()), id: \.offset) { qIdx, question in
                questionView(question, questionIndex: qIdx)
            }
        }
    }

    @ViewBuilder
    private func questionView(_ question: ParsedQuestion, questionIndex: Int) -> some View {
        let isActive = questionIndex == state.currentQuestionIndex
        let showBadge = (showShortcuts || (isExpanded && hotkeyManager.isCmdHeld)) && isActive

        VStack(alignment: .leading, spacing: isExpanded ? 8 : 3) {
            if let header = question.header {
                Text(header)
                    .font(isExpanded ? Constants.fontSubheadline : Constants.fontFootnote)
                    .foregroundStyle(OverlayStyle.orange)
                    .padding(.horizontal, isExpanded ? 8 : 5)
                    .padding(.vertical, isExpanded ? 2 : 1)
                    .overlay(Capsule().stroke(OverlayStyle.orangeBorder, lineWidth: 1))
            }

            markdownText(question.question)
                .font(isExpanded ? Constants.fontBody : Constants.fontSubheadline)
                .foregroundStyle(OverlayStyle.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .contentShape(Rectangle())
                .onTapGesture {
                    if questions.count > 1 { state.currentQuestionIndex = questionIndex }
                    focusTerminal(pid: permission.event.terminalPid, shellPid: permission.event.shellPid, projectDir: permission.event.cwd, sessionId: permission.event.sessionId, source: permission.event.source, sessions: sessionStore.sessions)
                }

            VStack(alignment: .leading, spacing: isExpanded ? 4 : 2) {
                ForEach(Array(question.options.enumerated()), id: \.offset) { idx, option in
                    optionRow(question: question, option: option, index: idx, questionIndex: questionIndex, showBadge: showBadge)
                }
                otherRow(question: question, questionIndex: questionIndex, showBadge: showBadge)
            }
        }
    }

    @ViewBuilder
    private func optionRow(question: ParsedQuestion, option: ParsedOption, index: Int, questionIndex: Int, showBadge: Bool) -> some View {
        let isMulti = question.multiSelect
        let isSelected: Bool = {
            guard !state.usingCustom.contains(question.question) else { return false }
            if isMulti { return state.multiSelections[question.question]?.contains(option.label) == true }
            return state.selections[question.question] == option.label
        }()

        Button {
            state.currentQuestionIndex = questionIndex
            state.usingCustom.remove(question.question)
            if isMulti {
                var set = state.multiSelections[question.question] ?? []
                if set.contains(option.label) { set.remove(option.label) } else { set.insert(option.label) }
                state.multiSelections[question.question] = set
            } else {
                state.selections[question.question] = option.label
                if questionIndex + 1 < questions.count {
                    state.currentQuestionIndex = questionIndex + 1
                }
            }
        } label: {
            HStack(alignment: .top, spacing: isExpanded ? 8 : 5) {
                Image(systemName: isMulti
                    ? (isSelected ? "checkmark.square.fill" : "square")
                    : (isSelected ? "checkmark.circle.fill" : "circle"))
                    .font(.system(size: isExpanded ? 13 : 11))
                    .foregroundStyle(isSelected ? OverlayStyle.orange : OverlayStyle.radioBorder)
                    .frame(width: isExpanded ? 16 : 13)

                VStack(alignment: .leading, spacing: isExpanded ? 2 : 1) {
                    markdownText(option.label)
                        .font(isExpanded ? Constants.fontBody : Constants.fontSubheadline)
                        .foregroundStyle(OverlayStyle.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let desc = option.description, !desc.isEmpty {
                        markdownText(desc)
                            .font(isExpanded ? Constants.fontSubheadline : .system(size: 9))
                            .foregroundStyle(OverlayStyle.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)

                if showBadge {
                    ShortcutBadge(index: index, isSelected: hotkeyManager.selectedButtonIndex == index)
                }
            }
            .padding(.vertical, isExpanded ? 6 : 2)
            .padding(.horizontal, isExpanded ? 10 : 5)
            .background(
                (hotkeyManager.selectedButtonIndex == index && showBadge)
                    ? OverlayStyle.orange.opacity(0.12)
                    : (isSelected ? OverlayStyle.selectedBg : Color.clear)
            )
            .contentShape(Rectangle())
            .clipShape(RoundedRectangle(cornerRadius: isExpanded ? 8 : 7))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func otherRow(question: ParsedQuestion, questionIndex: Int, showBadge: Bool) -> some View {
        let isCustom = state.usingCustom.contains(question.question)
        let otherIndex = question.options.count

        VStack(alignment: .leading, spacing: isExpanded ? 4 : 2) {
            Button {
                state.currentQuestionIndex = questionIndex
                if mode == .compact { store.onRequestTextInputFocus?() }
                state.usingCustom.insert(question.question)
                state.selections.removeValue(forKey: question.question)
                otherFieldFocused = question.question
            } label: {
                HStack(spacing: isExpanded ? 8 : 5) {
                    Image(systemName: isCustom ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: isExpanded ? 13 : 11))
                        .foregroundStyle(isCustom ? OverlayStyle.orange : OverlayStyle.radioBorder)
                        .frame(width: isExpanded ? 16 : 13)

                    Text("Other")
                        .font(isExpanded ? Constants.fontBody : Constants.fontSubheadline)
                        .foregroundStyle(OverlayStyle.textMuted)

                    Spacer(minLength: 0)

                    if showBadge {
                        ShortcutBadge(index: otherIndex, isSelected: hotkeyManager.selectedButtonIndex == otherIndex)
                    }
                }
                .padding(.vertical, isExpanded ? 6 : 2)
                .padding(.horizontal, isExpanded ? 10 : 5)
                .background(
                    (hotkeyManager.selectedButtonIndex == otherIndex && showBadge)
                        ? OverlayStyle.orange.opacity(0.12)
                        : (isCustom ? OverlayStyle.selectedBg : Color.clear)
                )
                .contentShape(Rectangle())
                .clipShape(RoundedRectangle(cornerRadius: isExpanded ? 8 : 7))
            }
            .buttonStyle(.plain)

            if isCustom {
                TextField("Type your answer...", text: Binding(
                    get: { state.customInputs[question.question] ?? "" },
                    set: { state.customInputs[question.question] = $0 }
                ))
                .focused($otherFieldFocused, equals: question.question)
                .textFieldStyle(.plain)
                .font(isExpanded ? Constants.fontBody : Constants.fontSubheadline)
                .foregroundStyle(OverlayStyle.textPrimary)
                .padding(isExpanded ? 8 : 3)
                .background(OverlayStyle.inputBg)
                .clipShape(RoundedRectangle(cornerRadius: isExpanded ? 8 : 7))
                .padding(.leading, isExpanded ? 28 : 22)
            }
        }
    }

    // MARK: Standard Content

    @ViewBuilder
    private var standardContentView: some View {
        if isExpanded {
            Text(permission.fullToolInputText)
                .font(.system(size: codeFont, design: .monospaced))
                .foregroundStyle(OverlayStyle.textPrimary.opacity(0.85))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if state.isContentExpanded {
            ScrollView(.vertical, showsIndicators: true) {
                Text(permission.fullToolInputText)
                    .font(.system(size: codeFont, design: .monospaced))
                    .foregroundStyle(OverlayStyle.textPrimary.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 150)
            .padding(5)
            .background(OverlayStyle.codeBg)
            .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadiusSmall))
            .overlay(RoundedRectangle(cornerRadius: Constants.cornerRadiusSmall).stroke(OverlayStyle.codeBorder, lineWidth: 1))
            .contentShape(Rectangle())
            .onTapGesture { state.isContentExpanded = false }

            Text("tap to collapse")
                .font(.system(size: 9))
                .foregroundStyle(OverlayStyle.textHint)
        } else {
            Text(permission.toolInputPreview)
                .font(.system(size: codeFont, design: .monospaced))
                .foregroundStyle(OverlayStyle.textPrimary.opacity(0.75))
                .lineLimit(4)
                .padding(5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(OverlayStyle.codeBg)
                .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadiusSmall))
                .overlay(RoundedRectangle(cornerRadius: Constants.cornerRadiusSmall).stroke(OverlayStyle.codeBorder, lineWidth: 1))
                .contentShape(Rectangle())
                .onTapGesture { state.isContentExpanded = true }
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionsSection: some View {
        if isOpenTerminalFallback {
            terminalFallbackActionsView
        } else if isPlan {
            planActionsView
        } else if isQuestion {
            questionActionsView
        } else {
            standardActionsView
        }
    }

    private var terminalFallbackActionsView: some View {
        HStack(spacing: isExpanded ? 10 : 8) {
            Text("Reply in terminal")
                .font(isExpanded ? Constants.fontBody : Constants.fontCallout)
                .foregroundStyle(OverlayStyle.textMuted)

            terminalFallbackButton
        }
        .frame(maxWidth: .infinity)
    }

    private var terminalFallbackButton: some View {
        Button {
            focusTerminal(
                pid: permission.event.terminalPid,
                shellPid: permission.event.shellPid,
                projectDir: permission.event.cwd,
                sessionId: permission.event.sessionId,
                sessions: sessionStore.sessions
            )
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "terminal.fill")
                Text("Open Terminal")
                    .font(isExpanded ? Constants.fontHeadline : Constants.fontSubheadline)
            }
            .foregroundStyle(.white)
            .padding(.vertical, buttonPaddingV)
            .padding(.horizontal, buttonPaddingH)
            .background(OverlayStyle.orange)
            .clipShape(RoundedRectangle(cornerRadius: isExpanded ? 8 : 7))
        }
        .buttonStyle(.plain)
    }

    // MARK: Plan Actions

    private let planOptions = [
        "Yes, clear context and auto-accept edits",
        "Yes, auto-accept edits",
        "Yes, manually approve edits",
        "Tell Claude what to change",
    ]

    private var planActionsView: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 12 : 2) {
            if isExpanded {
                // Horizontal options in expanded mode - equal height via Grid
                Grid(horizontalSpacing: 6) {
                    GridRow {
                        ForEach(Array(planOptions.enumerated()), id: \.offset) { idx, label in
                            planOptionButton(idx: idx, label: label)
                        }
                    }
                }
            } else {
                // Vertical options in compact mode
                ForEach(Array(planOptions.enumerated()), id: \.offset) { idx, label in
                    planOptionButton(idx: idx, label: label)
                }
            }

            // Feedback input
            if state.selectedOption == 3 {
                if isExpanded {
                    TextEditor(text: Binding(
                        get: { state.feedbackText },
                        set: { state.feedbackText = $0 }
                    ))
                    .focused($feedbackFocused)
                    .font(.system(size: 13))
                    .foregroundStyle(OverlayStyle.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(minHeight: 60, maxHeight: 120)
                    .background(OverlayStyle.textPrimary.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadiusSmall))
                    .overlay(RoundedRectangle(cornerRadius: Constants.cornerRadiusSmall).stroke(OverlayStyle.orange.opacity(0.2), lineWidth: 1))
                    .overlay(alignment: .topLeading) {
                        if state.feedbackText.isEmpty {
                            Text("Tell Claude what to change...")
                                .font(.system(size: 13))
                                .foregroundStyle(OverlayStyle.textPrimary.opacity(0.3))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .allowsHitTesting(false)
                        }
                    }
                } else {
                    TextField("Type your feedback...", text: Binding(
                        get: { state.feedbackText },
                        set: { state.feedbackText = $0 }
                    ))
                    .focused($feedbackFocused)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(OverlayStyle.textPrimary)
                    .padding(3)
                    .background(OverlayStyle.inputBg)
                    .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadiusSmall))
                    .padding(.leading, 22)
                }
            }

            // Approve / Deny
            approveAndDenyButtons(
                approveLabel: "Approve",
                denyLabel: "Deny",
                approveDisabled: state.selectedOption == 3 && state.feedbackText.isEmpty,
                onApprove: {
                    if state.selectedOption == 3 && !state.feedbackText.isEmpty {
                        onFeedback?(state.feedbackText)
                    } else if state.selectedOption <= 1 {
                        let autoAccept = [PermissionSuggestion(type: "setMode", destination: "session", behavior: nil, rules: nil, mode: "acceptEdits")]
                        onAllowWithPermissions?(autoAccept)
                    } else {
                        onDecision(.allow)
                    }
                },
                onDeny: { onDecision(.deny) }
            )
        }
    }

    private func planOptionButton(idx: Int, label: String) -> some View {
        let showBadge = showShortcuts || (isExpanded && hotkeyManager.isCmdHeld)

        return Button {
            state.selectedOption = idx
            if idx == 3 {
                if mode == .compact { store.onRequestTextInputFocus?() }
                feedbackFocused = true
            }
        } label: {
            HStack(alignment: .top, spacing: isExpanded ? 6 : 5) {
                Image(systemName: state.selectedOption == idx ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: isExpanded ? 12 : 11))
                    .foregroundStyle(state.selectedOption == idx ? OverlayStyle.orange : OverlayStyle.radioBorder)
                    .frame(width: isExpanded ? nil : 13)
                    .padding(.top, isExpanded ? 2 : 0)

                Text(label)
                    .font(isExpanded ? Constants.fontBody : Constants.fontSubheadline)
                    .foregroundStyle(OverlayStyle.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                if showBadge {
                    ShortcutBadge(index: idx, isSelected: hotkeyManager.selectedButtonIndex == idx)
                        .padding(.top, isExpanded ? 2 : 0)
                }
            }
            .padding(.vertical, isExpanded ? 10 : 2)
            .padding(.horizontal, isExpanded ? 12 : 5)
            .frame(maxWidth: isExpanded ? .infinity : nil, alignment: .leading)
            .background(
                (hotkeyManager.selectedButtonIndex == idx && showBadge)
                    ? OverlayStyle.orange.opacity(0.12)
                    : (state.selectedOption == idx ? OverlayStyle.selectedBg : (isExpanded ? OverlayStyle.textPrimary.opacity(0.02) : Color.clear))
            )
            .contentShape(Rectangle())
            .clipShape(RoundedRectangle(cornerRadius: isExpanded ? 8 : 7))
        }
        .buttonStyle(.plain)
    }

    // MARK: Question Actions

    private var questionActionsView: some View {
        approveAndDenyButtons(
            approveLabel: "Submit",
            denyLabel: "Skip",
            approveDisabled: !state.allAnswered(for: questions),
            onApprove: {
                let answers = state.buildAnswers(for: questions)
                onAnswers?(answers)
            },
            onDeny: { onDecision(.deny) }
        )
    }

    // MARK: Standard Actions

    private var standardActionsView: some View {
        VStack(spacing: isExpanded ? 10 : 3) {
            // Auto-allow row (global, 5s countdown)
            // Auto-allow toggles row: global left, session right
            HStack {
                // Left: global auto-allow
                Toggle(isOn: Binding(
                    get: { state.autoAllowEnabled },
                    set: { newValue in
                        state.autoAllowEnabled = newValue
                        store.setGlobalAutoAllow(newValue)
                        if newValue {
                            startAutoAllowTimer()
                        } else {
                            cancelAutoAllowTimer()
                        }
                    }
                )) {
                    Text("Auto-allow")
                        .font(Constants.fontFootnote)
                        .foregroundStyle(OverlayStyle.textMuted)
                }
                .buttonStyle(.plain)

                Spacer()

                // Right: session auto-allow
                if let sessionId = permission.event.sessionId {
                    Toggle(isOn: Binding(
                        get: { store.isSessionAutoAllow(sessionId) },
                        set: { newValue in
                            store.setSessionAutoAllow(sessionId, enabled: newValue)
                            if newValue {
                                if !state.isCountdownActive {
                                    startAutoAllowTimer()
                                }
                            } else {
                                cancelAutoAllowTimer()
                            }
                        }
                    )) {
                        Text("This session")
                            .font(Constants.fontFootnote)
                            .foregroundStyle(OverlayStyle.textMuted)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Countdown progress bar
            if state.isCountdownActive {
                HStack {
                    Text("\(Int(ceil(state.autoAllowRemainingSeconds)))s")
                        .font(Constants.fontFootnote)
                        .foregroundStyle(OverlayStyle.textMuted)
                        .monospacedDigit()

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(OverlayStyle.textPrimary.opacity(0.1))
                                .frame(height: 3)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(OverlayStyle.orange)
                                .frame(width: geometry.size.width * (state.autoAllowRemainingSeconds / 5.0), height: 3)
                        }
                    }
                    .frame(height: 3)
                }
            }

            approveAndDenyButtons(
                approveLabel: "Allow",
                denyLabel: "Deny",
                approveDisabled: false,
                onApprove: { onDecision(.allow) },
                onDeny: { onDecision(.deny) }
            )

            // Always-allow suggestions
            ForEach(Array(permission.permissionSuggestions.enumerated()), id: \.element.id) { sugIndex, suggestion in
                let showBadge = showShortcuts || (isExpanded && hotkeyManager.isCmdHeld)
                Button {
                    onAllowWithPermissions?([suggestion])
                } label: {
                    HStack(spacing: 4) {
                        Spacer(minLength: 0)
                        Text(suggestion.displayLabel)
                            .font(isExpanded ? Constants.fontBody : Constants.fontCallout)
                            .foregroundStyle(OverlayStyle.denyText)
                        if showBadge {
                            ShortcutBadge(index: sugIndex, isSelected: hotkeyManager.selectedButtonIndex == sugIndex)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, isExpanded ? 6 : 3)
                    .background(
                        (hotkeyManager.selectedButtonIndex == sugIndex && showBadge)
                            ? OverlayStyle.orange.opacity(0.08)
                            : Color.clear
                    )
                    .contentShape(Rectangle())
                    .clipShape(RoundedRectangle(cornerRadius: isExpanded ? 8 : 7))
                    .overlay(RoundedRectangle(cornerRadius: isExpanded ? 8 : 7).stroke(
                        (hotkeyManager.selectedButtonIndex == sugIndex && showBadge)
                            ? OverlayStyle.orange
                            : OverlayStyle.denyBorder,
                        lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Shared Approve/Deny Buttons

    @ViewBuilder
    private func approveAndDenyButtons(
        approveLabel: String,
        denyLabel: String,
        approveDisabled: Bool,
        onApprove: @escaping () -> Void,
        onDeny: @escaping () -> Void
    ) -> some View {
        if isExpanded {
            HStack(spacing: 10) {
                Text("⌘P close  ·  ⌘⎋ \(denyLabel.lowercased())  ·  ⌘↵ \(approveLabel.lowercased())")
                    .font(.system(size: hintFont, weight: .medium, design: .rounded))
                    .foregroundStyle(OverlayStyle.textPrimary.opacity(0.35))

                Spacer()

                Button(action: onDeny) {
                    HStack(spacing: 5) {
                        Text(denyLabel)
                            .font(isExpanded ? Constants.fontHeadline : Constants.fontSubheadline)
                        if hotkeyManager.isCmdHeld { ActionBadge(label: "⌘⎋") }
                    }
                    .foregroundStyle(OverlayStyle.denyText)
                    .padding(.vertical, buttonPaddingV)
                    .padding(.horizontal, buttonPaddingH)
                    .contentShape(Rectangle())
                    .overlay(RoundedRectangle(cornerRadius: Constants.cornerRadiusSmall).stroke(OverlayStyle.denyBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button(action: onApprove) {
                    HStack(spacing: 5) {
                        Text(approveLabel)
                            .font(isExpanded ? Constants.fontHeadline : Constants.fontSubheadline)
                        if hotkeyManager.isCmdHeld { ActionBadge(label: "⌘↵") }
                    }
                    .foregroundStyle(.white)
                    .padding(.vertical, buttonPaddingV)
                    .padding(.horizontal, buttonPaddingH)
                    .background(approveDisabled ? Constants.border : OverlayStyle.orange)
                    .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadiusSmall))
                }
                .buttonStyle(.plain)
                .disabled(approveDisabled)
            }
            .animation(.easeInOut(duration: 0.15), value: hotkeyManager.isCmdHeld)
        } else {
            HStack(spacing: 5) {
                Button(action: onApprove) {
                    HStack(spacing: 4) {
                        Spacer(minLength: 0)
                        Text(approveLabel)
                            .font(isExpanded ? Constants.fontHeadline : Constants.fontSubheadline)
                            .foregroundStyle(.white)
                        if showShortcuts { ActionBadge(label: "⌘↩") }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, buttonPaddingV)
                    .background(approveDisabled ? Constants.border : OverlayStyle.orange)
                    .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadiusSmall))
                }
                .buttonStyle(.plain)
                .disabled(approveDisabled)

                Button(action: onDeny) {
                    HStack(spacing: 4) {
                        Spacer(minLength: 0)
                        Text(denyLabel)
                            .font(isExpanded ? Constants.fontHeadline : Constants.fontSubheadline)
                            .foregroundStyle(OverlayStyle.denyText)
                        if showShortcuts { ActionBadge(label: "⌘⎋") }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, buttonPaddingV)
                    .contentShape(Rectangle())
                    .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadiusSmall))
                    .overlay(RoundedRectangle(cornerRadius: Constants.cornerRadiusSmall).stroke(OverlayStyle.denyBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Shortcut Handlers (compact mode only, via CGEvent tap)

    private func handleShortcutSelection(_ idx: Int) {
        if isOpenTerminalFallback {
            return
        }
        if isPlan {
            if idx < planOptions.count {
                state.selectedOption = idx
                if idx == 3 {
                    store.onRequestTextInputFocus?()
                    feedbackFocused = true
                }
            }
        } else if isQuestion {
            let qIdx = state.currentQuestionIndex
            guard qIdx < questions.count else { return }
            let q = questions[qIdx]
            if idx < q.options.count {
                state.usingCustom.remove(q.question)
                if q.multiSelect {
                    var set = state.multiSelections[q.question] ?? []
                    let label = q.options[idx].label
                    if set.contains(label) { set.remove(label) } else { set.insert(label) }
                    state.multiSelections[q.question] = set
                } else {
                    state.selections[q.question] = q.options[idx].label
                    if qIdx + 1 < questions.count { state.currentQuestionIndex = qIdx + 1 }
                }
            } else if idx == q.options.count {
                store.onRequestTextInputFocus?()
                state.usingCustom.insert(q.question)
                state.selections.removeValue(forKey: q.question)
                otherFieldFocused = q.question
            }
        }
        // Standard permissions: handled by selectedButtonIndex in suggestion buttons
    }

    private func handleShortcutConfirm() {
        if isOpenTerminalFallback {
            focusTerminal(
                pid: permission.event.terminalPid,
                shellPid: permission.event.shellPid,
                projectDir: permission.event.cwd,
                sessionId: permission.event.sessionId,
                source: permission.event.source,
                sessions: sessionStore.sessions
            )
            return
        }
        if isPlan {
            if state.selectedOption == 3 && !state.feedbackText.isEmpty {
                onFeedback?(state.feedbackText)
            } else if state.selectedOption <= 1 {
                let autoAccept = [PermissionSuggestion(type: "setMode", destination: "session", behavior: nil, rules: nil, mode: "acceptEdits")]
                onAllowWithPermissions?(autoAccept)
            } else {
                onDecision(.allow)
            }
        } else if isQuestion {
            guard state.allAnswered(for: questions) else { return }
            let answers = state.buildAnswers(for: questions)
            onAnswers?(answers)
        } else {
            // Standard: check if a suggestion is selected
            let sug = permission.permissionSuggestions
            if let idx = hotkeyManager.selectedButtonIndex, idx < sug.count {
                onAllowWithPermissions?([sug[idx]])
            } else {
                onDecision(.allow)
            }
        }
    }

    // MARK: - Helpers

    private var titleIcon: String {
        if isPlan { return "doc.text.fill" }
        if isQuestion { return "questionmark.circle.fill" }
        return "shield.checkered"
    }

    private var titleText: String {
        if isPlan { return "Plan Ready" }
        if isQuestion { return "Question" }
        return permission.toolName
    }

    private var projectName: String? {
        guard let sessionId = permission.event.sessionId,
              let session = sessionStore.sessions.first(where: { $0.id == sessionId }) else { return nil }
        return session.projectName
    }

    // MARK: - Auto-Allow Timer

    private func startAutoAllowTimer() {
        state.isCountdownActive = true
        state.autoAllowStartDate = Date()
        state.autoAllowRemainingSeconds = 5.0
        state.autoAllowTimer?.invalidate()
        state.autoAllowTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            Task { @MainActor in
                guard state.isCountdownActive else { return }
                if let startDate = state.autoAllowStartDate {
                    let elapsed = Date().timeIntervalSince(startDate)
                    let remaining = max(0, 5.0 - elapsed)
                    state.autoAllowRemainingSeconds = remaining

                    if remaining <= 0 {
                        cancelAutoAllowTimer()
                        onDecision(.allow)
                    }
                }
            }
        }
    }

    private func cancelAutoAllowTimer() {
        state.autoAllowTimer?.invalidate()
        state.autoAllowTimer = nil
        state.autoAllowStartDate = nil
        state.isCountdownActive = false
        state.autoAllowRemainingSeconds = 5.0
    }
}
