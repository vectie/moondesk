# MoonCode 三轮 token 审计与同类任务复测（2026-11-06）

后续对 382,588-input 样本的继续复查与修改见[第二轮审计](MOONCODE_TOKEN_AUDIT_FOLLOWUP_2026-11-06.md)。本文保留当时原始观测，不用新结果覆盖旧成本。

简单业务修改不等于廉价交付：前三轮只有 6,350 output tokens，却累计读取 2,294,816 input tokens。主要浪费来自失败后的模型往返、重复携带累计状态，以及把执行器内部的完整变更明细发给模型。问题发生在上下文窗口之内，不能靠再加 compaction 门槛解决。

本次仅修改现有结果投影、follow-up 构造和报错透传，删除误判管道失败的策略；没有新架构、状态机、重试限制、预算 gate、人工确认或工具。

## 三轮原始日志

与[完整仓库 Native 交付记录](MOONCODE_LIVE_NATIVE_REPOSITORY_2026-11-06.md)使用相同三轮 journal。未重写原历史，也未将前两轮失败移出成本。

| session 后缀（前缀 mooncode-live3-） | 响应 | input / cached input | output | 工具成功 / 失败 | 命令接受至停止 / finish |
| --- | ---: | ---: | ---: | ---: | ---: |
| dotfile | 16 | 477,443 / 181,248 | 1,910 | 7 / 11 | 102.768 秒，取消 |
| native-dotfile | 22 | 1,309,304 / 442,368 | 2,823 | 12 / 14 | 243.390 秒，取消 |
| native-complete | 11 | 508,069 / 116,096 | 1,617 | 11 / 4 | 104.580 秒，完成 |
| 合计 | **49** | **2,294,816 / 739,712** | **6,350** | **30 / 29** | 两次环境返工保留 |

缓存已经包含在 input 中；非缓存 input 为 1,555,104。外层 model retries 为 0：这里的大部分重试是模型收到工具错误后新发起的调用，不能用 SDK retry 指标代替它。

### 工具失败与重复探索

- 第一轮失败 IDE 1、shell 8、moon_cmd 2。绝对 SDK 字符串禁令和私有 HOME 下缺少 registry 阻断测试，模型不断换命令；第二轮失败 read 1、IDE 1、shell 12，执行器扫描竞态与固定 `/tmp` 测试夹具又阻断全仓验证。前一项禁令及后两项实际问题已在上一轮修复。
- 第二轮**相同完整 Native 命令提交 8 次**，有的改变 timeout。反复更换包装无法修复底层部署和扫描问题。对 path.mbt / 测试的重复读取也存在，但编辑后的补读有意义，不能统统计为无效探索。
- 第三轮仍有 IDE 1、shell 3 失败，涉及默认 metadata、Git/xcrun/系统配置。业务已修好，环境失败继续制造模型往返。本次对照使用既有 Shell 的直接 CLT Git、`GIT_CONFIG_NOSYSTEM=1` 和 `export`，没有添加环境 API。默认 IDE/moon_cmd 不继承这段 Shell 环境，仍有部署缺口。
- 一些管道只为观察输出，进程真实 exit 0；旧实现根据 verification 字段或命令关键词将它改写成工具错误。删除该改写和关键词 helper，保留 `pipeline_exit_ambiguous` 及既有验收提示/证据排除。观察成功与证明测试通过仍然分开。
- MoonBit 实测测试失败 exit code 为 2，工具目录原文却提示 1；修正描述，不改变默认成功码或检查条件。

### 上下文为什么膨胀

1. **完整内部执行明细进入模型。** 第三轮全仓测试 stdout 只有 **395 字符**，规范 tool result 却有 **327,569 字符**；metadata 327,053，其中 sandbox evidence 325,624，包含 **748 个 changed_paths 及 748 条 changes**，主要是编译产物。定向测试 stdout 40 字符，result 29,075 字符。编辑 receipt 还附带整文件前 80 行的 before/after，不是一行改动对应的小 diff。
2. **累计视图被反复追加。** 最后一轮最终请求包含 **10 份 horizon_progress、9 份 evidence_ledger**；第二轮为 **21 / 20**。每一份都累计前面结果，下一轮没有替换旧版。模型同时读到多份过时状态，后期成本随回合增长。
3. 第三轮每次 input 为 `3366, 14291, 19249, 21644, 24169, 27207, 31895, 41986, 45121, 138108, 141033`。最后两次合计 279,141，约占全轮 55%，时间上紧随全仓大 receipt。不是宣称这 55% 全由一个字段造成。
4. input budget 为 300,000；旧最终请求估计 142,741，第二轮最终 257,568，均未触发裁剪。**这是窗口内的重复和无关输入，不是窗口超限故障。** 已加载 skill 正文约 34,084 字符，工具 schema 约 10,557 字符，也占成本；前者是实际工作指令，未盲目截断，后者本次没有另造工具检索层。

## 最小修复与保留事实

