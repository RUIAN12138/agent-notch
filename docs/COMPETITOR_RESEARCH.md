# 竞品逆向证据与 Agent Notch 决策记录

审查日期：2026-10-23
Agent Notch 基线：`main` / `5154504`
范围：Vibe Island 1.0.54 官方 DMG、Boring Notch 2.7.3 官方 DMG，以及 Boring Notch `v2.7.3` 源码标签。

## 证据边界

本记录将已观测的包/源码事实与产品推断分开。两款竞品均未安装或启动；Vibe Island 的二进制未被反编译。REA 当前没有可用的 Hopper/Ghidra 分析提供器，因此其 Mach-O 结果只支持架构、依赖、导入和构建元数据等静态结论。Boring Notch 的悬停行为来自对应标签的源码，不证明发行二进制与该源码逐字节对应。

## REA 观察

| 对象 | 直接观察 | REA Evidence |
| --- | --- | --- |
| Vibe Island DMG | SHA-256 `2118d419e7ecbd8c9484cd4bc52bb6858610dac4e7f548cdf0763e6281be19e6`；完整清单 355 nodes / 376 occurrences / 360 edges；0 个完整性矛盾。本轮按用户选择再次只读检查，哈希与前次一致。 | `inspect_artifact`：`ev_2fd3ec2eadd9670dd32f46de9f0353b573e2055d12ff1905ef324fecb5242678`、`ev_4d624609ce9e97ef007cb73da2fd4bf25c8b9b7794a2ca81e497d9f7c130819e`；inventory: `ev_b92df0db220721a97272bf4f18894812fc945c3adea69d57be28f799e60f129c`、`ev_ac1faa260c5b4e7ddf9554877f19304779b097258419a1e70a511a7c847c9289`；前次资源页：`ev_fff3bbe96ebb3f9c87d99200087a0498278c484f4cae7611e811e84dea8afd8` |
| Vibe Island 主程序 | `vibe-island`，arm64 Mach-O；二进制 SHA-256 `3023bc09dff55329a19fdb09d6a3c76227159a0dcaa8f656ca04f4ae941bd2f4`。REA 报告 73 个 load commands、54 个依赖、3,519 个已返回 imports；imports 不完整，不能据此证明缺少其他符号。 | Mach-O: `ev_4c8cdef3f048a544d8a785375d9e252125d6b654b50d345c52782124d559a3c1`；summary view: `ev_284f40ac10de2f9565274cd96bf3167d9b7933b686db17e4cd5e885e7d1de786` |
| Vibe Island 原生派发元数据 | 对 arm64 主程序尝试 REA `inspect_native_dispatch_metadata`；读取器因 `objc_ivars` 第 46、48 项名称为空而失败，未产生可保留的 Evidence。该失败只说明当前读取器无法继续，不证明应用自身有缺陷；本机没有可用 Hopper/Ghidra 反编译提供器。 | REA 6.5.0 的执行错误诊断；无 Evidence ID |
| Vibe Island `Info.plist` | 版本 `1.0.54`，Bundle ID `app.vibeisland.macos`，构建提交字段 `c239e829231c`；声明启用用量功能、Apple Events 用途及 Sparkle 自动更新。均为包内声明，不是运行行为证明。 | `ev_c26a3fc6c573ef66fea89099cce06bd0fb736c9c57e19728f903e2a3ef196a26`、`ev_bc51bacf08ededa66dda128370432483f9746d50ed3573cace4dba2604e79e47` |
| Vibe Island 简体中文设置资源 | `zh-Hans.lproj/Localizable.strings` 中含有完成通知自动展开、问题到达时展开、Team 队友完成时展开、悬停延迟、全屏隐藏、空闲自动隐藏及完成停留时长等文案。另有子 Agent 提醒时机选项：每个完成、全部完成、主 Agent 回复。Team 完成设置帮助文案明确写着默认关闭、且不展开主面板/不播放完成音。资源文案不能单独证明设置实际接入了状态机或其运行效果。 | `inspect_plist`: `ev_28b3fbaad320405079e7b244b28417a3c315ebb5ac80873a3e72c30c840c10ea` |
| Vibe Island RemoteAgent manifest | 包内存在 schema v2 清单：远程 Agent 协议 `1.12.0`，覆盖 darwin/linux/freebsd 的 amd64/arm64，并列出每个资产的 SHA-256。REA 将文件识别为已验证的 2,261-byte 资源；清单本身是否有独立签名、应用如何验证和执行它，仍未知。 | inventory occurrence `art_de34ec5479366b67bdaea3124dcbc6cf188700ef1b587433e363b9dccfc9c166`；父 inventory `ev_e209a4be37f6f277738b5d7da78f5f22063ac15c32b6a3c2fccf0a025469d282` |
| Vibe Island 用量价格数据 | 包内另有 17,446-byte `usage-pricing.json`，顶层键包括 `models`、`aliases`、`schemaVersion`、`source` 和 `syncedAt`。本轮只确认资源存在及 schema 顶层，未校验单价、更新来源或 UI 使用路径。 | inventory occurrence `art_a953d29db95b76658e25c92eab9e58acf6f39ce099465653db3030d4df706f61`；父 inventory同上 |
| Boring Notch DMG | SHA-256 `23786382548d33c59b309db558e513a92e3f95b63d611544dcddf5d196e46698`；完整清单 229 nodes / 249 occurrences / 236 edges；0 个完整性矛盾。 | `inspect_artifact` 本轮重查：`ev_c53bd004dbd0660eae2ad30203d9d4213fb1f7f2796494cbcd646b21710eebe0`；inventory: `ev_451f56e7de5b1c371b241af2a5c195898f4be2f3d92a6c56de2aa4a788208033`；当前会话的清单汇总：`ev_f1a611572a604f6b3f88ccef988548996b5b45e1976c2669b3c0084495893bb0` |
| Boring Notch 主程序 | 发行包标记为 `2.7.3`；arm64 Mach-O SHA-256 `f136e7334c4c197c9d0fbdcbb0d95649771ed7427bcf361b28aa76af03ed3900`。REA 静态读取 75 个 load commands、57 个依赖；imports 非穷尽。派发元数据读取到 174 个 Objective-C class 记录和 113 个派发实现，但整体覆盖仍为 partial。 | Info.plist: `ev_07126bfb88575ccce59ce775049df9668e96c48b473317a8e74dbebda364817d`；Mach-O: `ev_7a890069c239ac1ebb58f5727a28ebb1fc88577d4cb3d606bb4b0ba77a56390c`；dispatch: `ev_3ef795e325685c37f257a42577a014acc75751fc7212bfbe4a2fc85c3b963756` |

