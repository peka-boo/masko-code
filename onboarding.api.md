# Hook API 文档

本文档描述了所有 Hook 事件的完整参数格式。

## 公共字段

所有事件都包含以下公共字段：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `hook_event_name` | String | ✅ | 事件类型 |
| `session_id` | String? | | 会话 ID |
| `cwd` | String? | | 当前工作目录 |
| `transcript_path` | String? | | transcript 文件路径 |
| `terminal_pid` | Int? | | 终端进程 PID (hook 脚本自动注入) |
| `shell_pid` | Int? | | Shell 进程 PID (hook 脚本自动注入) |

---

## 事件类型列表

### 1. SessionStart

会话开始时触发。

```json
{
  "hook_event_name": "SessionStart",
  "session_id": "019cd686-3b91-78a1-9356-21b475548352",
  "cwd": "/Users/test/project",
  "transcript_path": "/Users/test/.claude/projects/abc/transcript.jsonl",
  "source": "claude",
  "model": "claude-sonnet-4-6",
  "permission_mode": "plan",
  "terminal_pid": 12345,
  "shell_pid": 67890
}
```

### 2. SessionEnd

会话结束时触发。

```json
{
  "hook_event_name": "SessionEnd",
  "session_id": "019cd686-3b91-78a1-9356-21b475548352",
  "cwd": "/Users/test/project",
  "transcript_path": "/Users/test/.claude/projects/abc/transcript.jsonl",
  "source": "claude",
  "reason": "user_cancelled",
  "terminal_pid": 12345,
  "shell_pid": 67890
}
```

### 3. UserPromptSubmit

用户提交 prompt 时触发。

```json
{
  "hook_event_name": "UserPromptSubmit",
  "session_id": "019cd686-3b91-78a1-9356-21b475548352",
  "cwd": "/Users/test/project",
  "transcript_path": "/Users/test/.claude/projects/abc/transcript.jsonl",
  "message": "帮我实现用户登录功能",
  "terminal_pid": 12345,
  "shell_pid": 67890
}
```

### 4. PreToolUse

工具执行前触发。

```json
{
  "hook_event_name": "PreToolUse",
  "session_id": "019cd686-3b91-78a1-9356-21b475548352",
  "cwd": "/Users/test/project",
  "transcript_path": "/Users/test/.claude/projects/abc/transcript.jsonl",
  "tool_name": "Write",
  "tool_use_id": "toolu_abc123",
  "tool_input": {
    "file_path": "/Users/test/project/src/main.swift",
    "content": "print(\"Hello World\")"
  },
  "terminal_pid": 12345,
  "shell_pid": 67890
}
```

### 5. PostToolUse

工具成功执行后触发。

```json
{
  "hook_event_name": "PostToolUse",
  "session_id": "019cd686-3b91-78a1-9356-21b475548352",
  "cwd": "/Users/test/project",
  "transcript_path": "/Users/test/.claude/projects/abc/transcript.jsonl",
  "tool_name": "Write",
  "tool_use_id": "toolu_abc123",
  "tool_input": {
    "file_path": "/Users/test/project/src/main.swift",
    "content": "print(\"Hello World\")"
  },
  "tool_response": {
    "success": true,
    "message": "File written successfully"
  },
  "terminal_pid": 12345,
  "shell_pid": 67890
}
```

### 6. PostToolUseFailure

工具执行失败时触发。

```json
{
  "hook_event_name": "PostToolUseFailure",
  "session_id": "019cd686-3b91-78a1-9356-21b475548352",
  "cwd": "/Users/test/project",
  "transcript_path": "/Users/test/.claude/projects/abc/transcript.jsonl",
  "tool_name": "Bash",
  "tool_use_id": "toolu_xyz789",
  "tool_input": {
    "command": "npm run build"
  },
  "tool_response": {
    "exit_code": 1,
    "stderr": "Error: Cannot find module 'foo'"
  },
  "terminal_pid": 12345,
  "shell_pid": 67890
}
```

### 7. PermissionRequest

