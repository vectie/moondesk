# MoonCode 剩余 token 浪费复查（2026-11-06）

本次继续核对[上一轮 382,588 input tokens 的完整日志](MOONCODE_TOKEN_AUDIT_2026-11-06.md)。只修改已观察到的上下文重复、SDK 配置和快照保真问题；复用现有模型请求、技能目录、journal 和执行器，没有新架构、状态机、人工确认、预算 gate 或重试框架。

## 逐轮归因

上一轮 session `mooncode-cost-basename-fixed` 有 16 次响应、19 个工具结果，input 382,588（缓存 29,568）、output 2,620，235.327 秒至 finish。

| 观察 | 原因与边界 | 本次处理 |
| --- | --- | --- |
| 第一轮只调用 read_skill；第二轮 input 从 3,295 增至 14,135 | 技能目录要求“任务匹配描述就必须先读完整 SKILL.md”。通用 MoonBit 指南正文 34,084 字符，模型结果 36,103 字符，在后续 15 个请求中反复携带。用户没有指定这个技能，项目也没有在这次 prompt 中要求它。 | 删除框架按描述匹配就强制加载的门槛。用户／项目要求仍须遵守；其他技能在需要其工作流或参考资料时加载。选中技能仍读完整正文，不截断、不改个人技能文件。 |
| 最终全仓测试 stdout 394 字符，模型结果 19,690 字符 | 前一轮已去掉 sandbox changes，但另一份 `verification_inputs` 仍有 17,322 字符。另有重复 shell 命令及内部 grant/run/profile digests。 | 在现有模型投影中去掉这些内部副本；原检查输入、版本关联、签名和完整结果仍在 journal，Completion 仍读原始事实。保留输出、错误、状态、指纹、执行边界、artifact、evidence_ref。 |
| 证据 ledger 最终 7,897 字符 | 已有完整工具消息，又复制历史命令、输出摘要和 hash。 | 删除 successful_inspections 及其摘要 helper；保留紧凑读取路径／完整性和失败索引。原始输出由已有 read_result 回查。 |
| 每轮重发 task＋最近四项结果 | 当前 task 前缀已经刷新且受 Context 保护，工具历史也在。第二份自动进度没有提供新事实。 | 删除 progress message 及专属 summary/latest-checkpoint helpers。跨 command 的已保存 checkpoint 放入现有初始 task prompt；本轮 checkpoint 的完整工具结果保留。 |
| 默认 IDE outline 失败，随后 shell 探索 | 私有 HOME 没有 Moon SDK registry；只修 PATH 还不够。同一执行器明确设置 MOON_HOME＋SDK PATH 后成功。 | macOS 既有 local invocation 从已绑定并解析的 `/bin/moon` 路径定位 SDK 的 MOON_HOME，保留私有 HOME。没有继承宿主环境、新增配置字段或扩大读权限。 |
| 未改两个脚本却显示 Git 修改 | snapshot 把可执行文件统一复制成 0600，丢失 execute bits；模型误当用户改动。 | 现有复制保留源 fd 的 execute bits，仍为私有文件。复用现有 C stub，未增加公共文件系统 API。 |

工具 schema 每次约 10,607 字符，完整 skill、已读源码和测试也是每轮输入的一部分。字符大小不能直接当 provider tokens；这些数据说明少量解题输出仍可能对应很大的累计输入。不能靠把已加载的用户／项目指令截断来制造低成本结果。

两次修改后的测试失败都是真实业务回归，不能删除测试或伪装成功。源码与调用方的观察不足由模型修复；没有给执行器增加“必须先读某文件”的解题规则。上一轮最后的 Git 检查也有实际价值，不将所有补读统统计为浪费。

## 固定历史对照

保持原 16 次模型响应的动作、原指令和技能正文，只应用本次 metadata 投影、紧凑 ledger 和删除重复 progress。总序列化消息字符 **1,392,406 → 1,216,613，减少 12.6%**；最后一次 **137,833 → 100,734，减少 26.9%**。

该回放没有调用模型，也没有预测删去强制技能加载后模型会怎么行动；不能称为 token/费用节省。临时回放测试通过后删除，源文件与逐请求结果保留在私有证据目录。

## 同一历史真实 bug 的完整仓库复测

直接使用现有 MoonLib main（HEAD `74ab34f`），没有 clone 或源码副本。因当前 main 已修过 basename，明确恢复 `f2cfdd9` 的 `pathx/path.mbt`，保留 main 的三条验收断言，复现同一历史真实 bug；不是宣称又发现一个新缺陷。保存每次交付文件后再恢复相同起点。红测试均为 11/12。

使用相同 prompt 字节、模型 `codex/gpt-5.6-sol`、OAuth / chat_completions、执行器配置、完整仓库和 Shell 环境；只更换 session / command ID。启动后没有 steering、人工业务补丁或测试接管。模型非确定、文件系统／provider 缓存和宿主负载不同，不能把整单差额全部归因于某一行代码。

### 第一遍：上下文／SDK／快照修复后

Session `mooncode-cost2-basename`：**12 响应，248,354 input（缓存 32,512）/ 2,599 output**，planner latency 81.335 秒，外层 model retry 0。接受 `1793961357103` → finish `1793961611417`，**254.314 秒**。相对前一轮 input 少 35.1%，耗时却增加，不能称为全面提速。

20 个工具结果，16 成功 / 4 失败：原始红测试 1、修改后的 replace_ext 回归 1、1,200,000ms 超过已有 600,000ms 上限的拒绝 1、Git transport timeout 1。IDE 实际成功，Git 正确只显示 path.mbt，脚本 mode 噪声消失。模型两次 edit 修好业务，再通过 Native 定向 12/12、全仓 108/108、info/fmt 和 Git 检查。一次 Git 超时后由模型补读文件并以更长等待重新检查。

