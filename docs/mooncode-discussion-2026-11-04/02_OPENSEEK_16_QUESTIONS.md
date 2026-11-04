# OpenSeek 的 16 个问题

原始答复完整保留。后续修正见 [归档说明](README.md)，包含进度更新的原始顺序见 [完整讨论](TRANSCRIPT.md)。

## 02 OpenSeek 的 16 个问题

原聊天轮次：`01a1a666-08f7-72a2-ba3d-ad9f1a512396`

### 用户

answer the same question with latest ../openseek


### 助手完整答复

以下基于本地 `../openseek` 当前检出的 **`dbe35ecc`（2026-11-04）**。下面区分当前实现和建议补齐项；实现判断以源码为准。

与前面的 MoonCode 不同，**OpenSeek 自己拥有 Agent loop**。CLI、TUI、Desktop 共用引擎；`serve` 从 stdin 接收 JSONL 命令，通过 stdout 输出类型化事件，追加式 session 日志保存对话状态。[架构](/Users/kq/Workspace/openseek/docs/architecture.md:7)

**1、从用户输入到最终输出，全链路每一环的输入输出是什么？**

| 环节 | 输入 | 输出 |
|---|---|---|
| 接收输入 | prompt、图片、session、模型及运行选项 | 类型化命令；开始 turn 或进入待执行队列 |
| 构造会话 | 系统提示、工作区指令、skills、已有日志 | `Session`；用户输入追加为 `User` 事件 |
| 构造模型请求 | `Session.chat_messages()`、工具定义 | provider chat 请求 |
| 模型推理 | messages、function schemas | 流式文本、usage、完整 assistant/tool calls |
| 工具解析 | 工具名、原始 JSON 参数、调用 ID | 已解析的 `AgentToolCall`，或解码错误 |
| 校验与执行 | 类型化参数、文件状态、权限、运行能力 | `Respond(ToolOutput)` 或 `Control(...)` |
| 结果回灌 | 工具输出、错误、图片、调用 ID | 持久化 `Tool` 事件和下一轮模型消息 |
| 结束 turn | 普通最终回答或 `finish` 等控制结果 | `Finished`、`ContextYield`、`Failed` 等终止记录 |
| 前端展示 | 实时协议事件、持久化 session 事件 | 回答、工具结果、审批、后台任务状态 |

工具主要包括 `mbtx`、文件修改、后台任务、plan/goal/finish，以及配置后可用的子 Agent。`mbtx` 编译并运行 MoonBit 脚本，也能通过 SDK 调用宿主工具和 MCP。

关键保证是：**模型消息缓冲区在持久化追加成功后才更新**，避免模型已看到结果、磁盘却没有记录。但命令被接收、排队，不等于用户消息已经持久化。[主循环](/Users/kq/Workspace/openseek/agent/turn_loop.mbt:140)

**2、Harness 里 agent loop 怎么设计？除了 max turns，还有哪些终止条件？**

当前每个 step 是一次模型请求，然后处理该响应的工具批次。step 边界应用用户 steering、后台通知和计划/目标提醒。

主要退出条件包括：

- 普通最终回答，或 `finish`。
- `Abort`。
- 用户取消、执行中断。
- 模型或运行时失败。
- 显式 `max_steps` 耗尽。
- 上下文压力触发 `ContextYield`。

这里需要纠正与 MoonCode 的区别：**OpenSeek 的 `max_steps` 耗尽会写入 `MaxStepsExhausted` 终止记录，并非自动续跑的调度批次。** 未配置时默认基本不设 step 上限，由上下文机制约束长 turn。

上下文当前有 70% soft ceiling、80% hard ceiling；同时在工具批次中逐次检查剩余空间，预留摘要空间。触顶后压缩并结束当前 turn，下一 turn 从摘要继续。

目前没有统一的任务级累计 token、金额、耗时预算控制器。已有请求 idle timeout、工具超时和子任务局部限制。建议增加独立预算账本，将模型、压缩、工具和子 Agent 消耗统一结算；耗尽时保留现场并明确结束原因。[上下文策略](/Users/kq/Workspace/openseek/agent/auto_compact.mbt:2)

