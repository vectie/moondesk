# MoonDesk handoff notes

Read this with `AGENTS.md` before starting work. Record concrete pitfalls and
their resolution here; keep task-specific evidence in `docs/`.

Work directly on `main`; do not create a branch unless the user requests one.




## Long task notice lifecycle 2026-11-09

- Existing followup filter drops consumed user.live_steering and one-shot
  warning.finish_rejection/warning.patient_replan. Applied updates remain in
  Current task; fresh notices and retry regeneration remain. Old User copies
  pinned an entire long tool turn:128steps102 unfit/max31848, fixed0/max<=7104.
- Paired4x128, full initial1027 charged; plain input identical. Verified1024
  steps/1025input frames6066562,0unfit,287compactions,8real old-result reads,
  32correct after-step journal restores, same next request. Fresh Native
  process restores1024results/2updates/exact next request and old output.
- First extended fixture reloaded projected messages, not actual after-step
  resume; verified-2 saves pre-response plan and rebuilds followup. Comparing
  raw events to journal projection fails on journal_sequence: reuse existing
  unproject helper in harness, not new production compatibility logic.
- Short12-response trace53513 x8/96frames unchanged; Native1836/1836,
  context regression before2/3 after3/3, info/fmt, mbti unchanged.
  No new state/layer/hardening/provider call. Evidence long7-20261109 under
  /Users/kq includes failed fixtures, all sums/initial/recall/recovery costs.
  These are simulated decisions, not1024real LLM turns or a service kill test.

## Complete batch cutoff root cause 2026-11-09

- Field removal delayed pressure at round10:7116->7072 vs7104. At11 old
  scan raw6 hit prefix3 while seeking User, reset to latest19, losing result18.
  An Assistant-backward prototype still overflowed7301 and fell back19:
  rejected. Forward-skip orphan older Tool tail to7, clamp with existing
  newest complete turn. Same7334 input ->5537 fits and keeps proof (old3758
  fits but loses it). No test/result keyword policy, pin, state or new layer.
- 6 variants12 fully priced paths. Main49157->53513 (+4356=1452x3 last rounds),
  null counterfactual repaired54925/13 ->55034/12 (+109, no cost win).
  Profile/recall/combined58556/59025/63092; no field/schema changes shipped.
  8 real producer replays96frames; full task/Skill/edit/final108 retained.
- Existing test fails before (16/17),17/17 after; Native1836/1836, context3,
  info/fmt, mbti unchanged. Only cutoff fix and existing regression extended.
- Evidence /Users/kq/mooncode-compaction6-20261109, per-round candidates,
  traces/counterfactual/repairs/raw paid hashes; no provider calls. Compiler
  heuristic and serialized ledger differ813 here; no token-calibration change.
  Total carrying is not monotonic under pressure; do not promise it is.

## Unwrap checkpoint observations 2026-11-09

- Only unwrap prior checkpoint Observations instead of summarizing its header
  as a new User. Same96/768 budget, outer result ranges identical all12frames.
  Existing rolling-chat test fails2!=1 before fix, passes with old/new anchors.
- 13 main ablations19 fully priced branches. Main49166->49157, net9 (0.0183%),
  Pi47355 ratio1.0381/residual1802. Profile/recall/combined53900/53217/57284,
  save12 each. Eight real producer replays96frames, <=1 checkpoint marker total,
  full tasks/Skill/edits/final108 proof preserved. Window9472/7104 unchanged.
- Background/null/metadata-equality removals all lose proof at11/12;
  all11 variants priced with a real reader repair cost more than54000.
  Keep their schemas/metadata/arguments unchanged; do not add isolated gains.
- Native1836/1836, pruner17, info/fmt, mbti unchanged; no new test items.
  Evidence /Users/kq/mooncode-residual5-20261109 includes counts/failures/
  replay/raw paid hashes. No provider calls, new layers, states or hardening.

## SDK args and checkpoint framing 2026-11-09

- Same9472/7104: ten main ablations, fourteen conditional groups. SDK target
  uses existing args flags, net233 (schema242 minus argument6/checkpoint3);
  one checkpoint marker/no message count saves153. Selected49166, net386,
  Pi47355 ratio1.0382, residual1811. Eight verified replays/96frames retain
  original tasks, completeSkill, edit literals and final108/108 verdicts.
- No result headers removed. Status alone72/generic success alone104 save,
  but selected+either loses proof. Full recovery55092/13 and55085/13 costs
  more than baseline49552. Profile/recall/directory+recall54298/53653/57720
  ->53912/53229/57296, all issuing requests/receipts/carry/recovery charged.
- SDK fallback/eval/tests migrated; target event reads existing args flags,
  both --target value and --target=value tested against actual argv.
  MoonIDE target, program_args, grants, paths and canonical results unchanged.
- Evidence /Users/kq/mooncode-residual4-20261108 crossed midnight; date is9.
  Initial96frames passed but summary loop retained1 iteration; preserved
  failed driver/data, fixed global replacement and wrote production-verified.
  Do not overwrite original timing data; replayer uses timestamp run dirs.
  No provider call, new state/layer/confirmation or smaller context window.
- Native1836/1836, focused pruner17/SDK13/Skill3/tools3, info/fmt pass;
  mbti unchanged. Runtime-7/test+28 lines, no new test items. Measured compiler
  median/p95488/499ms per12frames, fixture794/821; no speed comparison claim.

## Checkpoint prefix and default return 2026-11-08

- Fixed generated checkpoints being protected as pre-assistant instructions
  and counted as user-turn boundaries. Skills now follow canonical task,
  before derived history; delete insertion flag/fallback. Existing single
  compiler/range/768-token checkpoint limit remains, framing is shorter.
- Default request uses Auto, not Required. Hide default finish schema and
  reuse existing text->internal finish decoding/acceptance. Explicit finish
  selection/catalog remains.6 default no-MCP tools,8 MoonBit,11 full profile.
  No new completion state, layers, human step, memory store or provider run.
- 18 raw ablations:boundary50728 (480 saved), framing-fixed50521 (687),
  natural50548 (660); selected boundary+framing+natural49552 (1656/3.23%).
  Ordered savings480+516+660; no sum of isolated values. Same9472/7104.
  One warmup+7 real default measurements,96frames all49552, <=1 checkpoint,
  all12 task bytes/complete Skill/edit literals/final verdicts preserved.
- Paired profile54576->54298/13,recall55582->53653/13,
  directory+recall60206->57720/14. All issuing requests/receipts/carry counted.
  Full candidate initially51459 lost verdicts; restoration54956/13 (3748
  worse). Hash inspection needs2 metadata reads+1 verdict repair66876/15
  vs baseline51208/12. No metadata/nonce/status fields removed in final.
- Initial gap3853=sum(4246,3850,4523,4107,504)-13377. Earlier commentary
  mis-summed the offset as17377; components/net unchanged, corrected in docs.
  Current residual2197:schemas3622/Skill3850/headers4523/checkpoint3111/
  task504 offset by system1728/assistant2909/bodies8776. Pi47355 ->1.0464;
  local fixed-trace ratio, no new billing/cache/future behavior/quality proof.
- Native1836/1836; final pruner17/17, Skill3/3, tools3/3, info/fmt pass.
  Runtime-6/test+8 lines, no new test items, .mbti unchanged. Current timing
  compiler410/416ms median/p95 per12frames, fixture671/674; not interleaved.
- Evidence /Users/kq/mooncode-residual3-20261108. Raw paid hashes unchanged.
  Metadata first full-read assumption failed under existing50k cap; fixed
  conditional fixture pages first12k then tail20 by returned line_count,
  charging every request plus proof repair. No runtime output-cap change.
  Framing v1 put a fixed header outside cap; fixed before shipping, all
  prototypes kept. Reproducer writes new run directories to retain samples.

## Complete-exchange input cleanup 2026-11-08

- Same9472 window and7104 budget; 8 paired main ablations. Baseline60749,
  read-only ABI merge60137, bundled Skill dedup60444, checkpoint-only52989;
  checkpoint+read51945, checkpoint+Skill52252, read+Skill59400, final51208.
  Final deployed default producer1warmup+7measurements all51208 (15.7% less),
  same-counter Pi47355 ->1.0814. Frozen original decisions, no paid rerun.
- Delete output-only clearing plus dead helpers/metric, use existing whole
  exchange checkpoint. Full task/instruction prefix and latest batch stay;
  journal/range refs remain. Old exact call arguments are not automatically
  returned by result reads; checkpoints are lossy, not a general quality proof.
- One read ABI: path for files, evidence_ref for existing retained reader.
  Delete read_result schema/dispatch/policy and use metadata for graph recall.
  Parallel result reads reuse exact-arguments identity; no alias or new layer.
