# MoonCode：减少快照留存与框架输出对照（2026-11-07）

本轮生产修复集中在一个仍然存在的资源问题：**Fort 只公开清单中的改动文件，却把整份执行工作区留到 TTL 到期。** 检查命令即使只改变 `.git/index`，也会留下整仓副本，累积占用磁盘。此前七次 storage-io 发生在进程启动前；六次已知失败后的重试发起轮次用了 72,734 实际 input。不断换测试命令无法腾出磁盘。

此前保存的 34 份 index-only retention manifest，声明文件合计 **515,440 bytes**；其余工作区内容原本就不在可读取/提升的清单里。这不是声称历史完整快照只有这些字节，也不是将释放磁盘量直接换算为节省 token。

主要的上下文越界已由既有 Shell cap 修复；[35 轮账本](MOONCODE_INPUT_BUDGET_AUDIT_2026-11-07.md)保留 935,131 实际 input，不能用本轮离线结果改写历史费用。

## 生产改动

在现有 `retain_scratch` 中，先按既有逻辑校验清单文件的大小和指纹，再保留这些文件及其祖先目录，删除同一私有 scratch 中的其余内容，最后写入原格式 retention record。

- 清单、retention ID、TTL、读取/提升接口和完整 stdout artifact 的存储方式保持不变。
- 不加第三次全树哈希；复用现有目录读取、删除和 confined tree discard。多一次目录清理，换取不再按调用次数累积完整工作区。
- 所有实际改动的清单文件仍可读、可比对、可提升；原始工作区、journal 和 receipt 不删。没有自动清理旧记录的迁移任务。
- 不增加预算、错误分类器、重试禁令、模型提示、状态机、架构层或确认流程。

扩展原有 retention/TTL 测试：两个清单文件合计 16 bytes，同一私有副本中另有 1 MiB cache 和未列入清单的文件。旧实现无法移除 cache，回归红；修复后只留下两个文件及其目录，TTL 删除与既有提升测试继续验证。清单校验失败仍不进入清理。这个受控用例证明磁盘保留行为，**不是实际任务 token 降幅**。

也验证过旧 checkpoint 中超大工具消息的恢复投影。该原型可把旧历史重新限长，但不是新执行已修 cap 后继续空转的主要资源原因；恢复专用代码与测试已移出产品，没有以兼容旧记录为由增加运行时分支。

## OpenSeek、Pi、DSH 对照测试

本轮没有共同模型的完整 Agent 实跑。下面是**同一份真实 Killed receipt 输出的实际源码保留函数测试**，不代表任务成功率、返工率或整单成本排名。

| 框架、本地版本 | 本次真正执行的代码 | 保留机制与边界 |
| --- | --- | --- |
| MoonCode，Claw `0542905b` | 现有 `mooncode_sandbox_terminal_result` | 默认 12,000；历史调用明确请求 20,000。失败保留头尾，完整输出已有 artifact 引用。 |
| OpenSeek `dbe35ecc`，0.7.3 | 原始 `ShellOutputSink` 的字节一致副本 | 默认 12,000 characters 的 head，超出部分落文件，可读回全文。仅隔离测试 sink，不含 Agent loop/元数据 footer。 |
| Pi `80f7a114`，coding-agent 1.5.0 | 直接导入 checkout 的 `truncateTail` | 默认最后 2,000 行或 50 KiB。真实 bash 还通过 OutputAccumulator 保存完整输出；本次只测截断函数。 |
| DSH `8bd07339`，spill-policy 0.2.2-alpha.3 | 直接导入 checkout 的 `retainContent` 与 `estimateContent` | base profile 配 12,500 heuristic tokens；kernel 保留头尾。真正插件还需 session owner、spillStore，并预留 notice；缺 backend 时会保留 inline 原文。本次未冒充插件集成。 |

