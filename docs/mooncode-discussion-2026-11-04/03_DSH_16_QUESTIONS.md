# DSH 的 16 个问题

原始答复完整保留。后续修正见 [归档说明](README.md)，包含进度更新的原始顺序见 [完整讨论](TRANSCRIPT.md)。

## 03 DSH 的 16 个问题

原聊天轮次：`01a1a66b-b471-7831-8aaa-c21191f34c2c`

### 用户

answer the same question with latest ../dsh


### 助手完整答复

以下基于本地 `../dsh` 当前检出的 **`8bd073392e`（2026-11-03）**，工作区干净。回答以源码及默认配置为准，“建议补齐”不代表已有能力。

先明确架构：**DSH 是基于 Cordis 的插件化 Harness，Agent loop 本身也是插件。** 下文默认指共享 `dsh-base`；具体 profile、preset 和用户 patch 可以替换策略，`sdk-minimal` 也有独立组合。[架构](/Users/kq/Workspace/dsh/docs/architecture.md:7)

**1、从用户输入到最终输出，全链路每一环的输入输出是什么？**

| 环节 | 输入 | 输出 |
|---|---|---|
| 输入接收 | 用户消息、附件、Session、模型选择 | 持久化 inbox 变更，等待 turn 领取 |
| 输入领取 | 下一步输入和排队消息 | 本 step 待处理消息 |
| 上下文组装 | 历史、系统提示片段、运行状态、可见工具 | prompt assembly；`agent/pre-step` 可接受、改写或拒绝 |
| 请求准备 | 模型路由、请求选项 | 绑定具体 adapter 的 prepared call |
| 请求记录 | 实际系统提示、接受的消息、工具声明 | Session 事件、request header/context、冻结的模型请求 |
| 模型调用 | 已准备的请求 | 流式 chunk、最终 assistant 消息或失败 attempt |
| 工具执行 | 模型返回的原始调用批次 | 经过策略、审批、校验、调度的调用结果 |
| 结果回灌 | 工具结果和附加上下文 | `tool/result` 等日志，成为下一步模型输入 |
| 结束或继续 | 工具是否要求后续推理、是否有新输入、停止钩子 | 下一 step 或 `turn/end` |
| 前端展示 | Session 事件和实时 assistant stream | 对话、工具卡片、审批、后台任务及最终结果 |

核心原则是：**模型可见内容必须能从 Session 日志重建。** 输入、系统提示变化、压缩和工具结果都通过日志表达。

默认还在模型请求和顶层工具派发前执行持久化 checkpoint，避免请求或工具已经产生外部影响，调用依据却尚未落盘。[Turn flow](/Users/kq/Workspace/dsh/docs/architecture.md:97)、[Checkpoint](/Users/kq/Workspace/dsh/packages/session/session-checkpoint-policy/src/index.ts:1)

**2、Harness 的 agent loop 怎么设计？除了 max turns，还有哪些终止条件？**

DSH 当前是 **turn → step → 模型请求 → 工具批次 → 下一 step** 的循环。

正常情况下，模型不再要求工具续接、next-step inbox 为空，且 `agent/turn-stopping` 没有追加工作，turn 才结束。其他退出包括输入被拒绝、取消、请求失败和工具明确结束当前 turn。模型输出达到上限也有独立的 `max-tokens` 结算原因。

**默认 loop 没有内置总 turn/step 预算。** 不能把以下限制解释成任务预算：

- `maxTokens`：单次模型输出上限。
- 上下文窗口：决定请求是否容纳得下。
- 工具 timeout：单次工具执行限制。
- 并行度：默认最多 10 个并行安全调用。

同 Session goal driver 还能继续调度后续轮次，因此“一个 turn 完成”也不等于“目标完成”。

建议通过生命周期插件增加累计 token、金额、墙钟耗时和无进展预算；统一计算子 Agent 消耗，耗尽时明确记录原因并取消或暂停，而不是改写为任务成功。[循环源码](/Users/kq/Workspace/dsh/packages/core/agent-loop/src/agent.ts:326)、[明确限制](/Users/kq/Workspace/dsh/packages/core/agent-loop/README.md:208)