- Bundled guide only drops duplicated generic advice. Complete current
  instructions350 tokens/message (was417), references/view-offset/checks kept;
  unknown/custom Skill bodies unchanged. Existing assets generator/installer.
- Fully charged paired profile/recall/directory+recall cases:62626->54576/13,
  66292->55582/13,68944->60206/14 requests. All checked edits/verdicts remain.
  Removing SDK declarations then loading the existing profile costs55388
  (+4180) with equal instruction body/location: rejected; keep declarations.
- Native1836/1836, recall1/1, parallel3/3, selection3/3, skills26/26; info/fmt.
  One obsolete clearing-specific test removed. Runtime-125, assets-5, tests-51
  lines. Only .mbti change removes obsolete CompileResult.redacted_tool_results.
  Native new read boundary recovers15 outputs+553 JSON/page reads (568 total,
  46.958s), exact original values, no effects replayed, private journal unchanged.
- Preserve all failures/negative candidates/private paid logs and costs at
  /Users/kq/mooncode-residual2-20261108. No billing/cache/new autonomy claims.
  Reproduced compiler median410ms/12frames, fixture669ms; no speed claim.
- Harness pitfall: String.replace changes only the first occurrence. Use
  split/join for all fixture roots/ABI substitutions and restore saved sources
  even on failure. Embedded skill assets trim final newline; compare complete
  deployed text with the generator's normalization, not raw-file byte equality.

## Source ABI and Skill prefix cleanup 2026-11-08

- Runtime now uses array-only edit `{path,edits[]}` and SDK `args[]/paths[]`.
  Scalar aliases, the kind/reason test-update gate/metadata and unused argument
  collectors are deleted. No compatibility layer; grant/path/atomicity remain.
- Existing YAML parser separates only standard Skill routing frontmatter from
  the model prefix. Markdown body is complete, canonical file/hash unchanged;
  custom/unknown frontmatter, plain text and reference files remain verbatim.
- 25 main groups +10 full-load groups separate code/window effects. Main at9472:
  baseline61154, edit60799, SDK60685, Skill60615, all60749; isolated gains do not
  add. At10240 all63304 is worse than62544, so calibration is explicitly charged.
- Old9728 passes both cases; old9472 loses a custom-branch edit. New9472 passes
  both; new9216 loses one, rejected. Default9472 uses the existing compiler and
  override, not a new stop/budget gate. Original62544 ->60749 (-1795/2.87%), local
  Pi ratio1.2828. Full conditional load68133 ->62623/13 requests (5510 saved);
  independent fixture, not interchangeable with prior68xxx evidence roots.
- Final default producer1warmup+7samples all60749, budget7104, original Markdown,
  edit literals and verdicts intact. Original calls/responses are mechanically
  migrated only in private fixtures; no model choices or original failures removed.
  Actual billed cost/new autonomous quality are unknown; no provider rerun.
- Full Native1837/1837 and focused checks pass; private unreachable helper cleanup
  also check/info/fmt. No added test items or public mbti changes. All sources,
  candidate groups, failure windows and cost data: /Users/kq/mooncode-abi-20261108.

## Measured input benchmark 2026-11-08

- /Users/kq/mooncode-input-benchmark-20261108: actual current producer/compiler,
  one warmup+7 measured12-frame frozen replays, all62544. Pi recorded47355, not a
  new Pi execution.1.32 is a local input-shape ratio, not new provider billing.
- Calibrate original request snapshots: MC132150 local/124777 actual (+5.91%),
  Pi47355/45950 (+3.06%). Cached reads18176/16000. Current billing/cache unknown.
- Basic4 schema5160 vsPi7188; control4 costs3900, SDK/IDE4070, full Skill5126.
  Recarried tool bodies12129 vsPi19751 (7622 less). Full test2348 appears once.
  Both have3 edits: weighted argument history3854 vs2246,1608 of assistant gap.
  Original actual catalog/pack/result queries0; Skill1. No synthetic calls in
  the primary benchmark. Main scoped claims/commands are in the dated doc.
- Controlled finish-schema/prose adapter ablation:63274,730 worse. Exact delta
  schema-624/system-36/headers+195/bodies+1195 = outline331+source864 carried one
  more round. Reverted; no production changes based on raw schema shrinkage.
- Main benchmark/ablation/component check Native1/1 each; no full-suite rerun
  or new paid autonomous quality claims. Median compiler343ms/12 frames; p95636
  (7 samples, includes slowest). Preserve all samples, not just earlier faster runs.
- Harness pitfalls: separate async tests ran concurrently and read missing
  output; aggregate in the producer test after writing. MC normalized metrics
  use cache_read_tokens, Pi prompt_tokens_details.cached_tokens; absent is null,
  never silently0. Failures and prior reports are archived. Runtime unchanged.

## Result receipts and recall costs 2026-11-08

- Same12 frozen responses, no provider, unchanged10240 window.62730 ->62508
  Skill-receipt dedup ->62544 with recall schema (+36), only186 saved: Pi47355
  comparison remains1.32x. Full test appears once2348; outline1986/source5184/
  original SDK failure4896/Shell2902. Preserve full skills, source and failures.
- read_result defaults to saved output lines; details=true retains canonical
  JSON paging.15 original outputs plus15 canonical results/553 pages verified
  without operation replay. Keep Skill location for relative resource paths.
- Fully priced recall73469/14 ->69381/13; directory+recall77907/15 ->73895/14,
  including repairing lost final verdicts. Directory query adds4485; unannotated
  Skill pair68635 ->68136/13 each, sharing a common fixture path. These are
  synthetic branches, not newly observed model decisions, billing or turn savings.
- Runtime metadata removal and equal status alias removal increased input:
  rejected. All evidence/failures: /Users/kq/mooncode-receipts-20261108; dated Pi
  report/ledger updated. No new state, architecture or approval; code on main.
- Claw Native1837/1837, recall1/1, Skill3/3, check/info/fmt pass; .mbti unchanged.
  Runtime net+20/test+23 lines, no added test items. No new paid quality results.

## On-demand tools and skills 2026-11-08

- Reuse existing Skill declarations/loading, native selector and journal;
  default8 tools without MCP,10 after bundled MoonBit guide, all13 through
  mooncode-tools. Default directory is IDs; full descriptions remain queryable.
- Same-log actual producer62730 vs75840 (-13110/17.3%); matched10240 window
  separates7457 window-only,3136 index and2517 tool selection. Full task,
  primary prompt, old skill instructions and all observed calls remain usable.
- Conditional custom/unannotated Skill branch charges an extra profile request
  (13 projected requests,68626); not a new observed model turn or free discovery.
  9216 loses facts there, so default10240. No new state/authority gate or paid run.
- Evidence /Users/kq/mooncode-on-demand-20261108; old costs/archive unchanged.
  Disk-full failure retained; completed script caches only reclaimed before
  full matrix retry. Current installed .system guide has the new declaration.
- Claw Native1837/1837, focused6/6, check/info/fmt pass; interfaces unchanged.
  Handwritten runtime+27 lines, generated assets+15, tests+67; no new test items.

## Residual Pi comparison 2026-11-08

- Existing-log gap76295-47355=28940 is now paired by category. Aligned basic
  four schemas430/request versus Pi599; nine additional tools992. Main
  system248 versus Pi502; full skill catalog592 extra. Configuration and
  capability differences are not all removable implementation overhead.
- Eight continuous ablations preserve failures/negative savings. Only flat
  model result headers ship:75840 (-455/0.60%), no new provider/model decisions.
  Tool headers9259->8804; full bodies20318 unchanged, task/skill/assistant
  unchanged. Runtime metadata removal and SDK field combinations were rejected.
  Evidence: /Users/kq/mooncode-pi-residual-20261108; dated section in the Pi
  input-gap report. Original costs/archive stay intact, no paid rerun.
- Claw Native1837/1837 (--strip -j2), check/info/fmt pass; interface unchanged.
  Desk docs-only;135 local links/11 archive hashes verified. No new test items.

## Measured working-set cleanup 2026-11-07

Latest follow-up: /Users/kq/mooncode-remaining-input-20261107. Same 12 frozen
responses, no provider call: 78258 ->76295 (-1963 /2.51%). Delete unreachable
browser driver/schema, serialize complete skill listing as compact JSON, and
remove repeated generic prose from referenced omitted-result handles. Schema
-2832, system/catalog -1596, result headers -537; retained bodies +3002.
Standalone browser deletion increases total input 154; never sum static savings
as continuous replay savings. Task/skill/assistant/current results unchanged.
Window remains 12288; first full-test presentation unchanged. Offline Pi ratio
1.61 is not new usage, fewer turns or an autonomous quality measurement.
Claw Native1837/1837, info/fmt pass; public interfaces unchanged, production-84
/tests-4 lines. Desk has docs-only changes, no redundant Native rerun.

