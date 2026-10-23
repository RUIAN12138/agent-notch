# 竞品逆向证据与 Agent Notch 决策记录

审查日期：2026-10-23
Agent Notch 基线：`main` / `d769929`
范围：Vibe Island 1.0.54 官方 DMG、Boring Notch 2.7.3 官方 DMG，以及 Boring Notch `v2.7.3` 源码标签。

## 证据边界

本记录将已观测的包/源码事实与产品推断分开。两款竞品均未安装或启动；Vibe Island 的二进制未被反编译。REA 当前没有可用的 Hopper/Ghidra 分析提供器，因此其 Mach-O 结果只支持架构、依赖、导入和构建元数据等静态结论。Boring Notch 的悬停行为来自对应标签的源码，不证明发行二进制与该源码逐字节对应。

## REA 观察

| 对象 | 直接观察 | REA Evidence |
| --- | --- | --- |
| Vibe Island DMG | SHA-256 `2118d419e7ecbd8c9484cd4bc52bb6858610dac4e7f548cdf0763e6281be19e6`；完整清单 355 nodes / 376 occurrences / 360 edges；0 个完整性矛盾。 | `inspect_artifact`: `ev_e10eb227d5c7181d4f2d105b5512e0cf1107cb24f9da616673ce358823f66d60`；inventory: `ev_e209a4be37f6f277738b5d7da78f5f22063ac15c32b6a3c2fccf0a025469d282` |
| Vibe Island 主程序 | `vibe-island`，arm64 Mach-O；二进制 SHA-256 `3023bc09dff55329a19fdb09d6a3c76227159a0dcaa8f656ca04f4ae941bd2f4`。REA 报告 73 个 load commands、54 个依赖、3,519 个已返回 imports；imports 不完整，不能据此证明缺少其他符号。 | Mach-O: `ev_4c8cdef3f048a544d8a785375d9e252125d6b654b50d345c52782124d559a3c1`；summary view: `ev_284f40ac10de2f9565274cd96bf3167d9b7933b686db17e4cd5e885e7d1de786` |
| Vibe Island `Info.plist` | 版本 `1.0.54`，Bundle ID `app.vibeisland.macos`，构建提交字段 `c239e829231c`；声明启用用量功能，并声明 Apple Events 用途是跳转至终端正确的窗口、标签页和会话。这些是包内声明，不是运行行为证明。 | `ev_c26a3fc6c573ef66fea89099cce06bd0fb736c9c57e19728f903e2a3ef196a26` |
| Vibe Island RemoteAgent manifest | 包内存在 schema v2 清单：远程 Agent 协议 `1.12.0`，覆盖 darwin/linux/freebsd 的 amd64/arm64，并列出每个资产的 SHA-256。REA 将文件识别为已验证的 2,261-byte 资源；清单本身是否有独立签名、应用如何验证和执行它，仍未知。 | inventory occurrence `art_de34ec5479366b67bdaea3124dcbc6cf188700ef1b587433e363b9dccfc9c166`；父 inventory `ev_e209a4be37f6f277738b5d7da78f5f22063ac15c32b6a3c2fccf0a025469d282` |
| Vibe Island 用量价格数据 | 包内另有 17,446-byte `usage-pricing.json`，顶层键包括 `models`、`aliases`、`schemaVersion`、`source` 和 `syncedAt`。本轮只确认资源存在及 schema 顶层，未校验单价、更新来源或 UI 使用路径。 | inventory occurrence `art_a953d29db95b76658e25c92eab9e58acf6f39ce099465653db3030d4df706f61`；父 inventory同上 |
| Boring Notch DMG | SHA-256 `23786382548d33c59b309db558e513a92e3f95b63d611544dcddf5d196e46698`；完整清单 229 nodes / 249 occurrences / 236 edges；0 个完整性矛盾。 | `inspect_artifact`: `ev_de40a4f52586602a93497b1a15ad4a54d870144e1198b5b603e83673245424dd`；inventory: `ev_2f0b2bf5221e6cb77d6242c4d3833c8cdffa14b79e7442b54ffe2e73dded71d2` |
| Boring Notch 主程序 | 发行包标记为 `2.7.3`；arm64 Mach-O SHA-256 `f136e7334c4c197c9d0fbdcbb0d95649771ed7427bcf361b28aa76af03ed3900`。 | Info.plist: `ev_07126bfb88575ccce59ce775049df9668e96c48b473317a8e74dbebda364817d`；Mach-O: `ev_7a890069c239ac1ebb58f5727a28ebb1fc88577d4cb3d606bb4b0ba77a56390c` |

