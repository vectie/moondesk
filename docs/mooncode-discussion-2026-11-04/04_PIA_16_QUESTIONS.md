# Pia 的 16 个问题

原始答复完整保留。后续修正见 [归档说明](README.md)，包含进度更新的原始顺序见 [完整讨论](TRANSCRIPT.md)。

## 04 Pia 的 16 个问题

原聊天轮次：`01a1a671-8b32-7553-a972-3410fdcb8db1`

### 用户

answer the same question with latest ../pia


### 助手完整答复

以下基于本地 `../pia` 当前检出的 **`80f7a1149`（2026-11-04）**。

这里要区分两条路径：

- **默认 Pi CLI / `agent-core`**：轻量 Agent loop，能力主要通过扩展增加。
- **实验性 `pi-durable`**：持久任务、提交事务、崩溃恢复和可重放 code mode；这些不是默认 CLI 的保证。`apps/p2` 是使用它的实验应用。

**1、从用户输入到最终输出，全链路每一环的输入输出是什么？**

默认 CLI 主链路：

| 环节 | 输入 | 输出 |
|---|---|---|
| 接收输入 | 用户消息、附件、steering/follow-up | `AgentMessage` 和待处理队列 |
| 准备上下文 | 历史、工具集合、模型设置 | 下一轮上下文；工具变化写入系统消息 |
| 上下文转换 | `AgentMessage[]` | `transformContext()` 后，再由 `convertToLlm()` 转成模型消息 |
| 模型请求 | 模型消息、工具声明、认证、取消信号 | 流式 assistant 消息 |
| 完成响应 | 文本、tool calls、stop reason | 完整 assistant 消息 |
| 工具执行 | 调用名、参数、调用 ID | 校验、执行前 hook、工具结果、执行后 hook |
| 结果回灌 | `toolResult` | 加入上下文，再次请求模型 |
| 结束 | 无工具续接、无排队消息，或停止决定 | `agent_end`、最终回答及 Session 记录 |

`pi-durable` 则把输入、generation、tool call 都建模为持久状态：

`submit → pi.user → generation task → tool tasks → tool-result → answer → submission settlement`

**默认 core 的事件流与 Durable 的持久提交是不同保证。**[主循环](/Users/kq/Workspace/pia/packages/agent/src/agent-loop.ts:163)、[Durable 模型](/Users/kq/Workspace/pia/packages/durable/README.md:92)

**2、Harness 的 agent loop 怎么设计？除了 max turns，还有哪些终止条件？**

默认 `agent-core` 有两层循环：内层处理工具调用和 steering，外层检查 follow-up。主要结束条件：

- 模型返回 error/aborted。
- 没有工具续接，也没有排队输入。
- `finishTurn` hook 返回 `end`。
- 整批工具结果都带 `terminate: true`，抑制自动工具续接；排队输入仍按规则处理。

**core 没有默认累计 turn、token、金额或耗时预算。**

Durable 有可选 `maxTurns`，限制一个 run 的工具轮数；达到上限时先完成该批工具，再以 `unanswered/turn_limit` 结束。未设置则无限制。另有模型请求重试、工具局部超时和 `restartLimit`。

建议增加统一预算账本，将模型、摘要、工具和子 Agent 消耗一起结算；区分“暂停/预算耗尽”和“任务完成”。[Core 退出逻辑](/Users/kq/Workspace/pia/packages/agent/src/agent-loop.ts:263)、[Durable maxTurns](/Users/kq/Workspace/pia/packages/durable/src/harness/types.ts:485)

**3、tool call 返回后，怎么参数校验、权限校验、沙箱执行和回灌？**

当前 core 顺序是：

`查找工具 → prepareArguments → Schema 校验 → beforeToolCall → execute → afterToolCall → 结果事件及消息`

参数通过 `pi-schema` 编译校验器，缓存于 WeakMap；先复制再进行类型转换和验证，例如把 `"42"` 转成数字。失败返回工具错误供模型修正。

一个重要保护是：**模型响应因输出 token 上限被截断时，整批工具调用都不执行**，即使补救 JSON parser 已经解析出看似合法的参数。

权限方面，默认 Pi **没有内置权限系统**。`beforeToolCall` 和 CLI 扩展的 `tool_call` 可以阻断，但必须由宿主安装策略。

QuickJS code mode 隔离脚本本身，不提供 Node、文件和网络 API；脚本调用的宿主工具仍具有宿主授予的能力。不能把 VM 隔离解释成 bash、文件工具已经被系统沙箱限制。[参数验证](/Users/kq/Workspace/pia/packages/ai/src/utils/validation.ts:1)、[截断调用保护](/Users/kq/Workspace/pia/packages/agent/src/agent-loop.ts:462)、[权限边界](/Users/kq/Workspace/pia/README.md:95)

