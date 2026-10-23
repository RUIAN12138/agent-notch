# 竞品逆向证据与 Agent Notch 决策记录

审查日期：2026-10-23
Agent Notch 基线：`main` / `93ee7f3`（本轮改动前）
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
- 更新说明还包含性能与稳定性修复；这些是厂商自述，不是独立测量。

对照当前 Agent Notch 源码：带精确身份的并行审批 FIFO、子 Agent Hook 状态恢复、根/子 Agent 生命周期隔离、Codex 中断/失败状态与迟到事件屏障，已有实现和对应 XCTest。可见这些可靠性方向并非缺失功能，不应仅因为竞品更新说明出现类似修复就重复造一套。

本仓库尚未发现 Codex 原生 `request_user_input` 交互的接收/应答集成，也没有 Codex 后台命令和端口控制面板。它们是值得评估的功能差距，但涉及新的 Codex 控制通道与用户可触发的命令/端口操作；在确认官方协议、权限边界、取消/失败/过期语义及真实端到端验收方案前，不从对方更新说明推演私有实现，也不直接接入。

### Boring Notch 当前公开发布列表

本轮检查的[官方 Releases 页面](https://github.com/TheBoredTeam/boring.notch/releases)当前展示 `Latest Nightly` 与 `v2.8-rc.1`，其发布说明提及高 CPU、通知 UI、镜像尺寸及音频输出悬停方面的修复。该页面与源码说明均属于上游材料，不证明对应二进制在本机的实际表现；本项目的 REA 包证据仍以 Boring Notch `2.7.3` 为准，源代码设计参考仍明确区分 `v2.7.3` 与 `v2.8-rc.1`。

**版本记录纠偏：**较早条目提到官方 Releases 页面还列有 `v2.8-rc.2`，与本轮读取到的页面列表不一致。当前不再把 `rc.2` 标为已核验的当前发布；如需追溯它，应另行核实对应 tag、源码和日期，不能据旧记录推断发行状态。

### 本轮结论与下一候选

静态对照的下一候选不是再加一套通知优先级，而是评估“Codex 原生提问在刘海中回答”的官方接入路径。需要先完成协议与安全边界审查，尤其是请求身份、并行问题、取消/超时、桌面与 CLI 覆盖范围；仅发现本地化文案或更新说明不足以实现或宣称支持。后台命令/端口控制范围更大，优先级低于完成 Codex 提问协议评估。
