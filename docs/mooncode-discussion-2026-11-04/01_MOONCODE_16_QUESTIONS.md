# MoonCode 的 16 个问题

原始答复完整保留。后续修正见 [归档说明](README.md)，包含进度更新的原始顺序见 [完整讨论](TRANSCRIPT.md)。

## 01 MoonCode 的 16 个问题

原聊天轮次：`01a1a660-2157-7302-8e4b-f31aa3c52169`

### 用户

answering this question (mooncode) 1、讲清楚从用户输入到最终输出的全链路，每一环的输入输出是什么
2、Harness 里 agent loop 怎么设计，终止条件除了 max turns 还有哪些(token/耗时/预算/重复动作)
3、模型返回 tool call 后，怎么做参数校验、权限校验、沙箱执行和结果回灌
4、Agent 陷入死循环或重复调用同一个工具怎么检测和处理(状态指纹/去重/回退)
5、长上下文超限时，短期记忆怎么压缩，摘要丢失关键信息怎么补，跨块关联怎么保证
6、多 Agent 协作时，任务怎么拆分、状态怎么共享、结果冲突怎么仲裁
7、多个 Agent 并发改同一个文件/资源，怎么防冲突，锁粒度怎么定
8、Agent 执行到一半服务重启，checkpoint 存什么、放哪、怎么恢复现场
9、human-in-the-loop 场景，用户驳回或超时时，任务怎么续跑和兜底
10、工具返回数据过大怎么截断/摘要，工具失败怎么重试、熔断、保证幂等
11、Function Calling 和 MCP 分别解决什么问题，工具太多时怎么检索和按需加载
12、RAG 在 Agent 里什么时机触发检索，query 改写和 rerank 怎么接
13、Prompt 注入怎么防，危险工具调用怎么拦截，敏感数据怎么脱敏
14、Agent 线上怎么评测:任务成功率、工具选错率、参数错误率、成本、耗时怎么埋点
15、badcase 怎么归因到模型 /prompt/ 检索 /工具，怎么回流成回归集
16、流式输出下，工具调用事件怎么往前端正向推送，断线重连怎么恢复


### 助手完整答复

下面按 **MoonCode 当前实现 + 需要补齐的工程设计** 回答。标为“建议”的内容，不代表已经实现。

先明确边界：**MoonCode 是 MoonClaw 的编码角色，MoonClaw 承担 Agent runtime；MoonDesk 负责输入、控制、审批和结果展示。** [架构说明](/Users/kq/Workspace/moondesk/README.md:22)

**1、从用户输入到最终输出，全链路每一环的输入输出是什么？**

主链路是：**输入 → 持久化命令 → 领取任务 → 组装上下文 → 模型规划 → 工具执行 → 结果回灌 → 验收 → 展示。**

| 环节 | 输入 | 输出 |
|---|---|---|
| 用户提交 | 文本、附件、工作根目录、模型选择 | 带 `session_id`、`command_id` 的命令包 |
| 接收与持久化 | 命令包 | journal 命令记录、排队事件、顺序号 |
| Runtime 领取 | 可执行命令、会话控制状态 | claim，或 busy、cancel、等待状态 |
| 上下文组装 | 用户任务、AGENTS.md、检索材料、历史结果、steer | 本轮模型 messages 和工具定义 |
| 模型规划 | messages、工具 schema | assistant 文本或带 ID 的 tool calls |
| 校验与授权 | 工具名、参数、任务范围、权限策略 | 可执行调用、审批请求或结构化拒绝 |
| 工具执行 | 已授权调用 | 输出、错误、退出码、文件变化、执行证据 |
| 结果回灌 | 工具结果和 `tool_call_id` | 下一轮模型上下文 |
| 完成与交付 | `finish`、里程碑、验证证据 | 完成回执、回答、diff、产物引用 |
| 前端展示 | journal 的事件/会话投影 | 对话、工具状态、审批和最终结果 |

交互主入口 `/turns` 会持久化命令并启动或复用 runtime service。前端应以运行时证据更新状态；收到请求只能说明“已接收”，不能说明“已完成”。

另外，**命令执行完成、目标达成、用户接受修改，是三个不同事实。** [运行时契约](/Users/kq/Workspace/moonclaw/cmd/daemon/mooncode_capabilities.mbt:37)

**2、Harness 里的 agent loop 怎么设计？除了 max turns，还有哪些终止条件？**