Vibe Island 资源 occurrence 的完整逻辑路径为 `VibeIsland.dmg/Vibe Island/Vibe Island.app/Contents/Resources/RemoteAgent/manifest.json` 和 `.../usage-pricing.json`。本轮 REA 直接检查 DMG 获得完整清单；由于 REA 的 DMG 解包器不支持该格式，随后只读挂载以解析 `Info.plist` 和简体中文 `.strings`。没有执行其中的程序，也没有访问清单 URL。REA 6.5.0 的 `analyze_swift_types` 因没有配置 Ghidra/Hopper/IDA provider 返回 `provider_unavailable`，未生成符号证据；本轮不安装分析器、不绕过此限制。

## Boring Notch 源码观察与可迁移点

本地源码 checkout 精确落在 tag `v2.7.3`，commit `16b0f11f51c79d42e27c10d77fd9e53c11410fdb`；该项目使用 GPL-3.0。`ContentView.swift` 的悬停处理取消前一任务、展开前等待可配置停留时间、在主线程再次检查指针/状态/浮层条件；默认展开等待由 `minimumHoverDuration` 设为 0.3 秒。退出后等待 100ms，并在关闭前检查电量弹层与屏幕共享保护。展开/收起共享一个 `interactiveSpring(response: 0.38, dampingFraction: 0.8)`。这些是源码观察，不代表发行二进制与该标签逐字节对应，也不代表真实桌面运行验收。