- No paid rerun. Current journal/compiler/skill-prefix reuse: 108403 -> 78258
  fixed-trace local input, 12 responses. Steps: 671 skill receipt, 28322 working
  set, 1152 redundant check schema; full test result accounts for 21789.
- Default working window 12288, explicit existing payload can expand it. Smaller
  measured settings lose recorded edit inputs; full skill/initial task and final
  verdict stay. First whole-test read is unchanged; old presentations use refs.
- Remove moon_check/fake watcher and duplicate check after SDK actions. Run-tests
  now runs one actual test; builds no longer add check. Desk/Claw core inventories
  and diagnostic contracts aligned. No new state, layer, approval or hardening.
- All 15 canonical results recovered, 553 local 20-line reads/55.7s for exhaustive
  metadata; original tools replayed zero. Future model recall/quality/cost unknown.
  Small-field removal saved only 82 after real compaction and was reverted.
  Evidence: /Users/kq/mooncode-cost-components-20261107; old costs/archive intact.
- Final Native: Claw 1837/1837, Desk 1726/1726; info/fmt pass. MoonBit
  production net -980 lines across both, tests -251; only obsolete exports
  removed. Recorded first-run failures and fixed event-lane/test migrations.

## Remaining input follow-up 2026-11-07

- No paid rerun. Deduplicate tool descriptions and compact the existing main
  prompt; guide targeted implementation/caller/test search and range reads,
  expanding as needed. No router, new tool, truncation, retry or completion gate.
- All tool ABI fields unchanged apart from descriptions; 15 captured calls
  validate. Current Book keeps 15 tools. Fixed producer carry replay retains
  12 responses / 95 observations: 113335 -> 108403 local tokens (4.35%). Schema
  contributes 4068, main prompt 864; all other messages are exactly equal.
- Full test read was 181 lines/7388 chars, carried ten times; Pi's initial grep
  was 42 lines/3085 chars including callers. Full tests/skills remain in replay.
  Do not claim measured behavior, fewer rounds, new billing or a new ratio.
  Evidence: /Users/kq/mooncode-input-followup-20261107; prior cost hashes intact.
- Claw full Native 1843/1843, check/info/fmt pass; public interfaces unchanged.
  Production net -12 lines, product tests unchanged; private audits removed.

## Default toolchain follow-up 2026-11-07

- No paid rerun. The Native/Git errors in the Pi comparison reproduce in Fort:
  authorized `/private/var/select` still needs `/var` alias metadata. One SBPL
  line fixes default compiler selection; two private Git environment values
  skip unavailable host system config/attributes. No toolchain discovery layer.
- Original executor configuration and real repository: default Exec moon Native
  108/108 and Shell Git checks pass without model-supplied environment exports.
  Preserve the 14.2% fixed-trace estimate; this is not a new token/round result.
  Evidence: /Users/kq/mooncode-toolchain-20261107; updated Pi input-gap report.

## Build-cache cleanup 2026-11-07

- Cleanup inventory/results: /Users/kq/moonsuite-cleanup-20261107. Build trees
  can contain raw evidence and release bundles; do not remove `_build` wholesale.
  The live Desk servers use `_build/native/release/build/cmd/main/main.exe`
  and `ui/rabbita-desk/dist`. Keep final CLI binaries/shared libraries as well.
- `moonmini` is a symlink to `bunnia`; include canonical aliases, Lepusa and
  Rabbita when scanning suite caches. MoonRobo `target` and MoonFish objects,
  databases and exports contain real source/data/evidence, not compiler caches.

## Pi input-gap audit 2026-11-07

- Paid reruns paused by this request; no new live provider call. The successful
  Pi and MoonCode deliveries both have 12 responses: 45950 vs 124777 input.
  Do not explain the 2.7155 ratio as more responses or hide Pi adapter costs.
- docs/MOONCODE_PI_INPUT_GAP_AUDIT_2026-11-07.md/.json reconcile all 24 requests.
  Local cl100k totals 47355/132150 differ from billing. Schema, full test reads,
  result envelopes/JSON escaping and command diagnostics account for the gap;
  exact duplicate messages within a request are zero. Original journals intact.
- Claw reuses existing producer/compiler/Book MCP configuration and atomic
  editing. Removes the extra read/error index and empty context, sends raw
  output after a JSON reference header, omits MCP schemas only when known
  unconfigured, and applies top-level edit then edits instead of rejecting both.
  No new router, gate, retry, model instruction strategy or runtime layer.
- Fixed 12-response carry replay preserves 95 observations, estimates
  132150 -> 113335 (14.2%); not new paid usage or fewer future decisions. The
  actual formerly rejected mixed edit produces the exact accepted source.
  Evidence/scripts: /Users/kq/mooncode-pi-gap-20261107. Low-cost goal stays open.
- Claw full Native 1843/1843, pruner 18/18; interfaces unchanged. Production
  MoonBit -31 lines / tests -22, temporary audit entries removed. Original
  paid log and ledger hashes checked, plus 129 local links / 11 archive hashes.

## Full four-framework delivery 2026-11-07

- User explicitly authorized live peers through the existing Codex OAuth route.
  No new vendor key is needed. docs/MOONCODE_FULL_DELIVERY_COMPARISON_2026-11-07.md
  and its JSON contain the shared task/tree, source commits, every observed
  response, failed setup attempts, rework, timing and independent acceptance.
- All four autonomously delivered the same real MoonLib basename bug, full
  Native 108/108; independent absolute-path Oct 12 Native 108/108 and pathx JS
  12/12 pass, only pathx/path.mbt changed, tests unchanged. No manual code fix.
  MoonCode 124777/1850, Pi 48538/1626 including two charged adapter failures,
  OpenSeek 1249588/7353, DSH 156664/2921 including title. These are actual
  input/output, not prices or a statistical ranking. Runtime/test delta is zero.
- Private evidence: /Users/kq/mooncode-live-peers-20261107. Keep setup warnings,
  failed attempts and all costs. Pi exit 0 can contain an assistant error;
  DSH completed bash can contain a nonzero test exit. Inspect task facts.
- Shared Git clones need local objects before sandbox execution: repack then
  remove alternates. The temporary Codex compatibility adapter must normalize
  assistant null content before using the internal MoonClaw message decoder.
  Both Pi follow-up failures occurred after tools ran; they were not Pi bugs.
  OpenSeek needs an isolated newer SDK; never upgrade the shared SDK mid-run.
- Prior missing-common-model/pause notes below describe earlier rounds. This
  authorized comparison is complete; no further paid rerun was performed to
  erase non-blocking warnings. Low-cost autonomous delivery remains unqualified.

## Resource fix and peer comparison 2026-11-07

- User requested a fix and OpenSeek/Pi/DSH comparison. Production change is in
  sibling Fort retention: keep only verified manifest files and ancestor dirs,
  not the whole workspace for a .git/index-only observation. Existing stdout
  cap stays; no new model prompt, retry rule, budget or recovery state.
- A saved-context cap prototype was tested then removed; it addressed old
  projections rather than ongoing disk growth. Do not count prototype lines,
  tests or token estimates as shipped improvements. Claw source is unchanged.
- docs/MOONCODE_RESOURCE_AND_FRAMEWORK_COMPARISON_2026-11-07.md records same
  actual-output retention tests: Pi/DSH direct source functions, OpenSeek
  byte-identical isolated sink after full workspace dependency resolution failed.
  These are not full agent/task success or cost measurements.
- Common-model live comparison remains pending: no DeepSeek/Kimi/GLM env key,
  OpenSeek CLI cannot select the current Codex model, Pi/DSH deps absent. Existing
  DSH wlc/Qwen config is a different route. Asked for config path/model name,
  never a secret in chat; do not label the offline kernels a completed live run.
- Fort final required-E2E Native 299/299 and release build pass; public APIs
  unchanged, +38 production lines / +24 lines in one existing retention test.
  Preserve the unrelated user workbench edits; only stage own retention files.

## Full input attribution 2026-11-07

- No paid rerun. docs/MOONCODE_INPUT_BUDGET_AUDIT_2026-11-07.md accounts for
  all 35 requests / 935131 actual input. Local cl100k estimate is 954652;
  do not present category estimates as provider billing.
- One oversized grep body contributed 552582 local tokens over six requests.
  Replaying its actual Killed receipt through the existing 20000-character cap
  reduces the fixed action trace by 509634; carrying current candidate history
  across all rounds gives 441848, not a measured new run or fewer decisions.
