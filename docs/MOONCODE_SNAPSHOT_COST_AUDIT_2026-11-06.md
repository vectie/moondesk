# MoonCode：快照、重复取数与往返复查（2026-11-06）

本轮没有达到降低总 token 的目标。一次真实同类历史 bug 复测为 **91,539 input / 1,679 output，10 次响应，169.897 秒**；相比上次 74,750 input 增加 **22.5%**。没有重复清理快照，但超时重试、业务返工与分开的最终复核抵消了收益。仅做两处小修改，未新增架构、执行状态、人工确认、工具禁令或测试门槛。

## 日志证明了什么

对照[上一轮完整技能实验](MOONCODE_SKILL_COST_AUDIT_2026-11-06.md)的八次响应和本轮规范 journal：

| 项目 | 上次 | 本次 | 判断 |
| --- | --- | --- | --- |
| 测试文件读取 | 1 次，181 行 | 1 次，181 行 | 必要上下文，没有重复读取 |
| 实现文件读取 | 1 次，140 行 | 1 次，130 行 | 不能靠强制缩短读取来追求低成本 |
| AGENTS.md | 缺失，读取失败 | 同样缺失 | 正常项目指令查找，不添加特殊绕过规则 |
| 快照清理 | 新 Shell 执行 `rm -rf .tmp` | 0 次 | 后续 Shell 不会进入前一个快照，旧调用无效 |
| Shell 超时 | 0 | 1 | Agent 自行换较窄命令重试成功，全部计费保留 |
| 修改后测试失败 | 0 | 1 | 首次只改 basename，遗漏 replace_ext 的纯斜杠语义；第二次 edit 修复 |
| 最终复核 | 与全仓测试在同一 Shell | 全仓测试后另一次 Git 状态/diff | 可以合并的已知序列；实际由模型分开选择 |
| 通用技能 | 完整加载 | 未加载 | 模型选路不同，不将其当作本次代码收益 |

本轮没有对实现/测试重新读取。第一次 grep 未收到结果后的重试也不能算重复消费成功结果。修改前 diff 与修改后 diff 针对不同文件版本，保留其验收意义。读取 130 行已经包含 replace_ext；此次遗漏属于模型对已有上下文的使用问题，没有证据要求运行时插入额外 read。

## 最小改动

- [终端结果](../../moonclaw/cmd/daemon/mooncode_execution_sandbox_gate.mbt)明确指出调用使用独立快照，后续调用从 MoonBook 重新开始。沿用原结果 message；无新字段或路径。上一轮已修改 Shell 目录说明，这次首次用于实跑。
- [证据索引](../../moonclaw/cmd/daemon/mooncode_runtime_model_planner.mbt)删除重复的诊断、重试、解题指导，仅说明索引是历史观察、按需复用/补读。主提示和真实工具结果保留；每个索引少 **260 字符**。保留读取范围、完整性、错误和原 journal/read_result，不删除恢复需要的事实。

没有发现需删除的另一套读取/执行实现或专属冗余测试。没有为了删行数删除实际回归断言，也没有加缓存、禁止重读、强制批处理或修改 compaction 阈值。普通 edit 后可以继续执行同批操作；本轮模型分别发出单调用响应，不能把十次响应归咎于运行时强制十个阶段。

**措辞更正：** 实跑的终端结果临时写作 `disposable snapshot (already cleaned)`。随后对照 Fort 的 `retain_execution_result`，发现 cleanup_verified 可以包含受管保留，不等于物理删除所有快照。最终提交改为 `per-call snapshot; later calls start from MoonBook`；现有执行器清理/保留行为完全不变。最终措辞通过既有终端集成检查，未另开付费复测，不能声称这段最终文本已被真实模型采用。原 journal 不改写。此前报告“前次已销毁”的绝对表述由此更正；独立调用不会续接前次目录这个结论不变。

## 完整真实任务对照

沿用原 prompt、模型 `codex/gpt-5.6-sol`、OAuth/chat_completions、执行器和环境配置；只换 session/command ID。在 MoonLib 完整真实 checkout main `be919a0` 恢复 `f2cfdd9:pathx/path.mbt`，保留所有当前验收断言（含 `///`）。这是已知历史 bug 复现，Git HEAD 已有正确实现；不是新未知缺陷，不能外推通用成功率。