**3、模型返回 tool call 后，如何参数校验、权限校验、沙箱执行和结果回灌？**

当前工具管线是：

`记录调用 → pre-execute → 审批 → monotonic guards → execute → post-execute → finalize → 记录结果`

具体分工：

- **参数**：executor 解析原始批次，参数复制并冻结；通过 `defineTool` 定义的工具在执行前强制校验支持的 JSON Schema 子集。
- **权限**：`tools/pre-execute` 可 allow/deny/ask；随后注册的 monotonic guard 只能收紧权限，审批通过不能覆盖 guard 拒绝。
- **执行**：工具按能力调用 filesystem、subprocess、sandbox 等服务。
- **结果**：结构化输出校验、内容投影、post policy 和最终归一化后，形成唯一模型可见结果。

失败会转成结构化工具错误，通常允许模型在下一 step 修正。取消后会等待已启动工作收敛，未执行调用补错误结果，保持调用配对。

限制是：支持的是明确的 Schema 子集；第三方自定义 executor 和 MCP 桥接仍需遵守各自验证责任，不能承诺任意 JSON Schema 都被完整执行。[执行管线](/Users/kq/Workspace/dsh/docs/tool-execution-pipeline.md:5)、[参数验证](/Users/kq/Workspace/dsh/packages/core/tools/src/schema.ts:580)

**4、死循环或重复工具调用怎么检测和处理？**

DSH 已有默认启用的 `repeat-tool-reminder`：

- 按 Agent 统计连续调用。
- 指纹是工具名加递归排序后的 JSON 参数，忽略对象属性顺序。
- 默认第 3、5、8 次提醒。
- 被拒绝的调用也计入。
- 新的用户输入清空计数。

**这是提醒机制，不会阻断、延迟或去重执行。** 它不判断资源状态是否变化，也不能识别改写参数、A→B→A 或多个 Agent 之间的循环。

建议进一步加入：

`动作身份 + 相关资源版本 + 结果摘要 + 验收进展`

对无进展循环返回已有证据、要求改变策略，必要时暂停。具有副作用的动作应先查询上次执行状态；不能用“重复调用检测”替代幂等控制。[检测源码](/Users/kq/Workspace/dsh/packages/guard/repeat-tool-reminder/src/index.ts:103)

**5、长上下文怎么压缩？摘要丢信息怎么补？跨块关联怎么保证？**

当前默认有三层处理：

1. spill：过大工具结果保存到外部存储，模型得到有限内容和恢复地址。
2. tool-result pruner：缩减较旧工具结果的中部，保留头尾。
3. conversation compaction：用结构化摘要替换一段模型可见历史。

`compaction-basic` 根据模型窗口、输出预留、headroom 和 token meter 计算压力。默认 threshold ratio 为 0.8，近期原文保留比例为 0.16，支持模型级覆盖。

压缩会保留近期尾部，避免拆开 assistant tool call/result 配对，并检查摘要提交时原范围是否仍有效。**原始日志保留，改变的是模型可见 surface。**

摘要要求保留目标、约束、文件、错误、待完成工作和下一步；但没有语义完整性证明。关键事实丢失时，需要通过原事件、spill 引用和当前文件补读。

跨块关联目前依赖事件序号、来源范围、调用 ID 和摘要内容。建议对关键约束、验收结论建立明确证据引用，而不是仅依赖摘要文字。[压缩配置](/Users/kq/Workspace/dsh/packages/compaction/compaction-basic/src/config.ts:73)、[范围选择](/Users/kq/Workspace/dsh/packages/compaction/compaction-basic/src/region.ts:107)

**6、多 Agent 怎么拆任务、共享状态、仲裁结果冲突？**

DSH 分成两个能力：

- **Subagent**：管理子执行、父子关系、生命周期、消息和结果交付；支持本地持续会话与外部 provider。
- **Agent Teams**：提供共享任务 DAG、owner、状态和 revision。

Team 任务记录在根 Session 日志。更新经过串行事务，并要求 `expectedRevision`，旧版本修改会被拒绝；依赖检查阻止循环及未满足依赖的领取。

