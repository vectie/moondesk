# MoonCode Shell 根因与交付成本复查（2026-11-07）

本轮修复了有实证的三个问题，但**没有达成降低任务总成本的目标**。两次任务和一次环境恢复后的续跑，共 **35 次响应，935,131 input / 6,169 output**。完整成本包含异常输出膨胀、磁盘不足、拒绝、编译错误和业务返工；不挑选其中一段作为“低成本成功”。

沿用[上轮 91,539-input 记录](MOONCODE_SNAPSHOT_COST_AUDIT_2026-11-06.md)。直接改 main，无新增架构、状态机、工具、重试层、人工确认或完成门槛。

## 三类 Shell 失败不能混为一谈

### 1. 原来的 transport timeout：调试构建与重复全量指纹开销

原调用 `cost4-snapshot-1:0:2` 的 grant 已消费，Fort 已创建 live-output；其 blob 留下 **1,560 bytes** 的 Git/grep 输出。最后一次写入约在调用开始后 13 秒，约 25 秒的 Claw transport deadline 到期后没有收到终端回执。这不是没有找到 Git，也不是每次临时编译执行器。

配置实际指向 `_build/native/debug/.../executor.exe`。无模型的原命令重放三次为 **12,039 / 11,716 / 11,484 ms**，另一次采样重放 **11,670 ms**；三段栈采样持续出现 MoonBit SHA-256/SIMD。当前约 129 MiB 的完整仓库快照，执行前后各全量 inventory/hash 一次，`retain_scratch` 又全量扫描一次，仅用于核对少量将保留的文件。原调用和重放都会因 Git 更新 `.git/index` 进入 retention。

| 原命令，同一工作区与限额 | 三次 publisher+executor elapsed |
| --- | --- |
| 原 debug | 12,039 / 11,716 / 11,484 ms |
| 原实现，release | 4,897 / 3,405 / 3,350 ms |
| 删除第三次全量扫描，release | 3,219 / 2,608 / 2,720 ms |

**改动：** 当前运行配置改为既有 release CLI；[Fort retain_scratch](../../moonfort/executor/store.mbt)复用已有 `inspect_sandbox_destination`，仅重验声明保留文件的大小/指纹，删除第三次全树 inventory。前后两次执行清单、真实权限、隔离、TTL 和内容校验保留，无新 FFI、缓存或协议字段。

这些重放证明了可修复的 CPU/全量扫描开销；没有在相同负载下复现原单次 25 秒超时，不能声称还原了每一秒。原实验与 Claw 全量构建/测试重叠，会影响延迟；本轮实跑等待检查结束后才提交。没有抬高 timeout 或隔离限额，也没有把上述顺序测量当作通用性能基线。

### 2. 新发现的 output-limit：非 Exited 回执绕过输出上限

第一轮实跑，模型为找调用方执行全仓 `grep -R ... | head -100`。它扫到 `.moonsuite` 中已有的单行 JSONL；限制行数并不限制这些长行的字节数。Fort 在 **10 MiB output-limit** 处返回 Killed 回执，保留完整 artifact，并给出 260,256 字符的 inline projection。

调用明明指定 `max_output_chars=20000`，但 [MoonClaw 结果转换](../../moonclaw/cmd/daemon/mooncode_execution_sandbox_gate.mbt)只对 Exited 分支截断。非 Exited 分支先返回，直接复制 `receipt.output`，把 **260,256 字符**再次回灌模型。随后六次 input 为 `102873,103328,103886,104192,104814,105154`；首次两次为 `3228,8852`，总 input **636,327**。这是真实的边界 bug，不是必要探索成本。

**改动：** 把已有成功/失败截断函数移到状态判断之前；错误回执同样遵守原 `max_output_chars`，保留诊断首尾及 `truncated`，artifact/receipt 引用不变。没有下调用户选择的上限、禁用 grep、隐藏历史目录或新增摘要机制。

既有授权/回执测试补了 Killed 分支：20K 字符输出、1024 字符请求上限，验证错误状态、首尾和截断事实。**修复前失败，修复后通过**。后续实跑没有再次选择同一个溢出搜索，因此不能把整轮 token 变化全部归因于这个补丁；确定的改进是该错误分支恢复遵守已有契约。

### 3. 第二轮 snapshot storage-io：磁盘不足，具体原因被丢弃

第二轮写完两次业务修改后，快照创建开始连续失败，最终累计 **7 次 storage-io 拒绝**。宿主卷仅剩约 **187 MiB**；本轮诊断以及前轮留存的完整快照占用了空间。重跑前没有核对剩余容量，是协调者的实验安排失误，不能把这些成本归给模型或隐藏成一次成功。

Fort 当时仅显示 `reason.code()`，把 `StorageIo` 内含的操作系统原因压成 `storage-io`。模型改命令、目标目录乃至运行 `true` 均无效，另一次盲目增加 timeout 被现有 ceiling 拒绝。它最终诚实报告验证阻塞；协议中的 `finish`/done 不是本报告的质量验收通过。

**改动：** [原错误分支](../../moonfort/sandbox/local_backend.mbt)保留 `StorageIo` 的具体 message，其他拒绝码不变。用真实不可读源文件复现“Permission denied 被抹掉”：旧实现失败，新实现通过。未新增错误分类器、自动重试或确认流程。

操作上，先释放本轮 10 个诊断快照，再释放本实验私有根中 24 个已结束、唯一声明文件为 `.git/index` 的冗余完整快照。每份 manifest 和声明文件先保存到私有证据目录；原 journals、模型输出、签名输出 artifacts、费用记录、业务仓库及其他用户数据保留。释放后可用空间约 **3.3 GiB**。这是操作员维护，不是新的运行时清理策略；未修改 retention TTL 或全局配额。