- The old 0.47% replay froze original tool results and reset history each round;
  it never measured the major cap fix. Six retries after a known snapshot
  failure consumed 72734 actual input in their issuing rounds; these overlap
  content accounting. Model rework/review and low-cost delivery remain open.
- No additional runtime bug established: documentation only, no speculative
  prompt, truncation/retry policy or test. Temporary audit entries/imports moved
  to /Users/kq/mooncode-input-budget-20261107; original journals unchanged.
- Final existing Native regressions: Claw 1844/1844, Desk 1726/1726; info/fmt
  passed, public interfaces unchanged, 123 links / 11 archive hashes verified.

## Offline-only audit 2026-11-07

- User explicitly paused paid reruns. Do not launch another live MoonCode/model
  canary without a new user instruction authorizing it. This is a work constraint,
  not a new runtime approval flow. No product-provider calls/tokens this round.
- docs/MOONCODE_OFFLINE_REPLAY_AUDIT_2026-11-07.md replays 12 actual source
  revisions and 41 captured follow-ups. Source/tests were visible for all nine
  recorded edits; caller behavior, StringView typing and root scan mistakes
  reproduced. Do not infer hidden model reasoning or predict fewer future calls.
- Correction: capped-1 retains its first pipeline warning for requests 2–15.
  Delete that automatic guidance path, retaining tool flags and evidence rules;
  deduplicate identical failure summaries in the existing index, not invocations.
  All 339 cumulative tool observations and other context remain identical.
- Content reduction is only 13796 chars / 0.47%, not tokens or live savings.
  Two invalid timeouts occurred in different commands without prior ceiling
  feedback visible. Git after a build sees .tmp; a fresh snapshot does not.
  Do not conflate those environments or cache shell calls by text.
- Lib removes duplicate root parsing and LLM retry prose, keeps the established
  behavior. Claw 1844/1844; Lib Native 108/108, JS 12/12; MoonBit net -54 lines.
  Replay must unwrap event.command and freeze enriched context/evidence refs;
  committed journal IDs are not interchangeable with provider-observed refs.

## Shell roots and interrupted delivery 2026-11-07

- See docs/MOONCODE_SHELL_ROOT_CAUSE_AUDIT_2026-11-07.md. Three observed phases:
  636327/1670, 158159/2323, then recovery 140645/2176 input/output. All 35
  responses total 935131 input/6169 output; cost goal failed. Do not report
  only the final phase or claim an unattended successful rerun.
- Debug Fort hashes full snapshots repeatedly; release calibration plus removing
  the third inventory reduces measured executor time. Non-Exited Claw results
  bypassed max_output_chars: actual 260256 vs requested 20000, causing the first
  context flood. Existing truncation now runs before status dispatch.
- Disk space was not checked before rerun; diagnostic copies contributed to
  exhaustion and seven snapshot refusals. Released only owned redundant copies,
  preserving declared files/manifests, output artifacts, journals and costs.
  Fort now retains the underlying StorageIo message. Recovery used one explicit
  operator follow-up and no manual business patch. CPU/timeout limits unchanged.
- Prompt tuning failed to remove caller mistakes or duplicate final Git calls
  and was withdrawn. Input contained replace_ext; this was model semantic use,
  not missing context. Parse structured metrics: raw output can itself contain
  escaped prompt_tokens/journal JSON; unanchored grep can dump it again.
- Claw 1844/1844, Fort 299/299, independent Lib Native 108/108 and JS 12/12.
  Only final Lib difference is a redundant .view() removal; public API stable.

## Snapshot and round-trip audit 2026-11-06

- docs/MOONCODE_SNAPSHOT_COST_AUDIT_2026-11-06.md records one new real run:
  91539 input/1679 output, 10 responses, 169.897 sec. Input increased 22.5%;
  no cleanup call, but one Shell timeout/retry and one post-edit regression.
  Do not describe this as overall cost improvement. Source/test read once each.
- Claw terminal message names per-call scope; evidence index removes 260 chars
  of repeated guidance. No new policy, cap, architecture or mandatory actions.
  Fort cleanup_verified can include managed retention: do not claim all snapshot
  bytes were deleted. Final message corrects the trial's overbroad wording;
  only the existing terminal integration check covers that final wording.
- Native Claw 1844/1844; independently Lib Native 108/108, JS 12/12. Business
  source again exactly matches accepted HEAD. Complete costs/limitations kept;
  daemon stopped, no hand-written implementation takeover or paid retry.

## Complete-skill cost audit 2026-11-06

- See docs/MOONCODE_SKILL_COST_AUDIT_2026-11-06.md. The 213432-input run
  retained 361020 chars of skill results and 7090 chars of receipts over ten
  follow-ups. The long guide is a shipped system asset, not a personal skill.
- Claw replaces its empty source gitlink with maintained Markdown at the same
  path and uses the unchanged generator/installer. Complete entrypoint
  34084 -> 1991 chars, references on demand, receipt 709 -> 275. No context
  truncation, extra model calls, caps, new state or manual confirmation.
- Single new run: 8 responses, 74750 input (cached 5120)/1685 output, 134.394
  sec; input -65.0% vs 213432. One atomic call/two edits, no post-edit rework;
  missing AGENTS read and red test retained. Same historical real bug/prompt,
  current HEAD includes an extra /// assertion. New source matched accepted
  HEAD, not a novel-bug or general success-rate qualification.
- Skill loading was still complete. Claw 1844/1844, Loader 26/26, independent
  MoonLib Native 108/108 and JS 12/12, Desk consumer 1726/1726; public API stable.
  Removed duplicated Loader snapshots (tests net -277). The existing source
  YAML parser/installed-link checks passed; standalone Python validator lacked
  PyYAML and no project dependency was added for it.
- Clarified shell's existing disposable snapshot after observing a useless
  cleanup call. Its effect on future round counts is unmeasured; no paid redo
  or rm ban. Final model prose omitted initial red/edit history; report retains
  it. Fort is unchanged and its pre-existing workbench edits remain untouched.

## Follow-up token audit 2026-11-06

- See docs/MOONCODE_TOKEN_AUDIT_FOLLOWUP_2026-11-06.md. The 382588-input run
  still duplicated 17322-char verification inputs, 7897-char inspection ledger,
  and automatic task/recent-result summaries. Removed those model copies,
  preserving journal/recall and original Completion evidence. Cross-command
  notes now enter the initial task prefix; selected skill content remains full.
- Catalog description matching no longer mandates skill loading. User/project
  requirements remain. The final model still chose the long MoonBit guide;
  this is not evidence that the policy change saved its input cost.
- Same historical real bug/prompt: first 248354 input/2599 output, 12 responses,
  254.314 sec with one Git timeout; final 213432/2144, 11 responses, 183.982 sec.
  Input -44.2% vs prior 382588, but both new trials' 461786/4743 cost retained.
  No in-run takeover. Two model edits/one regression; independently accepted.
- Fort derives SDK home for macOS registered Moon and preserves execute bits
  in snapshots. IDE and false Git script modifications are fixed. A transient
  Git timeout replayed successfully; no timeout/retry architecture added.
- Claw 1844/1844, Fort 298/298, Desk 1726/1726, real MoonLib Native 108/108 and
  JS 12/12. Public interfaces unchanged. Production net -75 lines, tests +35;
  existing Fort workbench changes untouched. All commits are on main.

## Three-run token audit 2026-11-06

- Read docs/MOONCODE_TOKEN_AUDIT_2026-11-06.md for root causes and comparison.
  Old 49 responses: 2294816 input / 6350 output. A 395-character full-test
  output arrived as a 327569-character result; follow-ups accumulated old
  ledgers/progress. Fixed-history message JSON replay shrank 53.1%; this is
  not a token or cash measurement. Preserve raw journal/recall references.
- Reused existing result projection and follow-up construction; removed
  exit-zero pipeline false failures and the keyword helper. Native test
  failure exit code is 2. No budget gate, new state, approval or architecture.
- Peer basename task exposed 18 generic grant refusals hiding timeout bounds.
  Claw now preserves publisher code/message; Fort prints requested/ceiling.
  One restart resumed the same journal/command. That first pass cost 918024
  input / 5404 output and 499.657 seconds; it was more expensive than the old
  clean sample, so all costs remain alongside the same-prompt clean rerun.
- Same-prompt rerun: 16 responses, 382588 input (cached 29568) / 2620 output,
  235.327 sec; no in-run takeover. Opaque refusals 18 -> 0; one numeric
  refusal corrected on next call. Input -58.3% vs first pass, -24.7% vs old
  dotfile success; elapsed is longer than the old easier bug. Three model
  edits/two regression failures remain visible. Native 108/108 and JS 12/12
  independently accepted. Claw 1844/1844, Fort 297/297, Desk 1726/1726.
