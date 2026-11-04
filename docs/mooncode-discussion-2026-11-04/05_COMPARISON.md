# MoonCode OpenSeek DSH Pia 十六项比较

此文件保留当时完整比较；后续哲学与方案调整见 [设计演进](06_DESIGN_EVOLUTION.md)，事实归属修正见 [归档说明](README.md)。

## 05 四项目比较

原聊天轮次：`01a1a677-ae91-7580-995c-de4692d3e1e7`

### 用户

Compare mooncode, openseek, dsh and pia across these 16 questions, highlighting implemented capabilities, defaults, gaps, and what mooncode should adopt from each.


### 助手完整答复

**MoonCode 应保留现有的事件日志、证据验收和可续跑机制，重点补齐统一工具管线、外部副作用恢复、资源冲突控制和观测能力。**

三者最值得借鉴的方向：

- **OpenSeek**：编码任务执行、worker/worktree 管理、上下文压力控制。
- **DSH**：统一工具策略管线、不可放宽的权限检查、任务 revision 和遥测接口。
- **Pi Durable**：持久任务阶段、显式 replay 策略、嵌套调用去重和断线状态恢复。

下面基于此前核对的本地源码。OpenSeek 为 `dbe35ecc`，DSH 为 `8bd073392e`，Pia 为 `80f7a1149`；MoonCode 按 MoonClaw/MoonDesk 当前工作树。性能和成功率需要同一任务集实测。

表中 **Pi CLI** 与实验性 **Pi Durable** 分开描述，后者的能力不能算作默认 CLI 能力。

**1–4：执行链路、循环、工具与防重复**

| 问题 | MoonCode | OpenSeek | DSH | Pia | MoonCode 应采纳 |
|---|---|---|---|---|---|
| **1. 输入到输出** | 持久命令队列、claim、planner、工具、journal、回执、UI 投影；运行完成与目标达成分开 | Session 投影驱动模型；工具分普通结果与控制动作；前端共用类型化 JSONL | 输入、请求、工具和上下文都由插件组合；要求模型可见内容可从日志重建 | CLI 是轻量事件循环；Durable 把输入、generation、tool 都建模为持久任务 | 借鉴 **OpenSeek 的明确类型边界、DSH 的统一扩展点**；执行逻辑继续由 MoonClaw 单一所有 |
| **2. 终止条件与预算** | `max_turns`、正数 `planner_max_steps` 是可续跑批次；当前 goal-runtime 拒绝聚合预算 | 显式 `max_steps` 耗尽会终止；默认无 step 上限，受上下文机制约束 | 默认没有总 turn 预算；有单请求输出限制和工具局部 timeout | CLI 无总预算；Durable 可选 `maxTurns`，默认不限制，另有重试与崩溃上限 | 增加**显式、可选的运行预算控制器**，独立于 criteria-only Goal；不要把批次、上下文或超时当成目标失败 |
| **3. 参数、权限、执行、回灌** | native schema＋各工具手写校验；进程调用绑定 grant；直接 `/tool-exec` 当前拒绝 | decode 转类型化输入；默认拒绝升级；wasm policy 不约束获准子进程的全部效果 | 支持的 Schema 子集强制验证；pre-policy→审批→monotonic guard→执行→结果归一化 | schema 校验及类型转换；输出截断响应的整批调用拒执行；默认无权限系统 | 优先采纳 **DSH 的统一管线、Pi 的截断调用保护**，保留 MoonCode 精确 grant 绑定 |
| **4. 死循环与重复动作** | 已硬拦截重复失败验证、重复完整读取、发现饱和；缺通用状态循环检测 | 有计划/目标提醒；无通用动作指纹检测器 | 默认第 3/5/8 次相同调用提醒；**不会阻断**，不识别状态进展 | CLI 无通用检测；Durable `restartLimit=5` 防连续崩溃，VM 指纹用于重放兼容性 | 合并为**动作身份＋资源版本＋结果＋进展**检测；保留精准补读例外，避免把合法重复检查误判为循环 |

