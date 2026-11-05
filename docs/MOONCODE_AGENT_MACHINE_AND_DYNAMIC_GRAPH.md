# MoonCode 执行原语与动态计算图设计

记录日期：2026-11-05，Asia/Shanghai。

用户给出清楚的目标，主 Agent 自顶向下拆解到可以执行就动手，根据结果继续理解、实施、验证和修复，最终交付可用结果。运行时提供明确的执行原语；计算图随执行形成，帮助理解进展与依赖。用户无需预先设计节点连线，也无需逐步确认计划。

本记录综合从十六问框架反思、工作方法收敛、Agent 机原语、跨框架比较，到数据模型和动态计算图的讨论。2026-11-04 的[原始讨论归档](mooncode-discussion-2026-11-04/README.md)保持原样；其中的[精简方案](mooncode-discussion-2026-11-04/CURRENT_PLAN.md)保留其历史身份。当前运行行为以 [MoonCode Workspace](MOONCODE.md) 和 MoonClaw 的[执行边界](../../moonclaw/docs/executable_book_runtime_boundary.md)为准。

## 讨论演进与采用的结论

| 讨论问题 | 采用的结论 |
| --- | --- |
| 原来的十六个问题是否全面、联系、发展地覆盖了产品？ | 它们是有用的工程检查表，覆盖 loop、工具、记忆、协作、恢复、权限和观测；不能单独组织用户价值、交付有效性与持续反馈。 |
| 是否应该先建立更高层的持续交付理论？ | 过高的概念层容易拉长落地距离。面对清楚的功能需求，先建立能直接指导行动的工作方法。 |
| 什么是内置工作方法？ | 明确可观察结果，定位现有实现，拆到知道改什么和怎样验证就行动。拆解与执行交替，不预先穷举整棵任务树。 |
| 怎样借鉴操作系统和编译器？ | 明确执行、上下文、文件、IO、同步、恢复的身份、操作、所有权、失败语义及组合规则。类比用来检查契约，不要求实现一套新 OS。 |
| 当前抽象是否已经完整？ | 概念映射和共享执行路径已形成；内部任务、调用、结果和 continuation 的契约仍有分散和字符串组合表达。命名清楚不能代替执行语义清楚。 |
| 其他框架提供什么启发？ | OpenSeek 的类型化工具边界、DSH 的服务与结果契约、Pi 的最小循环，以及实验性 pi-durable 的持久执行语义，各有可取之处。 |
| 反过来如何评价框架特色？ | 从实际机制映射到 OS、编译器、数据库和数据计算概念，判断它保证什么、没有保证什么。 |
| 为什么补充数据模型和大数据计算？ | 身份、引用、版本、派生视图、血缘、依赖、增量计算和重放，不能只用“内存”概括。 |
| 计算图由谁设计？ | 用户表达目标；AI 逐步生成行动；系统按执行事实和已知依赖形成图。完整图不是执行前置条件。 |
| 是解释执行还是编译执行？ | 完整任务采用增量解释执行、运行时构图；已明确的局部工具程序仍可编译执行。动态构图与是否编译是两个不同维度。 |

## 产品目标与约束

目标是更快获得完整满足本次请求的可用结果，同时降低用户的解释、决策、接管和返工负担。减少代码与测试只用于收敛实现，不能单独证明交付质量提升。

默认同一任务一个主 Agent，贯穿理解、实施、验证、修复与交付。独立工具可以并发，独立任务可以分别执行；这不要求常驻 Router、Reviewer、Watchdog 或默认多 Agent 团队。

真实的权限、信息或重大决策缺口才需要用户参与。常规实现选择、参数纠错、检查失败和可恢复中断，应由同一 Agent 在授权内继续处理。用户明确要求的人审条件仍然有效。

继续复用 task、loop、工具结果、journal、continuation 和 `finish`。不新增平行 Goal、Mission、Operation 数据库、通用检查器注册系统或第二份完成状态。计划是可调整的工作记录，不承担完成证明。

## 从系统原语检查设计

好的原语至少回答六个问题：它的身份是什么，拥有什么状态，接受哪些操作，操作有什么前后条件，失败或中断意味着什么，与其他原语如何组合。支持范围可以小，但范围内的语义应闭合。

### 当前八项职责审计

审计基线：MoonClaw `047749b3`、MoonDesk `248e6879`，以及本轮下述重构后的实现。结论是**基本功能已实现，职责可以闭合，但尚未成为具有完整类型契约和分布式执行语义的 Agent OS**。八项是分析维度，彼此有依赖，不是八层架构；一个 session 也不是一个 OS process。

| 维度 | 功能与所有者 | 接口、输入 → 输出 | 运行逻辑 | 实现与边界 |
| --- | --- | --- | --- | --- |
| Process / Thread | 被 claim 的 prompt/package command 是逻辑交付任务；service 拥有主执行协程，工具子协程属于调用它的 TaskGroup。Session 保存队列、会话与 Book 绑定。 | `/turns`、`start_runtime_service`、`runtime_loop_execute`、`runtime_turn_execute`；命令/修订 → 结果、可恢复位置或终态 receipt。 | service 取得 session 所有权，loop 取队列，turn 解释当前 command；独立只读调用 fork/join，取消沿已有 task group 传播。 | **已实现限定范围**。不是每个 turn 一个线程，也没有独立地址空间或持久调用栈。普通命令默认一个主 Agent；显式 worker 不构成默认常驻团队。 |
| Memory | Context compiler 拥有“本轮模型工作集”，journal 拥有原始执行记录，文件拥有文件内容。 | `compile_context` / `Pruner::compile_messages`；任务、消息、schema、窗口 → messages + metrics；`read_result(evidence_ref, end_ref?, lines?)` → 保留的原始结果或范围目录。 | 按压力保留指令/任务与最新完整交换，压缩旧消息，保留精确/首尾来源句柄，需要时补读。 | **已实现限定范围**。摘要有损；未保留的 stdout、旧文件版本不能恢复。补读扫描 session journal；不是新 memory store、自动 RAG 或新的模型轮次。 |
| Filesystem | Workspace 拥有选定 MoonBook 的真实路径、文件内容与本地条件写入。 | `workspace_path(book_root,path)` → canonical/relative identity；`workspace_replace(root,absolute,expected,content)` → 成功或 stale/error；read/edit/write/patch 为工具入口。 | 解析真实资源，在同一资源锁内比较旧内容，用同目录临时文件及 rename 替换；patch 复用既有回滚。 | **原生文件路径已实现**。同一资源的协作式互斥和过期检查，不是完整 VFS、MVCC、多文件事务或不可变版本库。shell、外部编辑器不参与此文件锁。 |
| I/O | provider transport 负责模型协议；catalog/executor 负责工具 ABI；grant/executor 边界负责实际执行授权。 | 模型消息 → provider response；`tool + arguments` → canonical result `{ok,is_error,message,output,metadata}` → execution/event → journal/model/UI。 | schema 校验、绑定既有执行条件、运行、返回规范结果；工具错误交回同一 Agent。用户输入、steering、审批和取消沿命令路径进入。 | **主线已实现**。Function Calling 是调用形状，MCP 是接入协议；都不自动提供权限、幂等或结果正确性。控制事件与已执行效果有区别；工具成功不等于交付完成。 |
| Synchronization | execution lease 保护 session 执行者；lifecycle gate 保护归档/恢复；journal lock 保护追加/claim 顺序；file lock 保护真实文件；batch join 保护工具生命周期。 | `open_session_execution_lease`、lifecycle/session lock、`workspace_file_lock`、`TaskGroup`；资源/操作 → 所有权、等待、busy 或有序结果。 | 外部入口持有 lifecycle shared gate + execution exclusive lease，内部 loop/turn 借用，不重入获取。不同 session 可运行；独立读并发，普通修改按调用顺序执行。 | **局部同步已实现**。这些锁不能合并成全 Book 大锁；本地提交序号不是跨服务时钟。进程工具与原生文件工具仍不具有统一写事务。 |
| Fault tolerance | Journal + continuation 保存执行位置和已完成结果；recovery 决定复用、重读或核对未知效果。 | append/checkpoint → `MoonCodeResumePoint`；`operation_recovery(operation_id,call)` → 既有 execution、允许安全重读或 outcome_unknown。 | 操作前 intent、操作后 result；重进执行时按调用身份复用；只读可重试，未提交外部效果先核对实际状态。 | **位置/结果恢复已实现**。不恢复任意 `.mbtx` 程序栈，不提供任意外部效果 exactly-once。当前恢复由既有 service 启动、任务控制或 `/turns` 重试触发；没有发现 daemon 启动时主动遍历所有 Book/session 唤醒任务的实现。 |
| Data model | Command/task revision、operation、tool-call、result event、resource version 分别拥有身份；canonical conversation/work graph 是派生视图。 | journal records/decimal sequence；continuation result refs + digest；`event_id` 是 work step 的来源，graph 从它导出 evidence_ref；显式检查携带 task_revision 与输入 fingerprint。 | 追加事实 → 恢复模型 → 本轮工作集/界面视图；日志顺序、调用身份和内容版本分别表达，不能互相代替。 | **关系已有，类型仍局部**。ResumePoint、sequence、completion verdict 已有类型；大量内部 command/result 仍为 Json，尚无统一强类型 IR、完整外键/血缘或自动失效重算。 |
| Compute engine | 模型是增量解释器；turn 执行下一批行动，policy 声明已知效果；程序片段使用现有 shell/项目语言；graph 只展示。 | task + context → model round → tool batch → results → next round/finish；`parallel_read_batch_allowed` / `execute_parallel_reads`；`work.graph` → 现有卡片和文件导航。 | 整体边观察边展开；已知连续计算可以脚本完成；只读调用依据效果声明并发，结果按源顺序 join；finish 使用当前任务与必要事实。 | **解释执行与最小图已实现**。没有预编译的完整 DAG、跨任务公共子表达式缓存、通用依赖调度器或工具调用 SDK。恢复旧结果与跨运行缓存是两种语义。 |

