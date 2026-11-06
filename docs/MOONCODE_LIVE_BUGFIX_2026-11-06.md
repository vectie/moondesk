# MoonCode 真实 bug 交付记录：目录名称（2026-11-06）

**结论：功能产物通过独立验收；自主验证链未通过。** 真实 MoonCode 模型修复了已有名称显示 bug，并如实披露进程工具不可用；最终测试由评测协调者执行。因此本例不能记为“无需验证接管的自动交付成功”，也不能据此勾选整体线上质量/成本基线。

## 任务与运行范围

- 基线：MoonDesk `4e434256`、MoonClaw `4a431c66`，均为本地 main；没有注入缺陷。
- 缺陷：既有 `display_name` 只处理一个尾随 `/`；`wiki///` 与 `资料 目录///` 返回空串，影响复用该函数的条目名称和标题。
- 验收：分别返回 `wiki`、`资料 目录`，保留原有空输入、单尾斜杠、普通文件、空格及编码样文本的语义；不增加功能。
- 协调者先在既有 `core/types_test.mbt` 加入两个验收断言，当前代码实际失败；原有用例此前通过。模型接收问题和验收条件，没有收到实现方案。
- 从当前 MoonClaw checkout 启动真实 daemon，经 `POST /v1/code/sessions/{id}/turns` 提交普通 prompt；没有 `runtime_tool_calls`、模拟模型、预置修复或 MoonFort 测试夹具。
- catalog selector：`codex/gpt-5.6-sol`；实际使用已有 Codex OAuth 凭据，观测 transport 为 `chat_completions`。没有登录提示或人工审批。
- Session：`mooncode-live-bugfix-20261106-display-name`；command：`live-display-name-bugfix-1`。

本例覆盖需求 → 实际模型 → 工具 → 原生文件修改 → journal → canonical 回复 → 独立产物验收。没有浏览器点击或安装态应用资格验证。副作用执行器未配置，实际 shell、moon_ide、moon_cmd、moon_check 均按现有边界拒绝；没有放宽授权或改用 host shell 冒充 MoonCode 的自测。

## 实际交付与返工

模型读取项目规范和源码，最终通过一次 `apply_patch` 修改 `core/paths.mbt`：先去掉路径两端的 `/`，再取最后一段。没有新增功能或文件；原有实现净减少四行。两个验收断言由协调者预先提供，不能算作模型自行发现的测试。

| 项目 | 实际结果 |
| --- | --- |
| 功能正确性 | 独立 core native 24/24、core JS 24/24 通过；最终完整回归见下文。 |
| 范围控制 | 模型只改 `core/paths.mbt`，没有 commit/push，也没有无关清理。 |
| 代码返工 | 成功应用补丁一次；独立验收后没有再改模型产出的实现。 |
| 工具参数返工 | 两次 `edit` 被错误拒绝，模型随后自行改用既有 `apply_patch`。 |
| 上下文探索 | 18 次 read 指向不存在的猜测路径，均返回实际错误；导航工具不可用后模型继续查找源码。 |
| 进程验证 | 五次进程工具调用被拒绝：moon_ide 1、shell 1、moon_cmd 2、moon_check 1。 |
| 交互接管 | 模型运行中无澄清、审批、steering 或人工代码修正；独立执行验证一次，由协调者接管。 |
| 回复可信度 | 最终回复明确说没有已执行测试结果，未把拒绝回执写成检查通过。 |

共有 **37 个规范工具结果：12 成功、25 失败**。成功为 read_skill 1、read 9、apply_patch 1、finish 1；失败为 read 18、edit 2、上述进程工具 5。`finish` 成功仅表示会话交付，不等于自主测试通过。

## 耗时与成本

以下时间直接来自本次 journal 的毫秒时间戳；时区 Asia/Shanghai。本次 canonical 开始/更新时间为空，不据此估算耗时。文件验收日志只有秒级修改时间，因而独立验收耗时取近似值。

| 里程碑 | 时间 | 距命令接受 |
| --- | --- | --- |
| 命令接受 | 2026-11-06 12:50:22.597 | 0 |
| 首次成功应用功能补丁 | 12:52:05.792 | 103.195 秒 |
| 最终 `finish` | 12:52:27.309 | **124.712 秒** |
| 终态 receipt | 12:52:27.333 | 124.736 秒 |
| service 完成 | 12:52:28.460 | 125.863 秒 |
| core 双后端独立验收完成 | 约 12:52:44 | **约 141 秒** |

16 次观测中的 `planner_latency_ms` 合计 **116.931 秒**。这是既有指标定义的模型请求耗时之和，不是服务端账单时间。外层 `model_retry_count` 合计 0；不覆盖 transport 内部未暴露的尝试。