**4、死循环或重复工具调用怎么检测和处理？**

**默认 CLI/core 没有通用的动作指纹、去重或无进展检测器。**

Durable 增加的是另一类保护：

- 可选 `maxTurns`。
- 同一任务连续崩溃且没有推进 checkpoint，默认达到 5 次后终止。
- generation 崩溃先按请求重试政策计费重试。
- code mode 检查确定性重放是否偏离。

这里的 **VM fingerprint 是恢复兼容性检查，不是 Agent 防循环指纹**。

建议额外维护：

`工具名 + 规范化参数 + 相关资源版本 + 结果摘要`

检测相同调用、A→B→A 和长期无进展，依次采取复用证据、诊断、重新规划和暂停。Durable 的嵌套工具调用也没有通用深度上限，需要用 `callers` 或宿主策略限制递归。[崩溃保护](/Users/kq/Workspace/pia/packages/durable/README.md:214)、[重放校验](/Users/kq/Workspace/pia/packages/durable/src/codemode/codemode.ts:1)

**5、长上下文怎么压缩？摘要丢信息怎么补？跨块关联怎么保证？**

CLI 默认自动压缩，触发条件是：

`contextTokens > contextWindow - reserveTokens`

默认预留 16,384 tokens，保留约 20,000 recent tokens。摘要追加为 `CompactionEntry`，通过 `firstKeptEntryId` 指向保留尾部，旧记录仍存在。

压缩会避免拆开工具调用与结果；过大的单个用户消息跨度可以拆成历史摘要和跨度前缀摘要。文件读取/修改列表累计保留。

但摘要仍有损：用于摘要的工具结果序列化会截到 2,000 字符，**没有关键事实完整性的语义验收器**。

Durable 还支持提前后台摘要，到阻塞阈值再等待；摘要过时会拒绝放置。关键事实缺失时，应根据 entry ID、工具调用 ID、文件路径和原记录补读。跨块关联主要靠这些身份与摘要内容，不是自动知识图谱。[CLI 压缩](/Users/kq/Workspace/pia/packages/coding-agent/docs/compaction.md:25)、[Durable 压缩](/Users/kq/Workspace/pia/packages/durable/README.md:606)

**6、多 Agent 怎么拆任务、共享状态、仲裁结果冲突？**

默认 CLI 不提供完整多 Agent 编排，但仓库有可安装的子 Agent 示例扩展：

- 每个子 Agent 独立 Pi 进程和上下文。
- 支持单任务、并行和串行 chain。
- 示例并行批次最多 8 个任务，4 个并发。
- 父 Agent 接收各子任务结果和 usage。

**独立上下文不等于独立文件系统。** 示例可以在同一 cwd 工作，没有自动 worktree 隔离。

Durable 提供更完整的结构：conversation/task ownership、持久子任务、`allSettled`/`failFast` 等待、父子取消传播，以及可原子修改的共享 documents。

任务拆分和语义冲突仲裁仍由父 Agent/业务控制器完成。建议对子任务明确修改范围、验收条件和依赖，用实际 diff、测试和证据裁决。[子 Agent 扩展](/Users/kq/Workspace/pia/packages/coding-agent/examples/extensions/subagent/README.md:1)、[Durable 子任务](/Users/kq/Workspace/pia/packages/durable/README.md:712)

**7、多个 Agent 并发改同一文件/资源，怎么防冲突？锁粒度怎么定？**

CLI 的 `edit/write` 使用文件级 mutation queue：

- 同一进程中，同一目标文件串行。
- 不同文件可以并行。
- Durable 按环境文件系统 ID 和 canonical path 分组。

**这些队列不能阻止 bash 或其他进程修改文件。** Durable 的存储事务也只保护内部状态，不覆盖外部文件。

core 默认工具并行执行；任何调用目标声明 `executionMode: "sequential"`，整个批次改为串行。并行路径使用 `Promise.all`，生产宿主还应控制批次 fan-out。

建议共享写入采用版本/hash 条件检查；Git index、合并用仓库级锁；复杂任务优先分 worktree。多个进程共享 Durable storage 也不受框架跨进程锁保护，必须由宿主保证单 owner。[CLI 文件队列](/Users/kq/Workspace/pia/packages/coding-agent/src/core/tools/file-mutation-queue.ts:29)、[Durable 文件队列](/Users/kq/Workspace/pia/packages/durable/src/tools/file-mutation-queue.ts:26)

**8、服务重启，checkpoint 存什么、放哪、怎么恢复？**

默认 CLI 的 Session 是追加式 JSONL 树，默认位于 `~/.pi/agent/sessions/` 下按 cwd 编码的目录。它恢复对话和分支上下文，**不能原样恢复执行中的 JavaScript、工具进程和审批等待**。