**3、模型返回 tool call 后，怎么做参数校验、权限校验、沙箱执行和结果回灌？**

当前执行边界分四层：

1. **JSON 解析**：原始参数无法解析时，记录对应调用的错误结果，允许模型修正。
2. **工具解码**：各工具的内部 decode 包转换成类型化输入，校验必填项、类型和业务约束。
3. **权限检查**：检查写入范围、文件状态、删除资格或沙箱升级权限。
4. **执行与记录**：普通结果返回 `Respond`；控制动作由 loop 处理。普通结果按 `tool_call_id` 持久化后回灌。

这里采用的是 schema 加工具内部显式校验，不能描述成所有参数都由一个通用 JSON Schema 验证器验证。

沙箱也要准确区分：

- `mbtx` 始终编译为 wasm，默认运行时携带 moonrun policy。
- guest 写入和启动进程受策略限制。
- **获准启动的子进程不继承 guest 文件系统规则。**
- read-only/worker 另有 macOS 内核写保护，属于可能不可用的补充防护。
- 经批准的 `escalated` 调用会省略 moonrun policy，只授权这一次调用。

因此，当前具备执行约束，但不能称为覆盖所有子进程的完整隔离环境。[工具边界](/Users/kq/Workspace/openseek/agent_tool/README.mbt.md:25)、[沙箱限制](/Users/kq/Workspace/openseek/agent_tool/mbtx/README.mbt.md:147)

**4、Agent 死循环或重复调用同一个工具，怎么检测和处理？**

**当前没有发现通用的“动作指纹＋状态指纹＋无进展窗口”检测器。**

已有机制主要是：

- plan/goal 提醒。
- 显式 `max_steps`。
- 上下文触顶让出。
- 用 `job_wait` 等待后台任务或输入，避免模型反复轮询。

这些机制能够约束运行，但不能证明重复动作已经被识别。session store 的 fingerprint 用于存储状态检查，也不是 Agent 防循环指纹。

建议新增：

`动作指纹 = 工具名 + 规范化参数 + 相关资源版本`

再结合成功输出摘要、文件变化和验收进展，识别相同调用、A→B→A 循环和长期无进展。处理顺序是：复用已有结果 → 返回具体诊断 → 重新规划 → 必要时暂停。

对有副作用的动作，应先核实上次执行状态；不能把防循环去重直接当成幂等保证。

**5、长上下文怎么压缩？摘要丢失关键信息怎么补？跨块关联怎么保证？**

OpenSeek 用**追加摘要事件**压缩上下文：

- 调用专用 summarizer。
- 用摘要覆盖指定 sequence 范围。
- `chat_messages()` 用摘要替代被覆盖历史。
- **原始事件保留在日志中，不重写删除。**

摘要提示要求保留目标、约束、关键决策、文件、命令、结果和后续步骤。摘要生成使用独立系统提示，将旧对话作为数据处理，避免 summarizer 继续执行编码任务。

还有一个重要细节：压缩期间到来的 steering 会先持久化，并保留在摘要覆盖范围之外，确保新指令原文进入后续上下文。

目前主要校验摘要非空、范围合法和消息投影有效，**没有关键事实完整性的语义验收器**。建议增加必须保留的约束和证据清单；摘要引用事件 sequence、文件路径及版本。发现信息缺口时读取原日志或当前文件核实。

跨块关联目前主要依赖摘要内容、覆盖范围和原始事件；尚无通用证据依赖图。[摘要生成](/Users/kq/Workspace/openseek/agent_session/compact/compact.mbt:2)、[压缩边界](/Users/kq/Workspace/openseek/agent/auto_compact.mbt:100)

**6、多 Agent 怎么拆任务、共享状态、仲裁结果冲突？**

当前有独立子进程形式的子 Agent，常见 kind 包括 `explore`、`review`、`worker`。父进程创建子 session、提交请求，通过结果文件接收类型化报告，并重新校验报告契约。

状态通过子 session、后台任务状态、结果报告和受控消息通道交换，不是共享一份可任意修改的内存。不同 kind 对工作中接收追加指令的策略也不同。