我会把 Harness 定义为一个**可持久化、可暂停和恢复的状态机**。每轮依次检查控制信号、恢复点、工具结果和完成条件，再决定是否继续规划。

MoonCode 当前有两层循环：

- 外层 runtime loop：领取命令，执行 turn，处理 idle、审批、取消、失败和暂时中断。
- 内层 planner loop：模型产出工具批次，执行、回灌，再规划。

关键区别是：`max_turns` 和正数 `planner_max_steps` 是**调度批次上限**。耗尽批次可以保存 checkpoint 后续跑，不能因此宣称目标完成。当前 goal-runtime 的终态是 `Achieved`、`Blocked`、`Cancelled`；普通 `finish` 不自动结算目标。

如果产品要支持总 token、金额、耗时预算，建议单独增加预算控制器：

- 执行前检查剩余额度，并为并发调用预留额度。
- 执行后根据实际 usage、工具费用结算。
- 子 Agent 消耗计入父任务总账。
- 预算耗尽进入可解释的暂停状态，保留现场。

**当前 criteria-only goal-runtime API 不接受聚合预算，不能把旧预算代码当成现有能力。** [循环实现](/Users/kq/Workspace/moonclaw/cmd/daemon/mooncode_runtime_loop.mbt:126)、[目标契约](/Users/kq/Workspace/moonclaw/mooncode/core/mooncode_goal_runtime_v1.mbt:1)

**3、模型返回 tool call 后，如何做参数校验、权限校验、沙箱执行和结果回灌？**

执行链应该有四道边界：

1. **解析与参数校验**：解析 JSON，校验工具是否存在、必填项、类型、范围，以及工具特有约束。例如行号合法、替换文本唯一匹配。
2. **权限与范围校验**：检查会话和工作根目录、任务是否只读、操作是否需要审批。模型填写的 `requires_approval=false` 不能产生授权。
3. **执行隔离**：进程工具绑定具体 sandbox grant，限制命令、目录、网络、资源和超时。
4. **结果归一化**：返回成功/失败、输出、退出码和证据，以原 `tool_call_id` 回灌模型。

MoonCode 当前采用工具 schema 加各工具的手写校验；**不能说已经统一实现了所有 JSON Schema 的运行时验证**。MCP 转发层也需要补充对远端 `inputSchema` 的本地校验。

当前直接 `/tool-exec` 返回 503；Agent 进程执行路径在沙箱路由缺失时拒绝执行。审批后的进程调用使用已持久化绑定的参数，避免批准后替换命令。 [工具入口](/Users/kq/Workspace/moonclaw/cmd/daemon/mooncode_tools.mbt:1)、[审批执行绑定](/Users/kq/Workspace/moonclaw/cmd/daemon/mooncode_runtime_turn.mbt:640)

**4、死循环或重复调用同一个工具，怎么检测和处理？**

检测重点是**重复动作是否产生新信息或推进状态**，不能只统计工具名字。

MoonCode 已有具体拦截：

- 相同验证调用已经失败，且之后没有净源码变化，拒绝再次执行。
- 已完整读取、证据仍被保留的文件，限制重复整文件读取。
- 实现任务连续发现源码、没有实质修改时，达到 6 次广泛发现或 12 次总发现后拦截继续发现。
- 精确行范围读取、修复 patch 上下文不匹配等情况保留恢复通道。

进一步建议维护动作和状态指纹：

`工具名 + 规范化参数 + 相关资源版本 + 当前任务阶段`

配合滑动窗口识别 A→B→A 循环和无进展状态。处理顺序是：返回已有证据或拒绝重复动作 → 回灌具体原因 → 重新规划 → 必要时暂停并请求用户处理。

回退必须限定为本任务有记录的修改，不能用整个工作区 reset 处理循环。 [重复验证检测](/Users/kq/Workspace/moonclaw/cmd/daemon/mooncode_runtime_turn.mbt:2187)、[发现饱和检测](/Users/kq/Workspace/moonclaw/cmd/daemon/mooncode_runtime_turn.mbt:2357)

**5、长上下文超限，短期记忆怎么压缩？丢失信息怎么补？跨块关联怎么保证？**

要区分**模型当前上下文**与**持久化证据**：前者是工作集，后者支持恢复和核实。

MoonCode 默认压缩会保留前置系统约束、完整任务契约和近期消息；超过 32 条消息时保留约 24 条近期后缀，并保留部分较早推理锚点。较大工具结果在后续请求中保留有限的头尾内容，同时生成累计证据账本。

