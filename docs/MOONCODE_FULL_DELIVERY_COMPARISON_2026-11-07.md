# 同一 Codex、同一真实 bug：四框架完整交付对比

2026-11-07。用户明确授权复用 MoonCode 现有 Codex 配置做真实交付比较。本次不再比较输出截断函数。四套运行都自主修改完整 Git 仓库、实际执行全仓 Native 测试并交付；随后独立验收全部通过。没有人工修改 Agent 的业务代码，没有增加产品功能、运行状态、审批流程或测试框架。

## 条件与复现材料

- 实际模型统一为 **`gpt-5.6-sol`，reasoning effort `none`**，复用 MoonClaw 已有 `codex/gpt-5.6-sol` OAuth 路由、刷新和 Responses 编解码；不需要另一个厂商的密钥。
- 四份完整 MoonLib Git 仓库起始 tree 都是 **`1c3c7190742a873cf0a42376e9c55a8d5b5556ab`**。只将 `pathx/path.mbt` 恢复为 `f2cfdd9` 的历史 bug，保留当前全部验收测试，并提交相同内容的实验基线。运行时均为 main。共享 clone 后做了本地 repack，移除外部 Git alternates，避免 Fort 无法读取源仓库对象。
- 同一份中文任务：修复 `docs/// → docs`、`资料/// → 资料`、`/ → /`；保留普通路径、空输入、单尾斜杠和 `replace_ext` 既有语义；实际跑全仓 Native，不改依赖、架构、无关包，不 commit/push、不使用子 Agent。完整原文、SHA-256、源码版本、逐轮 usage 和独立验收在[机器可读记录](MOONCODE_FULL_DELIVERY_COMPARISON_2026-11-07.json)。
- 引用 checkout：OpenSeek `dbe35ecc`、Pi `80f7a114`、DSH `8bd07339`；MoonClaw `0542905b`、MoonFort `1de0e6b`、MoonLib `f9cad489`。完整 commit ID 在记录内。
- 每个交付进程外部允许 8 分钟；MoonCode 由现有 service 执行并观察，10 分钟观察上限未触发。没有为测试添加内核预算、重试策略或完成门槛。
- 私有证据根：`/Users/kq/mooncode-live-peers-20261107`。保存四个完整仓库、原始 journal/session/JSONL、请求与响应、75 次实际 usage、所有失败启动日志、最终 diff、验收输出和临时 `.mbtx` 驱动。OAuth 解析产生的临时凭据文件在结束时删除，不提交 Git。

## 最小适配的实际范围

MoonCode 通过当前 daemon、journal、continuation 和真实 MoonFort release 执行器运行。复制既有执行配置，仅将 workspace、控制文件和结果存放目录指向私有实验目录；Native 编译器、系统 SDK 与原有授权策略复用。

三个参考框架的现有 OpenAI-compatible provider 接到临时 loopback 适配器。适配器调用 MoonClaw 原有 `@openai.chat` Codex 路由，保留各框架自己的 system prompt、工具、历史和 agent loop。流式客户端收到同一次完整响应转换的 SSE；每次只回报一次真实 usage。适配器不执行工具、不决定重试、不生成计划或完成结论。

| 框架 | 接入方式及环境准备 |
| --- | --- |
| OpenSeek | 使用现有 `--api-url`。CLI 仍接受 `deepseek-flash` 枚举，但适配器实际调用并记录 `gpt-5.6-sol`；这不是 DeepSeek 模型成绩。因当前源码需要 `core/async`，私有安装 Nov 6 SDK，仅裁去 CLI 不使用的 UI workspace 依赖，运行时代码未修改。使用现有 `--approval always` 自动处理工具授权，未启用 review gate。 |
| Pi | 当前源码 CLI，加私有 `models.json` provider。使用相同版本的已发布依赖、源码 resolver 和 OpenAI SDK；工具维持默认 read/bash/edit/write。 |
| DSH | 当前源码 headless CLI，加现有 `llm-pi-ai` provider overlay；停用不使用的 DeepSeek provider，复用同一 Codex。补齐源码路径解析、Native system addon、生产依赖和 Typert 生成，保留原 headless 工具与循环。`--approval-policy never` 不发起人工询问。 |

没有把各框架的沙箱、自动检查、技能、工具数量或辅助模型调用改成同一种实现。因此，这是同任务、同模型的**实际框架交付观测**，不是仅改变 agent loop 的严格控制实验。OpenSeek 自身检查使用更新的 SDK；共同 Native 环境已写入任务，独立验收则统一使用绝对路径 `/Users/kq/.moon/bin/moon`（Oct 12 SDK），不将运行内所有编译过程都宣称为相同环境。OpenSeek 初始 PATH 未包含宿主的 `rg`，造成两次 spawn 失败；这是实验启动环境的额外成本，不归因于其规划能力。

## 实际 token 与耗时：所有已观察调用均计入

