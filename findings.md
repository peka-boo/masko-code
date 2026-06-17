# Findings

## Session Findings

### 2026-03-08 Hooks popup chain

- Hook 注册由 `HookInstaller.install()` 写入 `~/.claude/settings.json`，统一把多个 Claude Code hook 事件指向 `~/.masko-desktop/hooks/hook-sender.sh`。
- `hook-sender.sh` 对 `PermissionRequest` 采用阻塞式 `curl` 调用本地 `POST /hook`，其余事件走 fire-and-forget。
- 代码注释明确说明：Claude Code 对 `AskUserQuestion` 也会发出 `PermissionRequest`，而不是单独的 question 事件。
- `LocalServer` 收到 `PermissionRequest` 后不会立即响应，而是把 `NWConnection` 连同 `ClaudeEvent` 一起交给 `PendingPermissionStore.add()` 持有，等待用户在浮层里操作。
- `ClaudeEvent` 负责把 hook JSON 解码为结构化对象，关键字段包括 `hook_event_name`、`tool_name`、`tool_input`、`permission_suggestions`、`session_id`、`cwd`、`terminal_pid`、`shell_pid`。
- 当 `toolName == "AskUserQuestion"` 时，`PendingPermission.parsedQuestions` 会从 `tool_input.questions` 中解析出：
  - `question`
  - `header`
  - `options[].label`
  - `options[].description`
  - `multiSelect`
- `PermissionPromptView` 会根据数据类型切换三种渲染分支：
  - `ExitPlanMode` -> `ExitPlanModeView`
  - `parsedQuestions` 非空 -> `AskUserQuestionView`
  - 其他 -> 标准 Allow / Deny 权限卡片
- `AskUserQuestionView` 会额外注入一个本地 `Other` 选项；它不是 Claude 原始协议字段的一部分，而是 Masko 侧增强 UI。
- 提交回答时，`PendingPermissionStore.resolveWithAnswers()` 会构造 `updatedInput = 原始 tool_input + answers`，然后以 `hookSpecificOutput.decision.behavior = allow` 的 JSON 回写给 Claude。
- 点 `Skip` 本质上会走 `decision = deny`，HTTP 返回为 `403 Forbidden`，同时带 `X-Exit-Code: 2`。
- 点 `Later` 只会把当前权限卡片折叠，不会关闭底层连接；连接仍被持有，等待后续再次处理或终端端先完成。
- `AppStore` 在收到同 session + agent 的后续 `PostToolUse` / `PostToolUseFailure` / `Stop` / `UserPromptSubmit` 时，会自动移除仍悬挂的待处理 permission，避免终端已处理而浮层残留。
- `OverlayManager` 会把 permission panel 作为独立 HUD 面板挂在 mascot/stats panel 上，并根据屏幕空间在上 / 左 / 右 / 下之间智能布局气泡尾巴。