还有可选的上下文压力压缩路径，但默认关闭；启用后会检查指令、来源元数据和 tool-call/result 协议是否保持，失败则放弃该次压缩。

补偿机制应包括：

- 长期保留目标、用户约束、未完成事项、审批和验证结论。
- 用 `command_id`、`tool_call_id`、journal sequence、路径和行号关联证据。
- 对缺失事实按引用重新读取，避免把摘要当成事实原件。
- 关键结论记录依赖的证据，关联资源变化后使结论失效。

**结构完整性检查无法保证摘要语义完全无损**，关键决策仍要允许回看原始证据。 [默认压缩](/Users/kq/Workspace/moonclaw/cmd/daemon/mooncode_runtime_model_planner.mbt:1412)、[可选压缩校验](/Users/kq/Workspace/moonclaw/cmd/daemon/mooncode_semantic_compaction_trial.mbt:464)

**6、多 Agent 协作时，怎么拆任务、共享状态、仲裁结果冲突？**

拆分依据是依赖关系和资源所有权。每个子任务需要明确目标、输入、产物、验收条件、允许修改范围和依赖；前置输入不完整的任务不能提前运行。

MoonCode 当前的 `spawn_workers` 创建普通子会话，要求调用方提供隔离的工作根目录。父子关系先持久化，再启动子任务。`wait_workers` 按 any/all 汇总状态，结果绑定到被委派的具体 command，而不是子会话最新消息。

状态通过 journal 和结果引用共享；产物引用本身不授予跨目录访问权限。

结果仲裁应由父 Agent 根据任务契约、测试和证据完成。有冲突时比较前提、资源版本和验证结果；必要时独立复验或交给用户。**当前没有证据表明已实现通用的自动语义冲突仲裁。** [Worker 实现](/Users/kq/Workspace/moonclaw/cmd/daemon/mooncode_workers.mbt:33)、[结果投影](/Users/kq/Workspace/moonclaw/cmd/daemon/mooncode_worker_results.mbt:2)

**7、多个 Agent 并发改同一个文件/资源，怎么防冲突？锁粒度怎么定？**

MoonCode 当前已有：

- 会话级 execution lease，阻止多个 runtime 同时执行同一会话。
- journal 排他锁，保证记录顺序和记录身份去重。
- 同批 worker 根目录互不重叠。
- 工具批次区分可并发读取、独占修改和结束边界。

这些机制**不等于跨所有会话的文件锁**：不同会话指向同一目录，仍需要资源级协调。

建议优先用独立 worktree，由集成者合并。确实要共享写入时：

| 资源 | 建议并发控制 |
|---|---|
| 单文件修改 | 文件版本/hash 校验，加短期写锁 |
| 多文件原子修改 | 一次获取相关锁，固定获取顺序 |
| Git index、提交 | 仓库级锁 |
| 构建目录、依赖安装 | 按共享目录或工具资源加锁 |
| 远端记录 | ETag/version 条件更新或服务端事务 |

修改提交时再次校验版本；冲突后重新读取、重新生成 patch。锁不要跨模型推理或人工等待持有。 [工具调度分类](/Users/kq/Workspace/moonclaw/cmd/daemon/mooncode_tool_effects.mbt:2)

**8、执行中服务重启，checkpoint 存什么、放哪、怎么恢复？**

MoonCode 使用选定工作区对应的 MoonClaw 产品数据目录，保存 `mooncode/sessions/<session-id>/` 下的会话数据；**journal 是命令、事件和回执的有序权威来源**。

当前 continuation 会记录：

- command 和执行阶段。
- planner plan、step/tool 索引。
- 已完成工具结果或其 journal 引用与摘要。
- 待审批调用及审批身份。
- transport 中断位置、待处理 steering 等。

恢复时重放 journal，取得执行所有权，找到未完成命令及最近有效 continuation，再从未完成边界继续。已有完成证据的工具不能重复执行。

最难的是：**外部动作已经成功，但服务在写完成回执前崩溃。** 此时需要工具端幂等键或查询接口确认状态；无法确认就进入待核实状态，不能盲目重试。对外部副作用不能仅凭 checkpoint 承诺 exactly-once。 [Continuation](/Users/kq/Workspace/moonclaw/cmd/daemon/mooncode_runtime_continuation.mbt:85)

**9、human-in-the-loop 下，用户驳回或超时，任务怎么续跑？**

审批应当是持久化等待状态，绑定**具体操作和参数**。