新 session `mooncode-cost4-snapshot`，command `cost4-snapshot-1`。只提交一次任务；运行中没有 steering、接管、手工业务修补或第二次挑选更好数字的实验。

| 观测 | 上次 | 本次 |
| --- | ---: | ---: |
| 响应 | 8 | 10 |
| input（已含缓存） | 74,750 | **91,539** |
| cached input | 5,120 | 2,560 |
| 非缓存 input | 69,630 | 88,979 |
| output | 1,685 | 1,679 |
| input + output | 76,435 | **93,218** |
| 接受到 finish | 134.394 秒 | **169.897 秒** |
| planner latency 合计 | 53.610 秒 | 51.706 秒 |
| edit 调用 / 修改后测试失败 | 1 / 0 | 2 / 1 |
| 无效快照清理调用 | 1 | 0 |

本轮 13 个工具结果，10 成功 / 3 失败：缺失 AGENTS、Shell TimeoutError、修改后 replace_ext 测试失败。没有隐藏失败成本或将失败后的修复算作一次成功编辑。随后 Agent 自主定向 Native 12/12、全仓 Native 108/108，检查 Git 状态和 diff，自行 finish。最终实现逐字节等于准备前的已验收 HEAD，无新增业务代码 diff；最终答复只强调工作树干净，未回顾修复过程，本文按实际两次 edit 和一次返工记录。

逐次 input：`3250, 6865, 7239, 9245, 9701, 10247, 10554, 10999, 11548, 11891`。工具目录仍 17 个，schema 为 10,672 字符（上一轮实跑 10,607；此前结束后补充了 Shell 生命周期描述），没有隐藏工具或削弱验收。

证据索引虽逐条缩短，累计字符却从 5,350 变成 6,539：本轮多了响应及错误。每次请求仍带已有源码、测试和调用历史；不能用局部提示减量冒充总成本下降。没有上下文丢失导致补读的证据，也未发生完整技能加载。十次响应全部返回 usage，外层模型重试 0；工具重试包含在以上数值中。

接受 `1793977630544` → finish `1793977804441` → service idle `1793977804737`。现金费用未知，聊天协调、开发编译和测试不在 provider 合计内。Claw 全量测试与任务部分并行，可能影响耗时；不是受控性能实验。

超时没有终端回执，仅有 `MoonFort execution failed closed: TimeoutError`；可信调用器是既有预编译 Fort publisher/executor，不存在每次临时编译该执行器的证据。未确定超时发生在执行器内部哪一步，不据此修改超时上限、增加重试层或删隔离步骤。工具事件 created_at 不能直接当作进程耗时，未以事件时间差编造延迟归因。

## 验收与记录

- MoonClaw Native 全量 **1844/1844**；精简索引的既有 follow-up 测试 **1/1**。最终终端措辞修改后，既有实际授权/回执集成测试 **1/1**。未新增措辞快照或一套镜像测试。
- 独立 MoonLib 全仓 Native **108/108**、pathx JS **12/12**；实现与原已验收版本完全一致。两仓 info/fmt、接口和空白检查完成，公开 `.mbti` 未变。Desk 仅改文档，Fort 无本轮修改，其用户已有工作台改动保留。
- 私有 `/Users/kq/mooncode-cost4-20261106` 保存请求、原文件、动作、逐次 metrics、轮次/证据体积、服务快照；原 session journal 位于 MoonLib `.moonsuite/products/moonclaw/mooncode/sessions/mooncode-cost4-snapshot/journal.jsonl`，SHA-256 `68d1da7753d79ad40b5d3adf94155ffb68cf67860a094980531faa307cec5e15`。凭据和原始日志不提交。专用 daemon 已正常停止。
- checklist 记录此次反例，总体低成本交付仍未勾选。保留此前全部实验，通过[前轮审计](MOONCODE_SKILL_COST_AUDIT_2026-11-06.md)和[更早完整成本](MOONCODE_TOKEN_AUDIT_FOLLOWUP_2026-11-06.md)串联查阅，不覆盖旧样本。

结论限于此次观察：快照清理没有再发生，但没有证明措辞导致它消失；整体成本回升。继续改动须有新的根因证据，不把模型的一次选路失误转成新的运行时门槛。

提交：MoonClaw `22176639`、MoonLib 文档 `1e0d2dd`；本报告及 checklist 随 MoonDesk 同次 main 提交。Fort 无新提交；四仓全部 remote 的 main 一并推送并逐个核对 HEAD。