worker 支持隔离 worktree 和指定目录模式。**报告是咨询性结果，实际文件变化需要由宿主根据 Git 状态和 diff 核实。** 最新 launcher 会捕获 worktree 变化并交接分支或保留现场，不应概括成自动合并所有 worker 结果。

任务拆分建议围绕独立验收条件、依赖和资源所有权。结果冲突交给父 Agent/控制器根据实际 diff、基线和测试仲裁；当前没有通用的自动语义仲裁器。

当前默认限制包括每 session 最多 16 个活跃子 Agent、其中最多 8 个 worker，每脚本启动总量最多 64 个。[Launcher](/Users/kq/Workspace/openseek/agent_subagent/launcher.mbt:12)、[结果交接](/Users/kq/Workspace/openseek/agent_subagent/worktree.mbt:95)

**7、多个 Agent 并发改同一文件/资源，怎么防冲突？锁粒度怎么定？**

当前有三类协调：

- **文件工具**：共享 `FileStateMap`，完整操作、检查和回退在同一进程内串行。
- **会话日志**：`session.lock` 协调读写，并拒绝 stale snapshot。
- **worker**：worktree 模式预留 `allowed_paths`；目录模式拒绝活跃 worker 目录重叠。

文件操作等待人工审批时会释放 gate，回来后要求重新校验文件状态，避免人工等待长期阻塞其他工作。

但有明确限制：**仓库 mutex 是进程内锁；原子写 registry 不是跨进程锁。** 两个引擎操作同一仓库仍可能竞争。日志锁也不能保护日志之外的工作区副作用。

建议按资源选粒度：单文件使用版本检查和短写锁；Git index、合并使用仓库锁；构建缓存和依赖安装按共享目录协调；远端资源使用版本条件更新。跨进程场景需要补充仓库级文件锁或租约。[文件 gate](/Users/kq/Workspace/openseek/agent_tool/serialization.mbt:2)、[仓库锁限制](/Users/kq/Workspace/openseek/agent_subtask/provision.mbt:2)

**8、执行中服务重启，checkpoint 存什么、放哪、怎么恢复？**

默认位置是：

```text
.openseek/sessions/<session-id>/
  openseek_session-<session-id>.jsonl
  session.lock
```

日志包含系统提示 header，以及有序的 User、Assistant、Tool、Runtime、Summary、Terminal 事件。重新加载后重放日志，恢复会话和模型上下文。

存储层已处理：

- 锁与 stale-snapshot 检查。
- 连续 sequence 校验。
- 崩溃遗留的末尾未完成记录。
- 原子替换、数据同步和适用平台上的目录同步。

但这里的 checkpoint 主要恢复**对话和任务认知**，不是恢复进程指令指针。内存中的待执行队列、审批等待、后台进程和连接不能仅靠 session 日志原样恢复。

未配对的 tool calls 在模型消息投影时补成错误结果，避免形成非法对话，不会自动重放全部工具。worker registry 另有遗留 worktree 捕获和交接恢复。

对“副作用完成、结果尚未写日志就崩溃”的窗口，仍需工具端幂等键或执行状态查询。[存储实现](/Users/kq/Workspace/openseek/agent_session/store/store.mbt:832)、[worker 恢复](/Users/kq/Workspace/openseek/agent_subagent/worktree.mbt:158)

**9、human-in-the-loop 下，用户驳回或超时，怎么续跑和兜底？**

当前审批策略是：

| 策略 | 行为 |
|---|---|
| `never` | 默认；拒绝需要升级权限的动作 |
| `ask` | 发出问题，等待控制器回答 |
| `always` | 自动允许一次，并输出审批事件 |
| `review` | reviewer 子 Agent 判断；无法决定时交给控制器或拒绝 |

**人工 `ask` 当前没有超时。** 等到用户回答、turn 取消或命令通道关闭；通道关闭会撤销等待，防止引擎永久挂住。

自动 reviewer 有 5 分钟 deadline。无报告、超时或启动失败视为 escalate：`serve` 可以转人工；无交互的 `run` 拒绝。委派子进程固定不能继续申请升级权限。

拒绝、撤销和无审批能力是不同结果，工具会给模型不同反馈。拒绝不能通过改写脚本自动重试绕过。