注意默认值：**新 Session 的 Team 模式默认关闭**，启用服务不代表每个任务自动组成团队。

任务拆分仍由模型或控制器完成，框架没有通用的自动分解、语义冲突仲裁器。建议每个子任务明确产物、验收条件、依赖和修改范围；父 Agent 根据实际文件、测试和证据裁决冲突。

子 Agent 的权限范围固定，不能从内部升级；父进程可处理超出子任务权限的动作。[任务事务](/Users/kq/Workspace/dsh/packages/team/agent-team/src/task-board.ts:111)、[Subagent](/Users/kq/Workspace/dsh/docs/subsystems/subagent.md:5)

**7、多个 Agent 并发改同一文件/资源，怎么防冲突？锁粒度怎么定？**

当前不同机制保护不同资源：

| 机制 | 保护范围 |
|---|---|
| Session write lease | 同一 Session 的跨进程单写者 |
| 工具独占 barrier | 当前工具批次内的执行顺序 |
| fs-local target lock | 同一进程中的目标文件修改 |
| Team revision | 任务板记录的并发修改 |
| Team writeScopes | 重叠告警，属于建议性信息 |

**Team writeScopes 不会锁住文件；工具独占也不是跨所有 Agent 的全局锁。**

还有关键默认值：读后写 observation policy 在共享 base 中默认关闭；未启用时，文件写入可以是原子但无版本条件的覆盖。跨进程 replacement writer 也不会被 fs-local 的进程内锁串行化。

建议优先隔离 worktree；共享修改时使用文件版本条件更新，Git index/合并用仓库锁，构建输出和安装目录按共享资源协调。多文件 patch 当前不提供整体事务回滚，部分成功后要重新读取现场。[默认策略](/Users/kq/Workspace/dsh/packages/bundle/base/cordis.patch.yml:292)、[文件限制](/Users/kq/Workspace/dsh/packages/fs/fs-local/README.md:126)

**8、服务重启，checkpoint 存什么、放哪、怎么恢复？**

共享 base 使用 JSONL Session 后端，根目录来自 `dshHomePath('sessions')`，按项目和 Session 分目录。当前写入格式版本是 v4，默认使用 zstd 压缩，例如 `session.v4.jsonl.zstd`。

日志保存输入队列、用户/系统消息、请求声明、assistant settlement、工具调用结果、压缩和各领域事件。

恢复过程包括：

- 取得该 Session 的独占 write handle。
- 读取并验证连续事件及物理尾部。
- 必要时执行格式迁移，保留旧 generation。
- 补充中断 turn 的收尾记录。
- 重建 inbox、模型上下文和领域投影，再开始执行。

默认有短时间 write-behind，但 checkpoint 会在模型请求和顶层工具派发前 flush；flush 失败则不派发。

Session 锁由内核持有，进程死亡自动释放，没有超时抢占一个仍活着的 writer。

**恢复日志不等于恢复后台进程、审批 Promise 和外部副作用。** 外部执行成功但结果未持久化的窗口仍存在，需要工具端幂等或状态查询。[写所有权](/Users/kq/Workspace/dsh/packages/session/session-persistence-jsonl/src/lease.ts:1)、[恢复流程](/Users/kq/Workspace/dsh/packages/core/agent-loop/README.md:114)

**9、human-in-the-loop 下，驳回或超时怎么续跑和兜底？**

要区分权限审批与普通问题。

权限审批只有四种结果：

- `allowed-once`：允许本次动作。
- `rejected`：明确拒绝。
- `cancelled`：请求撤销。
- `unavailable`：无人能回答或回答器失败。

只有第一种允许执行。当前 Session 审批策略为 `ask` 或 `never`；默认 `ask`，没有回答器时 fail closed。

审批会记录 `approval/asked`、`approval/decided` 审计对，并通过调用 ID 关联具体动作。**人工审批本身没有统一超时，主要由取消信号撤销。**

普通 `ask_user_question` 则支持超时返回 pending，让 Agent 继续独立工作；用户稍后回答会作为消息回灌。pending、跳过、拒绝都不能视为同意。