MoonCode 会先记录 pending approval 和 continuation。用户批准后，从等待位置继续；用户拒绝后，将“未执行”和拒绝原因作为结果回灌模型，再选择符合新约束的路径。

超时仍保持 pending，不能自动视为同意。当前 runtime service 遇到审批会及时让出执行；直接等待模式另有等待时限。

还需要区分：

- “拒绝这一次操作”：允许其他合规方案。
- “禁止这类操作”：形成后续任务约束。
- “取消任务”：进入取消流程。

恢复后应重新检查资源版本和授权有效性；操作内容发生变化时，旧审批不能覆盖新动作。 [审批机制](/Users/kq/Workspace/moonclaw/cmd/daemon/mooncode_runtime_approvals.mbt:2)

**10、工具数据过大怎么截断？失败怎么重试、熔断、保证幂等？**

输出处理要分两层：

- **执行层**限制捕获大小，防止内存被打满。
- **上下文层**保留诊断、摘要和引用，控制模型输入成本。

MoonCode 已有带 `truncated`、原长度和上限的截断，以及保留进程输出头尾的处理。但如果输出在捕获阶段已经被丢弃，后续摘要无法恢复；需要原文时，应在执行阶段保存受限产物。

失败按类别处理：

- 参数或权限错误：修正或等待授权。
- 确定性业务失败：先修复原因。
- 网络抖动、429、临时服务错误：退避、抖动、遵守服务端重试提示。
- 副作用结果未知：先查询执行状态。

当前特定模型 transport 已有退避重试和过载请求压缩，部分路径可持续重试直到取消；**这不是所有工具统一的熔断策略**。

建议按服务维护 closed/open/half-open 熔断状态；写操作使用稳定的逻辑操作 ID 作为幂等键，并校验参数摘要。 [输出限制](/Users/kq/Workspace/moonclaw/cmd/daemon/mooncode_tools.mbt:2041)、[模型重试](/Users/kq/Workspace/moonclaw/cmd/daemon/mooncode_runtime_model_planner.mbt:320)

**11、Function Calling 和 MCP 分别解决什么？工具太多怎么按需加载？**

**Function Calling** 解决模型如何结构化表达“调用哪个函数、参数是什么”。  
**MCP** 解决客户端如何发现和调用外部服务提供的工具、资源等能力，覆盖连接、协议协商和交互规范。两者可以串联：

`模型 function call → Harness 校验与授权 → MCP tools/call → 结果回灌`