Durable 则保存：

- transcript entries。
- agent/provider/inbox/live/usage documents。
- task 的输入、定义版本、phase checkpoint。
- 等待、睡眠、所有权、重试和结果。
- code mode 的启动参数与结果 journal。

重开 storage 后调用 `resume()`，任务从 phase 起点重跑，不是恢复指令指针。

工具只有声明 `replay: "safe"` 才自动重跑；否则生成 interrupted 错误。嵌套调用用稳定 key 复用已存结果。外部效果已经发生但结果未提交时，仍需工具自身幂等。

存储由宿主选择：SQLite、JSONL、IndexedDB、Cloudflare 等。SQLite 默认 WAL/NORMAL 保证进程崩溃恢复，但最新提交可能受掉电影响；JSONL 可选 `fsync: true`，且整个历史还占内存。**一个 storage 同时只允许一个 owner，框架不提供跨进程锁。**[恢复](/Users/kq/Workspace/pia/packages/durable/README.md:115)、[Storage 限制](/Users/kq/Workspace/pia/packages/durable/README.md:850)

**9、human-in-the-loop 下，用户驳回或超时怎么续跑？**

默认 Pi 没有统一审批状态机。扩展可以通过 `tool_call` 阻断，并使用 UI 请求确认；仓库的 permission-gate 示例在没有 UI 时拒绝危险操作。

这属于示例策略，不能据此宣称所有危险操作都有审批，也没有统一的超时、持久恢复或跨调用授权规则。

宿主需要明确区分：批准本次动作、拒绝、撤销、超时和无人回答。拒绝后应把原因反馈模型；超时不能视为授权。

Durable 可以承载持久化的人类决策流程，但需要业务自己保存问题、操作身份和决定，并通过提交/任务状态推进恢复。取消 `Submission.wait()` 只取消等待，不取消实际工作；停止工作必须调用 abort。[审批示例](/Users/kq/Workspace/pia/packages/coding-agent/examples/extensions/permission-gate.ts:1)、[等待语义](/Users/kq/Workspace/pia/packages/durable/README.md:76)

**10、工具结果过大怎么截断？失败怎么重试、熔断和幂等？**

内置文件/命令工具通常按 **2,000 行或 50KB，先到者为准** 截断：读取保留头部，bash 保留尾部，超大命令输出可保存完整临时文件。MCP 的模型文本限制是 20KB，可提供完整输出地址。

但模型文本上限不等于 structured output、落盘和宿主内存都受同一限制。

重试分层：

- provider 请求层处理临时网络/HTTP 错误和退避。
- CLI/Durable generation 层默认最多重试 3 次，基础延迟 2 秒。
- Durable 可将退避保存为 sleeping task，重启后继续。
- 普通工具失败不会因此自动获得安全重试资格。

当前没有统一熔断器或通用外部副作用幂等协议。Durable 的 `requestId`、嵌套调用 key 能防重复提交/调用关联，但未知结果仍需工具端查询。多层重试还会放大费用，应该统一预算。[截断](/Users/kq/Workspace/pia/packages/coding-agent/src/core/tools/truncate.ts:1)、[Durable 默认策略](/Users/kq/Workspace/pia/packages/durable/src/harness/agent.ts:21)

**11、Function Calling 和 MCP 各解决什么？工具多时怎么检索和加载？**

Function Calling 是模型表达调用名和参数的接口；MCP 是外部工具服务的发现、传输、认证和调用协议。

当前 Pi 有独立 MCP 客户端，以及 CLI 内置集成。MCP 默认 exposure 是 `codemode`：不把所有工具塞进模型声明，脚本通过 `searchTools()`、`describeTool()`、`describeNamespace()` 发现能力。

其他 exposure：

- `direct`：直接提供给模型。
- `deferred`：`tool_search` 命中后，下次请求加载。
- `hidden`：不可调用。

`tool_search` 使用 BM25 和名称加权，默认返回 8 个。CLI 会注册它，但通常初始不激活；deferred MCP 配置会启用。Durable 加载结果记录在 `modelTools`，压缩后仍保留。

**搜索命中表示发现能力，不表示产生权限。**[CLI MCP 默认策略](/Users/kq/Workspace/pia/packages/coding-agent/src/extensions/mcp/index.ts:1)、[Durable 工具检索](/Users/kq/Workspace/pia/packages/durable/src/tool-search/tool-search.ts:1)

**12、RAG 什么时候触发？query rewrite、rerank 怎么接？**

当前默认没有通用的文档向量 RAG、query rewrite 或 rerank pipeline。工具目录 BM25 也不等于知识库 RAG。

core 的 `transformContext` 可以注入检索材料，扩展/MCP 可以提供检索工具。需要审计或恢复时，宿主必须另外记录来源和检索结果，不能假设请求时注入自动进入持久历史。