- Default IDE metadata/Shell-vs-moon_cmd environment and snapshot executable
  mode noise remain. The latter makes unchanged scripts look modified in
  scratch Git; actual main scripts were untouched. Do not label it user dirt.

## Full real repository Native delivery 2026-11-06

- Actual MoonLib main at /Users/kq/Workspace/moonlib, complete Git repository;
  no source copy or manifest substitution. MoonCode fixed dotfile replace_ext
  in one line, added hidden-suffix assertions, and finally ran Native 12/12
  plus full 108/108. Independent Native 108/108 and pathx JS 12/12 passed.
- Two earlier attempts were stopped for real environment/runtime issues;
  restored only their business patch to original bug for fresh retries. Total
  49 observed responses, input 2294816 (cached 739712), output 6350. Final
  attempt 104.580 seconds to finish; all attempts to final finish 977.635 sec.
  Cash unknown; no overall no-takeover claim. Report:
  docs/MOONCODE_LIVE_NATIVE_REPOSITORY_2026-11-06.md.
- Reused Shell with explicit SDK/CLT environment. Fixed Fort read-root ancestor
  metadata and disappearing-directory monitoring, removed Claw's absolute SDK
  substring ban, and made five MoonLib test fixtures use its existing TMPDIR
  helpers. Recovery matches the original call before regenerating a grant.
  No new state, environment API, launcher, approval or architecture.
- Final third run had no steering, manual business patch or test takeover;
  coordinator changes are separately attributed. Moon_cmd does not inherit
  shell environment; optional system Git checks remained unavailable in the
  sandbox. Do not turn Native success into universal tool/UI/isolation claims.
- Claw 1844/1844, Fort 297/297, Desk workspace Native 1726/1726. Private run
  evidence lives in actual MoonLib .moonsuite and /Users/kq/mooncode-live3-20261106;
  daemon stopped; original Fort SQLite workbench changes remain uncommitted.

## Live executor delivery 2026-11-06

- Connected the existing real MoonFort publisher/executor to an evaluation
  daemon. Real model fixed nested History/Review directory classification in
  one two-line edit and ran core Wasm GC 24/24 without steering or test takeover.
  Exact implementation copied to main; independent Native/JS core 24/24 each,
  full Desk Native 1726/1726. Report:
  docs/MOONCODE_LIVE_EXECUTOR_BUGFIX_2026-11-06.md.
- Nine responses: input 262159 (cached 121472), output 1274; command-to-finish
  57.648 sec. No implementation rework; money unknown. Source-only full core
  copy and required local packages were evaluated, not a full repository or
  installed app. LocalOs/Degraded, no host bypass; evaluation daemon stopped.
- Actual runtime gaps fixed in siblings: Fort getcwd ancestor metadata,
  trusted tool helper PATH and /dev/null write-data; Claw binds parallel shell
  before dispatch and reuses it for later recording. Existing tests extended;
  no new execution mechanism. Original shell replay only proves grant routing,
  because its `|| true` and missing Git HEAD cannot prove diff validation.
- Tool ok with expected_exit=1 can describe an environment failure; accept
  test success only from actual test output and exit 0. Native sandbox Xcode
  selection remains a deployment limitation; Wasm GC was the autonomous check.

## Live MoonCode bug delivery 2026-11-06

- Ran the actual main-checkout MoonClaw daemon with a real Codex OAuth model,
  plain /turns prompt and no injected tool calls. MoonCode fixed display_name
  for repeated trailing slashes; coordinator provided the two failing
  acceptance assertions first and did not revise the model's patch afterward.
- Canonical usage: 16 responses, input 562434 (cached 269312), output 2354;
  37 tool results, 12 successful/25 failed. Command-to-finish 124.712 seconds,
  independent core acceptance about 141 seconds. Cash cost unknown, not zero;
  these counts exclude this chat's coordination model use.
- Delivery passed independent checks, but autonomous verification did not:
  no MoonFort process route was configured. The model disclosed the refusals;
  coordinator ran tests. Do not count this as no-takeover success or tick the
  general quality/cost baseline. Report: docs/MOONCODE_LIVE_BUGFIX_2026-11-06.md.
- Actual trace exposed three Claw bugs, fixed by the coordinator: neutral edit
  placeholders rejected valid calls, work-step failure marked an active turn
  failed, and read_skill rendered as a write. No feature, gate or authority
  changes. Real journal-prefix/edit-argument replay passed; temporary replay
  test removed, minimal permanent regressions retained.
- Final Claw native 1845/1845, Desk native 1726/1726; core native/JS each 24/24;
  JS workspace 2291/2291 includes UI 839, not an additional count. Info/fmt,
  interfaces and whitespace checked; .mbti unchanged. No browser/install or
  post-fix live-model rerun, so no token/latency improvement claim.
- Tooling pitfall: standalone .mbtx imports resolved app dependencies outside
  the local moon.work overrides and hit the old moonzip manifest. Use the
  ordinary project test for this baseline; do not change dependencies to make
  an evaluation pass. This preparation issue is not a MoonCode tool failure.
- Timing uses numeric journal recorded_at values; canonical started_at and
  updated_at were empty in this run. Do not derive live latency from those
  optional display fields or conflate finish, settlement and service idle time.

## Runtime ownership and control/projection simplification 2026-11-06

- Recorded the bounded meaning of ideal module boundaries: one owner per fact,
  traceable consumers and no duplicated behavior. JSON at dynamic ABI/provider/
  journal boundaries is not a reason to add an IR or extra validation.
- Claw groups its four live execution fields separately from session metadata;
  preserves the pre-task startup reservation and uses the existing execution
  lease instead of the second running branch. External metadata stays the same.
- Controls apply claimed steering once; follow-up request assembly uses one
  loop. Planner ledger reads canonical results without a temporary JSON
  protocol. Existing response projections moved to the receipt owner.
- Retired one duplicate synthetic single-flight case and retained its assertions
  in the existing wake fixture. Real lease/restart/cancel/steering tests remain.
- No added validator, runtime state, approval, retry limit, package or desktop
  execution responsibility. No UI/install or end-to-end quality claim.
- Validation: final Claw native 1844/1844, Desk native 1726/1726 and real
  capability probe passed; initial focused tests were 53/53 before merging the
  duplicate case. Info/fmt,
  whitespace and .mbti checked. Production -61/test -63 lines, net -124,
  including embedded .mbt test blocks; moved projection bytes unchanged.
- Counting pitfall: .mbt filenames do not distinguish all tests. The retired
  service test was embedded in a normal source file; do not report its removal
  as a production-code saving or count file moves as deleted implementation.

## Boundary closure: tool resume and planner pauses 2026-11-06

- Recorded the eight-responsibility assessment in the design checklist:
  functional ownership is clearer than type/package isolation. Continue with
  actual boundary leaks and duplication; do not introduce eight packages,
  a full IR, new scheduler or confirmation workflow.
- Claw continuation owns decoded tool position/quantum end/in-call distinction
  and optional validated approval. Turn consumes these directly. A newer
  execution checkpoint must not resurrect a superseded approval wait; the
  existing service fixture now covers that recovery pitfall.
- Resumed and in-quantum planner pauses share one production chooser and
  checkpoint serialization. Removed two separate constructors and mutable
  duplicate pause state; existing fixtures exercise the real production path.
- Memory/filesystem/lock scope and command/plan/result Json limits remain.
  No desktop execution/recovery state or wire contract changes were added.
- Validation: Claw native 1845/1845, Desk native 1726/1726, focused
  recovery/approval 28/28 and producer/consumer probe passed. Check/info/fmt,
  interfaces and whitespace checked; .mbti unchanged. Production .mbt -85,
  tests +44, net -41; no new test cases, UI/install or live-provider claim.

## Eight-module re-audit: session metadata and execution evidence 2026-11-05

- Claw now restores first-prompt/title metadata and command count through the
  same existing snapshot/journal-pair entry. Intake no longer performs a
  separate first-prompt restore. The current task/revision remains distinct.
- Preserve cache/snapshot priority and owner validation. The removed duplicate
  reads affect cold/missing-prompt recovery; warm bindings already avoided
  them. No new cache/store, client projection or public API is introduced.
- Removed five test-only Claw production wrappers; real model round, provider
  retry/transport, sandbox config and receipt exit handling stay authoritative.
  One predicate test was retired; existing recovery and actual MoonBit command
  fixtures were extended. Negative exits are read from the real receipt rather
  than assumed to be 1. The fixture reports Degraded isolation, not production
  MoonFort enforcement. Retry test names now match the evidence they observe.
