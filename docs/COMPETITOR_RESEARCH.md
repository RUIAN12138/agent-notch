# 竞品逆向证据与 Agent Notch 决策记录

审查日期：2026-10-25
Agent Notch 基线：`main` / `0dcf6b7`（本轮改动前）
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
| Vibe Island 简体中文设置资源 | `zh-Hans.lproj/Localizable.strings` 中含有完成通知自动展开、问题到达时展开、Team 队友完成时展开、悬停延迟、全屏隐藏、空闲自动隐藏、完成停留时长，以及“Agent 所在终端标签页在前台时不自动展开面板”的智能抑制文案。另有子 Agent 提醒时机选项：每个完成、全部完成、主 Agent 回复。Team 完成设置帮助文案明确写着默认关闭、且不展开主面板/不播放完成音。资源文案不能单独证明设置实际接入了状态机或其运行效果。 | `inventory_artifact` 页面：`ev_eb47da71cc1c0f4793a118286075930e99938fcdbb6bdc43963b905d40e631b4`；occurrence `occ_e1e8dadd03d71452fd16a16261065a2d19ae6e720edd245dd0eabcd07ec445c6`，artifact `art_8d21ee25fc054cf464625ada06632f105c486b6182983b745292e1d3f9b1459f`；父清单 `ev_ac1faa260c5b4e7ddf9554877f19304779b097258419a1e70a511a7c847c9289` |
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

### 收起边界清理瞬态选择器（2026-10-25）

