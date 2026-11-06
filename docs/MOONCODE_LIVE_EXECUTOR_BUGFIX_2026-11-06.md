# MoonCode 接通执行器后的真实 bug 交付（2026-11-06）

**结果：真实模型自主修复并自测，原样交付的实现通过独立验收。** 此例覆盖完整 core 包的局部修复；不代表完整应用、任意仓库或所有执行后端均已验证。没有新增功能、架构、状态机、审批或验收 gate。

## 范围与执行方式

- 基线：MoonDesk `15b11a3b`、MoonClaw `b0edd8d2`、MoonFort `eb1ab98`，均在 main。MoonFort 原有 SQLite 工作台未提交改动保留，不属于本次提交。
- 真实缺陷：`infer_source_layer("research/wiki/history")` 和 `infer_source_layer("research/wiki/reviews")` 返回 Wiki，而其目录下文件已正确返回 History / Review。协调者只在既有测试加入两条失败验收断言，没有注入缺陷或提供实现方案。
- 从现有源码构建 MoonFort 的 publisher、executor 和 output readers，通过既有 `MOONCLAW_MOONFORT_CONFIG` 接到评测专用 MoonClaw daemon。使用真实 macOS sandbox-exec、本地快照和签名 receipt，没有执行器 fixture 或 host shell 回退。
- 本地后端为显式 `AllowDegraded`，receipt 为 **Degraded**。未验证完整生产隔离；没有给已安装应用或其他正在运行的 daemon 改配置。
- 执行工作区：`/Users/kq/mooncode-live2-20261106/workspace`，复制完整 core 包源码及所需 MoonLib / x 本地依赖，并使用评测用最小 module/workspace manifests。没有复制主仓库 3.9 GB 的构建缓存；源码副本不是 Git worktree。依赖与 manifests 不计为产品修改。
- Session：`mooncode-live2-source-layer`；command：`live2-source-layer-1`。普通 `/turns` prompt，真实 `codex/gpt-5.6-sol` / OAuth，观测 transport 为 `chat_completions`。没有注入 tool calls、模拟模型、steering 或额外 Reviewer。
- 提交前已验证该执行器能运行 `moon test core --target wasm-gc`：24 项中 23 通过，目标回归失败。Native 进程仍存在本机 Xcode selection 路径配置问题；本轮预先明确使用可运行的 Wasm GC 后端自测。

## 自主交付与独立验收

模型自行读取规范、源码和测试，批量 edit 一次，仅在 History / Review 分支各加入一条完整目录后缀匹配。没有改变分类顺序、依赖或配置。随后真实 MoonFort 执行 `moon test core --target wasm-gc`，**24/24 通过**，模型 finish 如实说明改动和格式化未执行的原因。

协调者将模型的 `core/paths.mbt` **原样复制到 main**，没有改写实现。独立验收另外在既有测试补查两种嵌套文件路径和 `history-old` / `reviews-old` 两个相似名称，检查未误匹配。core Native / JS 各 **24/24**；MoonDesk Native 全量 **1726/1726**。这些集合有重叠，不能相加。没有 UI 或安装态应用验收。

| 返工 / 干预 | 实际观测 |
| --- | --- |
| 实现修改 | 模型一次 edit、两行实现；交付后实现返工 0 次。 |
| 人工干预 | 运行中 steering、问题回复、审批、人工补丁和验证接管均为 0；协调者负责预置验收断言、复制产物和独立验收。 |
| 模型新增测试 | 0；两条最初失败断言、四条独立边界断言均由协调者提供。 |
| 探索 / 自测 | moon_ide helper 查找失败；Wasm GC 首次复现误设 expected exit 为 1，实际为 2；模型也尝试 Native，返回 Xcode 配置错误。最终 Wasm GC 检查真实通过。 |
| 格式化 / diff | 单文件 fmt 要求 Git HEAD，源码副本不满足；并发 shell diff 因未绑定 grant 被拒绝。模型没有宣称这两项已通过。 |
| 规范工具结果 | 17 个，按 ok/accepted 为 13 成功、4 失败；详情见下文。 |

成功工具：read_skill 1、read 7、moon_cmd 2、shell 1、edit 1、finish 1；失败工具：moon_ide 1、moon_cmd 2、shell 1。其中一个“成功” moon_cmd 是 Native 返回恰好等于 expected exit 1 的环境错误，**不能作为测试通过证据**。自主自测结论只依据最后 Wasm GC 的 24/24 输出和 exit 0，不依据工具成功数量或 finish 本身。

## 用量与耗时