- Validation: Claw native 1845/1845, Desk native 1726/1726, core JS 64/64,
  UI 839/839; metadata/model-workspace 20/20, process/listing 28/28 and
  producer/consumer probe passed. Info/fmt and whitespace checked; .mbti
  unchanged. Production .mbt -66, tests +15, net -51. No new state machine,
  runner, model request or confirmation; no UI/install, live-provider or
  end-to-end performance qualification. See the current eight-module checklist.

## Eight-module re-audit: stream reads and typed readiness 2026-11-05

- Capability negotiation and readiness reuse one typed decode and the existing
  decision. Boolean readiness no longer builds/parses a status JSON object.
  Public response shapes and acceptance/error rules are unchanged.
- Claw raw diagnostics share one locked scanner for wait summaries and local
  spool output; zero-wait replay skips the discarded summary pass. Network
  delivery stays outside session/journal locks. Canonical watch remains the UI
  source; no desktop replay, index/store or new execution state was added.
- Removed test-only array replay/encoders and their positional cursor fallback.
  Existing production spool/HTTP tests cover physical positions, payload cursor
  shadowing, JSONL/SSE bytes, reconnect and rejection before 200. Six old-path
  tests and a duplicate daemon fixture were retired; no alternate producer oracle.
- Same-scanner local composition measurement: 1000 events, 10 iterations,
  three warmed batches 596/575/574 ms -> 386/386/388 ms. Includes spool/cleanup,
  excludes HTTP, model, compile/fixture and cold disk; no end-to-end speed claim.
  Temporary measurement code removed.
- Validation: Claw native 1846/1846, Desk native 1726/1726, core JS 64/64,
  UI 839/839; focused stream 8/8 and capability/routes 32/32, producer/consumer
  probe passed. Info/fmt and whitespace checked; .mbti unchanged. Production
  .mbt net -232, tests -293, total -525. No UI layout/package install or
  live-provider/full-task performance qualification. The eight-module checklist
  retains actual context, file, ownership, recovery and dependency limits.
- Tooling pitfall: refresh `moon ide` with its normal check after edits;
  `--no-check` can report stale/empty references from earlier source positions.

## Eight-module re-audit: catalog and execution ownership 2026-11-05

- Removed the duplicated core command/tool execution descriptions in both
  repos. Capabilities retain names/aliases/protocol ownership; actual schemas,
  argument checks, grants, tool policy and finish remain runtime-owned.
- Native packet assembly now serializes validated submissions directly,
  removing a full capability-tree allocation per submit and inferred packet
  control/approval fields. Real approval actions/IDs still pass through.
- commands is now an action-name array; tool_specs, old input-field catalogs
  and approval/review/completion labels are removed. No compatibility shim.
  Removed Desk's deprecated wrappers and three test-only bridge exports;
  Claw core drops 28 unused exports. Check .mbti removals, not just compilation.
- Old untagged cancellation matching and its fixture are gone; current tagged
  receipt replay, pinned targets and automatic startup recovery remain.
  The active-cancel predicate moved beside its producer without new logic.
- Retired five obsolete tests across both repos. One MoonWiki review test
  silently passed on an empty tools array; it did not prove runtime behavior.
  Actual schema/grant/file/finish/cancel/restart and UI regressions remain.
- Eight contracts were reviewed without forcing new abstractions: retain the
  context compiler, distinct lock lifetimes, native CAS and journal projection.
  Large scans, external writers and partial dependency provenance retain their
  limits. No new store, runner, state machine, model request or confirmation.
- Validation: Claw native 1852/1852, Desk native 1726/1726, core JS 64/64,
  UI 839/839, final cancel/recovery 14/14 and producer/consumer probe passed.
  Info/fmt and .mbti removals reviewed. Production .mbt net -2585, tests -379,
  total -2964; predicate relocation is not counted as deletion. No UI layout /
  package install or live-provider/end-to-end performance qualification.

## Process / Thread and restart recovery 2026-11-05

- MoonClaw daemon startup now discovers unfinished sessions from configured
  trusted Books and resumes the ordinary service without desktop resubmission.
  The desktop does not own a recovery queue, scheduler or new confirmation.
- Only pending candidates restore bindings. Existing journal claims,
  continuations, results and execution leases remain the execution authority.
  A queued command can precede a service finish; ordinary drain gaps resume.
- Explicit active-cancel events distinguish user stops from process shutdown;
  a cancelled coroutine alone does not carry that intent. Existing pending
  withdrawal and lifecycle boundaries remain distinct.
- Unresolved approvals wait; durable decisions can resume. Finished explicit
  manual limits stay stopped. Interrupted services retain their ID and options;
  max_turns remains per invocation, without a new cross-restart quota mechanism.
- Temporary local scan: 100 completed small sessions plus one empty fixture,
  23/25 ms, no retained bindings. No model/compile/cold-disk or large-log claim.
  Measurement code removed. See the design checklist for the full contract.

- Validation: Claw native 1854/1854, Desk core JS 65/65 and real producer /
  consumer probe passed. Info/fmt and whitespace checked; .mbti unchanged.
  65 local links and 11 unchanged archive hashes checked. Production .mbt
  net +163 and tests +287 for the missing startup path; no deletion claim.
  The existing quantum test now exercises new Daemon serve instances and
  cancellation/restart. No UI/install change, live-provider, SIGKILL /
  power-loss or production performance qualification.

## Data Model / Compute Engine convergence 2026-11-05

- Completed operation events own their execution header and tool_result.
  Checkpoints use event_id/event_digest or inline_execution for synthetic
  results, with no copied header or journaled_result flag. Event display
  names must not decide storage shape; patch/finish results can be refs.
  Operation recovery and hydration share mooncode_tool_execution_from_event.
- Initial/current/follow-up selection matches the existing ResumePoint.
  Quantum, transport and replan follow-ups share one assembly; retain
  steering, guidance and finish_rejected semantics. No new state machine.
- Receipt consumers use canonical nested result. Old flat worker fallback
  and flat-only conversation assumption are removed; fixtures now match
  the real producer. No legacy reader or output approval stage was added.
- Removed dead patch-verification metadata classification and its empty
  test. Ordinary patch completion has no new mandatory check or action.
- Temporary measurement: 100 write results with 33020-char source arguments,
  history serialization 3561392 -> 12692 ASCII chars. Original result events
  and current transcript are excluded; no model tokens/latency claim.
  Digest calculation and reference traversal still have their existing cost.

- Validation: Claw native 1852/1852; data/receipt/worker 75/75; model resume
  and steering 50/50 before retiring the old test; reference roundtrips 4/4;
  Desk core JS 65/65, UI 839/839; real producer/consumer probe passed.
  Info/fmt and whitespace checked; .mbti unchanged. Production net -68 lines,
  tests net +21, total -47. One obsolete test removed; existing tests extended.
  63 local links and 11 unchanged archive hashes checked. No app install,
  live-provider or end-to-end performance qualification.



## Eight primitive contracts audit 2026-11-05

- Current responsibilities are process/thread, memory, filesystem, I/O,
  synchronization, fault tolerance, data model and compute engine. See
  the runtime boundary and MoonDesk design synthesis for per-interface
  inputs/outputs, logic, actual guarantees and sibling comparisons.
- Retired unused `PruneResult`, `calculate_pruning` and `prune_messages`,
  four direct package dependencies and eleven legacy-only tests. Context
  has one real compiler; don't restore a second in-place pruning API.
- External execution entry points acquire session gates; internal
  `*_under_runtime_gates` borrow them. The loop no longer accepts a Boolean
  deciding whether to reacquire ownership. Lifecycle, execution, journal
  and native file locks protect different resources and remain distinct.
- Parallel scheduling reads the existing policy, not a second tool-name
  allowlist. Resource reads retain canonical identity. Declared read-only
  result recall and MCP listing now qualify for ordinary batches.
- Work-step identity follows operation_id on the runtime path. Provider
  call IDs can repeat upstream; they are not cross-round execution keys.
  Existing tests cover reuse, ordered parallel recall and no effect replay.
  Work steps use item_id/command_id/event_id; removed duplicate aliases
  step_id/turn_id/evidence_ref. Top-level turn/message IDs remain.
- Uncertain-operation recovery uses the common execution constructor.
  No extra state machine, agent, store, model call or human step was added.
- Remaining limits: cooperative native file locks; process tools/external
  writers do not participate. The boot discovery gap recorded at this audit
  is closed by the Process / Thread update above. Internal Json and
  partial dependency provenance do not constitute a typed IR or full DAG.

- Validation: Claw native 1853/1853; identity/session 21/21; initial focused
  checks 43/43; Desk core JS 65/65 and UI 839/839; real producer/consumer
  probe passed. Info/fmt and interface diff reviewed. Production .mbt net
  -157, tests net -282. No UI layout/build or installed-app change; no live
  provider/performance qualification. Archive hashes remain unchanged.