审批 desk 在内存中；进程重启后不能把旧问题继续当成有效授权。恢复时需要重新建立审批。[默认策略](/Users/kq/Workspace/openseek/internal/openseek/options/approval.mbt:2)、[人工等待](/Users/kq/Workspace/openseek/internal/openseek/execution/approval.mbt:77)

**10、工具输出过大怎么截断？失败怎么重试、熔断和保证幂等？**

已有多层输出限制：

- 进程输出默认约 12K 字符内联，超出后可落盘并返回引用。
- 输出 sink 默认硬上限为 2000 万字符，超出部分丢弃。
- Agent 对单条记录的文本结果设 60,000 UTF-16 单元上限。
- MCP 单次调用默认 120 秒，结果也有大小限制。

模型请求当前默认最多 5 次尝试，指数退避从 500ms 开始，单次等待最高 60 秒；429、5xx、传输故障可重试，普通参数和认证错误不应重试。

流式请求默认在收到响应后避免重放；Agent 显式提供 `on_retry`，允许特定中断重新请求，并通知前端丢弃失败尝试的预览。此时尚未执行该响应的工具，但可能产生额外模型费用。

**没有统一工具熔断器或通用副作用幂等协议。** MCP 超时可能发生在服务端已经执行之后，不能无条件重试。需要为写操作补充逻辑操作 ID、结果查询和未知状态处理。[输出 sink](/Users/kq/Workspace/openseek/agent_tool/shell_exec/sink.mbt:2)、[请求重试](/Users/kq/Workspace/openseek/deepseek/client/client.mbt:224)

**11、Function Calling 和 MCP 各解决什么？工具太多怎么检索、按需加载？**

Function Calling 表达模型选择的函数和参数；MCP 负责外部工具的发现、协议协商、调用和传输。

OpenSeek 当前的组合是：

```text
模型调用 mbtx
→ 脚本 @mcp.search(...)
→ 获得候选工具及 schema
→ 脚本 @mcp.call(server, tool, arguments)
→ 筛选结果并回灌模型
```

**MCP 工具不全部进入模型 function list。** 脚本下载并缓存目录，在本地使用 BM25 排序和分页，默认每页 8 个。

这降低模型请求随工具数量增长的成本，但连接、目录下载和本地检索仍有开销。schema 也不等于授权：当前 MCP 主要验证服务和工具是否可用，完整参数语义仍需服务端执行校验。

当前支持 stdio、Streamable HTTP，优先使用 `2026-07-28` 发现协议并保留旧协议兼容路径。[MCP 实现](/Users/kq/Workspace/openseek/mcp/README.md:1)、[目录检索](/Users/kq/Workspace/openseek/tools_sdk/mcp/mcp.mbt:1)

**12、RAG 在什么时机检索？query rewrite、rerank 怎么接？**

**当前核心 Agent 没有通用的文档向量 RAG pipeline，也没有默认 query rewrite/rerank。**

现有上下文来源主要是会话投影、摘要、工作区指令、skills，以及 Agent 主动调用文件工作流或 MCP 获得的材料。MCP 的 BM25 是工具目录检索，不等于文档知识检索。

要加入 RAG，可以通过 MCP 或宿主工具接入：

`识别事实缺口 → 保留约束的 query 改写 → 权限过滤召回 → 去重/rerank → 引用片段 → 回灌`

触发点可以是任务开始、出现未知符号、验证失败需要查资料，以及压缩后缺失证据。已有有效材料无需每轮重查。代码查询要保留符号、路径和版本，不能为了“自然语言化”丢掉精确标识。

**13、Prompt 注入、危险调用和敏感数据怎么处理？**

当前有一些具体控制：

- 工具参数解码、写入范围和文件状态检查。
- `mbtx` guest policy 与进程启动列表。
- 一次性审批，委派子 Agent 不继承可升级权限。
- summarizer 将旧对话作为数据处理。
- MCP 配置展示时处理 URL 凭证，终端输出做控制字符清理。

但这些不能组合成“已解决 Prompt 注入”。尤其源码明确指出：**进程 allowlist 是命令范围约束，不是完整安全边界**；允许的程序仍能执行代码、触发 hooks 或修改资源。

