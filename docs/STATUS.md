# MoonDesk productization status

The authoritative scope and phase gates are defined in `docs/MOONDESK_PRODUCTIZATION_UPGRADE_PLAN.md`.

## Current execution

The productization program has reached its finite Phase 10 decision:
**Not ready**. Phases 0–8 have passed their recorded repository or hosted gates.
Phase 9's repository-owned distribution path is implemented and locally
validated, but the Phase 9 external gate remains blocked.

The consolidated audit, exact owners, target dates, and evidence required to
change the decision are in
[`FINAL_RELEASE_READINESS_2026-07-30.md`](FINAL_RELEASE_READINESS_2026-07-30.md).
The distribution implementation and external proof boundaries are in
[`PHASE9_NATIVE_DISTRIBUTION_REPORT.md`](PHASE9_NATIVE_DISTRIBUTION_REPORT.md).

The earlier full Phase 9 local validation completed every functional stage before its
clean-tree assertion: 338 native tests, 501 UI tests, 6 localization tests, 8
release-verifier tests, the Phase 9 non-credentialed smoke, the production
build, generated-interface verification, and whitespace checks passed. The
root check then reported 331 warnings. The current coding-workflow source
passes its native and Code UI warning checks at 0/0, but warning-clean release
readiness is not inferred from that alone.

The coding-workflow hosted CI result is recorded below. Developer ID,
notarization, Gatekeeper, hosted update, clean-machine, lifecycle, rollback,
removal, and 24-hour soak results cannot be inferred from local checks.

## Coding workflow checkpoint (2026-09-27)

