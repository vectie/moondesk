# MoonCode 真实仓库 Native 交付记录（2026-11-06）

**最终第三轮自主修复、自测和交付通过独立验收；整项工作经历两次环境返工。** 前两轮不算成功，成本一并保留。没有增加架构、状态机、审批、工具或评测服务。

## 真实仓库与验收

- 直接使用现有 `/Users/kq/Workspace/moonlib` 的 **main**，基线 `dc62810`；没有 clone、新分支、core 源码副本或替换 manifests。原包、C stubs、依赖和 `.git` 都在。文件工具直接修改该仓库；进程按既有 MoonFort 机制快照**整个仓库**到私有 scratch 后执行。
- 同期 MoonDesk `ea072c28`、MoonClaw `657b74da`、MoonFort `7df62bb`；最终一轮启动前已包含下文协调者修复。MoonFort 原有 SQLite 工作台改动保留，不属于本次提交。
- 真实 bug：`replace_ext(".env", ".local")` 错误返回 `.local`；`config/.gitignore` 加 `.bak` 也丢失名称。协调者先补两条失败断言，未提供修复实现。既有 pathx Native 12/12；补入断言后实际失败。
- 三轮均为普通 `/turns` prompt、真实 `codex/gpt-5.6-sol` / OAuth，观测 transport `chat_completions`。没有注入工具调用、模拟模型或额外 Reviewer。后台错误通过原工具结果反馈。
- 本轮没有改用 Wasm/JS 冒充 Native。自主检查在真实 `LocalOs / AllowDegraded` 的 sandbox-exec 中完成，所有 Native 编译、链接和测试都有 executor receipt。该隔离仍为 **Degraded**，不是 MicroVM 生产隔离资格验证。

第三轮只改 `pathx/path.mbt` 的一个 match 分支：前导点不作为后缀分隔符；在既有测试补充 `.env.local` / `.gitignore.bak` 的后缀替换断言。协调者提供最初两条断言，模型自行补充后两条。最终业务实现未被人工改写。

## 运行与返工

| 轮次 / session | 实际结果 | 处理 |
| --- | --- | --- |
| 1 `mooncode-live3-dotfile` | 模型已修复，但 MoonCode 的绝对路径字符串禁令拦住 SDK 环境配置；默认 moon_cmd 又找不到私有 HOME 外的 registry。 | 协调者停止服务，保留完整历史；删除实际授权之前的重复路径禁令。恢复原始业务 bug 和原验收断言，重新执行。 |
| 2 `mooncode-live3-native-dotfile` | 定向 Native 12/12；全仓执行先被磁盘扫描竞态终止，修复后为 103/108，五项测试固定写宿主机 `/tmp`。 | 协调者修复扫描竞态和测试夹具；停止本轮，再恢复原始业务 bug。该轮未交付，不计成功。 |
| 3 `mooncode-live3-native-complete` | 模型一次业务 edit、一次测试 edit；定向 Native **12/12**，全仓 Native **108/108**，finish / canonical done。 | 本轮运行中没有 steering、人工业务补丁或测试接管；随后独立验收。 |

前两轮业务补丁均保存后丢弃，属于 **两次重新执行**，不是注入新缺陷。第三轮前的完整冷预检先得到 108/108；恢复原始业务 bug 后为 **107/108**，唯一失败正是待修断言。最后才提交第三轮任务。

第三轮有 **15 个规范工具结果，11 成功 / 4 失败**：成功 read_skill 1、read 4、edit 2、shell 3、finish 1；失败 moon_ide 1、shell 3。IDE 缺少默认后端 metadata；三次 shell 失败涉及系统 Git / xcrun / `/etc/gitconfig`，不影响已获得的 Native 测试证据。模型没有声称 Git diff 检查通过。格式化子命令已运行，但带后续 Git 的整个 shell 返回失败，不能把整条调用记为成功。

第 1 / 2 轮分别有 18 / 26 个已提交规范工具结果；中断时尚无结果的调用不伪装为已执行失败或成功。整体 **两次停止重跑**，第 2 轮还有协调者更新执行器；只有最后一轮可以记为无运行中接管的成功样本。第三轮交付后的业务实现返工为 0。

## tokens、耗时与费用

| 轮次 | 响应数 | 输入 tokens | 其中缓存输入 | 输出 tokens | 接受命令至停止 / finish |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1，取消 | 16 | 477,443 | 181,248 | 1,910 | 服务首次取消 102.768 秒 |
| 2，取消 | 22 | 1,309,304 | 442,368 | 2,823 | 服务取消 243.390 秒 |
| 3，完成 | 11 | 508,069 | 116,096 | 1,617 | **104.580 秒至 finish** |
| 已观测合计 | **49** | **2,294,816** | **739,712** | **6,350** | 不能只报最后一轮 |

