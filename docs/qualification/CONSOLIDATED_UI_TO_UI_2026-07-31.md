# MoonSuite consolidated UI-to-UI qualification — 2026-07-31

This is the current cross-repository qualification index and operator runbook.
It consolidates the product-owned guides listed in [Source guides](#source-guides)
without rewriting the earlier baseline reports. Historical results remain in
the standalone, interproduct, and remediation documents.

## Reading the result correctly

This report uses four deliberately narrow labels:

| Label | Meaning |
| --- | --- |
| `OBSERVED PASS` | The meaningful action and result or denial were observed through the published UI in the coordinating browser run. |
| `EXPECTED BLOCKED` | The UI correctly stops at a known missing contract, authority, provider, or product surface. This is useful behavior, but not an end-to-end pass. |
| `UNTESTED` | The procedure and implementation may exist, but this coordinating browser pass has not supplied visible evidence. |
| `NOT-APPLICABLE` | A standalone UI would violate the product shape. Qualification must happen through the named visible producer/consumer. |

An API call, source inspection, unit test, build, or screenshot by itself is
not `OBSERVED PASS`. Reload proves browser recovery; a process stop/start with
the same data root is required before claiming restart recovery.

## Current product matrix

This focused matrix covers the products that received new product-owned
qualification guides in this pass. Bunnia/Rabbita, Lepusa, MoonDesk, MoonEdit,
MoonFlow, MoonGate, MoonLeaf, MoonLib, and the public website were not silently
reclassified; their retained cases remain in the
[A–M](STANDALONE_A_M.md), [N–Z](STANDALONE_N_Z.md), and
[remediation](REMEDIATION_2026-07-31.md) reports. MoonStat is retired, and
MoonMini is an alias rather than a separate product.

| Product | Published surface and product-owned cases | Current focused result | Honest boundary or next gap |
| --- | --- | --- | --- |
| MoonBook / Bookkeeper | Existing MoonBook Rabbita app, MB-01–MB-03 and MB-N1/N2 | real-server replay and no-authority boundary `OBSERVED PASS`; research-outcome intake/acceptance `UNTESTED` | The governed research run deliberately stopped before producing a Bookkeeper submission. Replay changed the projection badge to loaded and retained zero records; review correctly required separately installed authority. |
| MoonCast | Studio, Cut Editor, and token-bound Client Review, MC-1–MC-4 | Studio G0–G5, exact MoonVis intake/editor/reload, and token-bound Client Review `OBSERVED PASS` | The placed take became immutable in the UI, Add became disabled, and Program rendered the base video plus mark with 16/16 sources bound. The deterministic fixture is not commercial provider acceptance. |
| MoonChat | No standalone app; visible through MoonFind and MoonBook, MC-01 and MC-N1–N3 | `NOT-APPLICABLE` standalone; MC-N1 deferred consumer proof `OBSERVED PASS`; accepted MC-01 path `UNTESTED` | The exact deferred decision produced append-only `pending_review` / `research-evidence`, then correctly failed a work item requiring `accepted-knowledge`. No MoonBook submission was created. |
| MoonClaw | Cowork/job UI and MoonDesk MoonCode projection | retained prior subresult; current focused rerun `UNTESTED` | MoonClaw is the only agent runtime. A product-local workflow is not another runtime. |
| MoonFind | Research Studio, MF-01–MF-03 and MF-N1/N2 | evidence, MoonTown return, durable named defer bundle, and `AWAITING-MOONCHAT` `OBSERVED PASS`; MoonFlow receiver panel/return `UNTESTED` | The plain MoonFind URL had no genuine MoonFlow token, so no receiver receipt was fabricated. Failed accepted-knowledge ingest was correctly rejected and no Bookkeeper submission exists. |
| MoonFish | Daily Research Desk, F1–F3 | F1 and key F2 denials `OBSERVED PASS`; process-restart part of F3 `UNTESTED` | Fixture-only, paper-only, no broker/order effect. The installed v2 40–65-session policy conflicts with one stale 2–20-session artifact schema. |
| MoonMold | Spatial Operator, M1–M3 | M1/M2 and reload/reconcile part of M3 `OBSERVED PASS`; process restart `UNTESTED` | Digital/mock evidence only. Its flat spatial artifact is not yet the portable composite envelope MoonRobo requires. |
| MoonMoon | Lunar Operator and Moonbook, MM-1/MM-2 and MM-N1/N2 | blocked-mission, route/cell, preview, and evidence-boundary cases `OBSERVED PASS` | Preview remained mission-gated and non-authoritative; the known question cited evidence and the unknown question declined to invent an answer. |
| MoonProj | Internal Projects page, P1/P2; plan adapter boundary P3 | P1 and safe P2 denial `OBSERVED PASS`; exact plan review UI `EXPECTED BLOCKED` | The page does not render or accept `moonproj/project.plan.prepare@0.1.0` artifacts. |
| MoonRobo | Rabbita cockpit, R1–R3 | R1 and safe R2 denial `OBSERVED PASS`; process restart `UNTESTED` | No qualified physical runtime. The cockpit has no portable MoonMold-ingestion form, and no movement was performed. |
| MoonTown | Energy Valley plus typed research-salon handoff, MT-01/MT-02 and MT-N1/N2 | same-attempt governed salon, delivered callback, and review-pending return `OBSERVED PASS` | Terminal UI showed execution `completed`, review `pending`, callback `delivered`, and no attempt-2. This is synthesis evidence, not accepted research. |
| MoonVis | Visual System Inspector, MV-1/MV-2 and MV-N1/N2 | MoonCast/video `ALIGNED → DRIFT → ALIGNED` with exact PNG digest `OBSERVED PASS` | Asset resolution and SHA-256 do not grant distribution rights or final-pixel contrast acceptance. |

## Current interproduct matrix

| Journey | Operator-visible chain | Current result | First incomplete boundary |
| --- | --- | --- | --- |
| Research reinforcement | MoonFind → MoonTown → MoonFind named review → MoonChat → MoonFind → MoonBook/Bookkeeper | governed deferred path through MoonChat `OBSERVED PASS`; positive accepted path `EXPECTED BLOCKED`; MoonBook stage `UNTESTED` | The exact request-changes decision normalized to `defer`, so MoonChat retained research evidence but correctly failed the requested accepted-knowledge claim. The first incomplete positive stage is named-human acceptance/MoonChat accepted-knowledge. |
| Creative production | MoonVis → MoonCast intake → Cut Editor → master → Client Review | MoonVis-to-Editor exact-asset seam plus Studio and Client Review fixture slices `OBSERVED PASS`; one correlated overlay→promoted-master→client chain `UNTESTED` | Exact asset intake/placement/Program rendering now passes. The retained client acceptance proves the client surface, but does not yet prove that this exact overlay revision was exported, promoted, and reviewed as the same master. Real-provider commercial acceptance remains external. |
| Financial research | MoonFish → MoonClaw → named paper-watch release → later MoonBook outcome | MoonFish UI slice `OBSERVED PASS`; Bookkeeper closure `UNTESTED` | Resolve the 40–65 versus 2–20-session contract split before presenting one canonical strategy. |
| Governed physical job | MoonProj → MoonMold → MoonRobo → MoonBook | `EXPECTED BLOCKED` | MoonProj has no exact plan-artifact review UI; MoonMold and MoonRobo do not share one portable envelope; MoonRobo has no corresponding intake UI. |
| Lunar evidence | MoonMoon → MoonFlow/MoonRobo | standalone expected-blocked behavior `OBSERVED PASS`; receipt-bound handoff `UNTESTED` | Mission/inspection receipts are declared, but no current browser receipt-bound handoff result has been supplied. |
| 63-stage composition | MoonFind graph → MoonDesk canvas → MoonFlow → owning products | retained remediation subresults only; current focused rerun `UNTESTED` | Do not infer 63 executed stages from 63 rendered nodes. Each product receipt and return path must be correlated. |

## One proportional qualification pass

Use one prepared fixture and one browser session per journey. Do not rebuild or
rerun expensive media fixtures after every click.

### 1. Freeze source and isolate state

For every repository in the journey:

```sh
git -C /Users/kq/Workspace/<product> rev-parse HEAD
git -C /Users/kq/Workspace/<product> status --short
```

Create a disposable root:

```sh
QUAL_ROOT="$(mktemp -d /tmp/moonsuite-ui-qualification.XXXXXX)"
mkdir -p "$QUAL_ROOT/suite" "$QUAL_ROOT/evidence"
```

Never use a canonical book, customer project, broker account, publication
destination, or robot bridge. Record the exact launch command, URL, commit,
working-tree state, and data root in `run.json`.

### 2. Start only the products needed by the journey

Use the product-owned guide for the exact build and launch command. The focused
local URLs are:

| Product | URL |
| --- | --- |
| MoonBook / Bookkeeper | `http://127.0.0.1:4321/apps/moonbook/` |
| MoonCast Studio | `http://127.0.0.1:4302/apps/mooncast/studio` |
| MoonCast Cut Editor | `http://127.0.0.1:4302/apps/mooncast/editor` |
| MoonCast Client Review | token-bound URL created by Studio |
| MoonFind | `http://127.0.0.1:4313/apps/moonfind/research` |
| MoonFish | `http://127.0.0.1:4317/apps/moonfish/daily` |
| MoonMold | `http://127.0.0.1:4193/` |
| MoonMoon | `http://127.0.0.1:8766/first_trusted_square.html` |
| MoonProj | `http://127.0.0.1:4300/`, then internal **项目组合** navigation |
| MoonRobo | `http://127.0.0.1:5290/` |
| MoonTown | `http://127.0.0.1:17842/index.html?seed=20260727` |
| MoonVis | `http://127.0.0.1:4198/` |

Before the first click, enable browser Network log preservation, clear the
Console, and capture the start state. Do not qualify a retained DOM after a
server rebuild; reload it from the real host.

### 3. Run the research reinforcement journey

1. In MoonFind, inspect the evidence-backed run and confirm provider/runtime
   absences are blockers, not successes.
2. Choose **Open typed handoff in MoonTown**.
3. In MoonTown, match the handoff id, producer run, participant books, topic,
   review owner, and output book. Confirm **PENDING · NOT EXECUTED**.
4. Choose **Start governed salon** exactly once. If callback delivery fails,
   restore MoonFind and choose **Reconcile same attempt** rather than creating a
   new run.
5. Return to MoonFind. Confirm the reducer output is present and still pending
   named-human review.
6. Enter a real reviewer, choose a bounded decision, list exact claim/idea
   ids, add rationale, and supply every nonzero Three-Gap statement.
7. Choose **Prepare MoonChat review bundle**.
8. For a MoonDesk-launched work item, choose **Return reviewed bundle to
   Flow**, inspect the immutable MoonFind receiver receipt, and then choose
   **Return to Flow**.
9. Execute the separately declared
   `moonchat/conversation.review.record@0.1.0` through MoonFlow. MoonChat has no
   standalone page.
10. Reload MoonFind and require `ready-for-bookkeeper` plus the exact
    MoonBook submission reference.
11. Open MoonBook's existing Bookkeeper page. First prove that review is
    blocked without authority. Install a separately reviewed human grant,
    select the exact record and grant, submit **Governed review**, then replay.
12. Confirm Three-Gap assessment stops at its own review gate and that
    capability activation remains false.

For the positive path, the named human must explicitly approve the exact
subset required by the work item. For the governed negative path exercised in
this pass, choose **Request changes** over the exact ids; MoonFind normalizes
that decision to `defer`, MoonChat must retain only `research-evidence`, and a
work item requiring `accepted-knowledge` must fail without creating a
Bookkeeper submission.

The exact MoonFind receiver criterion is:

```text
the exact named-human decision, Three-Gap statements, and portable MoonChat
review bundle exist; no MoonBook acceptance is claimed
```

That receipt closes only the declared MoonFind work item. It cannot be reused
as a MoonChat execution receipt or MoonBook acceptance receipt.

### 4. Run the creative journey

1. In MoonVis choose **mooncast**, **video**, and **current binding**.
2. Confirm **ALIGNED**, then inspect
   `moonsuite.mark.video-overlay.transparent`.
3. Record PNG size `38297` and digest
   `sha256:34ff722b02b79c0950ba0e65f2412a859ca6bb2fccc1ae094f31b4cefe89190f`.
4. Choose **simulate stale consumer** and require **DRIFT**. Return to
   **current binding** and require **ALIGNED**.
5. Obtain the named product-owner rights decision; catalog identity alone is
   not permission.
6. In MoonCast Studio, create a 180–480 second governed project and inspect
   G0–G7. Keep unfinished gates visibly unfinished.
7. In Cut Editor, open a production-backed project. Under
   **Rights-cleared local media intake**, select role **logo** and choose the
   exact MoonVis PNG.
8. Require the browser-computed bytes/MIME/digest to match MoonVis. Bind rights
   owner, rights basis, territory, channels, rights reference, source kind
   `moonvis-bundle`, and a digest-bound source reference.
9. Add the take at the playhead, edit it, create an authoritative preview,
   export the frozen render plan, and promote only the exact export.
10. In Studio, create a one-time token-bound Client Review portal. In the
    client surface, inspect the exact master/build, add a timecode annotation,
    confirm decision authority, and approve or request changes.
11. Confirm client acceptance does not publish, charge, or grant new rights.

An SVG rejection, stale MoonVis binding, missing rights, or mismatched digest
is a required governed stop. Recover by producing a new reviewed input; never
weaken validation.

### 5. Run MoonFish

1. Open **Daily Research Desk** and confirm fixture-backed, paper-only truth.
2. Keep `daily-a-share-ideas`, fixture session `2026-07-24`, and
   **Verified fixture**.
3. Enter a named workflow reviewer and choose **Submit to MoonClaw** once.
4. Open the succeeded run, inspect the selection funnel and independent
   bull/bear dossiers, then select a qualifying dossier.
5. Require share/exchange, observation, entry range, goal price, modeled
   increase, earliest/latest sale date, invalidation, factor score, catalyst,
   contradictory evidence, and policy identity.
6. Enter a named human, attest fixture/paper-only use, and choose
   **Approve paper watch**.
7. Confirm the release is `monitor_only`, `investment_ready=false`, and that no
   broker, order, or automatic paper position exists.
8. Reload and refresh runs/releases. For restart recovery, restart the same
   service over the same roots and require the identical record.

Do not merge the installed v2 40–65-session recommendation with the older
2–20-session artifact contract. Record which policy and schema produced the
visible sale window.

### 6. Run the governed physical-product slice

Run each available surface honestly; do not describe the missing middle seams
as a complete chain.

1. In MoonProj, open **项目组合**, inspect stage/Gate/health/agent projections,
   and prove the formal task fails safely when its gateway is absent.
2. Record `EXPECTED BLOCKED` for accepting the exact durable plan artifact:
   the current Projects page does not render it.
3. In MoonMold, create the digital model, export `editable-source` and
   `engineering`, inspect lineage/known losses/claim ceiling, reconcile the
   same attempt, and record a named digital-only review.
4. Prove `live-blender` and `../outside.json` fail explicitly without fallback.
5. Stop before MoonRobo ingestion. MoonMold's flat artifact is not the
   composite portable envelope MoonRobo validates.
6. In MoonRobo, bootstrap only safe readiness, ask for the next safe step,
   refresh the ledger, and choose **Prove Loop**.
7. Submit `Walk forward 0.5 metres now.` and require
   `physical_execution_allowed=false`, an exact runtime/readiness blocker, and
   no executed receipt.
8. In MoonMoon, inspect the blocked mission, two route candidates, two terrain
   cells, and **Adapter preview**. The mission must remain blocked.
9. In **Moonbook & Guide**, ask one known and one unrelated question. The
   latter must report unavailable evidence rather than inventing an answer.

### 7. Capture one result package

For each case, retain:

```text
<product>/_build/ui-to-ui/<run-id>/
  run.json
  browser-console.json
  failed-requests.json
  screenshots/
    01-start.png
    02-action.png
    03-result.png
  receipts/
  host.log
```

`run.json` must say whether each claim was directly observed, expected-blocked,
or untested. Record credentials, provider licensing, publication, trading,
payment, and physical authority as withheld when that is the test boundary.

## Interaction contract checklist

Every product-to-product transition must expose or preserve:

| Contract field | Operator question |
| --- | --- |
| Product and operation | Which product owns the next state, and what exact versioned operation is requested? |
| Input/output contracts | Which schema versions bind the bytes on both sides? |
| Artifact identity | Which workspace-relative reference, byte length, and SHA-256 are transferred? |
| Correlation | Which run, work item, attempt, idempotency key, and opaque handoff token identify this transition? |
| Authority | Which authority is requested, who granted it, and what is explicitly not granted? |
| Claim ceiling | Is the result research evidence, digital artifact, accepted knowledge, or a narrower class? |
| Review | Which exact acceptance criterion, named reviewer, decision, and receipt bind the output? |
| Recovery | Does retry reconcile the same durable attempt, or incorrectly create another effect? |
| Return path | Which visible control returns the operator to MoonFlow or the next owning product? |

Opaque correlation is not authority. A source digest is not a rights grant. A
MoonChat accepted review is not MoonBook acceptance. Digital/model evidence is
not physical authority.

## Known gaps that must remain visible

1. **MoonFish policy/schema drift.** The installed v2 policy is a separately
   identified 40–65-session strategy, while
   `approved-recommendation-artifact.schema.json` still describes 2–20
   sessions. Product owners must either keep both as separately named
   strategies or migrate the stale contract.
2. **MoonMold → MoonRobo portable envelope.** MoonMold emits flat
   `editable-source`/`engineering` artifacts. MoonRobo requires a composite
   manifest/transform envelope with exact parent/child identities, spatial
   conventions, consumer policy, authority, losses, assumptions, and gaps.
3. **MoonProj exact plan review UI.** The adapter produces a durable,
   review-pending plan, but the published Projects page cannot render or accept
   that artifact.
4. **MoonChat is UI-less by design.** Its proof belongs to the MoonFind →
   MoonChat → MoonBook consumer journey. A new standalone chat app would create
   a duplicate and misleading authority surface.
5. **Receiver scope.** The current receiver receipt closes only MoonFind's
   exact review work item. It proves that the named decision, Three-Gap
   statements, and portable bundle exist; it does not execute MoonChat and
   does not accept anything into MoonBook.
6. **Commercial and physical gates.** Licensed market data, after-cost edge,
   real MoonCast providers, distribution rights, signed/notarized packaging,
   qualified robot SDK/bridge/telemetry, and physical feedback remain separate
   acceptance programs.

## Coordinating browser evidence

Observed focused evidence:

- MoonVis passed `mooncast/video` current binding, visible drift, recovery, and
  the exact PNG digest:
  [mooncast-video-aligned.png](../../../moonvis/_build/ui-to-ui/2026-07-31-consolidated/mooncast-video-aligned.png).
- MoonMoon passed the expected-blocked mission, route/cell inspection,
  mission-gated non-authoritative preview, cited known answer, and honest
  unknown-answer boundary:
  [moonbook-unknown-boundary.png](../../../moonmoon/_build/ui-to-ui/2026-07-31-consolidated/moonbook-unknown-boundary.png).
- MoonCast Studio passed an accepted 180-second G0–G5 fixture with publication
  still false:
  [studio-accepted-180s.png](../../../mooncast/_build/ui-to-ui/2026-07-31-consolidated/studio-accepted-180s.png).
- MoonCast Client Review passed the exact accepted package/timecode path with
  publication still false:
  [client-accepted-master.png](../../../mooncast/_build/ui-to-ui/2026-07-31-consolidated/client-accepted-master.png).
- MoonBook's actual MoonBit server passed replay and the no-authority boundary:
  the badge changed from `awaiting projection` to `projection loaded`, the UI
  displayed `Replay complete; the served projection is refreshing.`, retained
  zero records, and required
  `moonbook bookkeeper authority install` before review:
  [bookkeeper-replay-no-authority.png](../../../moonbook/_build/ui-to-ui/2026-07-31-consolidated/bookkeeper-replay-no-authority.png).
- MoonTown reconciled the original `attempt-1` after callback repair and
  visibly reached `RETURNED · REVIEW PENDING`, execution `completed`, review
  `pending`, and MoonFind callback `delivered`, without creating attempt-2:
  [research-salon-returned-review-pending.png](../../../moontown/_build/ui-to-ui/2026-07-31-consolidated/research-salon-returned-review-pending.png).
  MoonFind then refreshed to `INGESTED-PENDING-REVIEW` with three correlated
  ideas and `READY-FOR-HUMAN-REVIEW`.
- MoonFind then recorded the exact synthetic qualification decision as
  **Request changes**, normalized to `defer`, with the exact three idea ids and
  explicit Three-Gap statements. Reload showed `AWAITING-MOONCHAT`, the durable
  bundle reference, and exact operation:
  [named-review-awaiting-moonchat.png](../../../moonfind/_build/ui-to-ui/2026-07-31-consolidated/named-review-awaiting-moonchat.png).
- MoonChat retained an append-only `pending_review` / `research-evidence`
  record. Because the qualification work item required `accepted-knowledge`,
  its result correctly returned `failed`,
  `named-human-decisions-incomplete`; MoonFind rejected failed ingest with
  HTTP 409 and did not create `bookkeeper-outcome-submission.json`.
  Retained evidence:
  [MoonChat result](../../../moonchat/_build/ui-to-ui/2026-07-31-consolidated/moonchat-result.json),
  [conversation review record](../../../moonchat/_build/ui-to-ui/2026-07-31-consolidated/conversation-review-record.json),
  and
  [native receipt](../../../moonchat/_build/ui-to-ui/2026-07-31-consolidated/native-receipt.json).
- The run used MoonFind's plain product URL, not a genuine MoonDesk-launched
  URL with an opaque MoonFlow receiver token. The receiver panel and
  **Return reviewed bundle to Flow** therefore remain `UNTESTED`; no token or
  receipt was fabricated.
- MoonCast Editor passed exact MoonVis PNG intake and final projection. The UI
  retained approved take `take-intake-88f213035b5bc66627ab`; Source showed the
  image plus `Analysis available · duration pending`; one governed mutation
  placed exactly one five-second `clip-intake-88f213035b5bc66627ab` at
  `00:00` on `track-ai-label`, authoritative editor r3. After reload the take
  said `Placed`, Add was disabled as `Already placed`, Program rendered the
  base video plus MoonVis mark, `16/16 sources bound`, and no error:
  [editor-logo-overlay-r3-final.png](../../../mooncast/_build/ui-to-ui/2026-07-31-consolidated/editor-logo-overlay-r3-final.png).
- The MoonFish, MoonProj, MoonMold, and MoonRobo results in the product matrix
  are the physical/finance agent's completed focused observations; their
  intentionally untested process-restart and missing-integration boundaries
  remain explicit. Retained screenshots are:
  [MoonFish paper watch](../../../moonfish/_build/ui-to-ui/2026-07-31-consolidated/monitor-only-paper-release.png),
  [MoonProj safe denial](../../../moonproj/_build/ui-to-ui/2026-07-31-consolidated/formal-task-safe-denial.png),
  [MoonMold named digital review](../../../moonmold/_build/ui-to-ui/2026-07-31-consolidated/named-digital-review.png),
  [MoonMold workspace denial](../../../moonmold/_build/ui-to-ui/2026-07-31-consolidated/workspace-boundary-denial.png),
  [MoonRobo operational-unproven state](../../../moonrobo/_build/ui-to-ui/2026-07-31-consolidated/operational-unproven.png),
  and
  [MoonRobo runtime/calibration denial](../../../moonrobo/_build/ui-to-ui/2026-07-31-consolidated/runtime-calibration-denial.png).

## Focused-pass stopping point

The coordinating browser evidence is complete for the scoped pass. The
research journey intentionally stopped at the first unmet positive criterion:
a deferred named-human decision cannot satisfy MoonChat
`accepted-knowledge`. Consequently:

- the negative/deferred consumer path is a pass;
- the positive accepted-knowledge path remains blocked by the deliberately
  non-accepting decision;
- MoonFind's token-bound receiver panel remains untested because this was not a
  genuine MoonDesk-launched work item; and
- MoonBook outcome intake/acceptance remains untested because no valid
  submission existed.

Future positive qualification must use a separately reviewed accepting
decision, a genuine opaque MoonFlow receiver token, the append-only MoonChat
record, and MoonBook's own authority-bound review. It must not rewrite or
promote this deferred record.

## Source guides

- [MoonBook / Bookkeeper](../../../moonbook/docs/qualification/UI_TO_UI_USE_CASES.md)
- [MoonCast](../../../mooncast/docs/qualification/UI_TO_UI_USE_CASES.md)
  and [MoonVis → MoonCast creative loop](../../../mooncast/docs/qualification/CROSS_PRODUCT_CREATIVE_LOOP.md)
- [MoonChat](../../../moonchat/docs/qualification/UI_TO_UI_USE_CASES.md)
- [MoonFind](../../../moonfind/docs/qualification/UI_TO_UI_USE_CASES.md)
  and [research reinforcement loop](../../../moonfind/docs/qualification/CROSS_PRODUCT_RESEARCH_LOOP.md)
- [MoonFish](../../../moonfish/docs/qualification/UI_TO_UI_USE_CASES.md)
- [MoonMold](../../../moonmold/docs/qualification/UI_TO_UI_USE_CASES.md)
- [MoonMoon](../../../moonmoon/docs/qualification/UI_TO_UI_USE_CASES.md)
- [MoonProj](../../../moonproj/docs/qualification/UI_TO_UI_USE_CASES.md)
- [MoonRobo](../../../moonrobo/docs/qualification/UI_TO_UI_USE_CASES.md)
  and [governed physical job](../../../moonrobo/docs/qualification/CROSS_PRODUCT_PHYSICAL_JOB.md)
- [MoonTown](../../../moontown/docs/qualification/UI_TO_UI_USE_CASES.md)
- [MoonVis](../../../moonvis/docs/qualification/UI_TO_UI_USE_CASES.md)