MCP 协议本身不会替 Harness 完成业务授权。[MCP 规范](https://github.com/modelcontextprotocol/modelcontextprotocol/blob/main/docs/specification/2026-07-28/basic/index.mdx)

MoonCode 有可选动态工具包和 `tool_search`：基础工具先加载，检索命中的工具在下一轮模型请求中加载，单次最多返回 5 个。MCP 通过 `mcp_list_tools` 和 `mcp_call_tool` 发现、调用工具。

工具检索结果还要受权限过滤；命中工具只表示“发现能力”，不能表示“获得执行许可”。 [按需发现](/Users/kq/Workspace/moonclaw/cmd/daemon/mooncode_deferred_tools.mbt:2)

**12、RAG 什么时候触发？query 改写和 rerank 怎么接？**

MoonCode 当前在每轮附加工作区上下文时，用任务文本检索知识库，再把片段作为来源材料注入上下文。

现有检索采用关键词打分，可叠加 embedding 相似度，排序后最多取 12 个片段；带来源、提取文本行号和引用。**当前这条路径没有独立的 query rewrite 或 cross-encoder rerank。**

需要增强时可以接成：

`任务/缺失事实 → query rewrite → 权限过滤后的混合召回 → 去重 → rerank → 补充关联片段 → 上下文`

改写应保留代码符号、版本和用户约束。除任务开始外，也可在发现事实缺口、工具失败需要文档、压缩后缺失关键证据时触发。已有有效证据无需每一步重新检索，以减少延迟和成本。 [检索入口](/Users/kq/Workspace/moonclaw/cmd/daemon/mooncode_book_instructions.mbt:2)、[当前排序](/Users/kq/Workspace/moonclaw/cmd/daemon/mooncode_knowledge_context.mbt:2)

**13、Prompt 注入怎么防？危险调用怎么拦？敏感数据怎么脱敏？**

核心是：**外部内容不能获得指令权限，模型输出不能获得执行权限。**

MoonCode 已有来源元数据；检索片段明确作为材料而非指令；危险进程操作经过审批和 grant 绑定。MCP 返回内容会处理配置 token 的脱敏，安全 stream 投影也过滤部分私有路径和 reasoning。

仍需分层加强：

- 外部网页、文档、工具描述和返回值按不可信数据处理。
- 服务端授权独立检查主体、操作、资源和目的地。
- 凭证通过受控执行环境注入，避免进入模型上下文。
- 模型入口、工具出口、日志和产物分别执行脱敏。
- 远端工具描述、schema、版本变化后重新审核。

来源标签和关键词黑名单都不足以证明防注入。路径字符串检查也不能替代操作系统隔离。这与 OWASP 对 Excessive Agency 的控制方向一致。[OWASP](https://genai.owasp.org/llmrisk/llm062025-excessive-agency/)

**14、线上怎么评测成功率、选错工具率、参数错误率、成本和耗时？**

先统一口径，再埋点：

| 指标 | 判定方式 |
|---|---|
| 任务成功率 | 验收条件满足且证据有效；不能只看 `finish` |
| 工具选错率 | 标注或复核发现的错误选择 / 可评估选择 |
| 参数错误率 | 参数校验失败调用 / 工具调用 |
| 成本 | 实际输入、输出、缓存 token 费用，加工具费用 |
| 耗时 | 排队、上下文构建、模型、工具、验证、人工等待分别记录 |

链路用 task/session/command/tool-call ID 贯通，同时记录模型、prompt、工具和检索版本。耗时看 p50/p95，并关注首次可见反馈、重试放大和恢复时间。

MoonCode 已有实际 usage、缓存、请求大小、工具 schema 大小等 planner metrics，以及分阶段延迟和 baseline/variant 回放框架。**这些代码不能直接证明已经有完整线上看板或线上成功率数据。** 缺失 usage 应标为未知，不能按零成本计算。 [Planner metrics](/Users/kq/Workspace/moonclaw/cmd/daemon/mooncode_planner_metrics.mbt:38)、[阶段指标](/Users/kq/Workspace/moonclaw/internal/harness_replay/phase_metrics.mbt:2)

**15、badcase 怎么归因到模型、prompt、检索、工具？怎么回流回归集？**

先定位**最早偏离正确行为的步骤**，然后做控制变量回放：

- 正确证据已在上下文，仍错误决策：检查模型或提示约束。
- 该召回的证据缺失、排序过低：检查检索。
- 原始证据有，压缩后丢失：检查记忆机制。
- 调用及参数正确，工具返回错误：检查工具或环境。
- 重复执行、审批错绑、乱序：检查 Harness 和恢复逻辑。

不能只看最终回答就归因给模型。应固定环境和其他输入，分别替换检索结果、prompt、工具结果，观察问题是否消失。

回归用例保留最小必要的初始状态、输入、工具 fixture、验收器和禁止行为。确定性故障做离线测试；模型决策做多次统计评测。

MoonCode 已有匿名 baseline/variant 回放和按任务类型分组的比较，但不能据此宣称自动根因归因已完成。 [回放验证](/Users/kq/Workspace/moonclaw/internal/harness_replay/replay.mbt:19)

**16、流式输出下，工具事件怎么推给前端？断线怎么恢复？**

建议由后端产生明确事件：规划、工具等待审批、工具开始、输出片段、工具结束、任务结束。每条事件携带 session、command、tool-call、event ID 和顺序号。

模型流式参数尚未收齐时，只能展示组装状态；**完整解析、校验和授权通过后才能执行工具**。

MoonClaw 当前提供 JSONL/SSE 格式和游标回放；MoonDesk 当前主要使用会话 watch 长轮询刷新，因此不宜描述为已实现一条持续的端到端 SSE 推流。

重连流程应是：

1. 客户端提交最后成功应用的 cursor。
2. 服务端回放该位置之后的事件。
3. 客户端按事件身份去重，并按 tool-call 更新对应工具卡片。
4. cursor 过期、出现缺口或回放超限时，重新读取权威快照。

现有可选 typed resume 契约会校验 stream 绑定、检测 cursor 异常，并在回放窗口超限时返回 409。前端切换会话还使用 generation 隔离旧请求。网络响应不应持有 journal 锁，否则慢客户端会拖住 Agent。 [恢复协议](/Users/kq/Workspace/moonclaw/cmd/daemon/mooncode_stream_resume.mbt:2)、[前端 watch](/Users/kq/Workspace/moondesk/ui/rabbita-desk/main/mooncode_session_watch_commands.mbt:11)