- MoonClaw `mooncode_runtime_model_planner.mbt`：构造 follow-up 时移除旧的 evidence_ledger / horizon_progress，然后按现有逻辑构造最新版。按已有 provenance 判断，不按消息文字猜测。
- 同文件现有 tool result 投影：对复制的 metadata 去掉 sandbox 的 `changed_paths / changes / requested_policy`，保留变更数量；native 文件修改结果不再重复携带整文件 diff。真实输出、错误、exit code、指纹、enforcement、cleanup、artifact 和 evidence_ref 保留。
- **原始 tool result、journal、UI 明细和既有 read_result 回读不变。** 没有全局截断、删原记录、摘要模型调用或新缓存。结果可回查，不靠重跑副作用补回信息。
- MoonClaw `mooncode_process_tools.mbt`：删除“观察管道 → 假失败”的分支及关键词 helper；原来的真实结果和证据资格规则复用。
- 实跑又发现 `publish_pending_grant` 丢弃 publisher 的 error，只返回通用拒绝。改为透传现有 code/message；MoonFort 原校验消息补上 requested/ceiling 数值。权限、上限、grant、重试语义未改。
- 回归扩展已有用例：二次 follow-up 只有一份累计视图、投影不修改原始事实且保留回读引用、观察管道不伪装失败、publisher 具体错误可见。替换旧的环境未配时即跳过的管道测试；未新增测试框架。

连同模型交付的 MoonLib 修复，三仓生产 MoonBit 合计净减 3 行；测试合计净增 46 行，均扩展/替换既有用例，没有新增 package。没有通过大规模删功能、删实际验收或重新分层制造减法。

## 固定历史的对照回放

按原 49 个不同 model_response_id 取各自已记录的 model_messages；保持原动作、目标、指令和工具输出，只应用上述投影与累计视图替换。没有调用模型，也不预测不同 prompt 会生成什么动作。

| session | 所有请求序列化消息字符，旧 → 新 | 最后一次，旧 → 新 |
| --- | ---: | ---: |
| dotfile | 1,764,170 → 1,243,261 | 170,759 → 100,722 |
| native-dotfile | 4,943,960 → 1,987,101 | 992,856 → 125,362 |
| native-complete | 1,875,717 → 796,803 | 535,728 → 100,937 |
| 合计 | **8,583,847 → 4,027,165，减少 53.1%** | |

这统计 durable message JSON（含 provenance）字符，不是 provider token、HTTP body 或现金费用。私有 `context-replay-final.json` 保存逐请求数值，`replay-source.mbt` 保存临时回放源；测试执行后移除，没有将用户 journal 固化成产品 fixture。

## 真实同类任务：basename 多尾斜杠

直接使用现有 MoonLib **main** 全仓，基线 `f2cfdd9`，同一真实 `codex/gpt-5.6-sol` / OAuth / chat_completions、同一 LocalOs / AllowDegraded 执行器。协调者只在既有 basename 测试补 `docs/// → docs`、`资料/// → 资料`、`/ → /` 三条失败断言；模型自行修复和验证。既有测试 12/12，加入断言后 11/12，执行器全仓预检 107/108。没有源码副本、分支、模拟调用或额外 Agent。

第一遍 session `mooncode-cost-basename` 已用精简投影，但尚未修复 publisher 错误丢失。模型请求 1,200,000ms，已有部署上限 600,000ms。**18 次 shell 拒绝只看到同一句通用错误**，模型反复尝试。协调者停止服务，修复上述两处诊断并重启；沿既有 journal / continuation 恢复同一 command，不追加 prompt、不改业务补丁。看到一次带数值的拒绝后，模型降低 timeout，Native 全仓 108/108 并 finish。

| 第一遍阶段 | 响应 | input / cached | output |
| --- | ---: | ---: | ---: |
| 诊断修复前 | 29 | 767,013 / 48,256 | 4,608 |
| 原任务自动恢复后 | 4 | 151,011 / 10,752 | 796 |
| 第一遍完整成本 | **33** | **918,024 / 59,008** | **5,404** |

命令接受 `1793947363013` 至 finish `1793947862670`：**499.657 秒**，包含 185.648 秒停机修复间隔；planner latency 合计 198.018 秒，外层 model retry 0。38 个工具结果，15 成功 / 23 失败：18 次通用拒绝、1 次带数值拒绝、2 次真实回归测试失败、1 次缺失文件读取、1 次 IDE 失败。模型 3 次成功业务 edit，先后两次破坏既有 replace_ext 断言再自行修复；协调者没有改写实现。独立 Native 108/108、pathx JS 12/12。

这遍 input **高于**旧成功轮 508,069，耗时也高于 104.580 秒，不能宣称整单降本。它验证了小上下文仍会被无信息错误的重复往返拖累。完整 Native 的原始 result 仍为 343,201 字符（stdout 394、748 个变更），但模型不再接收其完整内部明细；最后一次实际 input 为 42,176，没有旧轮 141,033 的尾部膨胀。任务和历史不同，此处不作为严格 A/B。

### 诊断修复后的相同任务重跑

先保存第一遍交付文件，恢复 HEAD 的业务实现、保留完全相同失败断言和 prompt，以新 session `mooncode-cost-basename-fixed` 执行。新 command 为 `cost-basename-fixed-1`，原 prompt 字节不变，仍由模型选择 timeout。完整仓库、模型、执行器配置和 Shell 环境保持相同；模型非确定，磁盘/缓存状态不承诺相同，这不是统计显著性实验。