| 指标 | 真实观测 |
| --- | --- |
| 模型响应 | 9 次，全部有 usage；外层 retry 合计 0。 |
| 输入 tokens | **262,159**，包含缓存输入 **121,472**；非缓存输入 **140,687**。 |
| 输出 tokens | **1,274**；输入 + 输出 **263,433**，缓存不重复相加。 |
| 现金费用 | **未知**；没有账单或价格凭证，不能记为 0。 |
| command → finish | **57.648 秒**：1793942737553 → 1793942795201。 |
| command → terminal receipt / service idle | 57.683 / 58.162 秒。 |
| planner latency 合计 | 51.558 秒，按现有 planner metrics 定义。 |
| 独立 core 双后端验收 | 最终日志为 1793942972 秒，即接受命令后约 **234 秒**；含额外边界断言、调度等待和文件锁等待，不作为纯测试执行时长。 |

最早可核对的本轮复现日志创建于 1793942480 秒，比提交命令早约 258 秒。这段含源码副本与执行器预检；更早的代码阅读、执行器首次构建和后续排错、全量回归、文档及推送不包含在 57.648 秒内。用量仅含 MoonCode 本次子任务，不包含本聊天协调模型。和上次 16 次响应任务的缺陷、工作区和提示均不同，不能据此宣称成本或速度提高。

执行器首次构建日志创建（1793942365 秒）至三仓最终回归完成（1793943226 秒）的可核对工程窗口为 **14 分 21 秒**，包含接通、预检、模型任务、独立验收与运行时排错；更早阅读和之后文档/推送仍在该窗口之外。

## 只修运行中实际暴露的问题

| 所属 | 实际问题与修复 | 验证 |
| --- | --- | --- |
| MoonDesk | 嵌套 History / Review 目录缺少后缀匹配；采用模型两行原样实现。 | 先红后绿，自主 Wasm GC 24/24；独立 Native / JS 及相似名称检查。 |
| MoonFort | scratch 子进程 getcwd 因祖先目录 metadata 被拒绝。只允许读取 scratch 祖先的 metadata。 | 初始真实 moon test 无法解析 cwd；修复后真实测试执行；既有 local E2E 加入 `/bin/pwd -P`。 |
| MoonFort | 固定系统 PATH 找不到受信 moon 可执行文件同目录的 moon-ide。macOS PATH 前置受信可执行文件目录，仍不继承用户环境。 | 原真实调用失败；修复后真实 executor 执行相同 `moon ide outline core`，exit 0。E2E 检查 PATH 前缀。 |
| MoonClaw | 并发只读批次提前执行 shell，稍后才绑定 grant；journal 中后补的 arguments 不能证明已执行时有授权。批次启动前复用现有绑定，后续记录复用该绑定。 | 既有顺序测试加入 shell，修复前失败、修复后通过；原始失败 shell 参数经真实 executor 回放获得 grant-bound receipt。 |
| MoonFort | 标准 `2>/dev/null` 被当作文件写入拒绝。只允许 null device 的 write-data。 | 实际回放暴露该错误；既有 local E2E 在 getcwd 检查中使用 null 重定向，真实执行通过。 |

上述执行器/调度修复由协调者完成，不归功于本次模型。并发 shell 的原样回放只证明授权链接通：该命令含 `|| true`，且副本缺少 Git HEAD，不能作为 diff 检查通过的依据。后续 `/dev/null` 修复由真实 local E2E 验证。没有以这些问题为由新增自动重试、审批、校验层或模型调用。额外开销为按路径深度生成少量 metadata 规则及字符串 PATH 拼接；并发批次复用同一个绑定，不额外绑定第二次。

运行时修复提交：MoonFort `7df62bb`、MoonClaw `657b74da`；模型产物、验收断言和本记录随 MoonDesk 同次提交。运行时修复后的验证包含原参数回放、真实执行器 probe 与本地回归，没有另付费重跑一次模型任务，因此不宣称四个工具失败已在真实模型重跑中消失。

## 回归与证据

- MoonClaw Native **1845/1845**；MoonDesk Native **1726/1726**；core Native / JS 各 **24/24**。
- MoonFort 首次无 CLI 路径环境时为 273/296，23 项明确要求编译后的浏览/比较 CLI。按既有要求构建并配置四个 CLI 后，包含最终 null 重定向修复的完整回归 **296/296**；真实 local E2E 强制启用。
- 三仓 info/fmt 与接口差异检查；无公共 `.mbti` 改动。MoonFort 新版 formatter 会迁移旧 Int / optional 参数写法；已撤回与本次无关的批量格式改动，保留原有未提交文件。
- 主任务 journal：`/Users/kq/mooncode-live2-20261106/workspace/.moonsuite/products/moonclaw/mooncode/sessions/mooncode-live2-source-layer/journal.jsonl`。
- 主 journal SHA-256：`7f2e92483d71c13ea57ee4e55e6ecd4b7240c40cf35aadad64af0bfad5043e81`。
- 同一私有 run root 保存 request、canonical snapshot、measurements、preflight receipt 与原 shell 回放；凭据和签名配置不进入 Git。评测 daemon 已停止。

此例验证局部源码副本上的自主修复与自测、main 上的独立验收；全仓源码快照、Native 沙箱工具链配置、生产强隔离、长期成功率和成本基线仍未由本例证明。