Vibe Island 资源 occurrence 的完整逻辑路径为 `VibeIsland.dmg/Vibe Island/Vibe Island.app/Contents/Resources/RemoteAgent/manifest.json` 和 `.../usage-pricing.json`。DMG 在只读挂载后检查；没有执行其中的程序，也没有访问清单 URL。

## Boring Notch 源码观察与可迁移点

本地源码 checkout 精确落在 tag `v2.7.3`，commit `16b0f11f51c79d42e27c10d77fd9e53c11410fdb`；该项目使用 GPL-3.0。`ContentView.swift` 的悬停处理取消前一任务、展开前等待可配置停留时间、在主线程再次检查指针/状态/浮层条件；退出后等待 100ms，并在关闭前检查电量弹层与屏幕共享保护。展开/收起共享一个 `interactiveSpring(response: 0.38, dampingFraction: 0.8)`。

- 源码：[悬停与展开处理](https://github.com/TheBoredTeam/boring.notch/blob/v2.7.3/boringNotch/ContentView.swift)、[视图模型](https://github.com/TheBoredTeam/boring.notch/blob/v2.7.3/boringNotch/models/BoringViewModel.swift)、[GPL-3.0 许可](https://github.com/TheBoredTeam/boring.notch/blob/v2.7.3/LICENSE)
- 迁移方式：只采纳“延迟任务必须可撤销、触发时再次验证当前状态”的交互原则，不复制其源码或可识别的界面表达。
- 已落地：Agent Notch 在 `d769929` 为指针转换增加独立代次，覆盖重排、展开、收起、用户接管和审批弹出；旧回调即使在指针回到相同状态后执行也会失效。相关代码与回归测试位于 `ClaudeIsland/Core/NotchViewModel.swift` 和 `ClaudeIslandTests/NotchPresentationTimingTests.swift`。

## 对用户提供的旧风险审查的当前核验

截至本记录基线，旧审查中若干 P0/P1 判断已不再符合源码：

- `ProcessExecutor` 的异步和同步路径都并发读取 stdout/stderr，使用有界缓冲和超时/取消清理；`ProcessExecutorTests` 覆盖双管道大输出、超时与后代持有管道场景。
- 权限响应不使用 session-only fallback。UI、`ClaudeSessionMonitor` 和 `HookSocketServer` 都校验会话、`toolUseId` 与请求身份；`PermissionRoutingTests` 覆盖重复 ID、替换请求、迟到回调和私有 socket 路由。
- `ProcessTreeBuilder` 有 400ms 拓扑缓存；SessionStore 只在新会话或 PID/TTY 改变时强制刷新。
- `ConversationParser` 已有按文件偏移增量读取和 Codex rollout 索引/缓存，不是每次都从头解析整个 transcript。
- `.github/workflows/ci.yml` 已运行 `AgentNotchCoreTests` Swift XCTest，而不只是 Python Bridge 和构建。

本轮在当前工作树运行 `ProcessExecutorTests`、`PermissionRoutingTests`、`SessionStoreLifecycleTests` 和 `NotchPresentationTimingTests`：73 passed、0 failed、0 skipped。Xcode 结果同时记录一条 `ProcessExecutorTests.swift` 的 QoS priority-inversion runtime warning；这不是测试失败，仍应单独跟进。`SessionStore`、`ConversationParser`、`ChatView` 的职责/体积仍是维护性债务，但不据此做无边界重写。

## 采用、暂缓与未验证项

- **已采用**：Boring Notch 的可撤销 hover 时序原则，已独立实现并提交。
- **候选但暂缓**：Vibe Island 的平台化 RemoteAgent manifest 与版本/散列清单可作为未来分发设计参考；当前不引入 SSH/远程执行能力，避免在核心状态与审批可靠性尚需真实运行验收时扩张权限面。
- **暂不采用**：Vibe Island 的价格数据资源；Agent Notch 已有订阅用量与会话 token 数据，但没有经过验证的跨模型成本口径，本轮也不扩展该功能。
- **未验证**：Vibe Island 的真实展开/收起、Agent 状态与审批交互。REA residual unknown `unk_055a4d687c6b84aff4d6bfdb2cc58b8da51794c7c245ccb8d34ed25647e99186` 要求 controlled replay；后续若要启动竞品 app，须在动作时确认，并避免登录、授权系统控制、触发终端控制或远程资产下载。
- **未验证**：Boring Notch 发行二进制与源码 tag 的构建对应关系，以及两款竞品在真实桌面中的完整行为矩阵。

因此本记录不是“竞品功能已经完整复刻”或“真实 Mac 交互验收通过”的声明，而是后续实现可引用的静态证据、已采纳决策和剩余验证边界。