- 输入包含缓存；非缓存输入 **1,555,104**，输入加输出 **2,301,166**。不是把缓存再加一次。49 次记录都有 usage，外层 model retry 合计 0。
- 三轮 planner latency 合计 **269.108 秒**（79.717 / 125.155 / 64.236）；不等于服务端计费时长。
- 首轮接受 `1793944670911` → 最后一轮 finish `1793945648546`：**977.635 秒，约 16 分 18 秒**，含中间排错和两次重跑。
- 最后一轮接受 `1793945543966`，terminal receipt `1793945648600`，service idle `1793945649282`，分别距接受 104.634 / 105.316 秒。
- 独立 Native 验收日志完成于 `1793945701` 秒，距第三轮接受约 **157 秒**，含协调调度，不作为纯测试运行时间。
- 可核对的首次 executor 预检日志创建 `1793944367` → 独立验收完成 `1793945701`：**22 分 14 秒**工程窗口。更早阅读、之后文档/commit/push 不在其中。
- **现金费用未知**。用量不含本聊天协调模型；取消请求若没有返回 usage，其潜在计费也不在已观测总量内。没有价格或账单凭证，不记为零，不宣称成本下降。

## 配置与实际 bug 修复

1. **Native 配置，复用已有 Shell**：显式选择 MOON_HOME、MOON_CC、MOON_AR、DEVELOPER_DIR、SDKROOT 和 CLT PATH，使用已安装依赖的 `--frozen`；不借助 `/usr/bin/cc` 的宿主 xcrun 缓存。不增加环境配置 API、wrapper 或 launcher。可直接复用的命令见 [MoonFort 配置](../../moonfort/docs/EXECUTOR_CONFIG.md#macos-moonbit-native-commands)。普通 moon_cmd 不自动获得这段 shell 环境，仍不能宣称其默认配置已支持此部署。
2. **MoonFort 路径解析**：已有祖先 metadata 循环扩展到受信工具和只读根，解决 clang 自身路径解析失败；未保留诊断用的整个 `/Library` 读权限。既有策略测试先红后绿，真实 Native 冷编译验证。
3. **MoonClaw 重复路径禁令**：删除 `$HOME`、SDK、Users/temp 等字符串命中就拒绝的分支及其专属旧测试。实际文件访问仍由原 grant/profile 执行；相对 cwd/parent 语义保留。既有测试新增 SDK 调用形状，先红后绿。
4. **MoonFort 磁盘扫描竞态**：并发删除/替换目录不再让普通编译和测试被误杀；保留不跟随链接和原有配额、权限错误处理。新回归在原 C 实现复现 `monitor_unverified / aggregate_disk`，修复后通过；真实全仓测试随后跑完。
5. **MoonLib 测试临时目录**：五个失败测试使用的 async/fs tmpdir 在此版本不读取 TMPDIR。复用已有 `fsx.mkdtemp` + `os.tmpdir`；只改测试夹具和 test import，没有开放宿主 `/tmp` 或修改依赖。
6. **重启时调用身份**：停止第一轮后，意外自动恢复暴露“先重新绑定随机 grant，再比较原 intent”导致身份不匹配。调整既有循环顺序：先按持久调用恢复结果/未知状态，确实要执行才绑定新 grant。原 checkpoint 的调用指纹回放吻合并返回 outcome_unknown；扩展既有重启回归，覆盖已有 process intent，确认返回未知而不执行其副作用。未增加摘要格式、重放策略或状态，没有据此宣称完成额外的服务崩溃资格验证。

配置与运行时修复、测试夹具由协调者完成，不归功于 MoonCode。进程始终使用既有执行器，没有 host shell 回退；真实模型最后一轮验证的是修复后的部署条件。

提交：MoonLib `f2cfdd9`、MoonClaw `9c035750`、MoonFort `bea777e`；本记录与 checklist 随 MoonDesk 同次 main 提交。

## 独立验收与证据

- 实际 main 工作区：MoonLib Native **108/108**，pathx JS **12/12**；独立检查业务 diff、格式和接口，未改写模型实现。
- MoonClaw Native **1844/1844**（删除一条旧绝对路径禁令专属测试）；MoonFort Native **297/297**，包括真实 local E2E 和新增目录竞态回归；MoonDesk 消费工作区 Native **1726/1726**。集合有重叠，不相加。
- 四仓 info/fmt、`.mbti` 和空白检查；没有公共接口变化。只保留本轮文件的差异，撤回 Fort formatter 对无关旧语法的自动迁移。
- 三轮原 journal 位于实际 MoonLib `.moonsuite/products/moonclaw/mooncode/sessions/<session>/journal.jsonl`。本地 `.git/info/exclude` 排除运行记录，不修改产品 `.gitignore`。
- SHA-256 按轮次：`3a2ba79cc3a3d8e1126b936dfeea5864913673b8c39d8960c4db8ec63e4adf68`、`28881b3f92093816bc36ee02f83b41a0e2e7ad79d8a06f1c979048aa45111cac`、`9866d74f3195098ad8b642ae2af134abe8d322502a9bf1a561d2e7b990a7a1e9`。
- 私有 `/Users/kq/mooncode-live3-20261106` 保存三轮 canonical、原 patch、metrics、配置及冷预检 receipts；凭据不提交。评测 daemon 已停止。

这是一个真实完整仓库上的最终成功样本，包含此前失败成本；不是一次即成功，也不证明 MoonDesk 全应用、所有工具默认环境、安装态 UI、生产隔离或总体线上成功率已获验证。