建议在任务开始、出现事实缺口、工具失败需查资料，以及压缩后缺关键证据时触发：

`query 改写 → 权限过滤召回 → rerank → 来源片段 → 上下文`

保留代码符号、路径、版本和用户约束；已有有效材料无需每轮重查。Durable 可将选中片段作为 entry 保存，支持后续核实和重放。

**13、Prompt 注入、危险调用、敏感数据怎么处理？**

最重要的现状是：**默认 Pi 使用启动用户的文件、进程、网络和凭证权限，没有内置全局权限系统。**

Schema 校验能验证参数形状，不能判断用户有没有授权。扩展可以阻断危险工具，但正则匹配示例不足以构成完整策略。

Code mode 的 QuickJS VM 限制脚本直接访问宿主；一旦暴露 `tools.bash` 或文件工具，仍可通过这些能力操作资源。因此应在宿主工具层实施授权，并按需要使用容器、微 VM 或系统沙箱。

敏感信息应在模型输入、工具结果、日志、遥测和产物分别处理。Durable 遥测设计主要记录 ID 和控制信息，但部分诊断消息仍可能含调用者内容；没有可以覆盖全部数据路径的自动脱敏保证。[默认权限](/Users/kq/Workspace/pia/README.md:95)、[Code mode](/Users/kq/Workspace/pia/packages/codemode/README.md:1)

**14、线上怎么评测成功率、工具错误、成本和耗时？**

当前已有明确的观测接口：

- core 的工具执行事件包含 `durationMs`。
- pi-ai 定义请求时长、首 chunk 时长、token 和 USD cost 指标。
- Durable 定义 submit/phase、checkpoint、replay、report 等事件。
- `pi.usage` 汇总模型、工具以及失败/取消尝试的可得 usage。

这些通过显式 telemetry context 传递；默认可为 NOOP，不能理解成自动上线了一套监控系统。

指标口径仍需业务定义：

- 成功率：独立验收，不是模型回答“完成”。
- 选错工具率：标注或复核。
- 参数错误率：Schema 失败单独统计。
- 成本：usage、模型价格、工具和子 Agent 总账。
- 延迟：模型、工具、重试、摘要和人工等待分开。

尤其 Durable 的 **Submission 已 done 时，`afterRun` 测试可能尚未结束**；done 不能直接当代码验收成功。[模型指标](/Users/kq/Workspace/pia/packages/ai/src/telemetry.ts:1)、[回答与后置验证](/Users/kq/Workspace/pia/packages/durable/README.md:669)

**15、badcase 怎么归因到模型、prompt、检索、工具？怎么回流回归集？**

当前有 transcript、usage、工具诊断、Durable task/report 和行为 eval，但没有通用自动归因器。

应定位最早偏离的位置：

- 正确证据已提供却决策错误：模型或 prompt。
- 原始历史有事实，摘要后缺失：压缩。
- 必要材料未召回：检索。
- 参数正确但执行异常：工具或环境。
- 重复副作用、恢复错位：运行时或幂等设计。

通过固定其他输入，替换某一层做对照；不要只凭最终失败归因。

现有 eval 支持隔离工作区、重复试验，以及 `with_docs/without_docs` 对照。回归应同时包含确定性的工具/恢复测试和多次真实模型任务评测，并用实际文件、测试或受保护的 oracle 判定结果。[Eval 框架](/Users/kq/Workspace/pia/packages/evals/README.md:1)

**16、流式工具事件怎么推前端？断线怎么恢复？**

core 已有完整事件序列：

`message_start/update/end → tool_execution_start/update/end → toolResult → turn_end → agent_end`

并行工具的 execution-end 按完成顺序出现，但最终 toolResult 消息保持模型原始调用顺序，前端必须按调用 ID 配对。

CLI RPC 通过 JSONL 推送事件，可以读取 `get_state/get_messages` 重建已记录内容；**core 本身没有通用、持久化的事件 cursor 重放保证。**

Durable 提供状态 watch：初始窗口加后续 commit ops。默认取最新 50 条，超过 100 条后缩回最新 50 条；客户端用 `ConversationTranscript` 合并、续看和补 gap。

最后一个重要限制：**Durable 的流式 partial/output 使用 deferred commits。** 默认约每 100ms 更新视图，最迟约 1 秒批量持久化；硬崩溃可能丢失这个窗口，甚至没有留下第一次 partial。恢复依赖已存状态，不能承诺每个已显示 token 都已落盘。[Core 事件](/Users/kq/Workspace/pia/packages/agent/src/agent-loop.ts:389)、[Watch 与持久化窗口](/Users/kq/Workspace/pia/packages/durable/README.md:477)