重启后旧审计记录不等于仍存在的等待，也不授予重新执行权限；需要恢复操作状态并重新建立审批。[审批契约](/Users/kq/Workspace/dsh/docs/subsystems/approval.md:9)、[问题等待](/Users/kq/Workspace/dsh/packages/interaction/tool-ask-user/src/timed.ts:1)

**10、工具结果过大怎么处理？失败怎么重试、熔断和保证幂等？**

当前 spill policy 在共享 base 中设为约 **12,500 estimated tokens**，保留必要内容、保存恢复地址；结构化 program value 与模型展示文本分别处理。后续 pruner 再缩减旧结果。

但 spill 缺少存储或无法计价时会保留原输出并报告原因，因此不能把这个值当成绝对硬上限。

模型重试由独立插件执行 provider 策略。默认 normal policy：

- 首次请求后最多重试 5 次。
- 处理配置的临时错误。
- 指数退避从 500ms 开始，最高 10 秒。
- 默认 ±10% jitter。
- 重试安排先记入日志，再等待。

也支持 `always`，会持续重试到成功、取消或卸载。

工具 timeout 仅对声明预算的工具生效，而且是**协作取消**；工具忽略信号时仍可能一直等待。当前没有统一工具熔断器或通用副作用幂等协议。

建议对服务端写操作增加逻辑操作 ID、结果查询和未知状态；不要因为超时就直接重做。[重试策略](/Users/kq/Workspace/dsh/packages/llm/llm/src/retry-policy.ts:14)、[Timeout](/Users/kq/Workspace/dsh/packages/guard/timeout-policy/src/index.ts:1)

**11、Function Calling 和 MCP 各解决什么？工具太多怎么按需加载？**

Function Calling 是模型表达工具选择与参数的方式；MCP 是外部服务的发现、协议、传输和调用机制。

DSH 当前把 MCP 工具注册成普通 Harness 工具，使用稳定的 `mcp__server__tool` 名称，进入同样的权限和结果管线。还支持 MCP resources 和服务端 instructions。

默认使用 native executor；可切换 PTC：模型调用 `run_code`，在程序里使用生成的工具 SDK，支持并行安全子调用。

与 OpenSeek 不同，**没有发现默认的本地 BM25 工具目录检索机制。** `deferLoading` 可以透传为 DeepSeek 的 `defer_loading`，实际行为取决于 adapter/provider，不能概括成所有模型都支持按需检索。

工具多时可用 scoped registry/preset 减少可见工具，再接 provider deferred loading 或单独检索插件。PTC 减少直接函数入口，但生成 SDK 本身仍有上下文成本。[MCP](/Users/kq/Workspace/dsh/docs/subsystems/mcp.md:5)、[PTC](/Users/kq/Workspace/dsh/packages/core/tool-executor-ptc/README.md:12)

**12、RAG 什么时候触发？query rewrite、rerank 怎么接？**

当前共享 base **没有通用文档向量 RAG、query rewrite 或 rerank pipeline**。

文件搜索、skills、Web、MCP 和可选 Session 搜索可以提供材料，但不能统称为已经实现了 RAG。Session 全文搜索也是可选能力。

接入时适合做独立工具或上下文插件：

`识别事实缺口 → query 改写 → 权限过滤召回 → rerank → 有来源的片段 → 日志化注入`

可在任务开始、遇到未知符号、诊断失败或压缩后缺失事实时触发。模型可见的检索结果必须记录到 Session；后台检索不能悄悄改变模型上下文。

改写要保留路径、符号、版本和用户限制。已有有效证据无需每个 step 重查，以控制延迟和 token 成本。

**13、Prompt 注入、危险调用和敏感数据怎么处理？**

当前有具体执行控制：

- 参数/输出验证和冻结。
- scoped 工具能力。
- 一次性审批和 monotonic guards。
- filesystem sandbox。
- 部分凭证及 MCP 诊断脱敏。

但 sandbox 模式约束的是**文件效果**，网络和进程可见性不在该模式词汇内；不同后端还区分 full/partial enforcement。不能把它解释成完整网络隔离。

另外，MCP server instructions 会进入系统提示，第三方插件也运行在宿主权限域，连接和安装本身需要供应链信任。日志可重建并不等于防注入。