工具管线最值得参考 [DSH](/Users/kq/Workspace/dsh/docs/tool-execution-pipeline.md:5)；MoonCode 当前循环与目标边界见[运行契约](/Users/kq/Workspace/moonclaw/cmd/daemon/mooncode_capabilities.mbt:37)，Pi 的截断调用保护见[主循环](/Users/kq/Workspace/pia/packages/agent/src/agent-loop.ts:462)。

**5–8：上下文、多 Agent、并发与重启恢复**

| 问题 | MoonCode | OpenSeek | DSH | Pia | MoonCode 应采纳 |
|---|---|---|---|---|---|
| **5. 长上下文压缩** | 默认消息后缀压缩；保留任务契约和证据账本；压力驱动压缩默认关闭 | 默认 70% soft / 80% hard ceiling；追加摘要，原日志保留；新 steering 保留原文 | token-meter 计价，考虑输出预留/headroom；保留近期尾部、工具配对；原日志保留 | CLI 默认 reserve 16K、recent 20K；Durable 另有后台压缩；摘要均不保证语义无损 | 借鉴 **OpenSeek 的提前预留、DSH 的完整请求计价、Pi 的后台压缩**；增加关键约束/证据保留检查 |
| **6. 多 Agent 协作** | 普通子会话、隔离根目录、any/all 汇总；调用方提供目录；无通用任务板 | explore/review/worker 子进程；默认最多 16 活跃、8 worker；支持 worktree/目录模式与结果捕获 | Subagent 管树；Team 提供 DAG、owner、revision；**新 Session 的 Team 默认关闭** | CLI 通过可选扩展；Durable 有任务所有权、持久等待、failFast/allSettled；P2 为实验应用 | **OpenSeek 的工作区生命周期＋DSH 的任务 revision＋Durable 的所有权/取消传播** |
| **7. 同文件/资源冲突** | 会话 execution lease 不等于文件锁；同批 worker 根隔离；缺全局资源协调 | 路径预留、仓库 mutex、目录重叠检查；部分协调仅进程内 | Team writeScopes **仅告警**；fs 目标锁进程内；读后写版本策略在 base 默认关闭 | 文件 mutation queue 进程内；bash/其他进程可绕过；Durable storage 假定单 owner | 自动准备隔离 worktree；共享写入使用 **版本检查＋短资源锁**；Git/安装/构建目录分别确定锁粒度 |
| **8. 崩溃与 checkpoint** | journal＋planner continuation，可保留已完成结果；外部副作用仍有未知结果窗口 | 日志有同步、尾部修复、stale snapshot；恢复会话，不恢复执行指针；可发现遗留 worker | 持久 inbox、跨进程 Session 写锁、请求/顶层工具前 flush；仍有根关闭时末尾事件丢失限制 | CLI 主要恢复历史；Durable 保存 task phase、sleep/wait、结果；只重跑 `replay:"safe"` 工具；**storage 无跨进程锁** | 优先采纳 **Durable 的阶段状态和 replay 声明、DSH 的副作用前 flush**；继续保留 MoonCode 的跨进程执行所有权 |

这里没有现成的“任意动作 exactly-once”方案。尤其不能把 Durable 的 replay-safe 声明或嵌套 key 去重直接等同于外部系统幂等。[Durable 恢复](/Users/kq/Workspace/pia/packages/durable/README.md:245)

OpenSeek 的 worktree/路径预留机制值得借鉴，但其[registry 明确不是跨进程锁](/Users/kq/Workspace/openseek/agent_subtask/registry.mbt:2)。DSH 的[读后写检查默认关闭](/Users/kq/Workspace/dsh/packages/fs/tool-fs/README.md:30)，也不应直接照搬其默认值。

**9–12：人工介入、工具可靠性、MCP 与检索**