接口全名、资源归属与失败语义见运行时自包含的[八项契约](../../moonclaw/docs/executable_book_runtime_boundary.md#agent-machine)。核心调用链如下；箭头表示数据流或调用关系，不表示新增分层：

```text
用户 command/revision → session queue → service/loop（执行所有权）
    → task + journal results → Context compiler → model round
    → tool calls → declared effects / batch → executor → filesystem / external I/O
    → result + operation identity → journal → next round / finish
                                  ├→ continuation recovery
                                  └→ canonical work / graph / watch → UI
```

### 身份不能混用

| 身份 | 用途 | 不等于 |
| --- | --- | --- |
| session_id | Book 绑定、会话、队列、日志及执行 lease 的范围。 | 当前交付任务或 OS process。 |
| command_id + task_revision | 本次交付请求与当前约束；控制命令引用所属任务。 | 一次模型请求、一次工具调用。 |
| operation_id | `command_id:step_index:tool_index`，恢复同一执行位置；step/tool index 为零基。 | 相同参数的全局计算缓存 key。 |
| tool_call_id | provider call/result 协议配对。原生开始/完成优先通过 operation_id 关联，避免上游跨轮重复 ID 合并执行。 | 跨轮执行主键、文件版本或权限。 |
| event_id / evidence_ref | 同一条已保留执行事实的来源/取回句柄。图从 step.event_id 派生引用。 | 原文件永远不变、结果仍适用于当前输入。 |
| canonical path + fingerprint | 资源位置及已观察内容；显式检查的适用性依据。 | inode 级隔离、完整依赖血缘。 |
| journal sequence | session 内已提交日志位置及 watch 游标。 | 墙上时钟、执行次数或全局因果序。 |

### 本轮实际收敛

- [x] **Memory**：语义引用检查确认 `calculate_pruning` 只有测试调用、`prune_messages` 无生产调用；删除两套旧算法、PruneResult、四个直接依赖及 11 个专属测试，只保留真实使用的 compile_messages。删除旧代码中的 O(n²) 路径不等于证明正常热路径提速。
- [x] **Process / synchronization**：删除 loop 的 `runtime_gates_held` 布尔开关及其有效路径中不可达的重新加锁分支；改成明确的外部获取所有权、内部借用接口。保留 service 向异步任务转交 lease 的现有机制，不把不同锁合并。
- [x] **Compute / I/O**：删除独立于 policy 的并行工具名名单；资源类调用仍用 canonical path/cwd，其他已声明只读调用用精确参数身份。`read_result` 与 `mcp_list_tools` 现在能进入既有只读批次。既有回归同时验证两个补读并发后顺序、原始结果与无效果重跑。
- [x] **Data model**：原生开始/结果通过已有 operation_id 关联，修复上游跨轮复用 tool-call ID 时 work step 被合并的问题；删除 work step 中没人消费的 step_id、turn_id 与重复 evidence_ref，保留 item_id、command_id、event_id；graph 由 event_id 导出结果引用。顶层 turn_id、消息 turn_id 和图中的结果引用仍有独立用途，保留。
- [x] **Fault tolerance / I/O**：unknown-outcome 的恢复结果复用同一 execution constructor，删除另一份手写结果包装；错误语义与“不自动重放外部效果”保持。
- [x] **Filesystem**：核对现有身份、CAS、锁与条件回滚；本轮不另写一个资源解析器、锁服务或版本存储。保留已知边界。

八项审计时的验证：MoonClaw native 全量 **1853/1853**，身份/会话定向回归 **21/21**，初次 memory/并行/lease/队列/恢复检查 **43/43**；MoonDesk core JS **65/65**、UI **839/839**，真实 producer → consumer probe 通过。`moon info` / `moon fmt` 与空白检查通过；接口变化仅删除内部 pruner 的废弃 API，canonical work step 别名删除及 operation 身份收敛已记录。MoonBit production 净删 **157 行**、测试净删 **282 行**（合计 439 行，不计接口/依赖/文档变化，不把搬移算删除）。历史归档 11 个文件哈希不变。没有 UI 布局/安装包改动，也未做真实 provider、崩溃断电或在线性能对照；不能从删旧代码推断质量和耗时已改善。

仍待明确/实现的产品能力只有具体问题：是否要求服务重启后无需客户端触发就恢复全部待办；是否需要把进程工具纳入同一资源写入机制；哪些实际任务需要更完整的依赖追踪。它们不是为了让类比“完整”就必须先造的子系统。内部 Json 契约和 daemon 编排仍可继续按真实重复收敛；本轮没有引入通用 IR、八个包、额外模型请求或人工步骤。


### Data Model 与 Compute Engine 收敛记录

本轮基线：MoonClaw `9f4e7222`、MoonDesk `9582617b`。目标是减少同一事实的重复表示和同一决策的重复实现，不扩建类型框架或增加运行前置条件。

| 位置 | 收敛后的契约 | 删除内容 |
| --- | --- | --- |
| 已完成调用 | journal event 保存一次 execution header 和规范 tool_result；恢复时共用 `mooncode_tool_execution_from_event`。 | operation recovery 与 continuation 各自手写的结果重建。 |
| checkpoint 历史引用 | `{event_id,event_digest}` 指向上述事件；没有可引用事件的合成结果使用 `{inline_execution}`。由实际保存的数据区分两种表示。 | 每条引用里的重复 execution header、journaled_result 布尔标记、按事件展示名称决定是否引用的规则。patch/finish 的规范事件也可以引用。 |
| 恢复后的模型请求 | 直接匹配既有 MoonCodeResumePoint：ResumeTools 复用当前计划；初始/初始 transport 重试构造 initial；其他恢复共用一次 follow-up，携带各自 steering/guidance。 | 三段相同 follow-up 参数组装、三个镜像恢复布尔值及 continuation_active 别名。恢复状态集合不变。 |
| finish receipt 消费 | worker 与 conversation 都从真实 producer 保留的 execution.result 读取规范结果。 | worker 的旧扁平结果兼容探测；conversation 对扁平字段的错误假设。旧测试数据改为真实 producer 的嵌套结果。 |
| 检查分类 | 现有显式检查和当前证据判断照常工作；普通 patch 使用普通 finish 规则。 | 已没有生产者的 patch-verification metadata 分支和一项并未证明检查发生的专属测试。不增加“编辑后必须测试”等要求。 |

- [x] 同一 execution 的重建只有一个入口；规范结果、引用和执行控制分别归属。
- [x] 减少 checkpoint 复制，保留现有来源 digest、顺序检查与未知效果恢复语义；没有新增校验服务或授权步骤。
- [x] 复用现有枚举表达恢复位置，不增加状态、状态机、调度层或额外模型请求。
- [x] 沿现有 compaction、restart、transport、空响应、steering、worker 和 canonical conversation 回归验证；临时数据量测量不加入产品测试框架。

临时对照使用相同的 100 个规范 write 结果、每次参数 33,020 个 ASCII 源码字符，对比本轮前后实际的历史区 serializer：**3,561,392 → 12,692 个 ASCII 字符**。这是 checkpoint 历史区的序列化大小，不含原始结果事件和当前模型 transcript，不是通用压缩比例、模型 tokens 或端到端速度对照。已有结果摘要哈希和历史引用遍历仍有成本，没有宣称常数时间 checkpoint。永久回归补充大 shell 参数和 patch 结果 roundtrip；临时测量文件已移除。

验证：MoonClaw native **1852/1852**；数据/receipt/worker 定向 **75/75**；恢复和 steering 定向 **50/50**（移除旧测试前）；最新大参数/patch 引用回归 **4/4**；MoonDesk core JS **65/65**、UI **839/839**，真实 producer → consumer probe 通过。`moon info` / `moon fmt`、接口与空白检查通过，`.mbti` 无变化。production `.mbt` **净删 68 行**，测试 `.mbt` **净增 21 行**，合计净删 47 行；删除一个旧测试，其余扩展既有测试，不新增常驻测量或测试阶段。63 个本地链接有效，历史归档 11 个文件哈希不变。未更新安装包，未做真实 provider 质量/成本或端到端延迟对照。

主要入口：[引用与 hydration](../../moonclaw/cmd/daemon/mooncode_runtime_continuation.mbt)、[规范 execution 重建](../../moonclaw/cmd/daemon/mooncode_tool_execution.mbt)、[主解释循环](../../moonclaw/cmd/daemon/mooncode_runtime_turn.mbt)。内部 command/plan 仍保留 Json，完整类型 IR、依赖计算引擎和全局缓存仍未引入。

四个分析视角处理不同问题，不构成必须部署的四层：

| 视角 | 核心问题 |
| --- | --- |
| 操作系统 | 谁在运行，拥有什么资源和权限，怎样等待、取消与恢复？ |
| 编译器与解释器 | 输入怎样成为可检查、可执行的下一段操作，错误在哪里返回？ |
| 数据库与数据模型 | 什么数据由谁拥有，身份与版本如何关联，哪些状态可以派生重建？ |
| 数据计算 | 什么可以并行、复用、增量执行或重放，怎样控制计算与数据规模？ |

## 如何编程这台 Agent 机

当前程序输入是用户任务、项目规范和适用技能；工具提供可执行操作。检索内容和工具输出属于观察，不能取得新的指令优先级或权限。

```text
用户任务与当前修订 + 项目规范 + 技能
                    ↓
              当前任务与上下文
                    ↓
          模型提出下一批结构化工具调用
                    ↓
         参数、权限、已知效果与执行条件检查
                    ↓
           执行 → 记录结果 → 构造下一轮
                    ↓
             验证、修复或 finish
```

自然语言目标不必一次编译成完整形式规格或固定工具序列。模型负责解释与选择下一步，运行时负责确定地执行已知契约。参数 schema 通过，只能说明参数形状符合要求，不能证明权限有效或用户问题已解决。

工具的外部效果、并发资格、重试资格和循环控制应分别说明。读取技能可能需要一个“先消费指令再行动”的屏障，但它并没有因此成为文件修改。不要把这些不同含义都交给一个宽泛的 mutation 分类，也不要让不同调用方各自重写工具名单。

局部程序可以使用已有的 mbtx、PTC 或 CodeMode 思想：把一段已明确的工具组合写成代码，经过相应语言运行环境和工具边界执行。SDK 类型声明、代码运行限制、工具授权与子进程隔离分别成立；一种保证不能代替另一种。

## 数据模型与事实归属

先明确逻辑关系，再决定物理存储。下面描述既有记录应表达的语义，不要求新建这些表、增加数据库或引入一套新实体层。

| 数据 | 身份与必要关系 |
| --- | --- |
| 任务 | 任务身份与修订，目标、约束、输出、必要检查，及有序用户修正。 |
| 调用 | 调用身份，所属执行与任务，工具和参数，授权范围，已知输入引用。 |
| 结果 | 对应调用，成功、明确失败或未执行、结果未知等执行事实，以及输出或引用。 |
| 文件或产物 | 所在位置、可识别版本，以及产生或观察它的调用。 |
| 检查证据 | 检查调用、任务修订、检查范围、相关输入版本和实际结果。 |
| Continuation | 所属执行、下一位置、等待或中断原因、已完成结果引用及必要恢复绑定。 |

Session、task、command、call、result 的身份不能互相代用。结果状态也不能代替执行控制：一次失败可以让 Agent 继续修复，一次成功的调用也可能只是等待前的观察。

```text
原始输入和执行记录
       ↓
派生的任务状态、会话、进度和索引
       ↓
按任务与预算选取的本轮模型上下文
```

journal 拥有系统已提交的执行记录。真实文件与外部服务分别拥有对应资源状态；记录中的观察可能已经过时。模型推断与已观察事实也应有区别。

UI 会话和图是派生视图，可按已有事实重建。摘要是有损派生内容，不能被当成原始记录；压缩模型上下文不等于删除历史，也不等于垃圾回收。RAG 是查询和取数路径，向量索引不是事实来源。

检查与版本的关系可以写成：

```text
任务 r3 → 读取文件 v1 → 修改为 v2 → 检查针对 r3、v2 成功 → finish
```

文件变为 v3 或用户修改目标后，旧检查仍然是历史事实，其适用性需要重新判断。当前 MoonCode 的输入指纹和任务修订提供部分关联，不代表完整依赖图、MVCC 或依赖完备的增量构建。

## 从特色反向映射成熟概念

| 框架机制 | 最接近的概念 | 评价与适用条件 |
| --- | --- | --- |
| Agent、子任务、wait 和 cancel | 进程生命周期、结构化并发 | 明确归属与结束条件；把并行工具全部变成 Agent 会增加推理和协调成本。 |
| steering、follow-up、后台通知 | 邮箱、可靠队列、异步事件 | 区分可靠用户输入和允许丢失的展示通知；消息边界与持久性要明确。 |
| 工具 schema、executor、结果与 control | 函数签名、调用约定、IR 校验 | 调用、数据结果和循环控制分开；合法参数不是业务正确性的证明。 |
| 工具效果和并发声明 | 副作用分析、执行屏障 | 由实际声明和资源约束安排执行，不能仅相信模型声称“独立”。 |
| DSH 服务 provider、MCP、扩展 | 驱动接口、VFS、RPC、动态链接 | 提供可替换实现与能力接入；实际保证取决于 provider、授权和部署组合。 |
| mbtx、PTC、CodeMode | 嵌入式语言、编译或解释执行 | 减少已知工具组合的模型往返；不要求完整任务预先成图。 |
| plan、goal、工作方法 | 应用算法与策略 | 指导下一步，不应自动变成所有任务的强制内核流程。 |
| Session journal | 事件日志、事件溯源；写前 intent 有 WAL 思想 | 记录和恢复的边界明确；不能直接推导外部效果的事务保证。 |
| DSH projection、MoonDesk canonical conversation | 派生视图、物化视图、变更订阅 | 从已提交事实生成展示，保留对应日志位置，避免双重完成真相。 |
| Pi 会话树 | 持久版本历史、分支视图 | 会话分支不自动分叉真实文件。 |
| context projection、RAG、摘要 | 查询、索引、排序、有损投影 | 来源、预算、覆盖范围与失效语义要清楚；摘要不能替代缺失的关键事实。 |
| 文件指纹、检查版本、结果引用 | 乐观失效检查、数据血缘 | 有已知依赖才可能精准复用；指纹不是跨进程事务隔离。 |
| pi-durable Document 与 Commit | 事务与原子状态更新 | 内部状态可以一起提交；外部文件、HTTP 与发布操作仍有独立副作用边界。 |
| 并行读、工具批次、子任务汇总 | fan-out、join、算子调度 | 并行已明确独立的片段，按依赖等待，不要求引入完整计算图调度平台。 |
| 结果复用与重复调用去重 | 物化中间结果、缓存、公共子表达式消除 | 同一次执行按身份恢复；跨次复用还要检查输入、环境和权限，不能只比较参数文本。 |
| checkpoint 与程序重放 | 有状态计算快照、恢复位置、重放日志 | 分清恢复状态与重新执行效果；模型调用也有成本和非确定性，优先复用已记录结果。 |
| 输出 spill、按需读取、并发上限 | 分块、外部存储、背压和资源调度 | 模型只取必要内容；截断与摘要不能冒充完整输出。 |
| badcase、评测与回放 | 离线数据处理、可重复实验、数据血缘 | 保留输入、配置、版本和结果；历史回放通过不能直接验收当前交付物。 |

## 框架比较与采纳边界

以下为本地源码基线，非上游最新发布或部署状态：MoonClaw `58160880`，MoonDesk `2e232e83`，OpenSeek `dbe35ecc`，DSH `8bd073392e`，Pi `80f7a1149`。

| 框架 | 执行与数据模型 | 强项 | 边界与 MoonCode 的取舍 |
| --- | --- | --- | --- |
| OpenSeek | Session 事件投影为消息；turn 驱动；AgentToolCall 返回 Respond 或 Control。 | schema 与 executor 集中，结果和循环控制类型明确；session append 有锁、旧快照检查和数据同步。 | 日志恢复与缺失结果补齐不等于恢复原执行栈。文件来源部分只在内存；goal、plan、review 策略进入 loop。借工具契约，不搬回重复完成门槛。 |
| DSH | Session 为身份；AgentHandle 管生命周期；turn/step、持久 inbox、projection 与能力 provider 分工。 | 规范结果、模型内容和 UI 展示分离；输出 schema、并发屏障、取消收敛、append/flush 契约明确。 | 实际 profile 决定启用能力；base 的 Native executor 开启、PTC 默认关闭，read-before-write observation policy 默认关闭。借服务与结果契约，控制插件组合成本。 |
| Pi coding-agent 与 agent-core | Agent 循环、AgentMessage 转换边界、带 parentId 的会话树。 | 嵌入接口简洁；context transform 与协议转换分开；同文件修改有进程内队列。 | 默认继承启动进程权限；历史恢复不能直接获得任意工具的持久续跑。借最小循环、消息接口和局部同步。 |
| pi-durable | 实验性的 Conversation、Entry、Document、Task、Commit；generation 拥有 tool tasks。 | 执行前 intent、明确的安全重放、任务所有权、有序提交和发布；CodeMode 可借记录结果恢复。 | 与普通 coding-agent 是不同路径。内部事务不覆盖外部副作用；持久性依 backend 而定。借恢复语义收紧现有 continuation，不整体替换 runtime。 |
| MoonCode | 任务修订、command/claim、主循环、journal、continuation 和 finish。 | 单主 Agent 路径已收敛；已有结果引用、未知效果反馈和必要检查关联。 | 该基线内部契约仍有分散的 JSON、工具名单与状态组合；下方 checklist 记录后续工具语义收敛。不以通过单测替代真实交付效果。 |

DSH Super-agent 文章针对交互连续性、人的注意力、多信道和多任务并发。计算、状态与环境分离，以及明确归属的事件直送，有参考价值；常驻 Router/Worker 是其场景选择。文章及原型不等于当前 checkout 的默认产品能力，其耗时工具调度实验也不能证明真实编码质量提升。

同一任务默认一个主 Agent，不意味着所有用户请求必须排在同一个推理循环后面。需要共享上下文的范围、工作所有权和独立任务调度，应分别按实际需求定义。

### 按相同原语横向比较

本轮只读核对本地 OpenSeek `dbe35ecc`、DSH `8bd073392e`、Pi `80f7a1149`；不是线上能力或性能排名。Pi coding-agent 与实验性 pi-durable 分开评价。

| 原语 | OpenSeek | DSH | Pi coding-agent / pi-durable | MoonCode 的取舍 |
| --- | --- | --- | --- | --- |
| Process / Thread | Session/turn、job 与原生循环；store claim 是会话身份占用，不能直接当所有执行的线程锁。 | Session-backed Agent；scope/fiber 管理注册归属和生命周期，ScopeKey 本身不是进程隔离或互斥锁。 | coding-agent 的 Agent loop/abort；durable 的 Task 树提供持久所有权。 | 保留 session lease、command 执行与结构化子任务，不把会话等同进程，不搬入持久 Task 平台。 |
| Memory | SessionItem → chat projection，压缩/来源仍须区分。 | committed session facts → 领域 projection/context；各视图由所属服务负责。 | transformContext → convertToLlm；会话树控制当前上下文分支，摘要仍有损。 | 借清楚的转换边界；只保留一个正常 compiler，按引用补读原始结果。 |
| Filesystem | 工具负责文件访问；owns_file_access 是声明，不自动带来 OS 级隔离。 | FsTarget 的 opaque targetKey 与 displayPath 分开，FsVersion/条件写入区分位置与新鲜度。 | coding-agent 按 realpath 的文件修改 Promise 队列，限本进程；durable 不因此把外部文件纳入数据库事务。 | 已有真实路径/条件替换，不为仿 VFS 增接口；借 target/version 的分工，保留外部进程写入缺口。 |
| I/O | AgentToolDefinition 邻接 schema/executor，Respond/Control 区分输出和循环控制；program_callable 为程序接入声明。 | canonical JSON value/schema 与模型/界面 render 分离，ToolRunContext 承载取消和执行身份。 | AgentTool/schema、事件流与模型转换边界；durable 为嵌套工具保留各自 intent/replay。 | 复用已有 catalog、规范结果与 grant 执行边界，删除恢复路径的独立包装，不新建注册框架。 |
| Synchronization | SessionStore 的 session.lock、快照/fingerprint 校验保证其存储范围。 | 批次 exclusive barrier 与 parallel pool，已提交事件推动投影；能力仍取决于 profile/provider。 | 默认并行模式可声明 sequential；本地文件队列只保护参与者；durable commit 原子更新内部文档。 | 锁按真实资源划分；并发资格统一读 policy，移除第二份工具名单。没有全 Book 互斥或分布式锁。 |
| Fault tolerance | 日志能重建历史；不等于恢复任意脚本栈或外部效果。 | 持久 Session/repair/projection 契约清楚，实际恢复还依挂载的组件与环境。 | coding-agent 会话历史不是 durable Task；durable 先 commit intent，按 safe/unsafe replay，内部事务不覆盖任意远端效果。 | 只借“复用已提交结果、未知效果按状态核对”；保留现有 continuation，不移植 durable runtime。 |
| Data model | 类型化 SessionItem、ToolCall/Result 与序列化较集中。 | 类型化 session sequence、Agent identity、规范结果、opaque resource identity 以及 asOfSeq 视图边界。 | session 的 id/parentId/leafId；durable 的 Entry/Document/Task/Commit 是另一套更强模型。 | 身份职责已有但 Json 仍多；先删无用别名、统一来源引用，不宣布已拥有完整外键或数据血缘。 |
| Compute engine | 增量循环 + `.mbtx`/可程序调用工具，可减少明确片段的模型往返。 | 动态工具批次、顺序屏障和可选 PTC/run_code；并非预先由用户画完整图。 | 动态 loop 与工具并发；durable 才具备 Task/嵌套调用的记录与恢复语义。 | 整体解释执行、局部普通程序、日志物化图；不让图调度，不为普通批量工作增加 Agent。 |

本轮补查入口：[OpenSeek Tool ABI](../../openseek/agent_tool/agent_tool.mbt)、[Session store](../../openseek/agent_session/store/store.mbt)、[DSH Agent 数据](../../dsh/packages/core/agent/src/types.ts)、[Scope 的路由语义](../../dsh/packages/core/scope/src/index.ts)、[资源身份/版本](../../dsh/packages/fs/fs/src/types.ts)、[批次调度](../../dsh/packages/core/tools/src/batch.ts)、[Pi 消息/调度接口](../../pia/packages/agent/src/types.ts)、[文件修改队列](../../pia/packages/coding-agent/src/core/tools/file-mutation-queue.ts)、[durable 的独立契约](../../pia/packages/durable/README.md)。

## 内置工作方法与认知负担

```text
明确本次可观察结果和必要检查
              ↓
定位现有实现与相关数据流
              ↓
拆到知道在哪里改什么、怎样验证
              ↓
立即行动；遇到具体障碍才继续拆解
              ↓
验证 → 修复 → 交付
```

这是一种内部工作习惯，不要求每项任务生成任务卡、完整计划、阶段报告或额外模型轮次。已经知道下一步时直接行动；只有影响行动的真实不确定性才驱动进一步调查。

用户要求“项目列表支持按名称搜索”时，先确定输入能筛选、清空能恢复等相关行为，再定位列表和数据来源。如果发现服务端分页，才处理搜索应如何进入查询接口的问题。完成从输入到结果的功能路径，再验证相关边界和项目要求的检查。不会为了满足修改次数而制造文件变更，也不会把“最小”解释为削减用户已要求的范围。

Agent 保持目标和约束可查，当前工作聚焦一个可执行子问题，复用已有结果。用户看到“搜索已接通，正在验证清空恢复”这样的结果进展；常规工具步骤可以按需展开。

## 任务驱动的动态计算图

用户输入是目标、约束和修正。AI 根据当前事实提出下一段行动；运行时检查并执行；界面根据记录形成图。无需用户拖线设计工作流，也不要求完整图在第一次工具调用前存在。

```text
任务与当前事实
      ↓
AI 提出下一批行动和候选依赖
      ↓
运行时检查已知条件并执行
      ↓
提交结果与引用 → 更新执行图的派生视图
      ↓
根据新事实继续解释，或验证后交付
```

动态图与解释执行相关，但不是“动态就不能编译”的语言分类。整体任务按观察增量展开；明确的局部程序仍可编译或在受控解释器中执行。当前没有必要发明完整 Agent DSL。

### 图中的对象与依赖

图可以按阅读粒度展示一次模型决策、工具调用、后台工作、产物版本、检查结果和任务完成事实。细粒度事件归并为可理解的工作节点，不必把每个 token 或每条日志画成节点。

| 依赖 | 可以依据什么建立 |
| --- | --- |
| 控制顺序 | 下一段行动依赖前一步判断；单纯时间相邻不能证明这种因果。 |
| 数据依赖 | 调用消费某个已记录结果或数据引用。 |
| 资源依赖 | 已知的同资源读写关系、执行屏障或授权要求。 |
| 验证依赖 | 检查对应的任务修订、输入版本与检查范围。 |
| 所有权依赖 | 已有主任务、子任务与结果汇总关系。 |

模型可以提出候选依赖，不能凭一句“独立”授予并发资格。运行时继续按工具与资源的已知约束执行；没有证据时不补造数据依赖，也不声称已识别所有外部依赖。

### 历史与计划分开表达

已经执行的节点、结果和有效引用属于历史事实。尚未执行的节点与边是当前计划，可以修改、撤销或替换。用户修正目标后，保留历史及修正记录，重新判断受影响的计划与证据，不把历史改写成“本来就按新目标执行”。

任务可以多次经历实现、验证、修复。按调用实例展开的历史依赖可以保持有序，不要求任务策略本身是一个静态 DAG。不能用节点完成比例或图是否“全绿”替代交付判断。

### 执行与绘图的关系

Agent 决定下一步，运行时提交事实，界面投影图。绘图本身不需要新增一次模型调用。执行不依赖图编辑器存在，也不依赖用户审核图。

继续使用现有 journal、调用身份、结果引用和版本关联。已知依赖是调用与执行记录的组成部分；展示图可重建、可缓存，不另建一份图数据库作为执行或完成 authority。所需的调度约束在执行边界检查，不能等 UI 画完图后才生效。

journal 不承诺完整依赖图。当前已实现最小动态图：模型批次 → 调用 → 文件，以及明确的结果回取与检查输入引用；不按时间先后推断数据依赖，也不提供完整失效重算。

用户通过图查看进展、检查产物、解释失败、跳转来源，并可修改目标或停止任务。依赖布局是系统的工作，不是用户必填的编程界面。

## 同步与故障恢复

即使只有一个 Agent，模型服务、远程工具、UI 和存储之间也存在延迟与故障。先明确本地顺序、资源版本和所有权，不以跨服务墙上时钟推断全部因果或权限优先级。

| 中断位置 | 恢复原则 |
| --- | --- |
| 尚未执行，只收到任务或 claim | 从既有任务上下文继续规划。 |
| 已有结果提交 | 复用结果和身份，避免把已完成操作当成新操作。 |
| 已记录 intent，没有提交结果 | 保留未知结果事实；安全观察可重试，外部效果先核对实际状态或 backend receipt。 |
| 等待真实授权或信息 | 保存现有现场；拒绝不等于授权，超时不等于执行失败或默认批准。 |
| 取消 | 到达实际执行及其子任务，按已确认状态报告，不由 UI 计时器伪造终止。 |

恢复结果引用与决定是否复用一次计算是不同问题。前者恢复同一调用的既有结果；后者还要求输入和执行条件仍适用。相同工具和参数不必然产生相同结果。

Session lease 保护 session 的执行所有权，journal 锁保护提交顺序，文件操作队列保护其声明范围内的操作，输入版本检查识别受影响证据。它们不自动提供跨 session、外部编辑器及任意服务的全局事务。

近期连续空响应的修复说明：保留 claim 和结果还不够，恢复状态也必须保持一致。曾因重置 `finish_rejected` 标记导致 continuation 无效；应以清楚的现有状态类型减少矛盾组合，不因此增加一套新工作流。

## 当前实现与后续设计

| 状态 | 内容 |
| --- | --- |
| 已实现 | 默认主 Agent，统一初始指令与原生工具目录，拆到可执行就动手的内置工作方法，已有 journal/continuation/finish，结果引用与未知效果反馈，必要检查和部分输入版本关联。 |
| 已确定的设计原则 | 从任务推进动态展开行动；用户不预先连线；图展示事实与计划的差别；沿用现有事实来源与权限边界。 |
| 尚未实现的方向 | 完整数据/资源依赖分析、自动失效重算、线上交付质量/成本对照，以及覆盖更多内部边界的明确类型。 |
| 不应推导的能力 | 完整依赖分析、跨工作区事务、任意外部效果 exactly-once、代码或检查通过即用户接受，以及真实模型交付质量已经改善。 |

后续改动以能完整交付的纵向任务为单位。本轮工具执行属性已集中到纯逻辑模块，具体见下方 checklist。结果契约、continuation 合法状态、任务/调用/产物版本/检查的必要引用继续沿现有边界收敛。图展示可以独立渐进加入，不阻塞现有任务执行，也不作为新增完成门槛。

## 质量与成本的检验

用真实功能修改、多轮修正、必要 UI 验证、长任务中断恢复和已满足无需改动的任务检查工作方法。评价结果是否可用、是否错误宣布完成、用户介入和返工是否减少，并观察总耗时、模型与工具成本。

单测保护具体协议、权限、恢复和执行行为。测试提示词包含某句话、节点计数或删除代码行数，都不能证明语义交付质量。普通任务完成不需要固定 Reviewer、额外快照、打包或用户审批；实际项目要求和任务后果决定必要检查。

性能成本进入设计：复用结果引用，按需读完整输出，避免每轮复制全量历史；图随新事件增量更新，历史按需展开；并发受依赖与资源约束。重试和压缩要服务有意义的下一步，不能把持续运行本身算成进展。

综合记录初稿只修改文档。后续精简改动及验证见下方 checklist 与两仓 HANDOFF；没有新增动态图运行或真实模型质量试验结果。

## 精简实施 checklist（2026-11-05）

本轮把执行原语落到现有代码，完成工具边界模块化并删除阻断自主修复的重复机制。勾选代表下面列出的具体代码与行为已验证，不代表完整 Agent 系统或动态图产品已经完成。

- [x] **一个主执行路径**：保留 task → loop → journal/continuation → finish；不增加 Agent、状态机或确认阶段。
- [x] **模块有明确所有权**：纯工具语义与 shell 分析归 `internal/mooncode_tools`；daemon 组合执行、授权、持久化与 provider，不在新模块引入 IO。
- [x] **原语语义分开**：并发资格、技能消费顺序、安全重放、本地操作和本地验证分别声明；`read_skill` 不再伪装成 mutation。
- [x] **删除重复分类**：并发、技能屏障、审批和恢复消费同一契约；删除旧 effect 枚举、字符串 key 和各处重复工具列表。
- [x] **提交之后继续修复**：删除 command 级 post-commit seal 与 terminal-commit 限制；同一命令能够 commit → 修复 → 验证 → finish，无需新用户指令。
- [x] **完成仍针对当前结果**：保留 commit 身份、实际变更路径、任务修订和输入指纹；修复后旧检查失效，检查后文件变化不能宣布完成。
- [x] **删除伪质量流程**：删除只重复审批结论的 Guardian shadow trial、专属事件、测试和过时文档；保留真实授权、沙箱及不确定效果处理。
- [x] **删除无生产用途的辅助实现**：删除 shell 文件观察旧实现及只测试它的用例、旧 seal 执行包装；纯语义测试移到所属模块，执行行为测试保留在 daemon。
- [x] **控制计算成本**：去掉每次 post-commit 工具调用前的重复 Git 快照；不增加模型调用、日志副本、数据库或新服务；总生产代码净减少。
- [x] **验证与记录闭环**：相关行为测试、全量 native suite、真实两仓协议 probe、接口和格式检查通过；记录证据、剩余限制并同步两仓文档。

本轮证据：

| 检查 | 结果 |
| --- | --- |
| 模块检查与测试 | `internal/mooncode_tools` 检查无警告；17/17 测试通过。 |
| Commit 后修复 | 两项实际 sandbox/runtime 测试通过：保留提交路径事实；同一命令继续修复和验证，检查后的输入变化仍阻止完成。 |
| Native 回归 | 1917/1917 通过，包含既有授权、取消、恢复、压缩和完成修复用例。 |
| 真实协议 | 使用两仓当前源码，MoonDesk 解码 MoonClaw capability producer 成功。 |
| 接口与文档 | `moon info`、`moon fmt`、diff 检查通过；只新增内部模块接口，既有 `.mbti` 不变。32 个本地链接有效，旧归档 11 个文件哈希未变。 |
| 净变化 | MoonBit 生产代码净减 623 行，测试净减 498 行；移动代码不算删除收益。 |

全量仓库仍有既有编译警告；本轮没有安装应用、执行 live-provider 质量评测或测量真实任务延迟，不能据此宣称发布门槛或模型交付质量已经达标。

动态图仍按前文作为 journal 的可重建视图演进。本轮不把图编辑器、图数据库或完整依赖分析塞入执行内核，最小图能力在后续五步实施中交付，完整依赖分析仍不勾选。

## 前轮模块减法记录与剩余项

以 MoonClaw `8b4c0f0d` 的运行实现为设计基线。上轮十项 checklist 已完成；已实现 Task、Completion、Execution、Tools ABI 与原生 Workspace 身份/条件写入；进程级 Workspace 隔离及其余细项按下方 checklist 保持待办。这份模块计划替换此前以评测、发布顺序组织的 phases 0–5。模块按职责和数据契约划分，不要求增加九个 package，更不增加九层调用或新的运行框架。

优化目标是让主 Agent 自主解决问题，运行时只承担确定的执行责任。用户约束、真实授权、资源隔离、数据完整性和明确要求的检查属于必要契约；从关键词猜要求、规定解题步骤、重复审批、双路径兼容以及为恢复制造额外状态，属于优先删除或收敛的对象。

### 模块边界

| 模块 | OS、编译器或数据系统概念 | 输入 → 输出 | 独立负责什么 |
| --- | --- | --- | --- |
| Task | 编译器前端、程序输入 | 用户输入/修正、项目规范 → 当前任务及修订 | 保留用户意图和约束，不用关键词生成新的完成门槛。 |
| Execution | Process、Thread、解释器与调度 | 当前任务、上下文、结果 → 下一批调用或继续/等待/结束 | 主 Agent 控制流、工具子任务归属、取消和 session 执行所有权。 |
| Context | Memory、上下文编译 | 任务、历史和来源引用 → 有预算的模型工作视图 | 取数、压缩、来源和按需补读，不产生权限或完成结论。 |
| Workspace | Filesystem、资源模型 | 路径、范围、版本、读写请求 → 文件内容或变更事实 | 真实文件、原子编辑、版本与资源引用。 |
| Tools | ABI、系统调用与驱动 | 调用、参数、既有授权 → 结果或执行错误 | 统一调用边界和 provider 适配，不规定 Agent 必须用哪种解题方式。 |
| Journal | 日志、恢复与持久数据模型 | 执行事实/位置 → 有序记录和可恢复现场 | 唯一持久执行事实，已完成结果复用、未知效果和恢复。 |
| Completion | 程序返回、任务级后置条件 | finish、当前任务和必要证据 → 完成或具体缺口 | 检查明确承诺与当前事实，语义交付由主 Agent 负责。 |
| Projection | 物化视图、动态图与终端输出 | journal 中可展示的事实和计划 → canonical 进展/图 | 可重建展示与导航，不调度执行或二次验收。 |
| Telemetry | profiler、执行追踪与回归工具 | 已有事件、用量和任务结果 → 诊断与比较记录 | 帮助开发者找根因，不进入每项任务的必经路径。 |

### 1 Task 模块 减少编译器前端的策略猜测

现有入口：`mooncode_runtime_horizon.mbt`、`mooncode_runtime_controls.mbt`、`mooncode_book_instructions.mbt` 和 `mooncode_runtime_model_planner.mbt`。

- [x] **删除** `requests_tests`、`requires_verification` 等英文关键词规则对完成条件的推导；删除通用 system 中 `dynamic_skill_gate_message` 的 MoonTown/MoonBit 专用政策，交还项目 AGENTS 与适用 skill。
- [x] **合并** 任务组织到既有 task contract，保留完整请求、项目上下文及有序修正；删除 prose marker/12k 输入截断和重复原文。修正复制 updates，不改写旧修订；显式 required checks 不被改计划消除，不增加规格生成 Agent 或确认表单。
- [x] **验收** 中英文表达同一请求不会得到不同硬门槛；“解释 fix 的含义”不被判成必须改代码；显式 required checks 仍然必须满足，长请求及后续修正不丢失。

保留真实用户要求，删除根据措辞猜出的额外要求。Task 不执行工具、不审批、不证明完成。

### 2 Execution 模块 减少解释器干预和重复调度

现有入口：`mooncode_runtime_turn.mbt`、`mooncode_runtime_loop.mbt`、`mooncode_runtime_service.mbt`、`mooncode_parallel_reads.mbt`、active/pending cancellation。

- [x] **删除** `mooncode_runtime_turn_recovery_plan` 替换模型工具调用、强制大范围 read 的策略。编辑失败返回准确错误及可用的局部信息，主 Agent 自己选择补读、缩小修改或换方法；不伪造一条模型提出的调用。
- [x] **收敛** service/loop/turn 的现有职责，复用一份终态 verdict，删除重复判定包装和 planner-mode/关键词分流。继续使用现有等待、暂停与取消控制；没有新增状态机，也不为减少行数删除不同资源的同步边界。
- [x] **减轻去重干预**：删除按读取历史拒绝完整 read/shell 观察、按相同参数拒绝刚失败检查的策略。已保留证据作为指导，模型需要的安全观察和重试正常执行；同次 operation 的 journal 去重及已完成结果复用保留。
- [x] **验收** 模型在同一任务修正编辑、重复读取并重试瞬时失败的检查；既有空响应、重启、取消和 quantum 回归通过。没有要求补一个成功动作、编辑或用户确认。

同步放在保护真实资源的位置：session execution lease 保证一个执行所有者，工具子任务通过结构化并发 join/cancel。生命周期锁和 journal 锁保护不同对象，不能按名称相似直接删除，也不扩成工作区全局锁。

### 3 Context 模块 减少内存管理的双路径和固定流程

现有入口：`mooncode_runtime_model_planner.mbt`、`mooncode_context.mbt`、`mooncode_context_provenance.mbt`、`internal/context_pruner` 和知识检索。

- [x] **删除** legacy 32-message suffix、active/shadow 并行路径、provenance v1 兼容读取和只证明旧开关的测试，留下一个正常使用的、按模型窗口与压力投影的路径。
- [x] **合并** 各处输出截断、摘要和 overload shaping 的重复责任；transport 只处理 provider 协议和重试，Context 决定本轮保留什么。保留完整指令优先级、调用/结果配对和任务修订；当前结果携带 evidence_ref，省略整段时保留首尾结果引用，重复压缩继续保留范围句柄。
- [x] **按需回取** journal、文件、sandbox 输出和知识片段；不强制每轮检索、总结或改写 query。没有保留原文的内容明确视为缺失，不能把摘要当成精确原文。
- [x] **验收** checkpoint 回灌后仍保留当前目标、关键约束和最近结果；继续使用现有 follow-up 选择下一步，不因压缩重跑已完成效果。原始事实仍在日志；不增加总结模型调用，不按固定条数重复投影。只补读实际保留的结果，未保留的 stdout 或源文件旧版本不会被凭空恢复。

现有 RAG 已有文本/embedding 混合排序，优先复用；只有具体检索失败需要时才增加 query 改写或 rerank。

本轮边界：[Context/Journal 运行契约](../../moonclaw/docs/LONG_CONTEXT_COMPACTION.md) 描述默认窗口预算、单一 compiler 与恢复。按需补读文件、已安装 skill 和可用 artifact/backend 复用现有入口；只读 `read_result` 已按 evidence ID 补读当前 session 日志中的规范结果；提供 `end_ref` 可列出压缩范围中的结果，再按单个 ID 取原文。返回 JSON 行号与截断标记。它按需扫描现有 journal，不是新索引；只保证实际保留的结果可回取，不保证工具本来就截掉的内容可恢复。摘要不是原文，不能通过重跑写入或外部效果来恢复旧输出。窗口估算使用现有 cl100k tokenizer，保留完整前缀和最新批次仍可能超预算；不声称任何输入都能装入窗口。tokenizer 词表延迟初始化一次，每轮计数仍与输入/schema 大小相关。

### 4 Workspace 模块 减少文件策略与存储责任混杂

现有入口：`mooncode_tools.mbt` 的读写/patch、`mooncode_task_scope.mbt`、`mooncode_moon_fmt_scope.mbt`、现有 book 路径解析与文件引用。

- [x] **合并现有重复路径**：单/多文件 unified diff 共用 patchset 执行器，每个文件只在该执行器读取一次；task scope 每次调用解析一次，直接文件 scope 与工具使用同一个 book-relative 解析规则。删除通用文件工具的 MoonBit manifest 语法门槛；复用既有文件/检查引用。
- [x] **收敛资源身份**：读写、scope、并行读取去重、检查输入、formatter selector 与 Moon 命令使用共用的真实路径解析；新文件解析最近的已存在父目录，拒绝越界和 dangling symlink。检查凭据记录 absolute_path，别名改指向同内容的其他文件也使旧检查失效。纯 lexical helper 只承担路径/argv 排版，不提供授权证明。
- [x] **删除全局工具偏好禁令**：保留 exact grant、既有路径与窄 scope 检查，移除“重定向、sed、inline interpreter 一律不能写文件”等强制改用某个工具的规则及仅服务这些禁令的解析。项目自身明确要求的 `.mbtx` 或编辑方式仍按项目规范执行。
- [x] **原生写入并发验收**：write/edit/patch 共用文件级稳定锁、内容比较和同目录 staging/rename；不同文件不串行。write 可带 read 返回的 expected_fingerprint，不强制增加读步骤。多文件 patch 只回滚本次已提交成员，恢复也比较当前内容；外部改动被保留，部分恢复返回明确 metadata，测试覆盖过期版本、竞争写入、权限位与未执行成员。
- [ ] **进程级隔离收尾**：任意 shell/formatter 不参加原生文件锁，现有 grant 没有 per-task writable-path 字段；窄范围快照仍不能归因并隔离执行期间的全部外部变化。保留事实错误与条件恢复，不宣称工作区级事务，也不新增全局工作区锁、人审或文件状态数据库。

保留原子写入、必要的旧内容匹配和实际权限范围。不同写入入口必须报告足够的变更事实以使旧检查失效；不会先删保护，再用“sandbox 应该会挡住”代替验证。

### 5 Tools 模块 减少 IO 的重复审批和词表判断

现有入口：`internal/mooncode_tools`、`mooncode_runtime_approvals.mbt`、`mooncode_execution_sandbox_gate.mbt`、`mooncode_process_tools.mbt`、MCP 与 provider transport。

- [x] **删除按命令名一律要求人审的分支**，例如 commit 或任意非只读 shell 自动要求批准。执行入口显式携带并核对现有授权范围；已有用户/宿主授权覆盖的操作直接执行，显式审批继续等待；超出配置的权限直接返回拒绝，Agent 可换方法或沿现有用户交互解决，不新增扩权流程。不能从模型的 `planner`、`approval` 或“安全”声明生成授权。
- [x] **收敛 ABI**：既有 native catalog 提取为唯一缓存 schema 来源，模型解码、审批前和最终执行复用同一个类型/required/enum/嵌套参数校验；错误不再被默认值吞掉。opaque grant 独立于模型参数，执行边界仍核对实际配置和 exact plan。删掉独立 supported-tool 名单、旧请求 envelope alias、隐式 patch 验证子调用及两仓的影子工具政策表；结果复用既有 event/envelope 与 provider 适配，不加另一层工具框架。
- [x] **缩小 shell 分析职责**：只保留执行、结果解释、并发或现有安全边界确实消费的语义，移除被上述策略删除淘汰的词表与解析分支。保留检查退出状态的真实性，不因模型填写了 `verification_kind` 就把任意命令算作检查。
- [x] **验收** 现有 runtime 用例已取消预置审批/plan，自动执行 commit、重定向、sed 和 `.mbtx` 生成后验证并 finish；显式审批/驳回/重启、grant 匹配及取消/未知效果回归保留。权限缺失仍拒绝，planner 标签不能免除显式审批。

本轮另外删除 `local_operation/local_validation` 两个审批属性及 sensitive/install/overwrite/inline-authoring 解析，保留只读并发判定、真实检查退出状态和必要 scope 分析。shell 初始执行/配置执行合并为一个入口，计划构造与最终执行复用同一 preflight；ABI 后续收敛已完成，见下文。

可写 shell 的检查失效复用原有只读执行属性：不能证明为观察的 shell 不沿用旧检查；receipt 的 changed_paths 纳入后续检查输入。原 mutation_states 仅为收集路径构造伪 before/after 状态，现已改为直接返回路径，减少实现。

Workspace 的全工作区 scope 不扫描 Git；窄 scope 的快照失败先拒绝再执行。原生写入按 canonical root + path 使用已有 OS 文件锁，替换文件 inode 不会绕开锁；既有 scope 恢复也用相同的条件写入。窄范围/局部 fmt 的快照成本和进程级外部变化归因仍待办，不能把原生文件锁写成任意进程或整个工作区的事务隔离。

此模块不是新增授权服务。具体命令仍使用真实 sandbox grant；减少的是重复人的决策，不是绕过隔离、取消或执行证据。

Tools/Workspace 本轮证据：最终 native 1892/1892；completion/fmt/repair 17/17；真实 producer → decoder probe、info/fmt 与文档链接检查通过。生产 MoonBit 净减 568 行，测试净减 447 行；internal tool interface 仅删除淘汰属性/函数。全工作区 scope 少一次完整前后 Git 快照；窄 scope 仍有整树成本。没有新增 package、状态机、人审步骤或模型调用；既有六项 daemon warning 与 live-provider/安装态未验证的限制保留。11 个历史归档哈希不变。

ABI/Workspace 后续实现：两仓各约 800 行的旧 native_command_execution 策略被删除，capability 中只保留实际协议和 owner 信息；不再发布旧工具顺序、全局 review、manifest 语法或重复 result checklist。MoonClaw 的 schema、opaque grant 和 execution result 各自保留必要边界。具体实现位于 [工具目录](../../moonclaw/cmd/daemon/mooncode_tool_catalog.mbt)、[ABI 参数校验](../../moonclaw/internal/mooncode_tools/arguments.mbt) 和 [Workspace 文件边界](../../moonclaw/cmd/daemon/mooncode_workspace.mbt)。

性能与保证：schema 在进程内构造一次；普通原生写入不增加 Git 或模型调用，但要读取/比较目标内容并暂存新内容，成本随该文件大小增长。CAS 比较复用现有 Book resource reader，保留其 16 MiB 文本上限；保留 rwx 权限，不承诺 inode、owner/xattr 或跨文件 crash transaction。rename 提供单文件替换原子性，没有宣称 fsync/power-loss durability。文件锁协调原生写入，非协作进程在最后比较之后仍可竞争；恶意目录替换的全面防护、shell/fmt 隔离和快照成本是未完成的边界。

本次验证：MoonClaw native 1890/1890、MoonDesk native 1733/1733、协议核心 JS 66/66、真实 producer → decoder probe 均通过。两仓 info/fmt 与接口差异检查通过；仅保留既有六项 daemon warning。生产 MoonBit 合计净减 1695 行（Claw -901、Desk -794）；测试净增 66 行，旧政策/隐式调用测试由四个实际边界回归替代，目录搬移不计作删除。40 个本地链接、11 个历史归档哈希已核对；未进行 live-provider 或安装态应用验证。

### 6 Journal 模块 减少恢复与持久化的重复成本

现有入口：`mooncode_session_journal*.mbt`、`mooncode_journal_sequence_v2.mbt`、`mooncode_runtime_continuation.mbt`、`mooncode_runtime_operations.mbt`。

- [x] **替换** 多套 continuation 字符串/布尔校验为覆盖现有暂停原因的明确类型，边界解码一次；删除重复校验、整段结果摘要 hash、旧 inline checkpoint 兼容分支和已下线 Goal journal 特判。恢复沿同一执行位置和结果身份，不新建 operation store；当前格式中的合成 inline result 保留。
- [x] **减少磁盘同步成本**：普通缓存命中追加只同步日志文件；首次观察文件、重启或缓存失效时保守同步祖先目录链，生命周期变更继续同步受影响目录。删除每次追加都向上 fsync 的路径。保留所声明的 crash/durability 契约并用故障测试确认。
- [x] **复用已有增量 append cache**，不另写一套索引。重启、文件替换或缓存失效才重建；journal 顺序、冲突身份、torn-tail 修复和一致的提交边界仍由同一 writer 负责。
- [x] **验收** 完成结果恢复不重跑；只有 intent 没有结果时保留未知并核对；坏日志不能伪装成空会话；追加成本不随全量历史反复增长。

这里优化的是已有日志与恢复，而不是建设分布式数据库。不同资源的锁、未知副作用语义和必要的同步不能为凑删行数移除。

缓存的目录同步事实在 archive/restore/delete intent 前失效；首次观察、缓存失效和重启仍保守同步祖先链，普通命中追加只同步文件。故障回归验证同步失败后 duplicate retry 不增加重复记录。恢复只回灌最新 checkpoint；引用唯一、有序、位于 checkpoint 之前且 event digest 匹配，错误明确报 InvalidJournal。已完成结果及未知效果仍沿原 operation identity 处理。checkpoint 构造仍遍历累计引用并保存一次当前 transcript，不宣称固定成本；Windows 目录 sync 原有 no-op 与非协作文件替换限制保留。

Context/Journal 本轮验证：MoonClaw native **1873/1873**，真实 MoonClaw producer → MoonDesk decoder probe 通过；info/fmt、空白检查和公开 `.mbti` 核对通过，未改变接口。生产 MoonBit 净减 985 行，其中 95 行仅供测试的 parser helper 归入测试，不算实际删除收益；测试净减 626 行，合计净减 **1611 行**。41 个本地链接和 11 个历史归档哈希已核对。全仓仍有既有 warning，不宣称严格 release gate、live-provider 质量、断电或安装态应用验证通过。MoonDesk 本轮只更新文档。

### 7 Completion 模块 减少验收的猜测与重复门槛

现有入口：`mooncode_runtime_completion.mbt`。结果证据与 completion verdict 已从 planner 收拢到这里；显式 task intent 归入既有任务构造，coding evidence 配额被删除。

- [x] **合并** 为一处 finish 判定：显式 required checks、产物和版本事实保留；删除关键词测试推断、`coding_evidence` 配额和终态重复 verdict 扫描。没有 accepted finish 的批次保留真实结果，但不宣告任务完成。
- [x] **删除通用错误后的补证动作要求**：可处理的读取失败不强制再执行一个“成功工具”。明确检查失败、未知结果造成的旧证据失效及相关输入过时仍返回具体缺口；未知副作用不被自动重放。
- [x] **验收** 回答、调研、无需修改、编码及 commit 后修复回归通过；显式检查不能用无关成功或改计划绕开，过时检查不能冒充当前结果。

运行时不通过英文动词或工具类别判断用户问题是否解决。主 Agent 负责语义质量和选取合理验证；显式要求来自用户、项目规范及其实际任务上下文，不能靠删除代码一并删除。

本轮实现证据：native 全量 1899/1899；相关恢复/取消/授权/任务回归 118/118；最终 task/completion/repair/catalog/parallel-read 检查 20/20；真实 MoonClaw producer → MoonDesk decoder probe 通过。新增的本地模型—sandbox 用例直接验证失败编辑后模型原计划不被替换、重复读取、瞬时检查重试和最终 required check；另有长任务输入及修订不互相改写的回归。旧英文分类、强制 read、重复调用拒绝和 prompt 句式测试随实现删除；重启用例改为显式声明其检查条件。

MoonBit 生产代码净减 1122 行，测试净减 1069 行，搬移的 Completion helper 不算删减收益。既有 `.mbti` 未变；没有新增 package、状态机、模型轮次或人工确认。默认完整工具目录可能比旧的四工具纯聊天分支增加 schema 成本，仍可显式选择窄目录；保留原始任务会增加长输入体积，下一轮 Context 负责统一投影。以上是本地执行和协议证据，没有完成 live-provider 质量或安装态应用验证。

### 8 Projection 模块 减少展示对执行的反向约束

现有入口：MoonClaw `mooncode_conversation_projection.mbt`、`mooncode_conversation_watch.mbt`；MoonDesk `mooncode_session_watch_commands.mbt`、canonical conversation 解码与渲染。已接入最小批次/调用/文件图，沿用现有工作折叠与证据卡片。

- [x] **只增加最小图投影**：利用已有任务、调用、结果、产物和检查引用，边执行边形成历史；计划节点可变，执行事实不改写。缺少依赖时保持未知，不要求先生成完整 DAG。
- [x] **删除被替换的重复展示/传输路径**：canonical watch 由 MoonClaw 从原 journal 构建，MoonDesk 只适配 session metadata。删除未被桌面使用的 typed resume、游标 codec、replay spool 与指标；删除桌面“取快照→下载原始事件只为取游标→再取快照”的路径、重复 watch 构造与 Int32/event count 游标。既有 UI codec、导航取消与 generation 检查复用，不增加事件重放或完成 reducer。
- [x] **验收** 无需用户连线或批准图，关闭图仍能执行；刷新/重连可重建，能定位失败和打开产物；watch 更新复用既有快照，折叠工作与证据详情控制展示密度；当前仍构造完整节点 DOM，不声称虚拟化，不为绘图调用模型。

上一轮完成传输/投影减法；本轮再沿 work steps 生成最小图。原始诊断 JSONL/SSE 保留；桌面只用 watch。实际 HTTP 回归覆盖鉴权、snapshot/heartbeat，追加唤醒与相同游标重连不重放；大十进制 revision 经过 metadata adapter 和实际 UI codec。turn 数组保序，单次投影用临时 command-id 索引，避免每条 event/receipt 都遍历全部 turn。等待期间只检查文件 metadata，不逐次解码 journal；初次和等待后的最终读取仍重建完整 canonical snapshot，变更响应仍传完整会话，不宣称增量缓存或常数重建成本。[当前 watch 契约](../../moonclaw/docs/MOONCODE_STREAM_RESUME.md) 取代旧 typed-resume 说明。最小动态图已交付，完整依赖分析继续未勾选，不增加图存储、模型调用、连线或审批流程。

### 9 Telemetry 模块 减少评测对正常执行的侵入

现有入口：`mooncode_planner_metrics*.mbt`、现有 harness/replay 和任务结果记录。

- [x] **合并** 用量/延迟/重试采集：首次规划、follow-up 和空响应复用同一 collector，观察值附到已有最终 planner event；canonical usage 从这些事实汇总。删除同步 MoonGate exporter、环境开关、export 专用 SDK method、两套 configured/effective 大小统计、工具名副本和派生 cache ratio；实际工具错误/结果引用沿原事件，不另造评测阶段或服务。
- [ ] **用真实任务验证改动**，保留错误完成、用户接管、返工、成本、启动/构建/交互耗时；实际 badcase 回流最小测试。评测是开发验证，不是每项任务的执行阶段。
- [x] **验收** 无遥测 exporter 或评测服务时正常执行；指标缺失不变成任务失败，缺少价格/结果依据时不伪造费用或成功率。恢复、重复 receipt 和空响应的本地回归覆盖实际用量；不从普通工具成功推断任务成功率。

用量不再依赖会被压缩的历史 planner steps，也不被后续 receipt 覆盖。观察复用 daemon UUID，避免时间戳相同的不同响应被日志去重；每轮仍只追加原来已有的 planner event，无额外 fsync 或网络等待。collector 记录 compiled request/schema 大小、provider 明报 tokens/cache、model call 的 wall elapsed time 与外层 retry 次数。缺失/非法 usage 不当作已测零；缺少价格不估费用。它不覆盖未返回 usage 的计费尝试或 transport 内部 fallback，request_chars 也不是 provider 最终 HTTP body 大小。现有 harness/replay 保留；真实线上交付成功率、用户接管、返工、费用及启动/构建/交互基线尚未建立，第二项不勾选。

Projection/Telemetry 本轮验证：MoonClaw native **1862/1862**，MoonDesk native **1729/1729**，协议核心 JS **65/65**，UI watch/usage **108/108**，真实 producer → decoder probe 均通过。既有重启任务覆盖提前 finish 被拒、连续两次空响应、重启、写入/检查/完成，6 次模型响应统计为 600 input/60 output tokens，写入只执行一次。两仓 info/fmt、空白检查及接口差异核对通过；公开差异仅增加 watch endpoint、移除弃用的流游标/endpoint builder 与 export 专用 SDK method。生产 MoonBit 合计净减 **1307 行**（Claw -954、Desk -353），测试净减 **739 行**，合计 **2046 行**。42 个本地链接、11 个历史归档哈希核对通过。保留既有 warning；没有新增 package、状态机、持久 store、模型轮次或人工确认；未做安装态应用、live-provider 或生产性能/质量资格验证。

### 实施顺序与删除标准

先做 Task、Completion 和 Execution 的解题策略减法，直接减少错误完成门槛与强制动作。随后一起收敛 Tools/Workspace 的实际授权和写入边界，再删审批词表、语法禁令；之后统一 Context 与 Journal，最后做最小 Projection。Telemetry 随每项改动验证，不是第一阶段的大工程。

每个模块都按“移除一条多余策略 → 走通实际行为 → 删除旧实现与专属测试”交付。模块化必须消除重复责任或便于独立验证，单纯搬文件不算完成。除真实的外部契约外，不保留旧实现兼容路径；不以新增状态、抽象层、人工确认或大批镜像测试换取删行数。

Task、Completion、Execution、Context/Journal 及 Tools/Workspace 的已勾选项已实施；本轮 Projection canonical watch 和 Telemetry collector 完成减法。只读历史结果补读与最小动态图已在下面五步中交付；进程级写入隔离、完整依赖分析及真实线上结果/成本基线继续待办。回归任务和安装态检查沿用现有工程流程，不再作为一组独立产品 phase 阻塞这些精简。


## 五步实现记录：可编程性与工作效率

本轮基线为 MoonClaw `165d3147`、MoonDesk `8ba58519`。前面的模块 checklist 保留已完成事实；旧策略删除不再重复列为待办。新一轮的目标是让单主 Agent 更容易组织工作、减少模型往返与重复探索、更快交付。OS/编译器/数据库/数据计算继续是分析视角，不增加架构层或九个包。

下面是开发改动的顺序，不是每项用户任务必须经历的运行阶段。每步落在现有入口，完成后更新对应 check；五步代码与本地行为验证已实施；真实 provider 的交付质量、tokens 和成本对照仍单列为未测，不能从本地 fixture 推断收益。

### Step 1 收敛模型调用路径，让解释器主线可读

- [x] 借 Pi 的应用消息 → context transform → provider messages 边界，以及 OpenSeek 对普通输出/循环控制的明确区分。保留 MoonCode 既有 Task、finish 和单主 Agent 工作方法。
- **改动**：在 `mooncode_runtime_model_planner.mbt` 让 initial/follow-up 分别提供所需消息，共用构造请求、发送、解码响应和记录观察的内部路径；`mooncode_runtime_turn.mbt` 继续拥有批次执行与循环控制。Provider transport 保持自己的职责。
- **删除**：两处重复的请求/响应组装、指标调用包装和没有独立行为的转发 helper。只为消除重复引入必要的内部函数，不先新增通用 middleware/hook 框架。
- **完成标准**：沿代码能直接看见“上下文 → 模型行动 → 执行 → 观察 → 下一轮”；现有首次请求、follow-up、steering、空响应和重启任务沿同一主线完成，不增加模型轮次或用户操作。

### Step 2 收敛工具结果，让程序、模型和 UI 容易使用

- [x] 借 DSH 的 canonical value 与 model/UI presentation 分离，以及 OpenSeek 工具定义与可执行行为相邻的设计。保持现有 catalog、executor 和 journal，不搬入插件系统或万能工具注册框架。
- **改动**：从 read/edit/shell 这些高频工具开始，统一内部结果入口及公共结果部分；结构化数据、文本输出、文件/产物引用各有清楚用途。规范结果进入原 journal，模型和 UI 从它投影。已有 `evidence_ref` 继续复用。
- **删除**：下游对 `result/tool_result/event/metadata` 的反复探测与多种默认兜底、每个消费者单独组织的工具包装，以及可由规范结果派生的重复副本。实际需要持久化的事实保留。
- **完成标准**：同一份结果可直接供脚本后续计算、模型阅读及界面打开文件/产物；无需了解每个工具历史上的包装差异。用现有编辑—检查—交付任务验证，测试结果行为而非 JSON 句式。

### Step 3 让确定的工作片段成为程序，减少模型往返

- [x] 借 OpenSeek 的 `.mbtx`/program-callable、DSH PTC 与此前 CodeMode 讨论中的核心思路：已经明确的连续工作可以写成程序，不确定之处再返回模型。DSH 的 PTC 并非默认开启，MoonCode 也不因此获得它的 SDK 或持久程序重放能力。
- **改动**：先复用现有 native tool batch、`mooncode_parallel_reads.mbt`、write/edit 和 shell 执行入口。独立观察走现有批次；已知的本地计算/文件处理片段可以由 `.mbtx` 完成，以正常工具结果返回有用输出和产物引用。小任务直接调用工具，不要求先写脚本。
- **删除**：为普通批量工作单独增加 Agent 的必要性，以及强制逐步汇报、把确定片段拆成多轮模型调用的引导。只在实测存在重复时删除对应实现，不先加另一套调度器。
- **完成标准**：例如处理多个已知配置文件并执行明确检查，可以减少模型往返并交付相同质量结果。比较总耗时和 tokens，计入脚本生成、MoonBit 编译/启动及链接成本；不能只比较工具调用次数。
- **范围**：这一步使用普通程序执行，不提供尚不存在的工具调用 SDK、外部效果事务或任意程序中途恢复。借 pi-durable 的“复用已有结果”原则，继续沿现有 operation/journal 恢复，不新建 Task/Document/Commit runtime。

### Step 4 形成可用工作集，按需取回旧结果

- [x] 借 Pi 的 context transform 与消息转换分工、DSH 从日志生成视图的方式。工作集是本轮需要的数据视图，原始记录继续由现有 journal/文件拥有。
- **改动**：复用 `mooncode_context.mbt` 和现有 compiler，让当前目标/项目要求、当前工作、最近观察和来源引用容易取得。补齐一个薄的只读 `read_result`，复用 journal reader、已有输出限额和 artifact 访问；压缩保留回取句柄，省略整段时保留对应日志范围引用。
- **删除**：靠重复内联历史结果、在多处重建相同工作摘要来补偿记忆的代码；根据实际用例减少因缺少旧输出而产生的重复探索。不增加固定总结轮次、强制 RAG 或新的 memory store。
- **完成标准**：长任务能接着修改既有文件；需要早先的精确输出时可以补读，不为恢复旧输出再次执行命令。保留完整任务/项目要求，摘要不冒充原文。

### Step 5 从现有事实生成最小动态图，让工作自然显现

- [x] 借 DSH 的日志投影、数据流中的已物化结果，以及 Pi 会话结构对可追溯历史的启发。此处不引入会话分支或工作区分叉。
- **改动**：在 `mooncode_conversation_projection.mbt`、canonical watch 和 MoonDesk 既有 work steps/evidence 展示上，逐步连接任务、工具批次、文件/产物和检查结果。复用现有身份和明确记录的引用。点击节点沿已有本地面板打开相关内容，计划随下一批行动更新。
- **删除**：有替代后再删重复的活动列表、状态计数和说明。缺少引用时不画猜测的依赖；不为绘图再请求模型，也不让图回头控制调度或产生完成结论。
- **完成标准**：用户能看懂正在做什么、得到什么、产物在哪里；刷新和重连从同一批事实重建。无需手工连线或批准图，关闭图仍能继续工作。按需展开控制渲染成本，不先建设图编辑器或图数据库。

### 本轮实现与实测

- **Step 1 / Pi、OpenSeek**：initial/follow-up 各自准备消息，共用一个 `mooncode_runtime_model_round`；请求、响应解码、上下文编译和观察记录只有一份。follow-up 同样采用用户选定的 reasoning effort。空响应恢复仍走原 loop。
- **Step 2 / DSH**：read/edit/shell 和 checkpoint 共用 execution envelope；模型、完成检查与补读共用 `mooncode_tool_result_value`。执行结果与 journal 的字段各有边界，不增加插件注册层。结果 ID 复用已有 operation ID；开始/完成用明确 tool-call ID 关联，删除按工具名/路径猜测匹配的分支。
- **Step 3 / OpenSeek、DSH PTC**：共用 prompt 内置“独立观察批量执行，明确片段用项目脚本，遇到新不确定性再回模型”。沿用 shell、项目语言和 `.mbtx`；已有 MoonFort fixture 桥接的真实本地执行用例 现在验证脚本读入修复后的文件、生成产物并返回结构化 JSON，再在同一个任务检查/交付。没有新增工具 SDK、语言或持久解释器。
- **Step 4 / Pi、DSH、pi-durable**：`read_result` 读取当前会话的已提交原始结果，支持精确 ID、范围目录、JSON 行选取和输出限额。重复上下文压缩保留首尾句柄。回归验证文件后来变化不改变历史结果，读取旧结果不执行原工具；包含 patch 类结果和跨 session 不可见行为。
- **Step 5 / DSH、Pi**：`work.graph` 是 existing work steps 的一次临时投影；批次选择、调用、文件、检查输入版本、明确的补读关系来自已有事实。MoonDesk 同一工作位置按分支画图，复用卡片与打开文件动作，删除被替代的重复 detail/evidence 展示。图没有持久状态，不参与完成判定。

局部修复沿用编辑/检查/finish 与重启回归；跨文件片段另做一次临时测量：三个已知 JSON 文件改同一字段，6 次 native read/write 为 **4 ms**；同等结果的 `.mbtx` 经 MoonFort fixture 桥接首次执行 **512 ms**、再次执行 **204 ms**，含 MoonBit 编译/启动与 fixture 桥接开销；此 fixture 的隔离回执标记为 Degraded，不是生产隔离或真实 MoonFort 部署的性能测量。脚本还检查落盘内容并返回结构化路径；native 数字仅含六次工具调用，未额外包含相同检查，不能把它们当成交付质量对等的端到端胜负比较。测量不含模型生成脚本的耗时/tokens，也不代表脚本一定更快。小型已知编辑继续直接用工具；模型往返成本高、片段较长时再选择程序。

长任务回归连续压缩两次后仍能找到最早结果范围；Context 包 29 项通过。UI 组件使用真实编译产物在浏览器验证折叠、失败输出、中文、文件导航与 390 px 无水平溢出；UI 全量 839 项通过。图视图构造随节点/边数线性增长，完整 canonical watch 仍读全历史并传全会话，折叠不等于按需创建 DOM。安装包更新和真实 provider 的质量/轮次/tokens/费用对照未执行，不宣称已取得线上收益。

### 五步实现时的交付验证

| 检查 | 本轮结果 |
| --- | --- |
| MoonClaw native 全量 | 1864/1864；最后的图/会话投影定向回归 30/30。 |
| MoonDesk native 全量 | 1729/1729。 |
| MoonCode core JS / 图 codec | 65/65；图字段 roundtrip 定向 3/3。 |
| UI MoonBit / Node | 839/839；i18n、bundle 与任务控件 Node 24/24。 |
| 真实跨仓库能力契约 | MoonClaw producer → MoonDesk decoder 通过。 |
| 生产构建 | `npm run build` 53.57 s（第二次构建）；主 Rabbita chunk 6,345,672 bytes，相对基线 +4,049 bytes，gzip 568.27 kB。默认懒加载分块回归通过，已更新仓库跟踪的 dist。不是启动/交互延迟对照。 |
| 文档/接口 | `moon info`、`moon fmt`、空白检查；唯一公开接口新增为桌面 core 的 `MoonCodeWork::graph()`。历史归档 11 个文件哈希不变。 |

共享轮次与 execution/result 边界六个相关文件合计净删 **61 行 production**，含新共用 constructor。补读、引用、图及契约接入作为新增能力另计；两个仓库 `.mbt` 合计 **production 净增 482 行、测试净增 341 行**。本轮是小范围能力补齐与职责收敛，不声称整体净删。新增常驻测试仅补两个 runtime/context 用例和一个 UI 用例，其余复用既有脚本、ABI 与 roundtrip 测试；临时性能测量和浏览器 QA harness 未加入产品仓库。没有新增包、调度状态机、图存储或人工流程。

新入口：[保留结果补读](../../moonclaw/cmd/daemon/mooncode_read_result.mbt)、[日志图投影](../../moonclaw/cmd/daemon/mooncode_conversation_graph.mbt)、[桌面图组件](../ui/rabbita-desk/main/mooncode_work_graph.mbt)。真实 provider 对照和安装包更新不在上述通过项内。

### 每步共用的对照方式

沿现有 harness/replay 和本地执行流程，固定三类代表任务：局部修复、跨文件功能、需要引用早期结果的长任务。修改前记录已有行为，每步复用这些任务对照交付质量、模型轮次、总耗时、tokens、重复探索和用户打断次数；相关改动才测编译/启动、构建或渲染成本。不另建常驻评测服务、运行时 Reviewer 或每项任务必过的评测阶段。

优先复用已有行为回归；只给实际发现的缺口补最小测试，删除被替代实现的专属测试。重构项单独统计净删减，`read_result` 和图展示作为新增能力单独列出，不把删测试等同于产品改善。既有授权、同步、恢复和 finish 沿原入口使用，不作为本轮扩建主题。

借鉴源码：[Pi 消息/Context 边界](../../pia/packages/agent/src/types.ts)、[OpenSeek 工具与程序调用属性](../../openseek/agent_tool/agent_tool.mbt)、[DSH 规范结果与展示接口](../../dsh/packages/core/tools/src/contracts.ts)、[pi-durable 工具恢复](../../pia/packages/durable/src/harness/tool.ts)。这些是设计参考，不是新增运行依赖。

## 源码与参考资料

### 当前源码入口

- MoonClaw：[主 Agent 与模型边界](../../moonclaw/cmd/daemon/mooncode_runtime_model_planner.mbt)、[任务上下文](../../moonclaw/cmd/daemon/mooncode_runtime_horizon.mbt)、[工具语义模块](../../moonclaw/internal/mooncode_tools/policy.mbt)、[continuation](../../moonclaw/cmd/daemon/mooncode_runtime_continuation.mbt)、[调用恢复](../../moonclaw/cmd/daemon/mooncode_runtime_operations.mbt)、[完成检查](../../moonclaw/cmd/daemon/mooncode_runtime_completion.mbt)。
- 相关入口：[压缩默认行为](../../moonclaw/docs/LONG_CONTEXT_COMPACTION.md)、[知识检索](../../moonclaw/cmd/daemon/mooncode_knowledge_context.mbt)、[planner 指标](../../moonclaw/cmd/daemon/mooncode_planner_metrics.mbt)、[canonical watch](../../moonclaw/docs/MOONCODE_STREAM_RESUME.md)、[桌面 watch 消费](../ui/rabbita-desk/main/mooncode_session_watch_commands.mbt)。
- OpenSeek：[工具与控制类型](../../openseek/agent_tool/agent_tool.mbt)、[Session 数据](../../openseek/agent_session/types.mbt)、[消息投影](../../openseek/agent_session/projection.mbt)、[存储](../../openseek/agent_session/store/store.mbt)。
- DSH：[工具契约](../../dsh/packages/core/tools/src/contracts.ts)、[批次执行](../../dsh/packages/core/tools/src/batch.ts)、[恢复](../../dsh/packages/core/session/src/repair.ts)、[存储接口](../../dsh/packages/session/session-persistence/src/handle.ts)、[派生状态](../../dsh/packages/session/session-projection/README.md)、[文件接口](../../dsh/packages/fs/fs/src/types.ts)、[默认组合](../../dsh/packages/bundle/base/cordis.patch.yml)。
- Pi：[轻量循环](../../pia/packages/agent/src/agent-loop.ts)、[类型边界](../../pia/packages/agent/src/types.ts)、[会话树](../../pia/packages/coding-agent/src/core/session-manager.ts)、[文件修改队列](../../pia/packages/coding-agent/src/core/tools/file-mutation-queue.ts)、[实验性 Durable](../../pia/packages/durable/README.md)、[Durable 工具恢复](../../pia/packages/durable/src/harness/tool.ts)。

这些相邻仓库链接用于本地源码追溯，不是 MoonClaw 独立构建或运行的依赖。

### 系统概念参考

- [End-to-End Arguments in System Design](https://web.mit.edu/saltzer/www/publications/endtoend/endtoend.pdf)：需要应用语义才能完整判断的结果，不能只靠底层成功信号证明。
- [Time, Clocks, and the Ordering of Events in a Distributed System](https://lamport.azurewebsites.net/pubs/time-clocks.pdf)：区分事件因果顺序与物理时间。
- [MLIR Interfaces](https://mlir.llvm.org/docs/Interfaces/)：通用分析通过操作声明的语义工作，避免为每种操作反复加特殊分支。
- [PostgreSQL Materialized Views](https://www.postgresql.org/docs/current/rules-materializedviews.html)：区分底层数据与可刷新派生结果；Agent 摘要另有有损语义。
- [PostgreSQL MVCC](https://www.postgresql.org/docs/current/mvcc-intro.html)：版本化快照有明确事务隔离语义；文件指纹本身不提供这种保证。
- [Spark RDD Programming Guide](https://spark.apache.org/docs/latest/rdd-programming-guide.html)：借鉴依赖、复用和恢复思想；Agent 的非确定模型调用和副作用不能直接按普通可重算变换处理。
- [Flink Fault Tolerance](https://nightlies.apache.org/flink/flink-docs-stable/docs/learn-flink/fault_tolerance/)：checkpoint 保障的内部状态一致性，与要求可重放 source、事务或幂等 sink 的端到端 exactly-once 有区别。

### 记录连续性

本文件承接 2026-11-04 归档之后的工作方法与架构讨论，采用最终收敛结论，同时保留高层方案为何被进一步简化、系统类比如何被数据模型修正、静态计划如何转向运行时构图的演进。阅读时不把各轮探索叠加为额外实现要求。