当前也没有看到覆盖模型输入、工具输出、session 日志和产物的统一敏感数据脱敏层。终端安全清理不等于秘密脱敏。

建议补充来源信任分层、宿主端操作授权、网络出口约束和凭证代理；敏感信息在进入模型、日志和产物前分别处理。[执行边界说明](/Users/kq/Workspace/openseek/agent_tool/mbtx/wasm_policy.mbt:2)

**14、线上怎么评测成功率、工具选错率、参数错误率、成本、耗时？**

当前已经有 session analyzer、确定性工具/file-edit harness，以及在隔离工作区运行真实 Agent 的 prompt-task eval。

需要注意：**通用 analyzer 将 `Finished` 视为 success，这是运行终止成功，不能直接作为任务正确率。** prompt-task harness 另加编译、测试和行为探针，才形成更可靠的任务判断。

线上建议记录：

- 任务成功：通过独立验收条件。
- 工具选错：通过标注、复核或明确规则判断。
- 参数错误：解码和参数校验失败单独分类。
- 成本：实际 token、缓存、工具费用及子 Agent 费用。
- 耗时：排队、模型、工具、编译、验证、人工等待分别计时。

当前日志有 usage 和事件时间，协议也输出 usage；但不能据此声称已有完整线上指标平台。子进程取消且没有结果时，成本可能未知；失败请求、压缩调用的计费覆盖也应单独核实。

`mbtx` 的编译成本是主要交互开销之一，当前有 session 级构建缓存，应在性能评测中区分冷启动与复用。[Analyzer](/Users/kq/Workspace/openseek/eval/session_analyzer/analyzer.mbt:39)、[任务评测](/Users/kq/Workspace/openseek/eval/prompt_task/README.md:1)

**15、badcase 怎么归因到模型、prompt、检索、工具？怎么回流回归集？**

当前日志和 eval 框架能支撑复盘，但没有通用自动根因分类器。

归因应找到最早偏离正确行为的位置：

- 正确事实已在上下文却错误决策：检查模型或 prompt。
- 原始事实存在，摘要丢失：检查压缩。
- MCP/文件检索未提供必要材料：检查检索。
- 参数正确而工具错误：检查工具、平台或环境。
- 重复执行、审批错配、恢复不完整：检查 Harness。

通过固定工作区、模型参数和工具结果，分别替换某一层做对照，避免只看最终失败就归因给模型。

回归集应分两类：参数、文件、协议和恢复故障做确定性测试；规划和完成判断做隔离工作区的多次模型试验，使用独立验收器。已有 prompt-task harness 支持保存原始日志、session、prompt 标签，并独立重新生成报告。

**16、流式工具事件怎么推前端？断线重连怎么恢复？**

当前有两条通道：

- **实时事件**：引擎 JSONL → Desktop host → WebSocket/桥接前端。
- **持久化事件**：session commit → `session.event`，携带日志 sequence。

实时协议包含 assistant delta、工具结果、参数解码错误、审批、子任务和终止事件。完整工具调用记录来自持久化 Assistant 事件，结果通过 `tool_call_id` 关联。stdout 由单一 drain 顺序写出，避免并发写坏 JSONL。

**当前重连方案是 resync，不是从连接 cursor 重放事件。**

重连后读取 `session.list`、`agent.runs`、当前 `session.load`；用 snapshot watermark 合并加载期间到来的持久化事件。未提交的流式 delta 丢弃，由已持久化内容重建。

还有两个重要边界：

- 慢客户端队列溢出会被断开，再走 resync。
- host 不按 `submission_id` 去重重发 prompt。发送结果未知时，应先读取日志确认，不能直接重发。

`agent.runs` 的 settlement 只保留在 host 进程生命周期内；host 重启后以持久化 session 判断消息是否落盘。当前协议也没有逐事件时钟，需要时间依据时读取 durable record。[重连契约](/Users/kq/Workspace/openseek/docs/remote-protocol.md:236)、[事件输出](/Users/kq/Workspace/openseek/protocol/emit/README.mbt.md:44)