| 问题 | MoonCode | OpenSeek | DSH | Pia | MoonCode 应采纳 |
|---|---|---|---|---|---|
| **9. 驳回与超时** | 待审批及 continuation 持久化，绑定具体参数；拒绝原因回灌；超时不自动同意 | 默认 `never`；人工 ask 无超时；自动 reviewer 有 5 分钟期限；无法决定转人工或拒绝；等待在内存中 | allowed-once/rejected/cancelled/unavailable 四态；默认 ask，无 answerer 则拒绝；普通问题另有 pending 语义 | CLI 审批由扩展提供；Durable 可承载持久人工流程，但宿主自行实现 | 采纳 **DSH 的结果枚举与审计配对**；借鉴 OpenSeek 可选 reviewer；保留 MoonCode 持久等待，明确授权失效规则 |
| **10. 大结果、失败、重试、熔断、幂等** | 有输出限制；部分模型 transport 可持续重试；缺统一工具重试/熔断 | 12K 内联、超出 spill，sink 有硬上限；模型有界重试；MCP timeout | base 约 12.5K token retention；spill 失败可保留原文，非绝对硬限制；工具 timeout 为协作取消 | 工具常见 2,000 行/50KB；MCP 20KB；Durable 有持久退避、调用 key 与 replay 策略 | 分开设计**捕获上限、模型保留上限、原文存储**；统一失败分类；未知副作用先查状态；熔断另做服务级策略 |
| **11. Function Calling、MCP、工具发现** | 动态工具包/搜索可选，默认关闭；deferred 搜索最多 5 个；MCP list/call | MCP 不进入完整 function list；脚本下载目录，BM25 检索再调用 | 默认 native，PTC 可选；有 provider 的 deferLoading 透传，无通用本地 BM25 发现 | MCP 默认 codemode；支持 direct/deferred/hidden；BM25，默认 8 个；Durable 加载状态可持久 | **OpenSeek 的目录化发现＋Pi 的 exposure/持久加载**；schema、可执行集合和授权必须一致 |
| **12. RAG、query rewrite、rerank** | 已有任务前知识检索：文本打分，可叠加 embedding，最多 12 段；无独立 rewrite/rerank | 无默认通用文档 RAG；可通过工具/MCP 接入 | 无共享 base 默认通用 RAG；上下文注入必须日志化 | 无默认通用文档 RAG；有上下文 transform 和检索工具接入点 | 保留 MoonCode 已有 hybrid；加入**缺口驱动检索、来源版本、召回评测**；rewrite/rerank 没有可直接照搬的完整实现 |

四者都缺统一的工具熔断和外部副作用幂等层。审批“没有回答”、工具“执行超时”和外部动作“结果未知”必须是不同状态。

工具发现可以直接参考 [Pi 的 deferred search](/Users/kq/Workspace/pia/packages/durable/src/tool-search/tool-search.ts:1) 与 [OpenSeek 的脚本目录检索](/Users/kq/Workspace/openseek/tools_sdk/mcp/mcp.mbt:1)。MoonCode 的[现有 hybrid 检索](/Users/kq/Workspace/moonclaw/cmd/daemon/mooncode_knowledge_context.mbt:2)已有基础，应优先做检索质量验证。

**13–16：安全、评测、归因与流式恢复**

| 问题 | MoonCode | OpenSeek | DSH | Pia | MoonCode 应采纳 |
|---|---|---|---|---|---|
| **13. 注入、危险调用、脱敏** | 有来源元数据、进程 grant 和部分输出过滤；不等于全面防注入/脱敏 | 默认拒绝升级，guest policy＋可选 macOS 写保护；获准子进程不继承 guest 全部限制 | monotonic guard、一次审批、文件效果 sandbox；网络不在模式范围；遥测脱敏 hook 默认无规则 | 默认无权限系统；QuickJS 隔离脚本，宿主工具仍有权限；无全路径自动脱敏 | **DSH 的不可放宽策略检查＋Pi 的受限 code VM＋OpenSeek 的类型化命令构造**；授权始终在宿主执行端 |
| **14. 成功率、工具错误、成本、耗时** | 有 provider usage、评测证据及分阶段回放；未证明有完整线上指标平台 | usage、缓存、匿名 A/B、阶段 p50/p95；缺完整线上业务指标 | Session ledger/ops、OTel、产品遥测；投递可丢失/重复；需接收端去重 | typed AI/Durable spans、首 chunk、token、cost；默认可 NOOP；`done` 可早于 afterRun 验证结束 | **Pi 的类型化指标＋DSH 的导出层＋OpenSeek 的分阶段对照评测**；成功以独立验收定义 |
| **15. badcase 归因与回归** | 已有工具/编辑 harness、失败诊断和回归测试；无自动根因分类 | 匿名 baseline/variant 回放，适合成本/行为回归；不能替代真实模型实验 | 录制 Session 回放、工作区结果检查、真实 API smoke | 隔离容器行为 eval、with/without docs 对照、重复实验 | 保存**完整因果链和版本**；借鉴 DSH 回放与世界状态断言、Pi 隔离对照实验；固定变量逐层归因 |
| **16. 流式推送与断线恢复** | 后端有 JSONL/SSE、序号和可选 typed cursor replay；MoonDesk 当前主要长轮询快照 | 类型化 JSONL；Web 重连 resync；无连接事件重放；重发 prompt 不去重 | follow 先监听再取 snapshot，按 cursor 补增量；保留活跃 attempt baseline | CLI 事件流无持久 cursor；Durable 是窗口 watch＋gap 补读；partial 默认约 1 秒持久化窗口 | **DSH 的 snapshot＋cursor＋attempt 身份、Pi 的有界窗口/gap**；保留 MoonCode 权威 journal 与隐私投影 |