## Programmable single-agent path 2026-11-05

- Initial/follow-up share one model round. Ordinary tools and checkpoint share
  result assembly; consumers use the canonical result boundary.
- Completed operation IDs identify results; tool-call IDs join start/result.
  Same-millisecond parallel reads must never collapse or match by tool name.
- `read_result` reads only retained session results, including patch events.
  Compaction preserves exact or first/last references through repeated passes.
  It does not rerun effects or reconstruct output already truncated at execution.
- Work graph is a disposable canonical projection and uses existing UI cards
  and file navigation. It is not a scheduler, completion rule or new store.
- Known local chunks use existing shell/project scripts; tiny native edits are
  faster locally. Measurement: six read/write calls 4 ms; fixture-bridge .mbtx first
  512 ms / warm 204 ms (script also checked outputs; no model time/tokens; Degraded fixture,
  not a production MoonFort performance measurement).
  Do not claim end-to-end speedup or live deliverable-quality improvement.
- Validation: Claw native 1864/1864 + final projection focus 30/30; Desk
  native 1729/1729; core JS 65/65 + graph codec 3/3; UI 839/839; Node 24/24.
  Real producer/consumer probe, info/fmt and production UI build passed.
  Build 53.57 s; main chunk +4049 bytes vs baseline. Source production net
  +482/test +341; shared round/result consolidation alone net -61 production.
  Existing warnings remain; live-provider and installed-app qualification
  are not included. The historical archive remains unchanged.



## Projection/Telemetry cleanup 2026-11-05

- Canonical watch moved to MoonClaw's existing session/journal projection.
  MoonDesk resolves the Book and adapts session metadata, preserving exact
  revision strings and runtime status. Do not restore raw-event downloads,
  event-count cursors or a desktop completion/replay reducer.
- Removed unused typed resume, replay/cursor trial code, synchronous metrics
  exporter and export-only SDK method. Planner observations reuse existing
  final events; canonical usage no longer depends on compacted historical plans
  or repeated receipts. Distinct responses reuse the daemon UUID source because
  timestamps can repeat. Missing usage/prices remain unmeasured/unpriced.
- Snapshot rebuild still reads full history; metadata polling and a temporary
  command index reduce repeated work without another projection cache. Dedicated
  graph UI is delivered in the later five-step plan; complete dependency edges
  and live outcome/cost baselines remain unchecked in the synthesis. No new state machine, store or human gate.
- Validation: Claw native 1862/1862; Desk native 1729/1729; core JS 65/65;
  UI watch/usage 108/108; real producer/consumer probe passed. Info/fmt and
  interface review passed. Code/tests net -2046 lines (-1307 production,
  -739 tests). 42 local links and 11 unchanged archive hashes checked.
- Runtime and desktop both advertise the watch endpoint; update them together.
  Existing warning debt and lack of installed-app/live-provider qualification
  remain. The SDK stream cursor/export methods were intentionally removed.

## Context/Journal cleanup 2026-11-05

- MoonClaw uses the existing context compiler by default for initial and
  follow-up planning. Fixed suffixes, shadow/active flags and overload transcript
  rewrites are removed; tool result JSON is no longer clipped again by planner.
- One recovery-position decoder reuses the existing loop and operation results.
  The append cache retains directory-sync success, invalidated before lifecycle
  moves; ordinary cached appends sync file bytes. No new state machine, store,
  model round or human confirmation was added.
- Checklist sections 3 and 6 record implementation and limits. Model-facing
  history lookup was unchecked at that step; read_result shipped later. The desktop continues to
  consume canonical conversation facts without a local replay path.
- MoonClaw native 1873/1873 and the real producer/consumer probe passed;
  public interfaces are unchanged. Code/tests together net -1611 lines, with
  95 test-helper lines moved rather than counted as deletion. The historical
  archive's 11 hashes are unchanged. No UI or packaged-app change was needed.

## MoonCode design discussion

MoonCode design discussion is archived in
`docs/mooncode-discussion-2026-11-04/README.md`, including all four projects'
16-question answers and the full conversation. Use `CURRENT_PLAN.md` there as
the implementation baseline: automation first, one primary agent, deletion of
duplicate mechanisms, and no compatibility requirement. Earlier proposals for
a new runtime framework and universal acceptance gates were superseded; do not
combine all historical plans into implementation requirements. Active references
are `docs/MOONCODE.md` and `docs/CODE_MODE_TEST_PLAN.md`; the old MoonCode phase
plans and execution diary were removed. Do not restore document-phrase closure
checks or treat dated test reports as current readiness.

The 2026-11-05 synthesis is
`docs/MOONCODE_AGENT_MACHINE_AND_DYNAMIC_GRAPH.md`: execution primitives,
OS/compiler/database/dataflow mappings, framework comparison, executable
top-down work and task-driven dynamic graphs. Keep the November 4 archive
unchanged. Minimal graph presentation has shipped; do not turn this design record
into another completion gate, graph database or user-authored wiring workflow.

## Current single-agent implementation

- Goal APIs, separate quality/no-change policy and desktop
  package-review/proof-gate inference were removed; ordinary completion uses
  `finish` and the existing canonical runtime projection.
- The task-controls surface keeps the editable working plan, removes the Goal
  form and hides an empty agent team. Do not recreate a desktop task state
  machine. A DOM interaction test verifies plan saving without a Goal form.
- The full discussion archive is historical and unchanged. Active runtime
  behavior is documented in MoonClaw's executable-book boundary.
- Capabilities and listings no longer require or project the nine-step
  executable-book lifecycle report. The canonical conversation and actual
  runtime owner/session/watch contracts remain authoritative. Update producer
  and consumer together; no old-protocol compatibility is required.
- `integration/mooncode_contract_probe` runs the real MoonClaw producer against
  the MoonDesk decoder using explicit local workspace dependencies. Keep this
  behavioral check instead of document phrases or duplicated readiness rules.
- MoonClaw now uses one native catalog for initial and follow-up requests.
  Keyword bundles, native tool search/loading and their trial tests were
  removed. Read-only subsets, explicit selection and MCP remain; no extra
  framework or approval step was added.
- Empty follow-ups resume through existing claims and results without a
  milestone prerequisite. Progress notes neither permit retries nor grant
  completion. MoonClaw preserves rejected-finish state across repeated empty
  responses; MoonDesk continues to display its canonical runtime facts.
- The runtime now documents its process/thread, memory, filesystem, IO,
  synchronization and fault-tolerance mapping. One shared model instruction
  applies top-down decomposition until executable, then implementation and
  verification. This adds no desktop phase, state machine or plan approval.

## Tool boundary cleanup 2026-11-05

- The synthesis's current plan is organized by Task, Execution, Context,
  Workspace, Tools, Journal, Completion, Projection and Telemetry. It replaces
  the rejected generic phases 0–5 with concrete responsibility/removal targets.
  Task/Completion/Execution are implemented; Tools/Workspace now have a
  first cleanup pass, with unchecked resource-identity/ABI/isolation work still
  pending. The older ten-item checklist covers the earlier tool cleanup.
  Keep real authority/data contracts while removing redundant policy.
- The design synthesis now contains a completed ten-item cleanup checklist
  and evidence. MoonClaw owns pure tool semantics in `internal/mooncode_tools`;
  MoonDesk continues to project canonical runtime facts, with no new UI phase.
- Guardian shadow qualification and the command-wide post-commit seal were
  removed. The same authorized command can commit, repair, verify and finish;
  changed verification inputs still prevent stale completion.
- MoonClaw native 1917/1917 and pure module 17/17 passed; two sandbox/runtime
  commit tests and the real cross-repo capability probe passed. Existing
  interfaces are unchanged. Production MoonBit net -623 lines; tests net -498.
- All 32 local design links resolve; November 4 archive hashes remain unchanged.
  No desktop runtime/UI code changed, installed-app update or live-model
  quality qualification was performed. Existing release warning debt remains.

## Task Completion Execution cleanup 2026-11-05

- The design checklist now marks Task, Completion and Execution complete;
  Context/Workspace/Tools/Journal/Projection/Telemetry remain pending.
- MoonClaw removed keyword-driven catalog/completion rules, the project-specific
  dynamic skill gate, forced recovery reads and read/retry rejection policies.
  Full requests and ordered task updates are preserved, and completion facts
  are owned by the existing completion file. Required checks, fingerprints,
  authorization, cancellation and journal recovery remain in place.
- MoonClaw native 1899/1899, related recovery/control 118/118 and final focused
  checks 20/20 passed. The real producer/consumer probe passed; interfaces are
  unchanged. Production `.mbt` net -1122 lines; tests net -1069.