权限请求时触发。这是**最重要的弹窗事件**，会显示交互式弹窗等待用户决策。

有三种弹窗场景：

#### 7.1 标准权限请求 (Bash/Write/Edit/Read 等工具)

```json
{
  "hook_event_name": "PermissionRequest",
  "session_id": "019cd686-3b91-78a1-9356-21b475548352",
  "cwd": "/Users/test/project",
  "transcript_path": "/Users/test/.claude/projects/abc/transcript.jsonl",
  "permission_mode": "plan",
  "tool_name": "Bash",
  "tool_use_id": "toolu_abc123",
  "tool_input": {
    "command": "npm install",
    "description": "Install dependencies"
  },
  "tool_response": null,
  "permission_suggestions": [
    {
      "type": "addRules",
      "destination": "session",
      "behavior": "allow",
      "rules": [
        {
          "toolName": "Bash",
          "ruleContent": "npm install"
        }
      ]
    },
    {
      "type": "addRules",
      "destination": "localSettings",
      "behavior": "allow",
      "rules": [
        {
          "toolName": "Bash",
          "ruleContent": "/Users/test/project/**"
        }
      ]
    }
  ],
  "terminal_pid": 12345,
  "shell_pid": 67890
}
```

#### 7.2 Plan 确认弹窗 (ExitPlanMode)

```json
{
  "hook_event_name": "PermissionRequest",
  "session_id": "019cd686-3b91-78a1-9356-21b475548352",
  "cwd": "/Users/test/project",
  "transcript_path": "/Users/test/.claude/projects/abc/transcript.jsonl",
  "permission_mode": "plan",
  "tool_name": "ExitPlanMode",
  "tool_use_id": "toolu_plan001",
  "tool_input": {
    "plan": "## 实现方案\n\n### 步骤 1: 创建用户模型\n...\n\n### 步骤 2: 实现登录逻辑\n...",
  },
  "tool_response": null,
  "permission_suggestions": [
    {
      "type": "setMode",
      "destination": "session",
      "mode": "acceptEdits"
    }
  ],
  "terminal_pid": 12345,
  "shell_pid": 67890
}
```

#### 7.3 问题交互弹窗 (AskUserQuestion)

```json
{
  "hook_event_name": "PermissionRequest",
  "session_id": "019cd686-3b91-78a1-9356-21b475548352",
  "cwd": "/Users/test/project",
  "transcript_path": "/Users/test/.claude/projects/abc/transcript.jsonl",
  "permission_mode": "plan",
  "tool_name": "AskUserQuestion",
  "tool_use_id": "toolu_question001",
  "tool_input": {
    "questions": [
      {
        "question": "Which styling approach should I use?",
        "header": "Styling",
        "multiSelect": false,
        "options": [
          {
            "label": "Tailwind CSS",
            "description": "Utility-first CSS framework with excellent DX"
          },
          {
            "label": "CSS Modules",
            "description": "Scoped CSS with traditional stylesheet syntax"
          },
          {
            "label": "Styled Components",
            "description": "CSS-in-JS with component-scoped styles"
          }
        ]
      },
      {
        "question": "Which features should I include?",
        "header": "Features",
        "multiSelect": true,
        "options": [
          {
            "label": "Dark mode",
            "description": "Add theme switching support"
          },
          {
            "label": "Responsive design",
            "description": "Mobile-first responsive layouts"
          },
          {
            "label": "Animations",
            "description": "Smooth transitions and micro-interactions"
          }
        ]
      }
    ]
  },
  "tool_response": null,
  "permission_suggestions": null,
  "terminal_pid": 12345,
  "shell_pid": 67890
}
```

### 8. Stop

代理停止时触发。

```json
{
  "hook_event_name": "Stop",
  "session_id": "019cd686-3b91-78a1-9356-21b475548352",
  "cwd": "/Users/test/project",
  "transcript_path": "/Users/test/.claude/projects/abc/transcript.jsonl",
  "stop_hook_active": true,
  "last_assistant_message": "任务已完成，我已经创建了登录功能的所有文件。",
  "terminal_pid": 12345,
  "shell_pid": 67890
}
```