OpenSeek 完整 workspace 测试首先失败于现有 registry 缺失依赖，包括 tty、diago、uml、office-viewer 等。没有修改这些依赖：隔离项目原样复制 `sink.mbt`，两份 SHA-256 同为 `93855d4488a9054eacd7fcafd5601c1db840e04ba2dff749b7da1cca5e9a4138`，只挂原文件实际需要的 async/fs/env/utf8 imports。Pi 和 DSH 的上述纯函数无需安装整个 workspace，Node 直接加载原 `.ts` 文件。

### 同一输出的实际保留量

下表只统计保留正文，排除工具 schema、消息 envelope、notice 和其他历史。token 列统一用 MoonCode 原 cl100k tokenizer 估算，**不是 provider 账单**。

| 路径 | 参数单位 | UTF-8 bytes | 正文本地 tokens |
| --- | --- | ---: | ---: |
| MoonCode 默认 | 12,000 | 12,000 | 3,270 |
| MoonCode 历史调用 | 20,000 | 20,000 | 5,427 |
| OpenSeek 默认 sink | 12,000 characters | 12,000 | 3,177 |
| OpenSeek 显式 sink | 20,000 characters | 20,472 | 6,027 |
| Pi 默认 | 51,200 bytes / 2,000 lines | 51,200 | 13,146 |
| Pi 显式 | 20,000 bytes | 20,000 | 5,088 |
| DSH kernel、未扣 notice | 12,500 heuristic tokens | 50,440 | 14,267 |
| DSH kernel、显式字节 pricing callback | 20,000 bytes | 20,000 | 5,292 |

同为 20,000，character、byte 和 token 的含义不同；不能称为严格同预算框架排名。正文内容选择不同，也会使同样字节量对应不同 token 数。

这次可借鉴的是**持久事实与模型呈现分开、只保存恢复需要的数据**。MoonCode 已有 bounded output、artifact 和 journal，无需复制 DSH 的服务体系或增加一套 spill 引擎。Fort 的改动是把留存磁盘收敛到现有清单，而不是复制任何框架的整套执行模型。

## 验证记录与未完成项

- 输出对照：Pi/DSH 原函数测试 2/2；OpenSeek 原始 sink 隔离测试 1/1，全文读回等于原输入；MoonCode 当前 receipt 投影与表中 20,000-byte 正文逐字节相同。没有付费 provider 请求。
- 保留最初 OpenSeek workspace 依赖失败。Fort 首次要求真实 E2E 的全量运行是 276/299：23 项缺 compiled CLI 环境路径，随后构建 release 并补齐现有测试配置；不是删除失败测试或降低要求。
- 最终 release 构建通过；按已有变量补齐 browse/compare/diff/output-reader CLI 路径，`MOONFORT_REQUIRE_LOCAL_E2E=1` Native **299/299**，包含真实 sandbox-exec、artifact 读取、提升和过期删除。info/fmt 通过，公开 `.mbti` 无变化。只扩展一个既有测试，没有增加测试框架。生产源码 +38 行、该测试 +24 行。
- 私有 `/Users/kq/mooncode-peer-20261107` 保存原始输出、全部测试/失败日志、各框架正文、token 统计、隔离源文件及未合并原型；不把私有日志加入产品测试。Claw/OpenSeek 临时入口移出后，三个参考框架和 Claw 的源码均未修改。
- **四框架共同模型的真实 bug 交付对比待完成。** 当前没有 DeepSeek/Kimi/GLM API 环境配置，Pi/DSH checkout 未安装运行依赖；OpenSeek CLI 的模型枚举不接受现用的 `codex/gpt-5.6-sol`。DSH 已有 wlc/Qwen 本地 profile，但不是同一模型。已请求共同配置的路径与模型名，没有请求用户在聊天中发送密钥。
- 后续同模型测试应使用相同初始 Git tree、任务、验收和权限范围，各保留一整次尝试的调用、失败、返工、input/cached/output 和耗时；本轮输出 kernel 对照不能代替它。低成本自主交付继续未验收。

生产提交：MoonFort `1de0e6b`；MoonDesk 本报告、索引与 checklist 随同 main 提交。MoonClaw/OpenSeek/Pi/DSH 无本轮源码提交。