## 为什么读过 replace_ext 仍返工，复核仍多一轮

从模型实际输入确认，实现和既有测试已经可见，没有发生 compaction 遗失或该文件被裁剪。旧 `basename("//")` 返回空，`replace_ext` 因此返回原路径；把 basename 的纯斜杠结果改为 `/` 后，原空值分支不再命中，会得到 `//.md`。模型未把这项行为变化传播到调用方，直到真实测试指出它。**读过函数不等于完成了调用语义推演。**

本轮一度用短提示强调调用影响和检查合并，结果仍返工。第一轮甚至在一个 Shell 中完成定向测试、全仓测试和 Git 复核后，下一轮又重复执行 Git。审查 runtime 后确认，edit 后普通批次能继续，未强制插入这些模型轮次。**这项提示修改已全部撤回**，不把未验证的提示调优留在核心，也不增加“必须读调用方”“必须批处理”之类 gate。

环境恢复后的续跑又暴露根路径被 scan 再次截成空、随后 replace_ext 的旧语义变化。三次业务 edit 后才通过。当前仍没有证明能稳定消除这些模型选路和推演错误；只记录 badcase，未宣称这两个问题已被框架修好。

## 完整实跑与所有成本

两次开始时均直接在 MoonLib main `1e0d2dd` 恢复 `f2cfdd9:pathx/path.mbt`，保留全部当前断言，原 prompt/model 相同，只换 packet/session ID。是完整真实仓库和真实执行器，不是源码副本、假工具或新未知 bug；Git HEAD 已有正确实现，不能据此外推未知缺陷成功率。

| 阶段 | 响应 | input | cached（含于 input） | output | 接受到 finish |
| --- | ---: | ---: | ---: | ---: | ---: |
| `cost5-release-1`：异常输出暴露，原 cap 未修 | 8 | 636,327 | 2,560 | 1,670 | 91.213 s |
| `cost5-capped-1`：cap 已修，磁盘阻塞 | 15 | 158,159 | 23,808 | 2,323 | 151.432 s |
| `cost5-capped-2`：同一 session 环境恢复跟进 | 12 | 140,645 | 57,856 | 2,176 | 106.491 s |
| **本轮合计** | **35** | **935,131** | **84,224** | **6,169** | **349.136 s 活跃任务合计** |

输入+输出 **941,300**，非缓存 input **850,907**，planner latency 合计 **260.250 s**。全部 35 次响应都有 usage，外层模型重试 0。工具共有 42 个结果，24 成功 / 18 失败；共 7 次 edit 调用，均计入。错误的 1,200,000 ms timeout 两次被原 600,000 ms ceiling 拒绝，没有通过改 policy 掩盖。

首个接受 `1793984017558` → 最终 finish `1793985419695`，跨度 **1402.137 s**，包括中间修复、构建、测试和磁盘维护。另有较早的 10 次无模型诊断调用共 **67.108 s**，命令、采样与回执保留；它们没有 provider 模型用量。现金价格未知，聊天协调模型、完整开发/编译/推送用量不在上述 provider 数字中。

恢复不是一遍无人干预成功：第二次任务返回“验证受阻”后，操作员释放空间并正常提交一次环境恢复跟进，保留此前模型业务修改，没有手工改业务实现。跟进实际完成定向 Native **12/12**、全仓 Native **108/108** 后交付。没有第三次恢复原 bug 来挑选更好数字的重跑。

## 验收与保存

- 独立验收 MoonLib 全仓 Native **108/108**、pathx JS **12/12**；原断言全部保留，无协调者业务补丁。最终相对原已修复 HEAD 仅删掉冗余的 `scan(trimmed.view())` 调用中的 `.view()`，不是新功能修复。当前产物来自 Agent 最终交付。
- Claw **1844/1844**；非 Exited 截断回归红→绿。Fort 最终 **299/299**，包括真实本地隔离 E2E、清单指纹和具体 I/O 原因回归；后者红→绿。公开 `.mbti` 不变，info/fmt/空白检查完成。未混入 Fort 的既有工作台改动和 formatter 的 Int/可选参数迁移。
- 最终生产修改：Claw 仅结果转换；Fort 仅保留文件校验和现有 I/O 错误消息。主提示、任务/完成/调度策略没有本轮改动。没有新增 package、服务或持久状态。
- 私有证据 `/Users/kq/mooncode-cost5-20261107` 包含三阶段 metrics、动作/轮次、原配置路径说明、采样、前后 executable、诊断对照、环境释放 manifest/声明文件和原/最终源码；凭据不提交。原 `cost4` journal SHA 保持不变。
- 第一 session `mooncode-cost5-release` journal SHA-256：`3b0188e962aa4698de92c82f3bcffd2665373a60621351aef2c0f84dfa45ade0`；第二 session `mooncode-cost5-capped`（含恢复跟进）：`e714f5c38679892c577d3afbfa94b94d343adb49e4a32a84140dfe33ca40acaf`。均在 MoonLib `.moonsuite/products/moonclaw/mooncode/sessions/`，专用 daemon 已停止。

**结论：** 修复有确定证据，成本目标仍失败。快照复制/留存的环境成本、未遵守输出契约、模型语义遗漏和冗余复核分别记录，不能用“加几句提示”或成功测试掩盖总开销；低成本、自主稳定交付的 checklist 继续不勾选。

提交：MoonClaw `76ceaa86`、MoonFort `4c389a0`、MoonLib `89ec1eb`；报告、索引与 checklist 随 MoonDesk 同次 main 提交。四仓全部 remote 推送并逐个核对 main HEAD，Fort 的原有工作台修改不在提交中。