Git 原命令以相同 20 秒 grant / 25 秒外层等待独立重放成功；没有原调用的已保存 audit receipt。该单次超时原因尚未确定，不扩大全局 timeout、不新增重试或恢复状态，也不把它写为已修复。完整失败成本保留。

### 最终一遍：再删除自动技能加载门槛

Session `mooncode-cost2-skill-choice`：**11 响应，213,432 input（缓存 10,752）/ 2,144 output**，planner latency 67.982 秒，外层 model retry 0。接受 `1793962301730` → finish `1793962485712`，**183.982 秒**；service idle 为 185.421 秒。无运行中人工接管。

| 观测 | 上一轮 | 本次第一遍 | 删除技能门槛后的最终遍 |
| --- | ---: | ---: | ---: |
| 模型响应 | 16 | 12 | **11** |
| input tokens | 382,588 | 248,354 | **213,432（比上一轮少 44.2%）** |
| cached input（已含在 input） | 29,568 | 32,512 | 10,752 |
| output tokens | 2,620 | 2,599 | 2,144 |
| 非缓存 input | 353,020 | 215,842 | 202,680 |
| 接受到 finish | 235.327 秒 | 254.314 秒 | **183.982 秒** |
| IDE 失败 | 1 | 0 | **0** |
| Git transport timeout | 0 | 1 | 0 |
| 成功业务 edit／修改后的测试失败 | 3／2 | 2／1 | **2／1** |
| read_skill 调用 | 1 | 1 | **1** |

最终 18 个工具结果，15 成功 / 3 失败：原始红测试 1、真实 replace_ext 回归 1、过大 timeout 拒绝 1；后两项都由模型自行处理，最后 Native 12/12、全仓 108/108、info/fmt 和 Git 检查实际通过。IDE 成功，Git 仅显示业务文件，未再声称存在用户脚本修改。

**删除自动技能门槛后，模型仍主动选择读完整指南。** 因而本例没有证明该策略删除省掉了技能输入，也没有证明最后两遍差额由它造成。技能正文继续完整携带；尚未把这个小任务降到足够轻量。剩余输入包含已选择的长指南、源码/测试、完整工具 schema 和 11 次模型往返。此处不继续添加策略或裁剪指令追求一个低数字。

本轮两遍完整实验合计 **461,786 input（缓存 43,264）/ 4,743 output**。这是排查和对照本身的实际代价；单例降幅不能抵消或覆盖实验总账。启动前一次连接拒绝未接受任务、没有模型 usage，随后确认新的 daemon status 才提交；没有重置进行中的任务。

## 验收与证据

- MoonClaw Native **1844/1844**，包括既有完整技能加载／引用、上下文压缩、checkpoint 续跑及验收用例。技能仍能完整加载，不再测试通用 prompt 必须强制调用的句式。
- MoonFort Native **298/298**，包括要求真实 local E2E。既有 E2E 增加可执行脚本：旧复制方式实际 Permission denied（0/1），修复后 1/1。增加一个小型 SDK 定位回归，未新增 fixture 框架。
- 实际执行器单独复现默认 IDE 失败、显式 SDK 成功；修复后不加 Shell 环境的同一 Exec outline 成功。只读 Git snapshot 不再显示原有脚本 mode 差异。
- 独立验收最终业务 Native **108/108**、pathx JS **12/12**；Desk Native consumer **1726/1726**。协调者只在既有 basename 测试追加 `/// → /`，覆盖最终相对 HEAD 新增的全斜杠分支，未改写模型实现。恢复历史 bug 后的实际修改不能用“相对已修复 HEAD 只有一行 diff”掩盖；两遍实际均为两次模型 edit、一次 post-edit 测试返工。
- Info/fmt 与生成接口检查完成，无公共 API 变化；Fort formatter 的无关旧语法迁移撤回，原有 SQLite 工作台改动保留。生产代码合计净减 **75 行**（含新增 6 行既有 C stub），测试净增 35 行；扩展真实执行路径，不新增 package。
- 原 382K session journal 与两次新 journal 均位于 MoonLib `.moonsuite/products/moonclaw/mooncode/sessions/<session>/journal.jsonl`。私有 `/Users/kq/mooncode-cost2-20261106` 保存 prompt、canonical、逐轮归因、回放、metrics、原交付文件和执行器 receipts；凭据不提交。新会话结束后记录 SHA-256 并停止专用 daemon。
- SHA-256：原 382K session 保持 `35bb269eb9e42877a57aae607cf8042ae5a0c29a19b2df2e1b9bd148ba593d08`；本次第一遍 `c9a0a9d41a50784de2b62287f3b0f5b0d70ae18f741c7a1a073b6aedb1189b12`；最终遍 `19709ebb2a79847debfff75a02aa491cfffc759a76d26dc9ac81b5b438a8bc2e`。专用 daemon 已停止。
- Cash 费用未知，已观测 input 包含缓存，不将缓存重复相加；未返回 usage 的潜在费用、本聊天协调模型、预检和构建不在 provider 用量里。等待编译锁／链接和一次服务未就绪的连接拒绝发生在最终任务被接受之前，未消耗该任务模型 tokens；不计入接受至 finish 的墙钟。

所有真实尝试都保留；不会为了更低的数字继续重跑。这里验证实际缺陷修复与单例成本变化，不据此推导总体线上成功率。

提交：MoonClaw `f9a1a356`、MoonFort `7659802`、MoonLib `5545645`；本报告、索引和 checklist 随 MoonDesk 同次 main 提交。四仓全部 remote 推送并核对 main HEAD；用户原有 Fort 工作台改动未提交。