- 源码：[悬停与展开处理](https://github.com/TheBoredTeam/boring.notch/blob/v2.7.3/boringNotch/ContentView.swift)、[视图模型](https://github.com/TheBoredTeam/boring.notch/blob/v2.7.3/boringNotch/models/BoringViewModel.swift)、[GPL-3.0 许可](https://github.com/TheBoredTeam/boring.notch/blob/v2.7.3/LICENSE)
- 迁移方式：只采纳“延迟任务必须可撤销、触发时再次验证当前状态”的交互原则，不复制其源码或可识别的界面表达。
- 已落地：Agent Notch 在 `d769929` 为指针转换增加独立代次，覆盖重排、展开、收起、用户接管和审批弹出；旧回调即使在指针回到相同状态后执行也会失效。本轮进一步将默认悬停进入延迟设为 0.3 秒、离开收起延迟设为 0.2 秒，并把收起延迟下限开放到 0.1 秒；单独保存的用户值保持不变。相关代码与回归测试位于 `ClaudeIsland/Core/NotchViewModel.swift`、`ClaudeIsland/Core/Settings.swift`、`ClaudeIsland/UI/Views/NotchStudioSettingsView.swift` 和 `ClaudeIslandTests/NotchPointerInteractionTests.swift`。

## 当前版本包与启动边界（2026-10-23）

本轮再次校验两份 DMG 的 SHA-256 与上表一致，并只读挂载检查应用包；完成后已卸载。用户本轮选择“仅静态分析”，且要求不触发更新/下载、不绕过系统安全设置，因此没有启动任何竞品；以下均为包内字符串、配置和源码观察，不是实际 UI 或运行行为。

- Vibe Island 包内信息为 `1.0.54` / `app.vibeisland.macos`。`Info.plist` 声明 `SUAutomaticallyUpdate = true` 并配置 Sparkle feed；启动可能发起更新检查或下载，因此未启动。
- Boring Notch 的 `spctl --assess --type execute` 返回 `rejected`。其上游 README 说明首次运行需在“系统设置 → 隐私与安全性”手动“仍要打开”；本轮没有移除隔离标记、修改 Gatekeeper 或绕过该提示，未启动该应用。
- Vibe Island 简体中文资源静态列出了悬停展开、鼠标离开收起、全屏隐藏、悬停延迟、问题到达时展开、任务完成时展开和空闲隐藏等独立设置。Agent Notch 已具备悬停展开/收起、单独延迟、全屏显示开关和问题自动展开；任务完成则采用紧凑提示、停留时长与轻微动画，不默认抢占用户当前窗口。这是不同的注意力策略，不应在没有偏好确认和真实验收前直接改成自动展开。
- [Vibe Island 官方 GitHub 仓库](https://github.com/vibeislandapp/vibe-island)把自己说明为问题反馈、功能请求和讨论的社区入口；该公开仓库未提供应用 Swift 源码。结合 REA 派发读取失败，本轮对 Vibe Island 的状态机判断仍限于包内配置/字符串和公开说明，没有伪造反编译结论。
- 因此，本轮只确认了 Vibe Island 的设置文案/包配置和 Boring Notch 的 Gatekeeper 状态；没有截图、无障碍树、实际悬停轨迹或真实状态切换证据。若后续需要运行时比较，需在不启用自动更新的安全启动方式明确后再继续；Boring Notch 还需由用户决定是否手动处理 macOS 的首次打开提示。

## 状态事件优先级：复现与修复

源码复核发现，`handleWaitingForInputChange` 在任一新完成事件到达时会关闭所有 `.notification` 所有权的展开面板；而 `showApproval(for:)` 也用 `.notification` 打开审批卡片。因此，一个无关会话完成时，仍待处理的审批也会被收起，属于真实的触发优先级冲突。新增回归测试先按旧策略复现为 14 项中 1 项失败。

修复后，完成事件仅在没有仍需自动展开的权限/问题交互时收起陈旧通知面板。判定复用 `shouldAutoExpandInteraction`：普通审批和计划审查会保护展开态；关闭“问题自动展开”时，`AskUserQuestion` 不会错误阻止收起；用户手动打开的面板仍不被完成事件接管。此改动只通过托管单元测试，不代表真实 UI 验收。

## 完成通知自动展开：静态线索与本地实现

Vibe Island 的简体中文资源明确区分“完成时自动展开”和“Team 队友完成时自动展开”，并为完成通知提供展开停留时长。它们是设置资源观察；由于本轮按用户选择只做静态分析，没有把这些文案当作真实 UI 或状态机行为证据。

Agent Notch 据此新增默认关闭的“任务完成时展开”选项。开启后，仅新的、处于当前提醒时限内且未匹配静音规则的完成事件可以打开会话列表；待处理且具有自动展开资格的审批/问题优先，用户已打开的点击/键盘/悬停面板不被接管，并继续使用现有全屏空间准入检查。自动展开面板在剩余完成停留时长后收起；如果用户在面板内交互（所有权转为 click），或出现待处理的自动展开交互，则不会被计时器收起。关闭该选项时仍保持原来的紧凑完成提醒行为。

这项是基于竞品设置文案做出的 Agent Notch 产品决策，不是对 Vibe Island 私有实现的复刻结论。新增测试覆盖默认值与持久化、打开策略/所有权边界、全屏空间拒绝，以及延迟到达时仍从真实 `completedAt` 计算停留时间。

## 子 Agent 完成时序

重新读取已导入的 REA 静态证据（共 26 条记录）后，`ev_28b3fbaad320405079e7b244b28417a3c315ebb5ac80873a3e72c30c840c10ea` 中还观察到 Vibe Island 设置资源提供“每个子 Agent 完成 / 全部完成 / 主 Agent 回复”三种通知时机，且 Team 自动展开默认关闭、无完成提示音。这些是包内资源文字，不证明竞品运行时状态机的具体实现。

协议核验后发现，Claude Code 官方 Hook 文档明确给 `SubagentStart` 与 `SubagentStop` 提供稳定 `agent_id`；`SubagentStop` 的 `agent_id` 与类型可用于匹配对应子 Agent。参见[官方 Hooks reference](https://code.claude.com/docs/en/hooks) 中的 `SubagentStart input`、`SubagentStop input` 和 common input fields。Agent Notch 现在将该 ID 从 Bridge 传入 HookEvent，并在私有 Bridge 快照中以锁保护的原子读改写保留每个 ID 最近的活动状态与事件时间，应用在中途启动或重启时可恢复当前并行集合。Swift 状态机按 ID 配对开始/结束，忽略同一 ID 的重复 Stop 和更旧的 Start；只有已观察到至少一个匹配的活动 ID、且最后一个活动 ID 被结束时，才生成“全部完成”代次。无法确认身份时不会伪造全完成。

设置现提供默认关闭的“关闭 / 每个子 Agent / 全部完成后 / 主 Agent 回复时”。旧版显式开启的布尔偏好迁移为“每个子 Agent”；“主 Agent 回复时”只在本轮已观测到 SubagentStart 后，等根 `Stop` 才生成独立提醒，不会把没有子 Agent 的普通完成误判为队友提醒。根 Agent `Stop` 独立决定会话是否完成。若根 `Stop` 已先到，但本轮某个精确匹配且仍活动的子 Agent 随后完成，按“每个子 Agent / 全部完成后”策略仍可生成队友提醒；这不会重新打开根回合，也不会改变会话完成状态。没有匹配到本轮活动 ID 的迟到/重复事件不生成提醒。提示使用 Hook 源时间戳计算现有停留时间，不播放声音，静音规则、审批/问题优先级、用户拥有的展开面板和全屏准入仍然有效。

已识别的 Hook 版本在 Claude Code `2.0.43+` 注册 `SubagentStart`；版本未知或旧版本不假定“全部完成”可用，而是保持安全降级。Bridge 全套 Python 测试为 91 项通过；Swift 回归覆盖 ID 解码、并行集合归零、重复 Stop、乱序 Start、根回复时机、离线快照恢复和旧设置迁移。托管 XCTest 结果是状态/协议回归证据，不是已安装应用或真实 Hook 回合验收。

## 对用户提供的旧风险审查的当前核验

截至本记录基线，旧审查中若干 P0/P1 判断已不再符合源码：

- `ProcessExecutor` 的异步和同步路径都并发读取 stdout/stderr，使用有界缓冲和超时/取消清理；`ProcessExecutorTests` 覆盖双管道大输出、超时与后代持有管道场景。
- 权限响应不使用 session-only fallback。UI、`ClaudeSessionMonitor` 和 `HookSocketServer` 都校验会话、`toolUseId` 与请求身份；`PermissionRoutingTests` 覆盖重复 ID、替换请求、迟到回调和私有 socket 路由。
- `ProcessTreeBuilder` 有 400ms 拓扑缓存；SessionStore 只在新会话或 PID/TTY 改变时强制刷新。
- `ConversationParser` 已有按文件偏移增量读取和 Codex rollout 索引/缓存，不是每次都从头解析整个 transcript。
- `.github/workflows/ci.yml` 已运行 `AgentNotchCoreTests` Swift XCTest，而不只是 Python Bridge 和构建。

本轮在当前工作树运行 `ProcessExecutorTests`、`PermissionRoutingTests`、`SessionStoreLifecycleTests` 和 `NotchPresentationTimingTests`：73 passed、0 failed、0 skipped。Xcode 结果同时记录一条 `ProcessExecutorTests.swift` 的 QoS priority-inversion runtime warning；这不是测试失败，仍应单独跟进。`SessionStore`、`ConversationParser`、`ChatView` 的职责/体积仍是维护性债务，但不据此做无边界重写。

本轮按 Boring Notch 的 hover 时序调整默认值后，运行 `NotchPointerInteractionTests` 与 `NotchPresentationTimingTests`：27 passed、0 failed。测试运行期间系统记录了 `com.apple.linkd.autoShortcut` 的连接警告，但所选测试全部通过；这仍是单元/托管测试证据，不是已安装应用的真实鼠标交互验收。

本轮在完成/审批优先级修复后运行上述两个套件：28 passed、0 failed。新增用例覆盖通知所有权、仍待处理的审批、可配置的普通问题，以及用户主动打开面板的边界；这是 policy/UI wiring 的测试，不是 macOS 桌面端到端验收。

本轮新增完成时自动展开与停留策略后，运行 `NotchCompletionExpansionTests`、`NotchPresentationTimingTests`、`NotchPointerInteractionTests` 和 `NotchFullScreenTests`：34 passed、0 failed、0 skipped。该结果覆盖偏好、策略、全屏准入与相关状态逻辑；仍不是已安装应用的真实桌面端到端验收。

## 采用、暂缓与未验证项

- **已采用**：Boring Notch 的可撤销 hover 时序原则已独立实现；其 0.3 秒进入等待和 100ms 退出复核启发了 Agent Notch 的新默认值（0.3 秒进入、0.2 秒退出），同时保留 Agent Notch 自己的指针代次防竞态与扩大后的几何命中边界。
- **已修复**：完成事件不再误收起仍有自动展开资格的审批/提问面板；依据是 Agent Notch 源码复现与回归测试，不声称这是 Vibe Island 私有实现的逆向结论。
- **新增可选策略**：Vibe Island 安装包静态资源展示根任务与 Team 队友完成自动展开，以及三种子 Agent 通知时机；Agent Notch 已实现默认关闭的根任务完成和队友完成展开，并复用既有停留时长自动收起，保留审批、用户所有权和全屏策略优先级。基于 Claude Hook 的精确 `agent_id`，队友提醒已支持“每个子 Agent / 全部完成后 / 主 Agent 回复时”三种时机；有效的本轮活动子 Agent 即使在根 Agent 已结束响应后才完成，也只生成队友提醒，不复活根会话状态。
- **候选但暂缓**：Vibe Island 的平台化 RemoteAgent manifest 与版本/散列清单可作为未来分发设计参考；当前不引入 SSH/远程执行能力，避免在核心状态与审批可靠性尚需真实运行验收时扩张权限面。
- **暂不采用**：Vibe Island 的价格数据资源；Agent Notch 已有订阅用量与会话 token 数据，但没有经过验证的跨模型成本口径，本轮也不扩展该功能。
- **未验证**：Vibe Island 的真实展开/收起、Agent 状态与审批交互。REA residual unknown `unk_055a4d687c6b84aff4d6bfdb2cc58b8da51794c7c245ccb8d34ed25647e99186` 要求 controlled replay；后续若要启动竞品 app，须在动作时确认，并避免登录、授权系统控制、触发终端控制或远程资产下载。
- **未验证**：Boring Notch 发行二进制与源码 tag 的构建对应关系，以及两款竞品在真实桌面中的完整行为矩阵。

因此本记录不是“竞品功能已经完整复刻”或“真实 Mac 交互验收通过”的声明，而是后续实现可引用的静态证据、已采纳决策和剩余验证边界。