At `7ebaa3cc`, hosted [push](https://github.com/vectie/moondesk/actions/runs/36309434915)
and [PR](https://github.com/vectie/moondesk/actions/runs/36309438059)
validation passed. The [exact-head unsigned `.21` preview](https://github.com/vectie/moondesk/actions/runs/36309440270)
passed full Linux validation, the focused macOS gate, packaging, and upload.
Downloaded artifact `10928757034` independently passed five-file
verification, identifies source `7ebaa3cc3057db550e5375658d3cd31e2f35b722`,
declares `hosted: false`, and contains the arm64 Lepusa runtime and MoonDesk
sidecar. A native collision check against that artifact started one instance,
received HTTP 200 from its health route, and saw the second instance refuse
the occupied endpoint instead of displaying the first instance's UI. That
check also found that the failed second launch returned process exit code 0.
Lepusa [PR #2](https://github.com/vectie/lepusa/pull/2) now fixes that exit
status at `55aa50e`; the first-instance and collision check against a
temporary copy of the app with the rebuilt runtime produced exit code 1 for
the failed second launch. The next MoonDesk preview pins this newer runtime;
its hosted package needs separate exact-head verification.

The latest native coding-workflow checkpoint is in
[`CODING_WORKFLOW_UPGRADE_PLAN_2026-09-26.md`](CODING_WORKFLOW_UPGRADE_PLAN_2026-09-26.md):
the exact-commit unsigned `0.0.0-preview.21` package at `720cf267` passed
release identity, five-file checksums, nonhosted channel validation, and
packaged UI comparison. Its native Mac window opened PR #6 at that exact
head in an isolated worktree, loaded all 270 files in directory groups,
filtered to one source file, and exposed a Chinese exact-line composer. A
disposable draft saved locally and was discarded without posting to PR #6.
The preceding `.17` native check also covered conversation drafts, an exact
line anchor after reopening, and keyboard Save with Option-Tab and Return.
Hosted [push](https://github.com/vectie/moondesk/actions/runs/36292356337)
and [PR](https://github.com/vectie/moondesk/actions/runs/36292359047)
validation passed at `5b83c6b5`; the current revision's hosted checks are
recorded below. The MoonTown schedule owner has a separate draft
[PR #1](https://github.com/vectie/moontown/pull/1). This evidence does not
establish the external Phase 9 release gates.

At implementation commit `4b1521b9`, the clean full validator passed 491
MoonDesk native tests, 626 Code UI tests, 1,959 MoonClaw tests, 369 MoonBook
tests, the pinned MoonTown packages, localization, release verification,
the production UI build, and the core boundary checks. The strict MoonDesk
native and UI warning budgets remained 0/0. Hosted
[push](https://github.com/vectie/moondesk/actions/runs/36306032740) and
[PR](https://github.com/vectie/moondesk/actions/runs/36306036322) CI passed.
The [unsigned `0.0.0-preview.21` workflow](https://github.com/vectie/moondesk/actions/runs/36306036498)
passed full Linux validation, the focused macOS gate, package creation,
artifact re-verification, and upload. Its downloaded artifact passed the
five-file checksum verifier; release identity names `4b1521b9` and the
preview channel declares `hosted: false`. The app contains arm64 Lepusa
runtime and MoonDesk sidecar executables. The hosted artifact remains an
unsigned QA preview, not a signed release or a hosted update channel.

The coding-workflow gap analysis and phase-by-phase implementation record are
[`OPENSEEK_GAP_AUDIT_2026-09-26.md`](OPENSEEK_GAP_AUDIT_2026-09-26.md) and
[`CODING_WORKFLOW_UPGRADE_PLAN_2026-09-26.md`](CODING_WORKFLOW_UPGRADE_PLAN_2026-09-26.md).
The MoonDesk–MoonTown schedule create/read/pause/resume path passed a connected
disposable-MoonBook check. A Chinese browser check also verified a duplicate-ID
conflict gives a specific message without losing the form draft. The source
editor, local/PR review, durable media, job and skill evidence, and scheduled
work have local implementation and validation described in that plan.
After the temporary native QA workspace was removed, `moon info`, `moon fmt`,
and the MoonDesk native command check passed against the ordinary dependency
graph; `moon info` still reported 270 warnings. The latest full MoonDesk native
test command, nested Code UI test command, seven localization checks, and three
production bundle checks all exited successfully. The focused MoonClaw native
daemon regression also passed.

This checkpoint does not change the **Not ready** decision. The rebuilt
MoonClaw daemon now serves the disposable MoonBook fixture. Its exact child
MoonBook session listing, Code conversation link, skill catalog, failed-job
history, and byte-free conversation export passed connected checks. The focused
native daemon regression for child-MoonBook listing and guarded deletion passed.
Real MoonFort navigation and executor-backed scheduled execution,
connected phone-width schedule execution with a configured
model, and the external release evidence above still require proof.
The unsigned preview packaging check also exposed a current dependency issue:
published `vectie/lepusa@0.1.6` resolves `moonbitlang/x@0.4.45`, whose path
regex syntax fails under the installed MoonBit 2026-09-20 compiler. The
preview helper now accepts an explicit local Lepusa checkout, restores the
ordinary workspace after packaging, and rejects a version that would fail the
preview-channel contract. With that checkout, the full unsigned
`0.0.0-preview.4` preview package, five-file checksum verification, release
identity, and non-hosted channel metadata passed. The packaged sidecar matches
the workspace build byte for byte, and its Code entry matches the checked-in
production bundle. Its schedule route returns an actionable 503 when MoonTown
is not configured, rather than the stale package's 404. The exact
`0.0.0-preview.4` app's Code setup and schedule form were inspected in its native
window at desktop and a measured 392 × 854. The schedule panel shows the
localized MoonTown setup action instead of remaining on Loading after the 503;
Refresh repeats that actionable state. Its message, fields, and disabled submit
control remain readable and reachable without horizontal overflow. Native
keyboard QA moved through schedule ID, task, and cadence, then skipped the
disabled submit. The latest Code bundle's Chinese answer controls, copied
feedback, and failed-work status passed connected browser accessibility checks.
The managed MoonClaw launcher now retains the private path-only control
binding across a daemon restart; the rebuilt fixture returned ready Code
status and its image-capable model catalog. The native adapter now sends
validated images once in the canonical command field. Mixed text/image and
image-only turns completed against a disposable loopback model, each with one
image in the model request. Authenticated media replay matched the submitted
PNG byte for byte, including after daemon restart. Code paste/drop images
stay out of workspace import. Native QA on the unlocked Mac found that the
programmatically clicked hidden file input did not open a picker. The composer
now contains a directly clickable file input. A missing top-level Code message
route had also silently discarded image intake; its regression test now covers
attachment and removal through the same handler used by the app. In the
connected browser, file selection, preview, removal, same-file reattachment,
image-only submit to the disposable loopback model, and canonical image and
answer replay after reload all passed. Enter opens the picker from the focused
file input, and Tab moves from attachment to submit. On the unlocked Mac,
the isolated `0.0.0-preview.12` app opened the native Open panel from Code,
accepted the synthetic PNG, displayed its preview and name in the composer,
and removed it through the visible control. A real provider has not been
exercised. A disposable MoonTown owner tick dispatched one scheduled Code turn through the
private MoonClaw control, the loopback model completed it, and a later tick
reconciled the schedule to done. The schedule is paused and its journal has
exactly one command. After a managed MoonClaw restart, the same scheduled
session reopened as done and still had one journaled command. Code's Chinese
browser UI opened the same scheduled conversation and displayed its completed
Work and answer. A fresh unsigned `0.0.0-preview.6` package includes the final
adapter fix and passed five-file checksums, release identity, and
non-hosted preview verification. The unsigned `0.0.0-preview.7` package
additionally labels completed and stopped Code sessions explicitly; the
rebuilt Chinese browser UI displayed 已完成 for the scheduled session. The
unsigned `0.0.0-preview.8` package passed its five-file checksums, release
identity, and preview channel; native QA exposed the image-picker defect. The
unsigned `0.0.0-preview.9` package contains the direct file input but predates
the message-route fix. The `0.0.0-preview.11` package includes that fix and a
two-column Code action layout at 390 px. The browser check
showed no header collision, no horizontal overflow in the composer, and
reachable transcript and attachment controls. The local Lepusa macOS runtime
now installs a WKWebView UI delegate that presents an app-owned file panel;
[Apple's WebKit documentation](https://developer.apple.com/documentation/webkit/wkuidelegate/webview%28_%3Arunopenpanelwith%3Ainitiatedbyframe%3Acompletionhandler%3A%29)
states that macOS file uploads are disabled without this callback. The
unsigned `0.0.0-preview.12` package includes this host change and passed
five-file checksums, release identity, and preview-channel verification.
Native picker and attachment acceptance passed on the isolated `.12` app;
the real-provider image turn remains pending.
Disposable GitHub PR [#5](https://github.com/vectie/moondesk/pull/5) verified
the connected Code publication path. A saved conversation draft survived page
reload and published as [comment #5851317380](https://github.com/vectie/moondesk/pull/5#issuecomment-5851317380).
An exact right-side line 4 review published as
[discussion #4113537062](https://github.com/vectie/moondesk/pull/5#discussion_r4113537062).
After the PR head advanced, the server refused a stale line draft, MoonDesk
retained the text, and a reload showed the saved draft without a post action.
The stale-request status and rejection decoding were corrected and passed the
Code UI tests. The QA PR was closed and its remote branch removed. The later
`.17` native composer check is recorded at the top of this section.
The latest unsigned `0.0.0-preview.13` package contains the PR failure-status
and rejection-message fixes. Its five-file checksums, release identity,
non-hosted preview channel, and packaged UI asset match passed. It was built
from the current uncommitted working tree; the identity's source commit alone
does not represent these changes.
Draft MoonDesk PR [#6](https://github.com/vectie/moondesk/pull/6) carries the
coding-workflow implementation. In a connected isolated PR worktree, Code
loaded all 260 changed files in bounded GitHub pages and showed the selected
base-to-head diff. File-path search reduced that live list to five matching
files and an unmatched query showed a clear empty state without losing the
selected diff. The original fixture checkout stayed dirty and unchanged.
The CI workflow now installs its required `ripgrep` tool; the unsigned preview
workflow uses pinned companion checkouts and an exact Lepusa preview host
revision. Local traffic-routing validation and the MoonClaw-producer to
MoonDesk-consumer protocol probe pass with the current MoonBit dependency.
Both hosted validation runs for the `5b83c6b5` PR revision passed,
as linked at the top of this section.
The current source tree now passes the strict MoonBit warning gate at 0/0
warnings for native and Code UI JavaScript targets. Deprecated environment,
string-builder, and byte-view calls were updated; derived trait methods are
explicitly extended, and test-only experimental rendering is scoped at each
affected test. Hosted repository validation now passes; hosted distribution
and credentialed release evidence remain open.
The local checkout path is not a clean-checkout dependency fix or signing,
notarization, and clean-machine evidence.

## Evidence policy and navigation contract

Repository-local work is complete only when its phase gate passes. Hosted CI,
signing, notarization, clean-machine, update/rollback, and soak claims remain
external evidence until their actual artifacts or URLs are recorded; missing
external proof does not block repository-local work that the authoritative
plan explicitly marks independent, but it does block dependency gates such as
Phase 2 to Phase 3.

Primary navigation remains exactly **Desk, Wiki, Code, Flow, Packs**, with
**Requests, Runs, Review, Publish** below Wiki.

## MoonSuite integration status

MoonDesk now follows the suite's single-runtime, graph-first topology:

- MoonFind owns discovery and desired-capability graph intent; MoonDesk presents
  its executable Work model for selection and inspection.
- MoonFlow owns validation, scheduling, execution, reconciliation, and restart
  recovery.
- MoonGate owns exact capability and authority resolution.
- MoonClaw is the sole agent runtime; MoonCode is a role/profile.
- MoonBook owns MoonWiki functionality, Bookkeeper outcome closure, and
  reviewed Three-Gap proposals.
- MoonTown owns civic coordination and reviewable cross-book synthesis.

The composition boundary accepts `moonsuite.work-model.v1`, resolves nodes
against `moonflow.capability-catalog.v1`, and keeps unsupported or unvalidated
operations unavailable. Validation and import share one digest-pinned catalog
snapshot and server-UTC evaluation time; their snapshot, report, and receipt
are retained under MoonDesk product state. Controls delegate to MoonFlow, and
missing runtime evidence disables rather than fabricates controls. Continuation
comes from graph dependencies and runnable state rather than hardcoded product
cards.

The locally validated MoonFind robotics reference has 63 stages, 43 unique
operations, 63 typed primary requests, and 11 domain-product owners. It
contains no MoonMini or MoonStat node and no publication, trade/order, or
physical robot command.

This integration evidence does not change the Phase 10 release decision.
MoonDesk has current hosted repository CI and warning-clean coding-workflow
checks. It still requires credentialed release evidence, signing,
notarization, clean-machine install/update/rollback/removal, and a 24-hour
lifecycle/resource soak. A production suite run additionally requires
host-published unexpired adapter health, real credentials, licensed providers
and data, named reviewers, rights/customer evidence, calibrated robotics
simulation, a safety case, and separately granted external or physical
authority.