Boring Notch `v2.7.3` 的 `BoringViewModel.close()` 会清理电量弹层、peek 预览和边缘自动展开等短命呈现状态（[官方源码，`close()`](https://github.com/TheBoredTeam/boring.notch/blob/v2.7.3/boringNotch/models/BoringViewModel.swift#L183-L200)）。对照 Agent Notch，屏幕、声音和 Claude 目录选择器把 `isPickerExpanded` 存在共享 selector 中；菜单视图消失不会自动销毁这些状态，因此收起后再次打开可能仍展开旧 picker。

Agent Notch 现在在统一 `notchClose()` 路径折叠这三个瞬态 picker，只清理呈现状态，不改动已保存的屏幕、声音或目录选择。`NotchPointerInteractionTests.testClosingAndReopeningPanelKeepsSettingsPickersCollapsed` 覆盖收起、再次打开和偏好保持。该结论依据上游源码与 Agent Notch 本地状态路径，测试不是已安装应用的桌面端到端验收。

### 录屏隐藏开关：能力参考与不采纳边界

Boring Notch `v2.7.3` 的设置视图提供“Hide from screen recording”选项，`BoringNotchSkyLightWindow.swift` 会据此设置 `NSWindow.sharingType`。这是对应源码标签的静态观察，不等于发行包运行行为。Apple 当前文档把 `.none` 标为 legacy，并明确警告不要依赖它隐藏屏幕捕获中的内容；因此 Agent Notch 不会照搬该实现，也不会以此向用户承诺截图/录屏隐私。若未来要做类似偏好，必须先找到当前受支持且经真实系统捕获验证的机制；仅隐藏窗口或设置旧 API 不足以证明内容未被捕获。

- 参考：[Boring Notch `v2.7.3` 设置](https://github.com/TheBoredTeam/boring.notch/blob/v2.7.3/boringNotch/components/Settings/SettingsView.swift)、[窗口实现](https://github.com/TheBoredTeam/boring.notch/blob/v2.7.3/boringNotch/components/Notch/BoringNotchSkyLightWindow.swift)、[Apple `NSWindow.SharingType`](https://developer.apple.com/documentation/appkit/nswindow/sharingtype-swift.enum?changes=_4) 与 [`.none` 说明](https://developer.apple.com/documentation/appkit/nswindow/sharingtype-swift.enum/none?language=objc)。

## Boring Notch 后续预发布源码（仅源码，不等于发行包）

补充静态查看官方 GitHub 上的 `v2.8-rc.1` 预发布源码后，发现 `ContentView.swift` 将当前通知与音乐列为有序 `liveActivities`，由 `activityIndex` 选择前台项；通知优先显示，过期后从活动集合自然消失，底层音乐即可重新出现，无需额外记录“恢复到哪个内容”。其 [`v2.8-rc.1` 发布说明](https://github.com/TheBoredTeam/boring.notch/releases/tag/v2.8-rc.1)另列出高 CPU 占用、通知 UI、镜像尺寸和音频输出悬停方面的修复。这些发布说明是上游自述，并非本地性能测量。

这条证据来自[`v2.8-rc.1` 的 `ContentView.swift`](https://github.com/TheBoredTeam/boring.notch/blob/v2.8-rc.1/boringNotch/ContentView.swift)，不是已检查的 `v2.7.3` DMG 或标签；本轮没有取得、用 REA 检查或运行 `v2.8-rc.1` 二进制。因此它只作为更晚源码的设计参考。可迁移的原则是将短暂提示按优先级建模并让过期项自然退出；Agent Notch 若实现多提示汇聚，审批/提问与用户主动打开的面板仍必须高于完成提示。

官方 Releases 页面现还列出 `v2.8-rc.2`，发布说明提到活动显示跟随偏好、音乐/封面和设置页行为等修复；这只是上游发布说明，不代表已分析该版本源码或二进制。当前工作仍以已检查的 `v2.7.3` 静态包和 `v2.8-rc.1` 源码为依据，不推断 `rc.2` 的内部实现。[Boring Notch 官方 Releases](https://github.com/TheBoredTeam/boring.notch/releases)

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

### 终端前台时抑制自动展开

Vibe Island 的本地化帮助文案写明：Agent 所在的终端标签页处于前台时，不自动展开面板。Agent Notch 借鉴这一注意力原则，新增默认关闭的“终端前台时保持提醒紧凑”选项：新审批/问题、根任务完成和已启用的子 Agent 完成事件仍按原路径更新状态；满足抑制条件时不自动接管展开面板，用户仍可手动打开。已启用的子 Agent 完成会在小刘海保留绿色勾号，直到“完成后停留”期限结束；审批和仍在运行的 Agent 状态优先于该完成提示。提示只使用现有静态图标，不增加常驻动画，并尊重减少动态效果设置。

本地实现使用既有 `TerminalVisibilityDetector.isTerminalFrontmost()`，判断受支持的终端应用是否位于前台；它没有判断“具体哪个 Agent 标签页”或 tmux pane 是否聚焦。因此这是有意较宽的本地策略，不是对 Vibe Island 精确会话匹配行为的复刻或运行时推断。新增测试覆盖偏好默认值/持久化与 enabled × terminal-frontmost 策略组合；定向 XCTest 为 7 passed，完整 macOS XCTest 为 483 passed / 0 failed / 0 skipped。Xcode 另报告 `ProcessExecutorTests.swift` 与 `SessionStoreLifecycleTests.swift` 的 QoS 优先级反转运行时警告；这些结果是本地自动化测试，不是安装后桌面 UI 验收。竞品仍只做静态分析，未启动。

子 Agent 完成提示随后补上了持久的紧凑态勾号：从 Hook 的真实完成时间开始计算现有停留期限；更晚的新完成会顺延期限，偏好时长变化和视图重新出现会重设可取消计时器。待处理审批和仍在运行的 Agent 指示优先；没有加入新的循环动效。新增截止边界回归后，`SubagentCompletionAttentionTests` 为 18 passed，完整 macOS XCTest 为 484 passed / 0 failed / 0 skipped。完整套件报告一条来自 `ProcessExecutorTests.swift` 的 QoS 优先级反转运行时警告；仍未进行安装后 GUI 验收，竞品仍只做静态分析。

### 并发会话的状态显示优先级

Boring Notch `v2.8-rc.1` 源码将通知和音乐作为有序短暂活动；新通知进入前台，过期后从列表自然退出，底层活动恢复显示。此结论仅来自该预发布 tag 的公开源码，不是 REA 检查过的 `v2.7.3` 安装包行为，也不是运行观察。[源码](https://github.com/TheBoredTeam/boring.notch/blob/v2.8-rc.1/boringNotch/ContentView.swift#L2335-L2353)

Agent Notch 的 `petMotion` 与紧凑/展开状态图标此前使用了不同条件顺序：当会话 A 等待输入、会话 B 仍在处理时，勾号/转圈按 processing 优先，但宠物按 waiting-for-input 优先，画面可能同时表达“已就绪”和“仍在运行”。现在用同一个优先级裁决结果驱动宠物、状态图标、紧凑宽度与活动可见性：权限 → 运行中 → 完成 → 空闲。子 Agent 的完成勾号仍保持静态，不会启动新的宠物循环动画。新增矩阵测试锁定权限、运行和完成同时出现时的裁决；`NotchPresentationTimingTests` 为 17 passed，完整 macOS XCTest 为 485 passed / 0 failed / 0 skipped。完整套件记录了 `ProcessExecutorTests.swift` 的 QoS priority-inversion runtime warnings；针对性测试记录了 `com.apple.linkd.autoShortcut` 服务连接警告，测试均通过。这些是本地逻辑/托管测试结果，不代表实际桌面 GUI 验收。

## 完成提醒过期与待处理交互竞争

继续审计提醒优先级时发现：完成通知面板的收起计时若在审批/自动展开问题仍待处理时到期，会正确让高优先级交互继续显示，但旧逻辑同时清除了完成通知的截止时间。若该交互随后从别处解决，通知所有权的面板就没有剩余计时器可收起。

现在计时到期会区分“收起 / 被待处理交互暂缓 / 面板已由用户或其他状态接管”三种裁决；暂缓时保留原完成时间，到 pending interaction 更新且阻塞消失后按原截止时间重试。若用户接管了面板，则丢弃自动收起意图。该实现参考 Boring Notch `v2.8-rc.1` 源码对短暂活动按优先级选择、过期后自然退出的设计原则，但不是对其活动栈的逐行复刻。`NotchCompletionExpansionTests` 覆盖暂缓、恢复与用户所有权边界；这是策略单测，不是已安装应用的 UI 验收。

## 子 Agent 完成时序

重新读取已导入的 REA 静态证据（共 26 条记录）后，`ev_28b3fbaad320405079e7b244b28417a3c315ebb5ac80873a3e72c30c840c10ea` 中还观察到 Vibe Island 设置资源提供“每个子 Agent 完成 / 全部完成 / 主 Agent 回复”三种通知时机，且 Team 自动展开默认关闭、无完成提示音。这些是包内资源文字，不证明竞品运行时状态机的具体实现。

协议核验后发现，Claude Code 官方 Hook 文档明确给 `SubagentStart` 与 `SubagentStop` 提供稳定 `agent_id`；`SubagentStop` 的 `agent_id` 与类型可用于匹配对应子 Agent。参见[官方 Hooks reference](https://code.claude.com/docs/en/hooks) 中的 `SubagentStart input`、`SubagentStop input` 和 common input fields。Agent Notch 现在将该 ID 从 Bridge 传入 HookEvent，并在私有 Bridge 快照中以锁保护的原子读改写保留每个 ID 最近的活动状态与事件时间，应用在中途启动或重启时可恢复当前并行集合。Swift 状态机按 ID 配对开始/结束，忽略同一 ID 的重复 Stop 和更旧的 Start；只有已观察到至少一个匹配的活动 ID、且最后一个活动 ID 被结束时，才生成“全部完成”代次。无法确认身份时不会伪造全完成。

设置现提供默认关闭的“关闭 / 每个子 Agent / 全部完成后 / 主 Agent 回复时”。旧版显式开启的布尔偏好迁移为“每个子 Agent”；“主 Agent 回复时”只在本轮已观测到 SubagentStart 后，等根 `Stop` 才生成独立提醒，不会把没有子 Agent 的普通完成误判为队友提醒。根 Agent `Stop` 独立决定会话是否完成。若根 `Stop` 已先到，但本轮某个精确匹配且仍活动的子 Agent 随后完成，按“每个子 Agent / 全部完成后”策略仍可生成队友提醒；这不会重新打开根回合，也不会改变会话完成状态。没有匹配到本轮活动 ID 的迟到/重复事件不生成提醒。提示使用 Hook 源时间戳计算现有停留时间，不播放声音，静音规则、审批/问题优先级、用户拥有的展开面板和全屏准入仍然有效。

已识别的 Hook 版本在 Claude Code `2.0.43+` 注册 `SubagentStart`；版本未知或旧版本不假定“全部完成”可用，而是保持安全降级。Bridge 全套 Python 测试为 91 项通过；本轮运行相关 6 个 Swift XCTest 套件为 67 passed、0 failed、0 skipped，覆盖 ID 解码、并行集合归零、重复 Stop、乱序 Start、根回复时机、离线快照恢复、旧设置迁移和同时间戳的并行完成。测试记录另有一条 `SessionStoreLifecycleTests` QoS 优先级反转运行时警告；托管 XCTest 结果是状态/协议回归证据，不是已安装应用或真实 Hook 回合验收。

进一步验证发现，不同 `agent_id` 的合法 `SubagentStop` 可以具有相同源时间戳；此前在 `SessionState` 仅按时间去重会漏计其中一个。现在精确 ID 的重复抑制由 `SubagentHookState` 负责，已匹配的不同 Agent 即使时间相同也分别增加完成代次；无 ID 的旧协议仍保留时间戳幂等保护。新增 XCTest 覆盖同时间戳并行完成。该修复不宣称已经验证真实 Claude Hook 并发流量。

本轮继续审计提醒重叠时发现，队友完成代次原先会先记入“已处理”，随后才检查审批优先级；如果审批正打开面板，队友完成不抢占面板，但也不会在审批解决后再提示。现在策略明确区分“呈现 / 暂缓 / 丢弃”：仍在原完成停留时间内且被自动展开交互或短暂 `.popping` 阻挡的代次保持未消费，在 pending 状态变化或 pop 转场结束后重试；已过期、静音、设置关闭或面板已由用户接管的事件按原策略丢弃。该改动参考 Boring Notch [`v2.8-rc.1` 源码](https://github.com/TheBoredTeam/boring.notch/blob/v2.8-rc.1/boringNotch/ContentView.swift)的有序短暂活动思路，但不是把其音乐/通知活动栈直接移植到 Agent Notch。新增测试覆盖审批阻塞后恢复、pop 转场、用户接管、静音、关闭设置与超时边界；仍属于策略/本地状态逻辑测试，不是实际 UI 或真实 Hook 回合验收。

### 根回合结束后的迟到子 Agent 启动

Vibe Island `1.0.55` 官方更新记录声称，根 Agent 完成后仍在运行的后台子 Agent 不应让根会话卡片重新显示 Working。这是上游公开行为主张，不是本地竞品运行观察或 REA 对私有二进制的结论。

对照当前 SessionStore 的真实 Hook 序列后发现，旧规则只阻止 `SubagentStop` 复活已完成根会话，却允许时间较新的 `SubagentStart` 进入 reducer。首次回归测试确认该路径会把根状态从已完成改为 processing；增加 reducer 边界后，测试又揭示 `SessionStore` 仍会在生命周期裁决拒绝该事件时更新 `SubagentHookState`，制造一个根卡片已完成但子 Agent 集合仍显示活动的矛盾状态。

现在 `.subagentStartCannotResume` 在根 `completedAt` 或 `.ended` 边界拒绝子 Agent Start，并被列入拒绝消费的观察类型；`SessionStore` 只在生命周期接受该 Start 时才登记活动子 Agent。旧的精确 ID `SubagentStop` 清理路径仍可消费迟到 Stop，不影响下一次真实 `UserPromptSubmit` 创建新一代根回合。`SessionStoreWatcherRecoveryTests.testLateSubagentStartCannotReviveCompletedParent` 覆盖根相位、完成时间、活动 ID、watcher 和诊断裁决；这仍是本地状态机测试，不证明真实 Claude CLI 的后台任务顺序或安装后 UI。

## Codex rollout 活动新鲜度

[Vibe Island 官方更新记录](https://vibeisland.app/changelog/)在 `1.0.54` 条目中声称修复了 Claude/Codex 长任务因 transcript 时间戳陈旧而过早变为 Ready 的问题。它是厂商发布说明，不是我们对竞品运行时行为的独立复现；本轮遵守“仅静态分析”，没有启动 Vibe Island 或 Boring Notch。

对照 Agent Notch 源码和回归用例，发现 Codex rollout 即使刚写入有效的活动事件，解析器仍只把 JSONL 事件时间交给生命周期裁决；时间戳过旧时，活跃会话会被 stale timeout 提前收尾。现在解析器只在本轮确实消费到活动生命周期记录时，才用该文件快照的真实修改时间刷新 `lastEvidenceAt`；无关 JSONL 写入和每秒轮询不会续命。任务开始时间与工具调用开始时间仍由事件时间决定，避免把旧回合伪装成新回合。Reducer 对仍运行的工具使用“工具开始时间与最新活动证据中的较新者”作为有界超时基准：没有新证据仍会在原有 60 分钟上限后结束，有新证据则不会仅因工具启动很早而误判空闲。

新增用例覆盖陈旧事件时间配合新文件写入、无关行不得刷新活动，以及长时间工具调用遇到较新证据时保持 processing；Codex 原生解析和生命周期裁决两个测试套件共 `43 passed / 0 failed`，随后完整 macOS XCTest 共 `390 passed / 0 failed / 0 skipped`。这是本地 XCTest 证据，不等于 Codex GUI、真实长任务或桌面刘海状态切换验收。

## Codex 取消与成功完成分流

Vibe Island `1.0.54` 官方更新记录还声称：Codex 按 Esc 取消会清除审批卡片但不播放完成音，中断回合不再继续显示 Working；这是上游发布说明，不是本机竞品运行观察。[官方更新记录](https://vibeisland.app/changelog/)

Agent Notch 原先把 `turn_aborted`、`task_aborted`、`task_cancelled`、`task_canceled`、`turn_cancelled`、`turn_canceled`、`thread_rolled_back` 与 `task_complete` 一并解析成成功完成，导致取消被标为已完成、进入完成保留/通知路径，也可能被迟到的旧活动证据重新显示为工作中。现在解析器为这些取消事件保留独立的 `.interrupted` 生命周期；Reducer 按源时间拒绝较旧中断、阻止同一代的迟到活动或完成记录复活，只允许时间更新的 `task_started` 开启下一代。接受中断时清理挂起审批和未完成工具、取消外部权限请求，并按现有五小时终端会话保留策略保存可归档的“已中断”卡片；该状态没有 `completedAt`，因此不进入成功完成提醒/声音路径。持久化恢复和生命周期诊断也区分 interrupted 与 completed。

随后继续核对失败时序，发现 `task_failed`、`turn_failed` 仍沿用成功完成状态，而且冷启动边界扫描可能从失败前后的迟到成功行恢复为“已完成”。现为两种失败事件增加独立 `.failed` 生命周期和 UI 状态：解析器将失败与成功/中断分开；尾部失败边界会压过同一代迟到的成功记录，只有较新的 `task_started` 才开启下一代；Reducer 按事件时间拒绝越界失败、同代迟到活动及成功，允许更新回合恢复。SessionStore 在失败时关闭未完成工具与待审批交互、清理外部权限/监听资源，并以终端卡片保存/恢复；失败不生成 `completedAt`，因此不会走成功提醒/声音路径，Codex/CodeBuddy 仍可从失败会话重试。

新增解析器、Reducer、状态行、诊断和冷启动恢复用例，覆盖 `task_failed` / `turn_failed`、失败后迟到完成、下一轮恢复、旧失败边界、无成功时间与持久化恢复。本轮完整 macOS XCTest 为 `412 passed / 0 failed / 0 skipped`；Xcode 另报告一条 `ProcessExecutorTests.swift` 的 QoS priority-inversion 运行时警告。仍是本地自动化证据，不证明真实 Codex GUI、真实失败回合或安装后提示/声音验收。竞品分析仍遵守仅静态证据范围，没有启动 Vibe Island 或 Boring Notch。

## 转录时间戳精度与生命周期边界

继续检查 Claude 状态时序时发现，公共 ISO 8601 解析器只启用了小数秒选项，但同仓库的 Claude JSONL fixture 会生成合法的整秒格式。解析失败后旧代码用读取时的 `Date()` 替代源时间，导致旧转录可能被误当成当前事件。现在解析器同时接受有/无小数秒时间；缺失或损坏的时间戳仍可供聊天内容显示，但会标记为不可靠，并从 transcript 生命周期裁决中排除。新增目标用例 `3 passed / 0 failed`。完整 macOS XCTest 执行了 393 项：389 项通过，4 个用例失败（合计 5 条断言失败）；失败涉及 3 个 `ProcessExecutorTests` 的时限断言和 1 个 `SessionStoreWatcherRecoveryTests` 恢复等待超时。后者单独重跑 `1 passed / 0 failed`；单独重跑 ProcessExecutor 用例时 Xcode 在测试启动前停滞，随后中止，因此它们是否仅为并发负载波动仍未确认。完整结果属于本机 XCTest，不代表真实 Agent/GUI 验收。

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
- **转场手感继续对齐**：Boring Notch `v2.7.3` 的 `ContentView.swift` 对展开/收起及悬停使用同一 `interactiveSpring(response: 0.38, dampingFraction: 0.8)`。Agent Notch 原先展开与收起分别使用普通 spring（0.42/0.8 与 0.45/1.0），反向状态变化时的速度衔接不一致。现把展开与悬停改为可中断的 0.38/0.8 interactive spring，收起使用更快且较少回弹的 0.30/0.9；reduce motion 仍分别保留 0.12s / 0.10s 的 ease-out。相关 policy 测试只验证配置合同，未做已安装应用的桌面帧率或主观观感验收；这是独立重实现交互原则，不复制 GPL 源码。
- **已修复**：完成事件不再误收起仍有自动展开资格的审批/提问面板；依据是 Agent Notch 源码复现与回归测试，不声称这是 Vibe Island 私有实现的逆向结论。
- **新增可选策略**：Vibe Island 安装包静态资源展示根任务与 Team 队友完成自动展开，以及三种子 Agent 通知时机；Agent Notch 已实现默认关闭的根任务完成和队友完成展开，并复用既有停留时长自动收起，保留审批、用户所有权和全屏策略优先级。基于 Claude Hook 的精确 `agent_id`，队友提醒已支持“每个子 Agent / 全部完成后 / 主 Agent 回复时”三种时机；有效的本轮活动子 Agent 即使在根 Agent 已结束响应后才完成，也只生成队友提醒，不复活根会话状态。
- **候选但暂缓**：Vibe Island 的平台化 RemoteAgent manifest 与版本/散列清单可作为未来分发设计参考；当前不引入 SSH/远程执行能力，避免在核心状态与审批可靠性尚需真实运行验收时扩张权限面。
- **暂不采用**：Vibe Island 的价格数据资源；Agent Notch 已有订阅用量与会话 token 数据，但没有经过验证的跨模型成本口径，本轮也不扩展该功能。
- **未验证**：Vibe Island 的真实展开/收起、Agent 状态与审批交互。2026-10-23 查询当前 REA unknown registry 返回 0 项；这不代表竞品运行行为已验证。本轮明确选择仅静态分析，因此仍没有 UI/运行轨迹，也不启动竞品。
- **未验证**：Boring Notch 发行二进制与源码 tag 的构建对应关系，以及两款竞品在真实桌面中的完整行为矩阵。

因此本记录不是“竞品功能已经完整复刻”或“真实 Mac 交互验收通过”的声明，而是后续实现可引用的静态证据、已采纳决策和剩余验证边界。

## 活动会话卡片显示当前步骤

Vibe Island 官方 `1.0.54` 更新记录声称，Claude 活动会话卡片现在显示当前步骤，而不是直接展示原始命令；这是厂商发布说明，不是本项目独立运行观察，也不证明其私有实现细节。[官方更新记录](https://vibeisland.app/changelog/)

对照 Agent Notch，会话状态标签已由生命周期状态机决定，但副标题此前无论会话是否正在处理，都会优先展示解析快照中的最后一条转录消息。新一轮开始后，旧 assistant/tool 内容可能暂时仍是快照末条，视觉上容易被误读成当前进度。现在 processing 行优先用当前仍在运行、且晚于最近终止边界的 Hook 工具名；不暴露原始命令行。若没有可确认的活动工具，则显示“正在生成回复”，不把陈旧 transcript 冒充为实时活动。子 Agent 容器显示为“子 Agent 正在工作”。压缩中也使用明确活动描述。

`SessionRowPresentationTests` 覆盖陈旧转录、最新活动工具、待审批工具排除、终止边界前的旧工具过滤、子 Agent 文案，以及中英文输出。该调整只改善列表行的当前活动表达；它不改变生命周期状态机，也不等同于真实 GUI/Hook 时序验收。

## 2026-10-23 上游公开更新（静态资料，不等于 REA 包证据）

本轮遵照“仅静态分析”，没有启动竞品。REA 已核验的 Vibe Island 安装包仍是 `1.0.54`；下列 `1.0.55` 内容来自官方更新日志，而非本机新版二进制、真实 UI 或运行轨迹。官方页面日期为 2026-10-23。

### Vibe Island 1.0.55

[官方更新日志](https://vibeisland.app/changelog/)列出几项与 Agent Notch 方向直接相关的变化：

- 新增 Codex 提问在刘海中展示并回答、后台命令与本地端口管理；更新说明称这类后台任务展示默认关闭。
- 审批/提问卡在命令失败、拒绝并附反馈、多个审批并行等路径下清理更可靠；Claude 子 Agent 可在应用重启后恢复；根会话完成后，后台子 Agent 继续运行不应让根卡片重新变成工作中。
- Codex 会话找不到原终端标签时，点击仍会退回到前置终端，而不是无反馈地失败。
- 用量提醒覆盖 5 小时和周窗口的阈值、耗尽与重置；更新说明称默认阈值为 80%，并支持声音及可选 Bark 手机提醒。
- 审批卡优先展示请求动作与原因，处理中的卡片展示当前步骤；更新说明还提到用量/会话跟踪及后台端口扫描的 CPU 优化。
- 更新说明还包含性能与稳定性修复；这些是厂商自述，不是独立测量。

对照当前 Agent Notch 源码：带精确身份的并行审批 FIFO、子 Agent Hook 状态恢复、根/子 Agent 生命周期隔离、Codex 中断/失败状态与迟到事件屏障，已有实现和对应 XCTest。可见这些可靠性方向并非缺失功能，不应仅因为竞品更新说明出现类似修复就重复造一套。

用量方向则存在清晰差距：当前读取器从本机 Codex session JSONL 解析 rate-limit 快照，只展示百分比与重置时间；此前没有阈值通知，设置页的“Claude 和 Codex”描述也与实际 Codex-only 读取范围不符。现已新增默认关闭的 Codex 本机阈值通知，可选 50%–100%，分别跟踪主/周用量窗口，只在两个观测快照间确认跨过阈值时提醒；初始快照已超阈值、通知关闭期间或重置时间已改变时均不补发，并按每个窗口的重置时间去重。启用前会请求 macOS 通知权限；通知不含会话内容，不访问网络。六项定向 XCTest 覆盖跨越、首次快照、关闭状态、窗口边界、去重和偏好持久化。该实现借鉴的是官方更新说明公开的产品能力，不证明 Vibe Island 本机运行行为，也未复刻其 Bark 集成或私有实现。

本轮再补一条组合回归：审批队列首项被用户拒绝并附带反馈后，再收到该工具的迟到 `PostToolUseFailure`，首项保持失败，而后续审批仍留在队首且可见。定向 XCTest 通过；这是状态机测试，不代表真实 Agent Hook 回合或桌面 UI 验收。

此前本仓库尚未发现 Codex 原生 `request_user_input` 交互的接收/应答集成。经本轮官方协议静态核验后，已新增一个默认关闭的实验性提问适配器，具体边界与未验证项见下文；Codex 后台命令和端口控制面板仍未实现，也不从竞品更新说明推演其私有实现。

### Boring Notch 当前公开发布列表

后续复查的[官方 Releases 页面](https://github.com/TheBoredTeam/boring.notch/releases)列出 `Latest Nightly` 与 `v2.8-rc.2`；其发布说明提及活动显示器跟随、通知 UI、镜像尺寸及音频输出悬停方面的变化。这些属于上游发布材料，不证明对应二进制在本机的实际表现；本项目的 REA 包证据仍以 Boring Notch `2.7.3` 为准，源码设计参考则分别标注具体 tag/commit。

**记录纠偏：**早先一次页面读取只记录到 `rc.1`，现已由后续对官方 Releases/tag 页的复查更正；不能据此推断 `v2.8-rc.2` 二进制已被本机静态分析或运行。

### Codex 原生问题的协议边界核验

Vibe Island `1.0.55` 的官方更新说明声称可以在刘海中回答 Codex 问题；这仍只是厂商功能说明，不证明其内部接入方式或本机运行行为。进一步核对 [OpenAI Codex app-server protocol](https://github.com/openai/codex/blob/main/codex-rs/app-server-protocol/src/protocol/common.rs) 后，`item/tool/requestUserInput` 是由服务端发起、标记为 experimental 的请求；它通过配对响应完成当前请求，而不是往会话里发送一条普通文本。对应的[响应 JSON schema](https://github.com/openai/codex/blob/main/codex-rs/app-server-protocol/schema/json/ToolRequestUserInputResponse.json) 按问题 ID 返回对象，对象内的 `answers` 字段才是字符串数组。

补充核对官方 app-server 实现后，发现可行路径比“协议没有控制通道”更具体：`thread/resume` 对同一 app-server 内仍运行的 `threadId` 会重新加入该线程；resume 完成后，服务端会把该线程尚未解决的 server request 重放给新连接。官方协议测试也验证了应答必须回传原 JSON-RPC `request_id`，answers 再按 question ID 映射，并在 turn 完成前收到 `serverRequest/resolved`。本地 Codex CLI 源码还提供 `app-server proxy`，将 stdio 转接到既有控制 socket；默认 socket 位于当前 `CODEX_HOME/app-server-control/app-server-control.sock`。参考：[thread resume 定义](https://github.com/openai/codex/blob/main/codex-rs/app-server-protocol/src/protocol/v2/thread.rs)、[resume 请求重放实现](https://github.com/openai/codex/blob/main/codex-rs/app-server/src/request_processors/thread_lifecycle.rs)、[原生提问协议测试](https://github.com/openai/codex/blob/main/codex-rs/app-server/tests/suite/v2/request_user_input.rs)、[CLI proxy 与控制 socket](https://github.com/openai/codex/blob/main/codex-rs/cli/src/main.rs)。

因此，真正的产品边界不是“绝对做不了”，而是 Agent Notch 只能通过正在承载该 Codex 会话的同一个 app-server 接入。另起 `codex exec resume` 或启动第二个 app-server 都不能等价替代；错误的线程所有权/进程可能造成重复控制或会话竞争。该提问 schema 和 daemon 生命周期仍属实验性接口，必须只尝试连接用户已经运行的本地服务，使用精确 thread/request/question ID 配对，不自动启动或重启服务，也不以普通聊天文本伪答。后台命令与端口操作仍暂缓，因其权限面和验收成本更大。

竞品与协议分析仍严格限于官方静态资料；没有启动 Vibe Island、Boring Notch 或连接 Codex app-server。下节实现只证明本地代码与公开 schema 对齐，目标 Codex Desktop 的实际控制 socket、线程所有权和真实回合行为仍未验证。

### Codex 原生提问接入（默认关闭，实验性）

本轮将上述候选收敛为一个默认关闭的实现：只有用户在设置中显式启用、且检测到活动 Codex 会话时，才运行 `codex app-server proxy` 并执行 initialize / `thread/resume`；不会启动或重启 Codex app-server，不调用 `codex exec resume` 发送伪造回答。resume 请求设置 `excludeTurns: true`，只请求线程元信息和活动状态，避免把完整历史装入第二个客户端。收到 `item/tool/requestUserInput` 后，刘海卡片按精确 server request ID、thread ID 和 question ID 提交答案；只接受已知选项或允许的自定义答案，支持保密输入，并仅在匹配的 `serverRequest/resolved` 到达后移除对应卡片。其他 server request 不做批准或拒绝，原 Codex 窗口仍是它们的决策入口。

本地核验的 Codex CLI 为 `0.164.0`；只读取了 `codex app-server proxy --help`，确认该命令描述为转发到正在运行的控制 socket，未连接该 socket。新增协议/偏好/呈现策略测试覆盖 JSON-RPC ID 回传、嵌套答案 schema、请求去重、乱序身份隔离和默认关闭。该协议仍为 experimental；本轮没有连接真实 app-server、没有在真实 Codex 回合中验证请求重放/所有权，也没有完成独立 UI 运行验收。若 proxy、thread/resume 或请求配对失败，设置状态会显示不可用，用户需回 Codex 原窗口处理。

本轮同时新增 `SessionStoreLifecycleTests.testSuspendedHistorySnapshotCannotOverrideNewerStopHook`，用注入的历史快照和可控异步闸门验证：旧用户消息快照在解析挂起期间遇到较新的 Stop Hook，之后恢复也不得把已完成会话重新判为 processing；XCTest 观察到 `.activeOlderThanHook`，完成时间保持 Hook 边界。本机生命周期套件及完整 macOS XCTest 均通过。此项是 Agent Notch 自身的状态时序回归测试，不是竞品运行观察或真实桌面验收。

### 自定义 Agent 生命周期观察接入

Vibe Island 官方[自定义 Agent 文档](https://vibeisland.app/docs/custom-agents/)及[集成指南](https://vibeisland.app/docs/custom-agents-agent-guide/)采用每个事件调用一次命令的轻量扩展方式，并列出 SessionStart、UserPromptSubmit、PreToolUse、PostToolUse、Stop、StopFailure、SessionEnd 等生命周期点。此处依据的是公开文档，不是 REA 私有二进制证据或运行时观察。

Agent Notch 原本 Bridge 接受任意 `--source`，但来源身份在 Swift 中会折叠为“Agent”，消息发送默认又会回落到 tmux；Bridge 也可能为未知 Agent 写入包含提示词/工具内容的合成 transcript。现已将来源改为安全 slug 并保留其显示名称；自定义来源只能报告受限的生命周期/工具事件，不写合成 transcript、不传原始工具输入、不提供消息发送或权限决策通道。既有明确支持的内置 Agent 仍使用原路由。接入示例和限制见 [AgentBridge 自定义 Agent 只读生命周期说明](../AgentBridge/docs/custom-agent-observer.md)。

该实现只采用“可插拔生命周期事件”这一优势，没有照搬 Vibe Island 的 RemoteAgent manifest、字段映射或其尚未核验的运行时行为；完整兼容仍需针对每个 Agent 的官方 Hook 语义做独立适配与真实环境验收。

### 活动显示器跟随（Boring Notch `v2.8-rc.2` 官方源码补充）

官方 [`v2.8-rc.2` 发布说明](https://github.com/TheBoredTeam/boring.notch/releases/tag/v2.8-rc.2)列出活动显示器跟随设置；合并的 [PR #1659](https://github.com/TheBoredTeam/boring.notch/pull/1659) 和实现提交 [`094d8a8`](https://github.com/TheBoredTeam/boring.notch/commit/094d8a8) 显示它通过监听 `NSWorkspaceActiveDisplayDidChangeNotification`，在单窗口模式下重新定位刘海；后续提交 [`4222408`](https://github.com/TheBoredTeam/boring.notch/commit/4222408) 将显示偏好收敛为持久化枚举，并保留旧偏好迁移。以上是官方源码/发行说明观察，不是已检查的 `2.7.3` DMG 内容或 `v2.8-rc.2` 二进制运行证明。

Agent Notch 采纳的是“默认不改变既有行为、显式选择后才跟随活动显示器”的兼容原则：新增 `activeDisplay` 选择模式，复用屏幕切换时重建窗口的路径，切换时由新窗口以收起态呈现；活动屏幕不可解析时回退到内置屏幕。系统屏幕参数变更仍保留原有防抖，而用户手动选择屏幕使用独立的应用通知，不再伪装成硬件变化。自动模式仍优先内置屏幕，指定屏幕仍通过已保存标识恢复。新策略测试覆盖活动屏幕优先级、回退、旧偏好值和同名显示器身份；本轮完整 macOS XCTest 为 `419 passed / 0 failed`。这些是本地构建/测试证据，不是多显示器桌面端到端验收。

### Hook Socket 就绪与 Bridge 快照恢复顺序（2026-10-25）

这是 Agent Notch 自身的启动时序问题，不是从 Vibe Island 或 Boring Notch 私有实现推断而来。源码显示 Bridge 会在发送 socket 事件前原子持久化活动会话快照；`ClaudeSessionMonitor` 原先异步排队启动 Hook Socket 后立即启动 `SessionStore`，而 SessionStore 仅在首次启动恢复时扫描一次 Bridge 快照。若启动期 Hook 恰好先写快照、socket 发送失败，且扫描发生在快照落盘之前，该活动会话就可能一直缺失到应用再次启动。

现在 Socket 启动提供完成回调，明确在监听器就绪（或启动失败）后报告结果；Monitor 收到该完成后再启动持久化恢复与状态轮询。这样，监听器建立前已写入的快照会在一次性扫描前落盘；失败路径也会触发恢复，并且如果 Monitor 已停止则不会迟到地重新启动 SessionStore。新增 PermissionRoutingTests 覆盖“回调时监听 socket 已可连接”和“socket 路径准备失败仍回调失败结果”；就绪回调测试先在旧实现上按超时失败，接入后通过。完整 macOS XCTest 为 `441 passed / 0 failed / 0 skipped`，并记录一条既有 `ProcessExecutorTests.swift` QoS 优先级反转运行时警告。

这是本地源码与 XCTest 的时序证据，不代表真实 Agent Hook 压测、安装后 GUI 验收，也没有运行 Vibe Island 或 Boring Notch；本轮继续遵守用户选择的仅静态竞品分析范围。

### 本轮结论与下一候选

Codex 原生提问已实现默认关闭的实验性接入，公开协议与配对响应边界已做静态核对；Codex Desktop 实际控制 socket、线程归属和真实提问回合仍未完成运行验收。下一候选是只读确认本机 Desktop 与 CLI 的连接/线程所有权模型，再决定是否做目标环境验证；不把新开 CLI 的普通文本消息当成原生问题答案。所有基于 Vibe Island、Boring Notch 的判断继续限于已留存的静态包证据、公开更新记录和 Boring Notch 源码，不能外推为运行时结论。

### 自定义 Agent 的外观配置（2026-10-24）

[Vibe Island 官方 1.0.55 更新记录](https://vibeisland.app/changelog/)称自定义 Agent 可以显示自己的图标；但当前公开的[集成指南](https://vibeisland.app/docs/custom-agents-agent-guide/)仍把自定义图标列为暂不支持。两份官方资料存在版本/文档不一致，因此这里只把“区分自定义 Agent 的名称和图标”视为产品方向，不据此推断 Vibe Island 的私有 manifest 或渲染实现，也不声称 1.0.55 安装包已被本机静态检查。

Agent Notch 采用更窄的本地实现：设置页允许为 Bridge 自定义来源 slug 配置显示名称及白名单 SF Symbol；覆盖仅用于刘海 Agent 徽标和会话列表，不改变来源身份、Hook 事件、消息传递或权限决策，删除资料即可恢复默认外观。内置 Agent 不可被此配置覆盖。名称长度、控制字符、图标白名单和资料数量均受限制；自动化测试只验证模型、UserDefaults 持久化与视图编译/渲染，不替代真实 Hook 回合或已安装应用的 UI 验收。

### 子 Agent 完成与根回合代际隔离（2026-10-24）

Vibe Island 官方 `1.0.55` 更新记录称，根会话回复后仍在运行的后台子 Agent 不应令已完成卡片重新变成 Working；`1.0.51` 还列出避免长任务被旧 transcript 或上一回合时间戳误判为 Ready 的修复。这些是上游发布说明，不是本机竞品运行观察。参考：[Vibe Island 官方更新记录](https://vibeisland.app/changelog/)。

Agent Notch 的精确 ID 配对虽然能区分并行 Agent，却仍有一个跨代际边界：旧根回合的 Agent 若在下一轮开始后才结束，它的 Stop 时间落在新根回合内，旧逻辑会把它计作新一轮完成提醒。新增回归测试先复现了该误报（旧 Agent Stop 增加完成代次），随后改为只让当前根回合内启动的活动 Agent 参与单体/全部完成提醒判断；旧 Agent 仍可被清理，但不会冒充新回合活动。当前根代际由已保存的 Hook 时间戳确定，无需改变快照 schema，也保留没有根时间戳时的中途启动兼容行为。

`SubagentCompletionAttentionTests` 定向套件为 17 passed、0 failed；新用例覆盖旧 Agent 晚结束时新一轮仍有 Agent 活动，以及旧 Agent 是新一轮唯一尚未结束的 Agent 两种时序。完整 macOS XCTest 为 433 passed、0 failed、0 skipped；另有 `ProcessExecutorTests.swift` 的 QoS 优先级反转运行时警告。结果是本地状态逻辑回归证据，不证明真实 Claude Hook 调度或安装后 UI 表现。

### Codex 旧工具记录不能越过真实完成边界（2026-10-24）

Vibe Island `1.0.51` 官方更新日志提到修复旧 transcript/上一轮时间戳把长任务误判为 Ready；这仅是上游行为说明，不证明它的内部实现。[官方更新日志](https://vibeisland.app/changelog/)

Agent Notch 自身状态裁决中发现相邻风险：Codex 的未匹配工具调用原本能恢复超时误判的长任务，但若它在真实完成后因不完整/延迟快照再次出现，也会被当作新工作状态，直接越过 `completedAt`。现将“超时合成的完成边界”单独标记并写入会话快照：真实完成不能被完成前启动的旧工具调用复活；超时边界仍可由持久未匹配工具调用恢复；若后续读到该回合的真实完成记录，则把边界升级为已确认完成。旧版快照缺少该字段时，以 `completedAt > lastActivity` 兼容识别超时边界。

新增 `LifecycleReducerTests` 与 `SessionStoreColdStartTests` 覆盖真实完成拒绝旧工具恢复、超时后恢复长工具、迟到真实完成确认超时边界，以及旧版快照兼容逻辑。完整 macOS XCTest 为 436 passed、0 failed、0 skipped；Xcode 仍报告 `ProcessExecutorTests.swift` 的 QoS priority-inversion runtime warning。该结论来自 Agent Notch 源码/自动化测试，不是 Codex 或竞品真实运行回合验收。

### 被移除会话的迟到 Hook 隔离（2026-10-24）

Vibe Island `1.0.55` 更新说明称根回合完成后，仍运行的后台子 Agent 不应让根卡片重新进入 Working；这是官方发布说明，不是本机运行观察或其内部实现证据。[官方更新记录](https://vibeisland.app/changelog/)。这提醒我们继续检查“终止后旧事件迟到”的其他边界。

Agent Notch 接受 `SessionEnd` / `SessionExpired` 后会删除会话及其生命周期游标。此前若旧队列中的 `PreToolUse` 或 `UserPromptSubmit` 在之后才到达，就可能因游标已删除而重新创建 Working 会话。当前保留最多 512 个最近的移除时间边界，并将其写入权限受限的 `removed-session-boundaries.json` 侧车文件；读取和写入均有大小上限。普通活动会话快照先落盘，之后才写入已清除的边界，因此进程若在两次原子写入之间退出，旧边界仍会挡住陈旧活动行。跨重启恢复时，时间戳不晚于移除边界的持久会话行和 Bridge 快照会被忽略；严格更新的活动 Bridge 快照（包括中途启动可见的 `PreToolUse`）可以恢复会话并清除旧边界。新的 Hook 根代际仍要求事件时间严格晚于移除边界；缺失或错误的 Agent 时间戳仍需要各来源适配器和真实 Hook 验收。

新增 `SessionStoreLifecycleTests.testRemovedSessionRejectsLateActivityButAllowsLaterRootStart` 覆盖 SessionEnd 后旧工具事件和旧提示事件被拒绝，以及更晚的新提示能恢复同一会话。跨重启用例 `SessionStoreWatcherRecoveryTests.testRemovedSessionBoundarySurvivesRestartWithoutBlockingNewMidToolRestore` 进一步覆盖：旧活动行与旧 Bridge 快照被墓碑挡住，而较新的 `PreToolUse` 快照能恢复中途启动的工作会话。该跨重启用例定向运行 1 passed；本轮完整 macOS XCTest 为 438 passed、0 failed、0 skipped。Xcode 记录 `ProcessExecutorTests` 与 `TmuxTargetFinderTests` 的 QoS 优先级反转运行时警告。这些是本地状态逻辑自动化证据，不等于真实 Agent 事件队列、真实 Hook 调度或已安装 UI 验收。

### 信息通知不应伪造空闲会话（2026-10-25）

本条是 Agent Notch 自身状态入口的源码发现，不是对 Vibe Island 或 Boring Notch 内部实现的推断。`Notification(auth_success)` 等普通信息事件没有目标会话状态迁移，但此前 `SessionStore.processHookEvent` 会先构造占位会话，再因为没有生命周期信号而将其保存，导致没有真实 Agent 回合的空闲卡片进入会话状态。

现在新会话只会由有效生命周期信号建立；已存在的会话仍能收到普通信息事件，`Notification(idle_prompt)` 仍被视为完成信号。新增 `SessionStoreLifecycleTests.testInformationalNotificationCannotCreateSession` 先在旧实现上复现失败，修复后通知相关定向测试 3 passed；完整 macOS XCTest 为 439 passed、0 failed、0 skipped。Xcode 记录 `ProcessExecutorTests` 的 QoS 优先级反转运行时警告。以上是本地源代码与自动化状态测试证据，不是实际 Agent Hook 调度或桌面 UI 验收。

### Now Playing 媒体能力：本轮不移植（2026-10-25）

REA 已留存的 Boring Notch `v2.7.3` arm64 Mach-O 依赖表包含 `MediaRemoteAdapter.framework`（Evidence `ev_7a890069c239ac1ebb58f5727a28ebb1fc88577d4cb3d606bb4b0ba77a56390c`）。这只证明发行包链接该框架，不证明它在本机实际运行。Boring Notch 官方 README 将 MediaRemoteAdapter 列为 macOS 15.4+ Now Playing 来源的依赖；该 adapter 自己的 README 说明其方案通过 `/usr/bin/perl` 动态加载 helper framework，并称 macOS 15.4 起在应用内直接加载 MediaRemote 已不可用。后者是上游项目对其技术背景的说明，不是 Apple 对私有 API 的稳定性保证。

上游近期发布记录仍在修复 Now Playing 可用性、回退与连接恢复；Boring Notch 用户 issue 也报告过来源消失、控制器失效或重启后恢复。这些 issue 是用户报告，未在本轮复现，不能视作已确认缺陷；但与依赖自身的系统版本 workaround 一起，说明这不是低维护的即插即用能力。MediaRemoteAdapter 单独采用 BSD-3-Clause，而 Boring Notch 项目为 GPL-3.0；Agent Notch 保持 Apache-2.0 边界，不复制 Boring Notch 源码。

产品决策：Agent Notch 的核心任务是 Agent 生命周期、权限与问题提醒，媒体卡片会增加一个与核心状态无关、且依赖系统版本 workaround 的活动源，本轮不接入。继续优先把 Vibe Island/Boring Notch 可迁移的“事件新旧边界、提醒优先级、短暂活动过期、可取消悬停任务”落实到生命周期状态机与测试。未来若明确需要媒体能力，再评估 BSD adapter 的打包、helper 失败恢复、macOS 版本矩阵和许可证归属；不能只因 Mach-O 链接了该框架就承诺可用。

本轮同时复核 Agent Notch 的中途启动恢复：`SessionStoreWatcherRecoveryTests.testOfflineBridgeWorkingSessionRestartsWatcher`（离线 Bridge 中最新事件为 `PreToolUse/running_tool`）及两个 Hook Socket 启动完成回调用例共 3 项定向 XCTest 通过。这证明测试环境中的快照恢复和监听器就绪顺序，不替代真实 Agent Hook 压测或安装后 UI 验收。

### 观察型 Agent 退出后的卡片清理（2026-10-25）

Vibe Island `1.0.55` 官方更新日志称，自定义 Agent 的卡片会在其应用退出时清理；这是公开产品行为说明，不是私有实现或本机运行观察。[官方更新日志](https://vibeisland.app/changelog/)

Agent Notch 已能通过现有进程检查器发现 Hook 所属 PID 退出，但此前无论来源是否具备消息/会话交互能力，都会统一转成 `ended` 并保留最近终态卡片最长 5 小时。对自定义 observer 和 Gemini 来说，进程退出意味着没有可返回的本地会话控制面，继续显示 Working/Ended 卡片会误导用户。现复用既有 `LifecycleReducer`、进程身份校验和跨重启移除边界：仅自定义来源与 Gemini 在精确 PID 退出后移除卡片；写入移除时间边界以拒绝更早的迟到 Hook，并允许严格更新的同会话活动事件恢复。Claude、Codex、CodeBuddy、Cursor 等交互型来源仍保留原有终态卡片。

定向 XCTest 先在旧策略下复现回归，修复后覆盖 observer/Gemini 的移除裁决、自定义卡片删除、迟到 Hook 拒绝、较新 Hook 重启恢复，以及内置 Codex 仍保留 ended 状态。这是根据 Vibe Island 公布的产品结果做的独立生命周期决策，不声称复刻其内部实现；自动化结果也不代替真实外部 Agent 退出与已安装 UI 验收。

### 观察型 Agent 更新重启期间的卡片连续性（2026-10-25）

Vibe Island `1.0.53` 官方更新说明称，Agent 应用退出后卡片会在短暂延迟后清理，同时在应用为更新而重启时尽量不让卡片消失；`1.0.55` 又明确提到自定义 Agent 卡片随来源应用退出清理。[官方更新日志](https://vibeisland.app/changelog/)。这是厂商公开描述，不是其内部实现或本机运行观察。

Boring Notch `v2.7.3` 的公开源码 `ContentView.handleHover` 会先取消旧延迟任务，触发前再检查取消状态、悬停状态和当前视图状态。[对应源码](https://github.com/TheBoredTeam/boring.notch/blob/v2.7.3/boringNotch/ContentView.swift)。这是对 Boring 源码的静态观察；将同一“延迟工作可撤销、执行前复核身份和状态”的原则用于卡片清理，是 Agent Notch 的独立设计选择，不表示 Boring Notch 用此机制管理 Agent 卡片。

对照 Agent Notch，观察型来源在精确 PID 退出的第一次轮询就会立即删卡，无法容忍更新重启期间短暂的 PID 空窗。现改为先把卡片裁决为 `ended` 并记录移除时间边界，等待 2 秒后再清理；同一会话在边界之后到达的有效生命周期 Hook 会取消待清理任务、清除边界并按新事件恢复状态，边界之前的迟到 Hook 仍被拒绝。若应用确实退出且没有新生命周期证据，卡片在短暂 grace 后消失；时间边界继续阻止旧持久化快照或 Bridge 快照复活会话。

回归覆盖 reducer 对自定义来源/Gemini 的 ended 裁决、进程退出后仍保留 ended 卡片、迟到事件不能取消清理、超时后删除，以及新 `PreToolUse` 在 grace 内到达时撤销删除并保持新 PID 的 processing 状态。该验证是本地状态机/XCTest 证据，未启动 Vibe Island 或 Boring Notch，也未验证真实更新重启过程和桌面 UI。

### Vibe Island 1.0.55 最新公开功能核对（2026-10-25）

Vibe Island 官方更新页目前列出的最新版本为 `1.0.55`（2026-10-23）。更新页称该版本支持在刘海回答 Codex 问题、默认关闭的后台命令/本地端口查看与操作、远程 Copilot CLI，以及把审批卡片调整为先说明操作意图，再展示完整命令；Claude 活动卡也显示当前步骤。[官方更新页](https://vibeisland.app/changelog/)。这些是厂商发布说明，不是本地 `1.0.55` 包的 REA 观察，也不证明内部实现。

Agent Notch 已有默认关闭的 Codex 原生提问实验接入，并已实现处理中的当前步骤展示；目前没有后台命令/端口生命周期与停止操作。该功能暂不移植：列举端口和命令需要新的进程/网络监听数据源，而“一键停止”会扩大现有权限与进程控制面，不属于当前优先的状态可靠性收敛。审批卡方面，`ChatApprovalBar` 目前能显示工具名和有限长度的输入摘要；`PermissionContext` 没有独立的“操作理由”字段，所以不应从命令文本猜造理由。后续若接入来源明确提供的 rationale，应先保留来源字段并测试缺失/不可信内容的呈现，再调整卡片层级。

本轮在当前工作树运行完整 macOS XCTest：466 passed、0 failed、0 skipped。Xcode 另记录 `ProcessExecutorTests.swift` 一条 QoS 优先级反转运行时警告；测试通过不等于真实 Hook 调度、实际进程/端口管理或已安装 UI 验收。

### 监控轮换时隔离迟到的启动与停止（2026-10-25）

Boring Notch `v2.7.3` 的公开源码 `ContentView.handleHover` 会取消旧延迟任务，并在触发前复核取消标记、悬停状态和当前视图状态。[对应源码](https://github.com/TheBoredTeam/boring.notch/blob/v2.7.3/boringNotch/ContentView.swift)。这是静态源码观察；本轮只借鉴“异步回调执行前确认它仍属于当前生命周期”的原则，不声称 Boring Notch 采用相同的 Agent 监控架构。

Agent Notch 的 `ClaudeSessionMonitor` 在停止时会异步排队停止 `SessionStore` 的轮询；如果显示器切换重建窗口后，新监控的 socket 就绪回调先启动轮询、旧停止 Task 后到，旧调用此前会无条件取消当前任务。旧 socket 启动回调也可能在同一个 Monitor 再次启动后仅凭 `isMonitoring == true` 误认自己仍有效。现为每次监控启动分配全局递增代际：迟到启动回调必须匹配当前代际；SessionStore 记录轮询所有者并将已运行任务交给新代际，旧代际停止会被忽略。代际高水位在停止后保留，因此同代际的迟到启动也不能复活已停止轮询；当前代际停止仍可正常取消。

新增 `SessionStoreColdStartTests.testLateStopFromPreviousMonitorDoesNotStopNewPollingLifecycle`、`testLateStartFromStoppedMonitorCannotRestartPolling` 和 `testStopDeliveredBeforeStartCallbackCannotBeReorderedIntoRestart`：覆盖旧停止取消新轮询、迟到启动复活已停止轮询，以及停止先于尚未执行的启动到达 Actor；前两种场景先在旧实现下复现失败，第三种验证代际高水位在无活动所有者时也能退休旧请求。该测试是可控 actor 调度顺序下的源代码回归证据，不是实际显示器热插拔、真实 Hook 调度或桌面 UI 验收；本轮仍未启动 Vibe Island 或 Boring Notch。

### 过期 Hook 时间戳不能被提升为“刚刚到达”（2026-10-25）

REA 留存的 Vibe Island 设置资源说明其完成通知/展开有独立停留时长；Boring Notch `v2.7.3` 源码则在悬停延迟任务触发前复核当前指针和视图状态。这些是包内文案与源码观察，不是竞品运行时结论。它们再次提示：延迟处理应保留事件时间，并在影响当前状态前核对边界。

Agent Notch 自身的 `HookEvent.lifecycleObservedDate` 原先把“比接收时刻早超过 24 小时”的有限时间戳改成接收时刻。旧的 `PreToolUse` 因而可能越过已完成边界，让卡片重回 processing；同一归一化还被权限 Socket 用来判断请求是否早于完成，可能把陈旧请求当成新请求而不关闭。上一轮先改为：缺失/非有限时间仍以接收时间兼容；超过 5 分钟的未来值钳制到接收时间；超过 24 小时的旧 Hook 显式忽略，同时 `lifecycleObservedDate` 保留它的真实旧值供权限边界比较。下一小节记录了随后对同步审批/提问请求的细化。

新增 `SessionStoreLifecycleTests.testAncientHookTimestampCannotReviveCompletedSession`、`testAncientHookTimestampCannotCreateSession` 和 `testAncientHookTimestampRemainsOlderThanItsReceiptTime`；前两项先在旧实现下复现失败。`PermissionRoutingTests.testAncientPermissionTimestampRemainsBeforeCompletionBoundary` 验证过期请求在其真实时间早于完成边界时会关闭。以上是本地源代码与 XCTest 的时序证据，不证明竞品私有状态机、真实 Hook 延迟分布或已安装 UI；本轮没有启动竞品应用。

相关 `SessionStoreLifecycleTests` 与 `PermissionRoutingTests` 定向套件合计 64 passed、0 failed；最终完整 macOS XCTest 为 474 passed、0 failed、0 skipped。该结果验证当前源码的自动化行为，不替代真实 Agent Hook 调度或桌面运行验收。

### 异常时间戳不能吞掉同步审批请求（2026-10-25）

复核上一节的未来时间戳防护时发现一个交互边界：`HookSocketServer` 会先为 `PermissionRequest` 登记一个等待 Agent 答复的 socket，再把事件交给 `SessionStore`。若其来源时间超前超过 5 分钟，通用 Hook 防护此前会直接丢弃事件；结果可能是 Agent 正等待审批响应，但状态层没有对应的审批卡。这个问题来自 Agent Notch 自身的接收/裁决顺序，不是对竞品内部实现的推断。

现在按事件语义处理：早于接收时间 24 小时以上的事件仍拒绝；超前 5 分钟以上的普通生命周期事件仍拒绝，避免异常 `PreToolUse` 重开已完成会话或创建幽灵卡片；`expectsResponse` 为真的同步审批/提问请求则使用本地接收时间排序，保留其等待交互状态。缺失或非有限时间戳仍按接收时间兼容。该例外依据 Agent Notch 当前持有的响应连接和请求语义，是本项目设计选择，并非 Boring Notch 或 Vibe Island 的行为结论。

静态参考仍保持边界：Boring Notch `v2.7.3` [源码](https://github.com/TheBoredTeam/boring.notch/blob/v2.7.3/boringNotch/ContentView.swift#L2459-L2520)在悬停延迟执行前取消旧任务并复核当前指针/视图状态，可作为“异步状态变化必须按执行时事实复核”的设计参考；Vibe Island DMG 的设置文案只能证明存在完成展开/停留时长选项，不能证明其运行时状态裁决。竞品应用均未启动。

新增 `SessionStoreLifecycleTests.testImplausiblyFutureHookTimestampCannotReviveCompletedSession`、`testImplausiblyFutureHookTimestampCannotCreateSession` 和 `testFutureDatedInteractivePermissionUsesReceiptTime`。新的审批用例先在旧策略下失败（状态层没有创建 session），修复后通过。完整 macOS XCTest 为 477 passed、0 failed、0 skipped；Xcode 报告 `LifecycleDiagnosticsTests`、`ProcessExecutorTests`、`TmuxTargetFinderTests` 有 QoS 优先级反转警告。以上是本地源代码和 XCTest 证据，不替代真实 Hook 调度、审批端到端或 GUI 验收。

### 冷启动快照的未来时间不能延长状态（2026-10-25）

这是 Agent Notch 自身的恢复时序问题，不归因于 Vibe Island 或 Boring Notch。Hook 入口已限制异常时间戳，但持久化快照恢复此前直接使用未来的 `completedAt`、`lastActivity` 等日期计算卡片保留和缺失会话宽限期。复现测试将完成时间设为未来 6 分钟；旧实现会把该值原样恢复，使它看起来比实际恢复时刻还新。

现在从磁盘恢复时统一将晚于恢复时刻的日期钳制到恢复时刻，并覆盖 Hook/回合时间及子 Agent、工具边界的数值时间戳；移除会话墓碑仍以原始时间证据校验，未来快照值不能越过墓碑。新增 `SessionStoreColdStartTests.testColdStartClampsFuturePersistedCompletionToRestoreTime`，先在旧实现下失败，修复后通过。完整 macOS XCTest 为 478 passed、0 failed、0 skipped；Xcode 记录 `LifecycleDiagnosticsTests` 一条 QoS 优先级反转运行时警告。

这验证的是本地冷启动快照恢复，不证明真实 Agent 时钟漂移、外部 Hook 延迟或安装后 UI。Vibe Island 与 Boring Notch 仍仅作静态分析，未启动应用。

### 所有生命周期来源共享未来时间边界（2026-10-25）

这次发现来自 Agent Notch 自身代码，不是竞品私有状态机结论：Hook 入口已有 5 分钟未来时间检查，冷启动快照也已归一化，但 `LifecycleReducer` 同时接收 transcript、Codex 原生轮询、Bridge 恢复等证据，这些入口此前没有共享校验。于是已写入文件的 assistant 最终回复若带未来时间，会把 `completedAt` 推到当前时间之后；后续真实回合即使已经开始，也可能因为早于该边界而无法改变状态。

现在 Reducer 在任何状态迁移前统一校验 `observedAt` 及 active/tool/completed/failed/interrupted 携带的日期：非有限值或超前接收时刻 5 分钟以上的证据不参与状态变更，并在诊断轨迹中以 `implausibleFutureTimestamp` 标记。同步审批/提问仍由 Hook 接入层先归一化为本地接收时间，因此不会丢掉正在等待答复的卡片。新增 Reducer 状态矩阵与 transcript 文件更新回归；两项均先在旧实现下失败，修复后通过。完整 macOS XCTest 为 480 passed、0 failed、0 skipped；Xcode 记录 `ProcessExecutorTests` 一条 QoS 优先级反转运行时警告。

Boring Notch `v2.7.3` 的静态源码在悬停延迟动作执行前重新核对取消状态与当前 UI 条件；这里采用的只是“异步证据要在改变状态前再次校验”的一般原则，未把它描述为 Boring Notch 的 Agent 生命周期行为，也未复制 GPL 源码。以上仅为本地状态机与 XCTest 证据；Vibe Island / Boring Notch 均未启动，真实 Hook 与安装后 UI 仍待独立验收。

### 悬停关闭边界不应打断审批交互（2026-10-25）

Boring Notch `v2.7.3` 的公开源码 `ContentView.handleHover` 会取消过期悬停任务，并在关闭前检查当前视图状态；`BoringViewModel.close()` 还会尊重电池浮层/屏幕共享的关闭保护。这是静态源码观察，REA 对应的 Boring Notch DMG 仅用于身份与制品核对，不据此推断内部 Agent 交互。Agent Notch 已把同一交互原则独立映射到权限审批：审批到达时将悬停预览转为通知所有权，避免指针离开时的自动关闭任务收起仍可操作的审批会话；用户主动打开的面板继续保留用户所有权。

此前单元测试分别覆盖了“指针离开只关闭 hover 所有的面板”和“点击可接管 hover 预览”，但没有覆盖审批恰好在鼠标离开关闭倒计时期间到达。本轮新增 `NotchPointerInteractionTests.testApprovalArrivingDuringHoverExitDelayKeepsPanelOpen`：通过测试事件源让悬停打开、离开并确认关闭条件已经成立，再送入审批并跨过旧关闭时限；面板仍打开且展示对应会话。指针交互、展示时序及两条信息型 Hook 回归合计 34 passed、0 failed、0 skipped；随后完整 macOS XCTest 为 481 passed、0 failed、0 skipped（macOS 27.2 / arm64），Xcode 记录 `ProcessExecutorTests.swift` 一条 QoS 优先级反转运行时警告。这是 ViewModel 与测试事件源的时序证据，不等同真实鼠标/AppKit GUI 或已安装应用验收；竞品应用仍未启动。

### 重启后遗失审批上下文的非操作性恢复提示（2026-10-25）

Agent Notch 的 Bridge 快照只保留最新事件与状态，不含权限请求正文，也无法恢复应用重启前的审批响应 socket。因此 `waiting_for_approval` 快照恢复后继续保持安全的 `.processing` 生命周期裁决，但不再把它展示成普通 Working：会话行改为提示“上次记录为等待审批，请检查 Agent 自身窗口”，可归档且没有批准/拒绝操作；刘海使用静态琥珀提示，不播放等待或处理中循环动画。真正的实时审批仍最高优先，其他正在处理的会话也高于恢复提示。接受到时间更新的生命周期 Hook 后，该提示失效；本地持久化会保存恢复边界，使应用再次重启时不会短暂退回误导的 Working。

新增 `SessionStoreWatcherRecoveryTests.testOfflineApprovalSnapshotRestoresNonActionableNoticeUntilFreshHook`，覆盖 Bridge 恢复、应用快照再次恢复、无可操作交互以及新 Hook 清除提示；`SessionRowPresentationTests` 覆盖提示文案/归档和新 Hook 边界，`NotchPresentationTimingTests` 覆盖并发状态优先级。完整 macOS XCTest 为 488 passed、0 failed、0 skipped（macOS 27.2 / arm64）；Xcode 记录 `ProcessExecutorTests.swift` 一条 QoS 优先级反转运行时警告。该结果验证本地状态模型和自动化测试，不替代真实 Agent 审批恢复或安装后 GUI 验收；Vibe Island 与 Boring Notch 仍未启动，本次不把该设计归因于竞品。

### 刘海开合动效速度偏好（2026-10-26）

Boring Notch 官方 [Issue #1062](https://github.com/TheBoredTeam/boring.notch/issues/1062) 记录用户希望加快刘海展开动画；合并至 `dev` 的 [PR #1079](https://github.com/TheBoredTeam/boring.notch/pull/1079) 展示了从“秒数滑块”调整为“独立启停 + 倍速滑块”的讨论，最终把动画关闭与速度调节分开，避免用 `0×` 同时表示“瞬间完成”与“没有速度”的歧义。该证据是公开 issue/源码变更记录，不证明本地静态检查过的 `v2.7.3` DMG 包含此功能，也不是启动竞品后的运行观察。

Agent Notch 采用相同的交互原则而非复用上游代码：设置页提供独立的开合动画开关，关闭时使用零时长切换；速度保持 `1×` 默认值以兼容当前手感，范围为 `0.5×–2×`，同时作用于打开、关闭和悬停响应。macOS“减少动态效果”开启时，速度滑块显示系统控制并禁用，系统简化过渡不随倍速变化。偏好经过持久化和非有限/越界值钳制测试。

新增速度策略与偏好测试后，定向 `NotchPresentationTimingTests` 为 `18 passed / 0 failed`；完整 macOS XCTest 为 `489 passed / 0 failed / 0 skipped`（macOS 27.2 / arm64）。Xcode 仍报告 `ProcessExecutorTests.swift` 一条既有 QoS 优先级反转运行时警告。以上验证本地源码、偏好模型与自动化测试；尚未进行设置页 GUI 手动验收或已安装应用体验测试。