### 9. StopFailure

代理因错误停止时触发。

```json
{
  "hook_event_name": "StopFailure",
  "session_id": "019cd686-3b91-78a1-9356-21b475548352",
  "cwd": "/Users/test/project",
  "transcript_path": "/Users/test/.claude/projects/abc/transcript.jsonl",
  "reason": "token_budget_exceeded",
  "last_assistant_message": "抱歉，上下文超出了限制...",
  "terminal_pid": 12345,
  "shell_pid": 67890
}
```

### 10. SubagentStart

子代理启动时触发。

```json
{
  "hook_event_name": "SubagentStart",
  "session_id": "019cd686-3b91-78a1-9356-21b475548352",
  "cwd": "/Users/test/project",
  "transcript_path": "/Users/test/.claude/projects/abc/transcript.jsonl",
  "agent_id": "subagent_001",
  "agent_type": "Explore",
  "terminal_pid": 12345,
  "shell_pid": 67890
}
```

### 11. SubagentStop

子代理停止时触发。

```json
{
  "hook_event_name": "SubagentStop",
  "session_id": "019cd686-3b91-78a1-9356-21b475548352",
  "cwd": "/Users/test/project",
  "transcript_path": "/Users/test/.claude/projects/abc/transcript.jsonl",
  "agent_id": "subagent_001",
  "agent_type": "Explore",
  "terminal_pid": 12345,
  "shell_pid": 67890
}
```

### 12. Notification

通知事件。

```json
{
  "hook_event_name": "Notification",
  "session_id": "019cd686-3b91-78a1-9356-21b475548352",
  "cwd": "/Users/test/project",
  "transcript_path": "/Users/test/.claude/projects/abc/transcript.jsonl",
  "title": "权限请求",
  "message": "Claude 正在请求写入文件的权限",
  "notification_type": "permission_reminder",
  "terminal_pid": 12345,
  "shell_pid": 67890
}
```

### 13. PreCompact

上下文压缩前触发。

```json
{
  "hook_event_name": "PreCompact",
  "session_id": "019cd686-3b91-78a1-9356-21b475548352",
  "cwd": "/Users/test/project",
  "transcript_path": "/Users/test/.claude/projects/abc/transcript.jsonl",
  "terminal_pid": 12345,
  "shell_pid": 67890
}
```

### 14. PostCompact

上下文压缩后触发。

```json
{
  "hook_event_name": "PostCompact",
  "session_id": "019cd686-3b91-78a1-9356-21b475548352",
  "cwd": "/Users/test/project",
  "transcript_path": "/Users/test/.claude/projects/abc/transcript.jsonl",
  "terminal_pid": 12345,
  "shell_pid": 67890
}
```

### 15. TaskCompleted

任务完成时触发。

```json
{
  "hook_event_name": "TaskCompleted",
  "session_id": "019cd686-3b91-78a1-9356-21b475548352",
  "cwd": "/Users/test/project",
  "transcript_path": "/Users/test/.claude/projects/abc/transcript.jsonl",
  "task_id": "task_001",
  "task_subject": "实现用户登录功能",
  "terminal_pid": 12345,
  "shell_pid": 67890
}
```

### 16. TeammateIdle

Teammate 空闲时触发。

```json
{
  "hook_event_name": "TeammateIdle",
  "session_id": "019cd686-3b91-78a1-9356-21b475548352",
  "cwd": "/Users/test/project",
  "terminal_pid": 12345,
  "shell_pid": 67890
}
```

### 17. ConfigChange

配置变更时触发。

```json
{
  "hook_event_name": "ConfigChange",
  "session_id": "019cd686-3b91-78a1-9356-21b475548352",
  "cwd": "/Users/test/project",
  "terminal_pid": 12345,
  "shell_pid": 67890
}
```

### 18. WorktreeCreate

Git worktree 创建时触发。

