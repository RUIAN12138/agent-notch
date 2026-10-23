# 自定义 Agent 只读生命周期接入

Agent Notch 的 Bridge 可接入按 Hook/事件触发的 Agent。此能力借鉴了 Vibe Island 官方 [Custom Agents 文档](https://vibeisland.app/docs/custom-agents/) 与 [Agent 集成指南](https://vibeisland.app/docs/custom-agents-agent-guide/)中“每个生命周期事件调用一次命令、无需专用 SDK”的接入思路；它不是 Vibe Island manifest 的兼容实现，也不代表对方未公开运行时的逆向结论。

## 配置约定

为 Agent 分配一个唯一来源标识，并在该 Agent 官方支持的生命周期 Hook 中调用已安装的 Bridge：

```sh
"$HOME/.multiagent-notch/bin/notch-bridge.py" \
  --source my-agent \
  --event UserPromptSubmit
```

若 Hook 的标准输入已包含 `hook_event_name`，可以省略 `--event`。`--source` 使用小写 ASCII slug：首字符为字母，其余字符为字母、数字、`_` 或 `-`，总长不超过 64 字符。Bridge 会将合法值规范成小写；非法值安全降级为 `unknown`。

建议只注册 Agent 能稳定提供的 `SessionStart`、`UserPromptSubmit`、`PreToolUse`、`PostToolUse`、`PostToolUseFailure`、`Stop`、`StopFailure`、`SessionEnd`。Agent Notch 会保留来源身份并展示工作/工具活动；自定义 Agent 的工具名可以显示，但提示词和原始工具输入不会进入合成 transcript。

## 能力边界

- 自定义来源是只读状态观察，不会被路由到 Claude/Codex 的聊天传输。
- 自定义来源不支持审批、问答、通知或子 Agent 控制事件；这些事件会被 Bridge 成功忽略，不阻塞外部 Agent。
- 会话仍可使用已有 PID/TTY 信息尝试定位终端，但这不等于自定义终端协议或聊天通道已验证。
- 不要仅因 Bridge 接受某个 `--source` 就宣称该 Agent 已完整兼容。应逐项核对它的 Hook 语义、事件身份、失败/取消边界和真实安装环境。

完整的 Vibe Island 实现包含自己的来源清单与字段/事件映射；Agent Notch 目前只采用轻量 Hook 命令边界，避免为每个 Agent 重复造专用 SDK。