- Documentation links and the unchanged November 4 archive were checked.
  MoonDesk runtime/UI was not changed. Existing warning debt and the lack of
  live-model/installed-app qualification remain; do not claim those passed.

## Tools Workspace cleanup 2026-11-05

- Removed command-word approval inference and planner-based exemptions.
  Explicit approval annotations always remain effective; normal execution
  binds the exact configured MoonFort capability without an extra human step.
- Removed global shell-authoring prohibitions and file-tool MoonBit manifest
  grammar checks. Project instructions and real compiler checks remain.
  Shell now has one execution entry and one shared preflight implementation.
- The pure policy exposes only parallel-read, after-skill and replay facts.
  Removed obsolete sensitive/install/overwrite/inline-authoring parsing and
  associated tests; retained actual read-only scheduling and check semantics.
- Unified single/multi-file diffs use one executor with file/hunk identity,
  fingerprints, prevalidation and existing rollback. Scope is parsed once;
  absolute in-book paths compare like relative paths. Whole-workspace scope
  skips the Git snapshot; narrow scope snapshot failure precedes execution.
- Authoring shells invalidate prior checks through the existing boundary.
  Receipt changed paths join tracked check inputs; the collector returns
  paths directly instead of constructing artificial before/after states.
- Do not mark the entire Workspace/Tools plan done. General ABI/schema
  convergence, canonical symlink identity, narrow/formatter snapshot cost
  and external/concurrent-write isolation remain unchecked. Current grants
  have no per-task writable-path field; snapshots are not transactions.

- Validation: final native 1892/1892; final completion/formatter/repair checks
  17/17; real MoonClaw producer → MoonDesk decoder probe passed. `moon info`
  and `moon fmt` passed; the only interface diff removes obsolete internal
  tool properties/functions. Six existing daemon warnings remain. Production
  `.mbt` net -568 lines; tests net -447. No new package/state machine, human
  approval step or model request. No desktop runtime/UI change or installed
  app/live-provider qualification. Full-workspace scope removes entire Git
  snapshots, but narrow scopes retain their existing O(worktree) cost.

## Tools ABI and Workspace identity follow-up 2026-11-05

- The cached runtime catalog now owns schemas and supported-name lookup.
  One validator covers model decoding, pre-approval calls and execution.
  Removed legacy request aliases and hidden patch verification execution;
  actual grants and result/event/provider contracts remain distinct.
- Both repositories removed the unused native command policy tables,
  tool sequences and result checklists. Capability fingerprints changed
  together; keep the real producer/consumer probe, not those phrase tests.
- Physical workspace paths now join scope, aliases, parallel-read identity,
  verification and command selectors. Check receipts bind actual paths;
  retargeting an alias to equal bytes still invalidates the earlier check.
- Native writes reuse OS locks, pinned Book resource comparisons and atomic
  sibling rename. Stable per-resource lock paths survive inode replacement;
  other files proceed. Optional expected_fingerprint supports stale writes.
  Rollback only compares/restores successfully committed patch members.
- Pitfalls: /var and /private/var aliases must agree in shell boundaries and
  argv; pre-approval schema checks prevent malformed calls waiting on humans.
  A scope snapshot lists dirty tracked files, not every tracked file: a clean
  missing baseline needs read-only HEAD content, not deletion or blind restore.
  Runtime lock metadata belongs to .moonsuite, excluded like product state.
- Limits: CAS retains the reused 16 MiB text-reader bound and preserves rwx,
  not inode/owner/xattrs or cross-file/power-loss transactions. Process tools
  do not participate in native file locks; non-cooperative writes and hostile
  parent replacement remain stronger-isolation work. No new package, state
  machine, model round, global workspace mutex or human confirmation.

- Validation: MoonClaw native 1890/1890; MoonDesk native 1733/1733;
  protocol-core JS 66/66; focused runtime/core 16/16 and boundaries 23/23;
  real producer → decoder probe passed. Info/fmt passed, with the existing
  six daemon warnings. 40 local links and 11 archive hashes checked.
- Production MoonBit net -1695 across both repos (-901 Claw, -794 Desk).
  Tests net +66 after replacing retired policy assertions with four actual
  boundary regressions. Moving the catalog is not counted as deletion.
  Interfaces remove 25 unused policy APIs, add the shared validator and
  Stat.mode, and replace unchecked Git restore with read-only HEAD lookup.
  No installed-app or live-provider qualification was performed.

## Validation 2026-11-04

- Last MoonDesk code validation (`5f6174bc`): native 1734/1734, UI 2293/2293,
  JavaScript 514 with one skipped. Later rounds change MoonDesk docs only.
- MoonClaw's shared-program cleanup passed its full native suite 1927/1927,
  including generic and Kimi-identified local transport/restart fixtures.
  Public interfaces are unchanged; the real producer/consumer probe passed again.
- The strict release gate still stops at existing warnings: unused Flow
  sandbox declarations, an unused UI pack helper, and four unnecessary
  annotations in external MoonLeaf. No installed-app update or live-model
  quality qualification was performed.
- Native Flow crossing requires its separately configured fixture; ordinary
  suite success does not establish that external integration.

## UI preview and packaged application

- The installed Lepusa app serves its frontend and API on port 4201. A separate
  development backend may be running on 4199. Inspect the actual app URL rather
  than assuming that a browser preview uses the installed backend.
- For UI iteration, run the existing Vite development command with
  `MOONDESK_API_ORIGIN=http://127.0.0.1:4201`. The default proxy target is 4321.
  Inspect the development preview before doing the production frontend build.
- UI-only edits need a frontend build, resource installation and app signature
  verification. They do not require relinking the native executables. Native
  backend changes require the corresponding native build and packaging path.
- Canonical Desk section aliases may be localized; authored names and real
  paths must remain content. `app` and `apps` are separate section identities
  and must remain distinguishable in Chinese.
- File selection accepts workspace drops on the whole dialog. Preserve this
  interaction when removing the old instructional dropzone. Keep loading,
  empty results and failures distinct.
- Attached editors that replace their form DOM must set
  `data-popup-focus-dismiss="false"`. Native WebKit can briefly restore focus
  to the main workspace during reconciliation; treating that as an outside
  dismissal closes the editor immediately. Outside pointer/Escape dismissal
  remains handled by `quiet-controls-runtime.js`.

Latest inspection: `docs/UI_UX_AUDIT_2026-11-04.md`.

Secondary-surface continuation: `docs/UI_SECONDARY_AUDIT_2026-11-04.md`.

- Legacy activity selections can close the command palette without opening a
  modern focus-view tool. Route settings/search to their actual local tool
  messages and verify the destination, not only palette dismissal.
- Drawer redraws must preserve unsaved preference/learning drafts per book.
  Input availability updates should not rebuild the form or lose focus.
- Icon-only utilities need localized accessible labels. DOM tests should find
  them through those labels rather than visible text.
- Native WebKit can render selects shorter than the shared minimum height.
  Single-select controls in secondary surfaces use explicit height/appearance
  and the shared chevron; verify them in the native app, not only Chromium.

State/narrow-window continuation: `docs/UI_STATES_AUDIT_2026-11-04.md`.

- Book's Markdown/image/source viewer must consume `preview_state`, not infer
  loading from `preview == None`. A failed request can legitimately have no
  preview; show its failure and retry the selected path locally.
- Markdown uses the generic preview path, while
  `wiki_document_path_supported` identifies Office/PDF/artifact handling.
  Do not reuse that predicate to decide whether a normal Markdown file exists.
- Loaded setup drafts must not retain an in-flight `loading` flag after their
  old DOM is detached. Refresh success must clear stale errors even when data
  has not changed; apply the same rule to room polling.
- Shell `data-state` updates also occur while Code is polling. Recreating
  calendar/room runtime roots on each update resets scroll, focus and pending
  requests. Retain the local view for the current book/document, and restore
  its position when the shell reattaches it.

Code/Flow continuation: `docs/UI_CODE_FLOW_AUDIT_2026-11-04.md`.

- Translate changing typed status text before rendering it. Automatic
  localization can replace a text node retained by the virtual DOM; the next
  state can otherwise leave a stale translated loading message on screen.
- A non-Git MoonBook needs an explicit Changes state with refresh. An unloaded
  source editor must not claim Saved or clean diagnostics.
- Code's working-panel controls use stable button roles and pressed/expanded
  state, and explicitly restore their enabled state. Opening a local panel
  never requires a selected file, chat or PTY. Preserve direct click handlers
  and keyboard switching when changing the runtime-managed controls.
- Flow composition retrieval failure is independent of an empty runs listing.
  Keep the previous composition on failure and offer Retry locally.
- A Flow listing refresh should retain a verified result viewer when its exact
  artifact identity is unchanged. Reset its review context and invalidate the
  viewer when the refreshed identity changes.