不能将“源码里有 sandbox”视为已经安全审计，也不能将 `finish/done` 直接作为任务成功。[DSH 沙箱范围](/Users/kq/Workspace/dsh/docs/subsystems/sandbox.md:9)、[Pi 默认权限](/Users/kq/Workspace/pia/README.md:95)

流式恢复最值得参考 [DSH follow 的订阅顺序](/Users/kq/Workspace/dsh/packages/api/session-controller/src/web/controller.ts:27)；Pi Durable 的窗口机制能控制长会话成本，但其[partial 延迟持久化窗口](/Users/kq/Workspace/pia/packages/durable/README.md:523)必须明确展示为恢复限制。

**MoonCode 的建议采纳顺序**

| 优先级 | 采纳内容 | 来源 | 验收重点 |
|---|---|---|---|
| **P0** | 统一工具调用管线：参数验证、授权、grant、执行、结果归一化；截断参数整批拒执行 | DSH＋Pi | native、MCP、嵌套调用都经过检查；hook 重排不能放宽授权 |
| **P0** | 明确 `planned/running/succeeded/failed/outcome_unknown` 等操作状态；工具声明 replay 策略 | Pi Durable＋DSH | 在副作用前后各崩溃一次，确认已完成动作不重跑；未知结果进入查证 |
| **P0** | 自动准备 worker worktree；任务 revision；共享资源版本检查与短锁 | OpenSeek＋DSH | 两个会话竞争同文件、Git index、构建目录时不静默覆盖 |
| **P1** | 请求级 token 压力计价、摘要预留、关键约束/证据保留检查 | OpenSeek＋DSH＋Pi | 压缩后仍能完成原任务；减少重复发现；统计摘要成本与缓存损失 |
| **P1** | 类型化 trace、父子成本、失败类别、真实验收器与回归集 | Pi＋DSH＋OpenSeek | 区分运行成功和任务成功；覆盖重试、摘要、子 Agent 与未知 usage |
| **P1** | typed snapshot/cursor/attempt 流；长会话窗口与 gap 补读 | DSH＋Pi Durable | 断网、重启、切会话、慢客户端均不丢已提交结果或串台 |
| **P2** | 大工具目录 BM25、持久按需加载、可选 code mode | OpenSeek＋Pi | 比较 schema tokens、发现延迟、工具选错率；收益覆盖 VM/存储开销后启用 |

**采纳时应保留的 MoonCode 优势：**

- Goal 的 criteria/evidence 与普通 `finish` 分开结算。
- 会话执行 lease 和单一 journal 顺序。
- 具体动作、参数与 sandbox grant 的绑定。
- 已有的状态相关重复验证拦截。
- 已有 hybrid 知识检索与证据引用。

所有运行时改进应落在 **MoonClaw**；MoonDesk 承接状态、审批和结果展示。对 MoonCode 最有价值的是把这些已有保证连成一致链路，再按实测收益增加编排复杂度。