| 观测 | 第一遍（含运行时修复） | 修复后重跑 |
| --- | ---: | ---: |
| 响应 | 33 | **16** |
| input tokens | 918,024 | **382,588（少 58.3%）** |
| cached input（已含在 input） | 59,008 | 29,568 |
| output tokens | 5,404 | 2,620 |
| 非缓存 input | 859,016 | 353,020 |
| 接受到 finish | 499.657 秒 | **235.327 秒（少 52.9%）** |
| planner latency 合计 | 198.018 秒 | 113.018 秒 |
| 通用无原因拒绝 | 18 | **0** |
| 带数值 timeout 拒绝 | 1 | 1，下一次即降到允许范围 |
| 成功业务 edit / 修改后的测试失败 | 3 / 2 | 3 / 2 |
| 运行中人工接管 | 1 次修复运行时并重启 | **0** |

重跑共 19 个工具结果，14 成功 / 5 失败：IDE 1、原始红测试 1、修改后的真实回归失败 2、带数值 timeout 拒绝 1。两次代码回归被模型自行修正；不是一次改对。成功 shell 5 次，最终 Native 定向 12/12、全仓 108/108，info/fmt、接口检查和 Git diff 检查有实际结果。最终 finish / canonical done；没有协调者改写业务实现或接管测试。独立 Native 108/108、pathx JS 12/12 再验通过。

接受 `1793948527575` → finish `1793948762902` → service idle `1793948763556`，后者为 235.981 秒。外层 model retry 0。启动时协调者遗漏已有 control 环境，三次 HTTP 503 均在任务被接受前、未调用模型；补齐原部署环境后一次任务被接受，未改认证实现。

相对旧第三轮 **508,069 input / 104.580 秒**，本次为 **382,588 / 235.327 秒**：输入少 24.7%，耗时更长。两个不同 bug 的业务返工不同，不能宣称速度全面提高。相同 basename 任务的下降与不透明拒绝消失吻合，但没有把差额全部归于单一代码行。

本次两遍合计 **1,300,612 input / 8,024 output**；连同旧三轮共 **3,595,428 input（缓存 828,288）/ 14,374 output**。排查和对照本身花费这些 tokens，不能用最后一遍覆盖总成本，现金费用仍未知。没有继续重跑挑更低样本。

## 验收、证据与剩余问题

- 回归：MoonFort Native **297/297**，MoonDesk Native **1726/1726**，MoonClaw 最终 Native **1844/1844**。Claw 前一次 1843/1844 的唯一失败是旧通用错误断言，更新后该用例及全套通过。三仓集合不相加。
- 四仓 info/fmt、生成接口和空白检查；Fort formatter 自动迁移无关旧语法已撤回。没有公共 API 变更。用户原有 SQLite 工作台改动未纳入提交。
- 三轮原 journal 的位置与 SHA-256 保持[原交付记录](MOONCODE_LIVE_NATIVE_REPOSITORY_2026-11-06.md#独立验收与证据)所载。新 journal 位于 MoonLib `.moonsuite/products/moonclaw/mooncode/sessions/<session>/journal.jsonl`；第一遍 SHA-256：`7c5fd29b3973da8b6c73f31603088353918772a8c2c2840842cc4449ec3901ff`。
- 修复后重跑 journal SHA-256：`35bb269eb9e42877a57aae607cf8042ae5a0c29a19b2df2e1b9bd148ba593d08`。两遍分别保存 final-audit.json、request/submitted/canonical；daemon 已停止。
- 私有 `/Users/kq/mooncode-live3-20261106` 保存旧三轮审计/回放；`/Users/kq/mooncode-cost-20261106` 保存本次请求、canonical、metrics、实际发布文件及配置。凭据和原始 journal 不提交。
- Cash 费用未知，缺失取消响应的 usage 不推为零，本聊天协调模型不在 provider 合计中。相同任务重跑的墙钟从被接受的新 command 起算；启动配置排错、文档和 Git 交付另计。
- 仍有默认 IDE metadata / moon_cmd 环境缺口。另观察到 Fort 快照文件统一以 0600 创建，导致 `.git` 中原有可执行脚本显示 mode 变化；真实 main 中这些脚本未改。模型第一遍声称保留“用户脚本修改”，实际是快照噪声。此问题记录待修，未借 token 审计扩展权限/文件系统实现。现有 LocalOs 仍为 Degraded，不新增隔离能力声明。

本次归因以实际字段大小、调用序列和 provider usage 为证据。减少重复输入已经得到固定历史的验证；总体交付成本、泛化成功率仍需更多任务，不能由单例或回放直接推导。

提交：MoonClaw `943b5abe`、MoonFort `a36a2b9`、MoonLib `74ab34f`；本报告、索引和 checklist 随 MoonDesk 同次 main 提交。四仓全部 remote 推送后核对 main 的 HEAD；Fort 用户原有工作台改动保留在工作区。