| 成本项 | 实际观测 |
| --- | --- |
| 模型响应 | **16 次**，16 次都有 usage |
| 输入 tokens | **562,434**，其中缓存输入 **269,312** |
| 非缓存输入 tokens | **293,122**，为上述两项之差 |
| 输出 tokens | **2,354** |
| 输入 + 输出 | **564,788 tokens**；缓存输入包含在输入总数中，不重复相加 |
| 现金费用 | **未知，不记为 0**；本次没有价格/账单凭证，OAuth 响应没有费用字段 |

用量来自 canonical turn usage 与对应 planner observations，不以 prompt 字符数替代 provider tokens。这里记录的是 MoonCode 子任务用量，不包含本聊天的评测协调/排错模型用量；完整现金成本不能据这些数据精确结算。

首次明确记录准备时刻为 12:44:40；命令提交前约 5 分 43 秒用于当前代码启动和连通。全部修复回归完成于约 13:05:25：有时间戳的准备/运行/排错/验证窗口约 **20 分 45 秒**。更早的选题探索没有完整计时，文档和 commit/push 也不包含在该窗口；不能把 124.712 秒当成本次工程工作的全部耗时。

## 只修本次暴露的三个运行时 bug

运行时修复提交：MoonClaw `b0edd8d2`（main）。功能修复和本记录随 MoonDesk 同次提交。

| 实际现象 | 根因与最小修复 | 验证 |
| --- | --- | --- |
| 两次合法单次 edit 携带 `edits: []` 占位而被拒绝 | 旧实现按字段存在与否判断“两套修改”。改为按有效单次内容和非空 batch 判断，忽略中性占位；两种有效修改同时存在仍返回原错误。 | 既有原子编辑用例覆盖两种默认占位和冲突不写入；本次真实首条 edit 参数通过原执行入口成功重放。 |
| 服务仍在运行、同一任务继续规划，canonical turn 却显示 failed / Work interrupted | work-step 的 failed 被当成整个请求终态。进度更新只把 queued 推进为 running，终态仍由既有 terminal event/receipt 决定。 | 新回归保留失败步骤，同时请求继续；本次真实 journal 前缀修复前失败、修复后为 running；完整历史仍为 done。 |
| 加载 skill 显示 Updated SKILL.md | title/detail 的只读分类遗漏 read_skill，误落到修改文件描述。复用既有读取描述。 | 既有 skill 用例及本次真实历史回放得到 Read SKILL.md，原技能来源/摘要语义保持。 |

这三个运行时修复由评测协调者完成，不归功于本次 MoonCode 模型。没有增加工具、状态机、校验、审批、重试限制、强制验收 gate 或架构层。执行器缺失是部署前置条件，保留明确拒绝；没有为此增加功能或兼容旧 checkpoint。

## 回归与证据

- 功能 bug 先红后绿：原有测试 1/1 → 加入两个断言后 0/1 → 修复后 core native **24/24**、core JS **24/24**。
- 运行时三个 bug 均在修复前复现：编辑 **1/3** 通过；投影/实际轨迹 **1/4** 通过。修复后关联用例 **16/16**，实际历史与原 edit 参数单独回放 **1/1** 通过。
- 最终 MoonClaw native **1845/1845**、MoonDesk native **1726/1726**。
- JS 工作区 **2291/2291**，包括 MoonDesk UI **839** 项；这些是重叠集合，不能相加。没有执行实际浏览器/安装态界面验收。
- 两仓 `moon info` / `moon fmt`、接口及空白检查完成，公共 `.mbti` 无变化。
- 本次 journal SHA-256：`d5a04bef82fe4f4d1f219b79fe9a160a2bdb92bb86f20241726c60f3d8ecbbb0`。
- 原始 journal 在选定 checkout 的忽略目录 `.moonsuite/products/moonclaw/mooncode/sessions/mooncode-live-bugfix-20261106-display-name/journal.jsonl`；请求、快照、统计位于 `_build/mooncode-live-delivery-20261106/`，未提交原始内容或凭据。
- 实际回放临时用例已移除，永久回归只保留对应 bug 场景。专用 daemon 已经通过原 shutdown API 退出，未停止其他运行实例；两份临时凭据配置已移除，保留无凭据的评测证据。

本次未做修复后的第二次真实模型运行，不能宣称返工次数、tokens 或耗时已经下降。一个小 bug 的观测也不能代表全部真实任务成功率。下一次自主验证需要先接通现有执行器部署；本轮不扩建机制。