```json
{
  "hook_event_name": "WorktreeCreate",
  "session_id": "019cd686-3b91-78a1-9356-21b475548352",
  "cwd": "/Users/test/project",
  "terminal_pid": 12345,
  "shell_pid": 67890
}
```

### 19. WorktreeRemove

Git worktree 移除时触发。

```json
{
  "hook_event_name": "WorktreeRemove",
  "session_id": "019cd686-3b91-78a1-9356-21b475548352",
  "cwd": "/Users/test/project",
  "terminal_pid": 12345,
  "shell_pid": 67890
}
```

---

## permission_suggestions 字段说明

`permission_suggestions` 是一个数组，每个元素包含以下结构：

### addRules 类型

添加权限规则（如 "Always allow in folder"）。

| 字段 | 类型 | 说明 |
|------|------|------|
| `type` | String | 固定为 `"addRules"` |
| `destination` | String | `"session"` 或 `"localSettings"` |
| `behavior` | String | `"allow"` |
| `rules` | Array | 规则数组 |

**rules 数组元素：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `toolName` | String | 工具名称，如 `"Bash"`, `"Write"` |
| `ruleContent` | String | 规则内容，可以是具体命令或路径通配符如 `/Users/test/project/**` |

```json
{
  "type": "addRules",
  "destination": "session",
  "behavior": "allow",
  "rules": [
    {
      "toolName": "Bash",
      "ruleContent": "npm install"
    }
  ]
}
```

### setMode 类型

设置权限模式（如 "Auto-accept edits"）。

| 字段 | 类型 | 说明 |
|------|------|------|
| `type` | String | 固定为 `"setMode"` |
| `destination` | String | `"session"` 或 `"localSettings"` |
| `mode` | String | 模式名称，如 `"acceptEdits"`, `"plan"` |

```json
{
  "type": "setMode",
  "destination": "session",
  "mode": "acceptEdits"
}
```

---

## 弹窗场景总结

| 弹窗类型 | tool_name | 说明 |
|----------|-----------|------|
| 标准权限 | `Bash`, `Write`, `Edit`, `Read` 等 | 请求工具执行权限 |
| Plan 确认 | `ExitPlanMode` | 展示计划并等待用户确认 |
| 问题交互 | `AskUserQuestion` | 展示问题选项供用户选择 |

---

## 字段完整列表

| 字段 | snake_case | 类型 | 适用事件 |
|------|------------|------|----------|
| hookEventName | `hook_event_name` | String | 全部 |
| sessionId | `session_id` | String? | 全部 |
| cwd | `cwd` | String? | 全部 |
| transcriptPath | `transcript_path` | String? | 大部分 |
| permissionMode | `permission_mode` | String? | PermissionRequest |
| toolName | `tool_name` | String? | 工具相关事件 |
| toolUseId | `tool_use_id` | String? | 工具相关事件 |
| toolInput | `tool_input` | Object? | PreToolUse, PostToolUse, PermissionRequest |
| toolResponse | `tool_response` | Object? | PostToolUse, PostToolUseFailure |
| message | `message` | String? | UserPromptSubmit, Notification, Stop |
| title | `title` | String? | Notification |
| notificationType | `notification_type` | String? | Notification |
| source | `source` | String? | SessionStart, SessionEnd |
| reason | `reason` | String? | SessionEnd, StopFailure |
| model | `model` | String? | SessionStart |
| stopHookActive | `stop_hook_active` | Bool? | Stop |
| lastAssistantMessage | `last_assistant_message` | String? | Stop, StopFailure |
| agentId | `agent_id` | String? | SubagentStart, SubagentStop |
| agentType | `agent_type` | String? | SubagentStart, SubagentStop |
| taskId | `task_id` | String? | TaskCompleted |
| taskSubject | `task_subject` | String? | TaskCompleted |
| permissionSuggestions | `permission_suggestions` | Array? | PermissionRequest |
| terminalPid | `terminal_pid` | Int? | 全部 (hook脚本注入) |
| shellPid | `shell_pid` | Int? | 全部 (hook脚本注入) |