敏感数据方面，telemetry 有脱敏扩展点，但**服务本身不附带脱敏规则**；规则作用于导出副本，不改写本地原始日志。

建议把外部材料与授权指令分层，并独立限制操作目标、出口和凭证；模型输入、日志、遥测、产物分别处理敏感内容。[沙箱范围](/Users/kq/Workspace/dsh/docs/subsystems/sandbox.md:9)、[脱敏扩展点](/Users/kq/Workspace/dsh/packages/session/session-telemetry/src/index.ts:24)

**14、线上怎么评测成功率、工具选错率、参数错误率、成本和耗时？**

当前已有较完整的采集基础：

- turn/step、tool call/result、请求和失败 attempt。
- assistant compact stream 与 usage。
- Session telemetry 的 ledger/ops 通道。
- OTel 输出，以及独立的产品交互遥测。

但“有日志和 OTel”不代表已有经过验收定义的任务成功率看板。

建议明确指标口径：

| 指标 | 判定方式 |
|---|---|
| 任务成功率 | 独立测试、实际产物或人工验收 |
| 工具选错率 | 标注/复核错误选择，不直接用工具失败代替 |
| 参数错误率 | 参数校验失败 / 调用次数 |
| 成本 | 实际 usage、缓存、工具及子 Agent 消耗 |
| 耗时 | 模型、工具、审批、压缩、排队分开计算 |

还应关注首次可见输出、重连恢复、上下文压缩和冷 Session 打开的 p50/p95。

遥测可能丢失或重复；ledger 接收端按 `(session.id, session.format_version, event.seq)` 去重。精确成本不能把采样或缺失 usage 当零。[Session telemetry](/Users/kq/Workspace/dsh/docs/subsystems/session-telemetry.md:5)

**15、badcase 怎么归因到模型、prompt、检索、工具？怎么回流回归集？**

DSH 的优势是请求上下文可重建，失败 attempt、工具错误和策略结果也有记录；但没有看到通用自动根因分类器。

归因先定位最早偏离的位置：

- 正确证据已提供，决策仍错：模型或 prompt。
- 事实在原日志中，压缩后丢失：记忆策略。
- 所需材料未召回：检索。
- 参数正确但执行失败：工具、环境或权限。
- 重复执行、恢复错位、消息顺序错误：Harness。

固定其他条件，替换某一层做对照；不要只凭最终回答归因。

回归可以利用现有录制 Session replay、工具/协议测试和真实 API 测试。DSH 测试规范要求关键行为检查实际世界，例如重新读取文件、执行验证，并检查未涉及文件保持不变。

**录制回放验证可重现行为，真实模型试验验证新决策能力，两者不能互相替代。**[测试规范](/Users/kq/Workspace/dsh/docs/testing.md:9)

**16、流式工具事件怎么推前端？断线怎么恢复？**

当前有两条互补通道：

- **持久化 Session 事件**：包括工具调用/结果，按 seq 排序。
- **实时 assistant stream**：start/chunk/end，带 attempt ID、revision 和 chunk index。

模型 attempt 结束时，完整 compact stream 写入 `assistant/message` 或日志专用 `assistant/attempt`，之后才发送 committed end，关联具体 seq。工具卡片从调用事件建立，再按调用 ID 结算结果。

Web 的 `follow()` 会先订阅并缓冲增量，再读取 snapshot，返回 opening cursor，然后过滤已覆盖事件，避免“读快照与订阅之间”的丢事件窗口。

重连时重新建立 follow，获取：

- 历史窗口和 cursor。
- 领域 projection。
- 同一宿主进程仍存活时的 active assistant stream baseline。

客户端用 attempt/revision/index 合并实时帧，用 seq 合并已提交记录。

**宿主进程重启后，尚未结算的实时 chunk 不具备持久恢复保证。** 已提交消息从日志恢复；需要区分“网络断线但宿主仍活着”与“执行进程死亡”。[Follow 实现](/Users/kq/Workspace/dsh/packages/api/session-controller/src/web/controller.ts:27)、[Stream settlement](/Users/kq/Workspace/dsh/packages/core/agent-loop/src/assistant-stream.ts:73)