input 包含 cached；cached 不能再加一次。数值来自 Codex 返回 usage，非字符估算。价格未测，Pi/DSH 自定义模型显示的 cost=0 不代表免费。这里也不包含协调本实验的外层 Codex 对话费用。

| 框架 | 实际响应数，含失败尝试/辅助调用 | Input | 其中 cached | Output | 完成交付的一次运行 |
| --- | ---: | ---: | ---: | ---: | ---: |
| MoonCode | 12 | 124,777 | 18,176 | 1,850 | 85.628 秒 |
| Pi | 14：12 次交付 + 2 次适配失败 | 48,538 | 16,000 | 1,626 | 68.727 秒 |
| OpenSeek | 33 | 1,249,588 | 831,616 | 7,353 | 292.709 秒 |
| DSH | 16：15 次主循环 + 1 次标题 | 156,664 | 79,616 | 2,921 | 106.422 秒 |
| 合计 | **75** | **1,579,567** | **945,408** | **13,750** | 不相加：部分运行重叠 |

MoonCode 时间是 journal 的 `runtime.service_started → runtime.service_finished`；HTTP 观察进程耗时 90.555 秒，包含十秒轮询的等待余量。其他三套是 CLI 进程墙钟时间；每次 provider latency 也单独保留。四套模型调用耗时合计分别为 62.480、59.865、272.206、89.063 秒；Pi 这个数字包含失败适配调用，不能与其成功运行墙钟时间直接相减。

Pi 成功交付本身为 **45,950 input / 1,455 output，12 次响应**。两次适配失败额外 **2,588 input / 171 output**，未从总账扣除。DSH 标题额外 **443 input / 16 output**，主循环为 **156,221 / 2,905**。标题不算子 Agent，但属于实际成本。

### 启动和适配失败没有删除

| 尝试 | 进程耗时 | 实际情况 |
| --- | ---: | --- |
| Pi 缺 OpenAI SDK | 0.505 秒 | assistant 报模块缺失，但 CLI 仍 exit 0；尚未请求模型。不能用 exit 0 判断交付成功。 |
| Pi 第一轮适配失败 | 18.780 秒 | 模型返回且两个工具执行成功，下一轮回灌被临时 decoder 拒绝，随后客户端连接重试；1,294 input / 92 output。 |
| Pi 第二轮适配失败 | 19.191 秒 | 相同 follow-up 解码问题；1,294 input / 79 output。 |
| DSH 源码路径缺失 | 0.054 秒 | 切换 cwd 后不能解析 workspace 的未构建 lib；设置现有 tsx 的 tsconfig 路径。没有模型请求。 |
| DSH Native/Typert 缺失 | 1.920 秒 | 补构建 addon、依赖和生成物。没有模型请求。 |

Pi 三次失败启动加成功运行合计 **107.203 秒**，DSH 两次失败启动加成功运行 **108.396 秒**；这些不包含操作者修复适配器的间隔或依赖安装时间。

两次 Pi follow-up 失败的已证实根因是 MoonClaw 内部 message decoder 要求 assistant content 为 string/array，而 OpenAI-compatible 历史合法地发送 `content=null`。临时适配器将缺失/null content 规范为 `""`，补 assistant 空 tool_calls，然后用已保存的多轮请求验证。没有修改 Pi 核心、没有为重试建立新缓存。静态 SSE 测试还暴露了临时 router 混用动态/静态路径的错误，改成四条固定路由；这是适配器问题，没有按 Pi agent 缺陷计算。

OpenSeek 保留首次全 workspace TLS 下载失败、CLI 依赖裁剪和旧 SDK 不支持 `core/async` 的失败；DSH 保留源码模块解析、缺 Native addon、Typert 缺 TypeScript/依赖的失败。MoonCode 保留私有目录权限、Git alternates、控制目录配置的预检失败；在模型运行前修正，真实 Fort 已实际复现 11/12 原始失败。所有原始日志保留，未伪装成零成本启动。

从实验目录创建 12:47:16 到最后一个 Agent 进程结束 13:21:40，共 **34 分 24 秒**，来自文件系统时间戳、秒精度，包含安装、适配修复、操作者工作和部分重叠运行。没有统一计时每套从零安装的全部步骤，因此不提供虚构的独立冷启动总耗时。

DSH 最终运行仍有一个 `dsh-web` Typert contributor 缺 `zod` 的启动 warning，日志完整保留。该 coding 任务和所有验收完成；这不是“整个 DSH profile 无异常”的证明，也没有为消除一个非阻塞 warning 再付费重跑。

## 返工、失败与交付质量

下表只统计成功交付尝试内的工具记录，不将参数错误、预期红测试、环境错误混称为同一种失败。

| 框架 | 工具调用 | 编辑调用 | 失败与返工 |
| --- | ---: | --- | --- |
| MoonCode | 15 | 3 次，2 次成功，其中一次包含两个原子编辑 | 5 个失败结果：不存在的 AGENTS.md、两次工具链环境失败、一次 `replace_ext` 回归、一次同时混用两种 edit 参数。Agent 自行修复，无人工业务接管。 |
| Pi | 13 | 3 次，均成功 | 3 次测试失败：修复前原始红测试、修改后根路径回归、随后 `replace_ext` 回归；后二者属于实际代码返工。 |
| OpenSeek | 35 | 11 次：9 次应用、1 次范围不匹配、1 次 warning guard 撤回 | 10 个 error 工具结果：两次 rg spawn、一次编辑范围、一次 process 权限、一次根路径回归、四次 `replace_ext` 测试失败、一次 warning guard 撤回。多次调整 basename 后才处理调用方；最后恢复无关生成的 `.mbti`。 |
| DSH | 19 | 3 次，均成功 | 一次读取不存在的 moon.mod.json；三次非零测试：原始红测试、根路径回归、`replace_ext` 回归。非零测试以完成的 bash 结果和 exit code 回灌，不能只数 `status=error`。 |

OpenSeek 的 warning guard 是模型在 edit 参数中**主动选择阈值 1**，不是默认强制 gate。不能据此声称该框架默认拦截所有新增 warning。模型实际选择的额外约束也可能增加返工，不需要为 MoonCode 再增加同类门槛。

四套最终均满足：

- Agent 自己实际运行全仓 Native，原始输出/产物保存；OpenSeek 后台 job exit 0，完整 `fg-13.out` 为 108/108，不以截断后的前 12,000 字符代替原始测试结论。
- 独立以同一绝对路径工具链运行全仓 Native **108/108**、pathx JS **12/12**、`git diff --check` 和测试文件不变检查，全部通过。
- 最终 tracked diff **仅 `pathx/path.mbt`**。四份验收测试 SHA-256 相同；没有删断言、更新 snapshot 或改依赖以通过验收。
- basename 与 `replace_ext` 的既有边界通过现有测试。最终代码分别有小幅不同，并非协调者替四套应用同一个补丁。
- 无子 Agent、无人工业务代码修复、无人工测试接管；启动适配发生的人工工作已单独记录。没有在原始 MoonLib main 重引入 bug 或保留这些实验补丁。

## 对 MoonCode 的直接结论

1. **完整链路成立，低成本目标仍未完成。** 这次 12 次响应、124,777 input 自主交付成功；Pi 相同任务成功路径为 45,950 input。旧 935,131-input 三段尝试与本次任务提示、环境、运行历史不同，不能拿两数相减声称因果降本或总体成功率提升。
2. **先减少每轮携带的数据和可避免的返工。** MoonCode 第一轮 3,175 input，最后 14,443；12 轮 message 数从 2 到 29，工具 schema 固定 10,672 字符、17 个工具，累计 request_chars 为 544,042。字符数不当作 token 归因。它不是又一次超长 grep，而是普通历史增长和额外轮次一起累积。没有证据表明摘要阈值或新预算 gate 是这次的解法。
3. **借 Pi 的简洁边界，不复制一整套系统。** Pi 默认仅四个工具，第一轮 1,294 input、system 2,246 字符，成功路径末轮 5,335 input。后续值得验证的是既有工具说明是否重复、两种 edit 参数是否让调用者困惑，以及已明确的代码/测试能否在现有工具中一次取齐；本次不据一个样本删除必要能力或增加路由层。
4. **借 DSH 的统一接入和完整记账。** 现有 provider overlay 能复用 Codex，不需要扩展新执行框架。但标题那一次调用也必须进成本；本次 DSH 最后一轮 13,660 input，与 MoonCode 接近，说明服务化本身不会消除历史成本。
5. **借 OpenSeek 的可编程片段与持久输出，同时看清开销。** 它首轮就有 25,882 input、system 69,335 字符，末轮 50,263 input；完整 SDK/工作流材料、脚本错误、较长检查输出和反复修正会一起推高成本。不能把“写成程序”当成小任务必然更省，也不能把这一个环境受限样本当成总体框架排名。

本次产品运行时和测试净变更 **0 行**。临时 Codex 适配器和测试入口归档后移出 MoonClaw；保留实际配置、原始结果、机器账本与文档。没有扩大架构，也没有以新增检查、预算规则或人工确认包装这次比较。

收尾核对：75 次响应逐轮重加与总账一致，63 个 peer provider response ID 无重复；四份 Agent 原始全仓通过证明与独立验收分开保存。MoonDesk/MoonClaw `moon info`、`moon fmt` 和空白检查通过，公开接口无变更；128 个既有本地链接、11 个历史归档哈希和新报告链接核对通过。临时监听器与私有 daemon 已停止，误由帮助命令创建的全局 headless profile 移回私有证据目录，原有 desktop profile 未动。
