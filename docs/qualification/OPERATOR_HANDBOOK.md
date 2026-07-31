# MoonSuite UI-to-UI operator handbook

This handbook teaches a human operator how to qualify MoonSuite as a set of
visible products rather than as a collection of builds, APIs, or in-memory
models. It covers direct applications, products whose correct release proof is
through a visible consumer, and the principal interproduct journeys.

The governing rule is simple:

> Start with a visible user control, cross the real host boundary, and finish
> with a visible result, evidence, review, or explicit denial that can be tied
> to the same durable run.

A source inspection, successful build, direct API call, or screenshot alone is
not a UI-to-UI pass.

> Current-run note: the table below is the retained baseline snapshot. Use
> [the consolidated 2026-07-31 report](CONSOLIDATED_UI_TO_UI_2026-07-31.md)
> for the latest product-owned cases, focused-run status, exact interaction
> contracts, and one proportional end-user procedure. Pending coordinator
> outcomes remain untested rather than being inferred from implementation.

## Current verified snapshot

As of 2026-07-31, the retained browser evidence supports only these conclusions:

| Case | Result | What was actually observed |
| --- | --- | --- |
| `MM-UI-001` | `PASS` | MoonMoon visibly compared a different lunar route without changing mission authority, then exposed the four controlling blockers and evidence authority. |
| `MP-UI-001` | `FAIL` | MoonProj's **Moon 专案 → 任务编排 → 创建任务** emitted an intent toast, but no task form or lifecycle appeared. The console also reported a `MutationObserver` error. |
| `IP-01` canvas interaction | exercised | MoonDesk visibly imported the external book, rendered 63 nodes, and exercised Fit, zoom, node drag, canvas pan, save, and **Start governed run**. |
| `IP-01` restart | mixed | Restart restored the imported book, 63 nodes, run sequence 64, and first runnable item; the moved node reset to its original coordinates, so canvas layout persistence failed. |
| `IP-01` end to end | `BLOCKED` | The durable projection reached run sequence 64, state `ready`, with one runnable item, `understand-needs`; the operator action queue was `NOT PUBLISHED` / `UNAVAILABLE`, so the runnable work could not be visibly dispatched. |
| `IP-03` MoonWiki intake | `PASS` | An immutable needs packet was imported, named-approved, bound to exact brief/bible/script sources, and used to create a durable 1-episode/3-scene/15-shot MoonCast project. |
| `IP-03` production handoff | `BLOCKED` | G0–G5 production, accepted-master evidence, and the resulting MoonFlow handoff have not been completed. |
| A–M report | 7 `PASS`, 4 `FAIL`, 10 `BLOCKED`, 4 `NOT-RUN` | See `STANDALONE_A_M.md` for exact case evidence. |
| N–Z report | 5 `PASS`, 2 `FAIL`, 2 `NOT-RUN` | See `STANDALONE_N_Z.md`; the MoonRobo pass is explicitly limited by its labelled sample fallback. |

“Exercised” is deliberately not `PASS`. The 63-stage composition and canvas
controls worked, but the missing operator action queue prevents the complete
MoonFlow-to-execution journey from passing.

Unless a sibling qualification report contains retained evidence for another
case, treat it as `NOT-RUN`.

## 1. Understand the three qualification lanes

### Direct application

The product owns a visible browser or packaged application. Start its real
host, operate its controls, and inspect its visible and durable result.

Direct applications are MoonBook, MoonCast, MoonClaw, MoonDesk, MoonFind,
MoonGate, MoonMold, MoonMoon, MoonProj, MoonRobo, MoonTown, MoonVis, and the
public website.

MoonFish is a domain pack with a pack-owned Daily Research application. It may
be served by its native qualification service or hosted by MoonDesk; this does
not make the pack a second agent runtime.

### Consumer proof

The product is a library, framework, contract, or orchestration service and
correctly has no independent user application. Prove it through a named visible
consumer:

| Product | Required visible consumer proof |
| --- | --- |
| Bunnia / Rabbita | A generated mini application or a shipped Rabbita product UI |
| Lepusa | A packaged MoonDesk or MoonGate application |
| MoonChat | A MoonDesk or MoonBook review surface |
| MoonEdit | MoonDesk text/code editing |
| MoonFlow | MoonDesk Flow and run projections |
| MoonLeaf | MoonDesk office-document editing |
| MoonLib | A consumer showing stable suite identity, paths, contracts, and evidence layout |

Use result `CONSUMER-PROOF` only after the consumer journey passes. Before
execution, use `NOT-RUN`; if the required consumer surface is missing, use
`BLOCKED`.

### Not applicable

Use `NOT-APPLICABLE` only when a standalone UI would contradict the product
contract and the product has an explicitly named consumer lane. It does not
mean the product is tested. Record the consumer case that still supplies its
release proof.

MoonStat is retired and is not a qualification target. MoonMini is an alias,
not a separate published product.

## 2. Prepare a safe, isolated run

### Prerequisites

Install or make available:

- MoonBit and the `moon` CLI;
- Node.js 22 and `npm`;
- `git` and `jq`;
- `warren` for the current MoonProj browser surface;
- a browser with Console and Network inspection;
- product dependencies already installed, or permission to run the documented
  package installation command.

Record versions before the first case:

```sh
moon version
node --version
npm --version
git --version
```

### Create one isolated root

Never qualify against a user's canonical MoonBook, customer project, broker
account, publication destination, or robot bridge.

```sh
QUAL_ROOT="$(mktemp -d /tmp/moonsuite-ui-qualification.XXXXXX)"
SUITE_ROOT="$QUAL_ROOT/suite"
FIXTURE_ROOT="$QUAL_ROOT/fixtures"
mkdir -p "$SUITE_ROOT" "$FIXTURE_ROOT"
```

Use a different loopback port for every running service. This handbook uses
the following example range:

| Surface | Example port |
| --- | ---: |
| MoonDesk | 44063 |
| MoonCast | 44084 |
| MoonFind | 44187 |
| MoonGate | 44114 |
| MoonMold | 44115 |
| MoonBook | 44116 |
| MoonClaw | 44117 |
| MoonMoon | 48766 |
| MoonProj | 44300 |
| MoonRobo | 45290 |
| MoonTown | 17842 |
| MoonVis | 45198 |

Confirm a port is free before launching:

```sh
lsof -nP -iTCP:44063 -sTCP:LISTEN
```

No output means no process is listening.

### Record source identity

For every product in a case:

```sh
git -C /Users/kq/Workspace/<product> rev-parse HEAD
git -C /Users/kq/Workspace/<product> status --short
```

Record existing dirtiness; do not clean, reset, or overwrite it. A result
qualifies only the recorded revision and working-tree state.

### Create transient evidence storage

```sh
RUN_ID="2026-07-31-<case-id>"
RUN_ROOT="/Users/kq/Workspace/<product>/_build/ui-to-ui/$RUN_ID"
mkdir -p "$RUN_ROOT/screenshots" "$RUN_ROOT/receipts"
```

Keep the evidence untracked. Do not place credentials, customer data, licensed
market data, private papers, or unclear-rights media in it.

### Start browser capture before the first click

1. Open a fresh tab for the case.
2. Open Developer Tools.
3. In **Network**, enable **Preserve log** and clear the current list.
4. In **Console**, clear previous messages and retain warnings and errors.
5. Record the viewport size.
6. Capture `screenshots/01-start.png`.

Do not reuse a console log from an earlier product; it makes attribution
ambiguous.

## 3. Perform and record a genuine UI-to-UI action

For every meaningful action, write down:

1. the visible control name;
2. the value typed or item selected;
3. the source product and receiving product;
4. the operation or run identity shown by the UI;
5. the authority ceiling;
6. the visible state before and after;
7. the durable artifact or receipt, if claimed.

Use the mouse and keyboard against the product. Do not:

- call the final API instead of clicking its initiating control;
- invoke a reducer or update function from developer tools;
- inject fixture state after the page loads;
- replace a host response in browser code;
- infer rendered state from source strings;
- count source records and call them visible nodes;
- grant publication, payment, trading, or physical authority.

Terminal inspection after a visible action may corroborate the result. It may
not replace the visible action.

### Durability check

If the UI claims durable state:

1. record the visible run, project, attempt, or receipt ID;
2. reload the page;
3. reopen the same record through visible navigation;
4. confirm its identity and state;
5. when restart recovery is part of the contract, stop and restart the host,
   then reopen it again.

If the state is documented as browser-session-only, say so and do not claim
durability.

### Denial check

A fail-closed journey can pass when denial is the intended outcome. Require:

- a visible reason;
- the exact missing capability or authority;
- a visible next step;
- no false success state;
- no hidden external effect.

## 4. Assign the result honestly

Use this decision:

```text
Could the operator reach the first meaningful control?
├─ no, because a named prerequisite or product boundary is absent → BLOCKED
└─ yes
   ├─ did a required visible/durable assertion fail? → FAIL
   ├─ did every required boundary and assertion pass? → PASS
   └─ was the case not completed? → NOT-RUN
```

Additional labels:

- `CONSUMER-PROOF`: a complete passing consumer journey for a non-UI product;
- `NOT-APPLICABLE`: no standalone lane by contract, with the required consumer
  case named.

Do not turn an expected error into `BLOCKED` when the product surface itself is
present and broken. That is `FAIL`, as in `MP-UI-001`.

## 5. Direct product cases

The following recipes define reproducible cases. A launch command is not a
test; complete the visible actions and assertions.

### MoonBook — knowledge and replay

Launch an isolated wiki:

```sh
BOOK_ROOT="$QUAL_ROOT/moonbook"
cd /Users/kq/Workspace/moonbook
moon run --release cmd/main -- wiki init "$BOOK_ROOT"
moon run --release cmd/main -- serve "$BOOK_ROOT" \
  -n 127.0.0.1 \
  -p 44116
```

Open `http://127.0.0.1:44116/apps/moonbook/`.

Case `MB-UI-001`:

1. Click **简体中文** and confirm the application language changes.
2. Click **English** and confirm it changes back without losing the selected
   book.
3. Click **Replay durable journal**.
4. Confirm replay or refresh finishes visibly and does not invent accepted
   knowledge.
5. Reload and confirm the selected book and durable journal projection remain.
6. Record any Bookkeeper review queue separately from accepted truth.

For a Bookkeeper case, use a prepared review fixture, open it through the
visible review queue, record a named-human approve/reject/defer decision, and
confirm the receipt binds the exact proposal digest. Bookkeeper must not
self-approve a Three-Gap learning proposal.

Case `MB-UI-002`, fresh-book authority denial:

1. In **Governed loop operator**, inspect the authority area.
2. Confirm it says there is no active reviewer authority and names
   `moonbook bookkeeper authority install` as the setup step.
3. Select **Governed review**.
4. Confirm no control silently installs or assumes reviewer authority.

Installing an authority fixture by CLI belongs to a separately authorized
setup; the default case passes by remaining honestly denied.

### MoonCast — governed project and editor

Build and start with isolated data:

```sh
cd /Users/kq/Workspace/mooncast
npm --prefix ui/rabbita-mooncast install --no-audit --no-fund
npm --prefix ui/rabbita-mooncast run build
MOONCAST_RABBITA_DIST=/Users/kq/Workspace/mooncast/ui/rabbita-mooncast/dist \
MOONCAST_DATA_ROOT="$QUAL_ROOT/mooncast" \
MOONCAST_HOST=127.0.0.1 \
MOONCAST_PORT=44084 \
moon run cmd/studio
```

Open `http://127.0.0.1:44084/apps/mooncast/studio`.

Case `MC-UI-001`, governed project smoke:

1. Enter project ID `uiq-episode-001`.
2. Enter title `UI Qualification Episode`.
3. Enter objective `Approved 3-minute product explainer master`.
4. Enter audience `Design partners`.
5. Enter channels `review-only`.
6. Enter rights owner `UI Qualification Owner`.
7. Enter duration `180` seconds and budget `20000`.
8. Click **Rights remain pending** and confirm it changes to
   **Rights owner confirmed**.
9. Click **Create governed project**.
10. Confirm the visible project graph and G0–G7 rail appear.
11. Confirm the host reports
    `Project and seven governed creative drafts created.`
12. In **Named human authority**, enter actor `UI Qualifier`, role `producer`,
    and a current ISO-8601 decision time.
13. Click **Confirm deliberate action**.
14. Click the enabled G0 **Record evidence gate**.
15. If the host reports `exact_brief_approval_required`, record `FAIL` for
    this version of the case. Open **Creative**, approve the exact brief as a
    separate named decision, and only then rerun G0.
16. Confirm G0 has an immutable receipt while later gates remain pending.
17. Reload and reopen the same project.

This case proves project creation and workflow projection only.

The 2026-07-31 run created revision 8 with one episode, three scenes, 15 shots,
and seven drafts, but the direct G0 attempt returned
`exact_brief_approval_required`. `MC-UI-001` is therefore `FAIL` as written;
the precise denial is useful evidence that project creation did not
self-approve the brief.

Case `MC-UI-002`, early Cut Editor denial:

1. Open `http://127.0.0.1:44084/editor`.
2. Under **G4 production project**, enter `uiq-episode-001`.
3. Click **Import / open G4**.
4. Confirm the editor rejects the import because the project has not passed
   G4.
5. Return to Studio and confirm the project gate rail is unchanged.

This is a passing negative journey only if the denial is precise and the host
does not create an editor fixture behind the UI.

The retained 2026-07-31 run is `PASS`: the editor displayed
`canonical G4 approval is required before editor import`.

Case `MC-UI-003`, saleable episode acceptance:

1. Import a rights-cleared MoonWiki needs packet through **Needs / Strategy**.
2. Record a named approval of the exact packet.
3. Advance G0 through G3 with visible brief, rights, bible, script, storyboard,
   animatic, and budget reviews.
4. Generate or import the bounded deterministic multi-shot fixture.
5. Open the cut editor and make a visible narrative or compliance edit.
6. Inspect continuity, rights, subtitle, audio, cost, and technical QC.
7. Export the 3–8 minute master and promote that exact digest.
8. Record technical, creative, rights, and client acceptance.
9. Prepare, but do not publish, the governed MoonFlow handoff.
10. Reload and confirm the project, accepted master, lineage, and reviews.

A project card or 12-second placeholder is not a pass for `MC-UI-003`.
Publication remains excluded.

### MoonClaw — sole agent runtime

```sh
CLAW_HOME="$QUAL_ROOT/moonclaw"
mkdir -p "$CLAW_HOME/workspace"
cd /Users/kq/Workspace/moonclaw
./scripts/build-rabbita-ui.sh
moon run --release cmd/main -- gateway start \
  --home "$CLAW_HOME" \
  --cwd "$CLAW_HOME/workspace" \
  --port 44117
```

Open `http://127.0.0.1:44117/ui#/cowork`.

Case `MCL-UI-001`:

1. Click **New Chat**.
2. Confirm a new selected conversation appears in the sidebar.
3. Confirm the transcript shows `Conversation created.`
4. Reload and confirm the conversation remains.
5. Do not submit a model request unless credentials and cost authority are
   explicitly in scope.

The 2026-07-31 isolated run is `FAIL`: although the UI was served on port
4317, its visible gateway target remained hard-coded to
`http://127.0.0.1:18123`. **New Chat** could not create a session. Treat the
gateway address as host-supplied configuration in the next rerun.

For an execution case, the visible proposal must show the same MoonFlow run and
attempt ID, declared workspace, authority, output, and receipt. MoonClaw is the
only agent runtime; a domain pack must not start another model loop.

### MoonDesk — shell, import, and durable projections

```sh
cd /Users/kq/Workspace/moondesk
npm --prefix ui/rabbita-desk run build
MOONFLOW_ROOT=/Users/kq/Workspace/moonflow \
MOONCLAW_ROOT=/Users/kq/Workspace/moonclaw \
moon run --release cmd/main -- serve "$SUITE_ROOT" \
  --ui ui/rabbita-desk/dist \
  --host 127.0.0.1 \
  --port 44063
```

Open `http://127.0.0.1:44063/`.

Case `MD-UI-001`:

1. Stay in **Desk**.
2. Expand **Import existing → Import from path**.
3. type the exact fixture folder into **Folder path**.
4. Click **Import Path**.
5. Confirm the named book appears in the library.
6. Open Wiki, Code, Flow, or Runs using visible navigation.
7. Make only a fixture-safe change or selection.
8. Reload and confirm every state described as durable.

Do not call a host import endpoint directly. If the selected fixture lacks
MoonDesk's required root `book.json`, retain the visible import denial. Repair
only the external fixture, retry through the UI, and record the compatibility
gap.

### MoonFind — research workspace and fail-closed capability

```sh
cd /Users/kq/Workspace/moonfind/ui/rabbita-moonfind
npm install
npm run build
npm run dev -- --host 127.0.0.1 --port 44187 --strictPort
```

Open `http://127.0.0.1:44187/`.

Case `MF-UI-001`, published projection denial:

1. Inspect the displayed 63-stage / 43-operation projection.
2. Click **Capability preparation unavailable**.
3. Confirm the visible denial says no prepared MoonFind capability execution
   was published by the host.
4. Confirm the page does not pretend that research ran.

This is a negative UX check, not a full research execution pass, when the page
is only a static published projection.

Case `MF-UI-002`, governed synthesis:

1. Select or import the source corpus through the UI.
2. Start governed cross-paper synthesis.
3. Confirm full-text evidence, source digests, contradictory evidence, and
   malicious-document isolation are visible.
4. Open the typed MoonTown handoff.
5. Follow the review and Bookkeeper return path described in `IP-02`.

If **Open in MoonTown** is absent, classify the cross-product case `BLOCKED`;
do not infer it from descriptive text.

### MoonFish — daily research pack

Install the pack into an isolated host and start its native qualification
service:

```sh
FISH_ROOT="$QUAL_ROOT/moonfish"
cd /Users/kq/Workspace/moonbook
moon run --release cmd/main -- \
  pack install \
  /Users/kq/Workspace/moonfish/moonpack \
  "$FISH_ROOT" \
  /Users/kq/Workspace/moonfish/testdata/moonfish-host-profile.json

cd /Users/kq/Workspace/moonfish
MOONFISH_BOOK_ROOT="$FISH_ROOT/book" \
MOONFISH_PACK_ROOT=/Users/kq/Workspace/moonfish/moonpack \
MOONCLAW_PACK_RUNNER=/Users/kq/Workspace/moonclaw/_build/native/release/build/vectie/moonclaw/cmd/pack_workflow_runner/pack_workflow_runner.exe \
moon run --target native --release cmd/moonfish_service -- \
  --workspace-root "$FISH_ROOT" \
  --port 44118
```

Open `http://127.0.0.1:44118/apps/moonfish/daily`.

Case `MFS-UI-001`, verified fixture through MoonClaw:

1. Confirm **Native runtime ready**.
2. Leave **Verified fixture** and its fixed fixture session selected.
3. Enter named reviewer `UI Qualifier`.
4. Click **Submit to MoonClaw**.
5. Confirm a run ID and the visible statement that MoonClaw executed the job
   and MoonBook recorded the result.
6. Confirm **Durable workflow runs** contains that exact run.
7. Reload and confirm it remains.
8. Confirm the policy is partial/not followed and the fixture remains not
   investment ready.

This proves the visible pack → MoonClaw → MoonBook fixture path. It does not
create a released recommendation.

Case `MFS-UI-002`, complete recommendation review:

1. Start the daily run.
2. Inspect every hard-filter rejection and the deterministic ranking.
3. Compare factor contributions.
4. Open the dossier and independent bear review.
5. Approve, reject, or abstain as a named reviewer.
6. Create the paper-only recommendation plan through a visible control.
7. Verify security, exchange, evidence cutoff, next valid session, observation
   and entry range, deterministic goal price, gross and after-cost expected
   increase rate, planned sale window, installed 40–65-session horizon,
   invalidation, staged/full/forced exits, expiry, catalyst, bear case,
   contradictory evidence, liquidity risk, and exact policy ID/version/digest.
8. Add it to the paper account only after review.
9. Reload and later record outcome and Three-Gap evidence.

Current status: `BLOCKED`. The Daily Research Desk can render an existing
operator release record, but it has no visible action to create that record
from the completed run. Its honest empty state, **No named release has been
recorded. Moonfish will not fabricate a stock.**, is correct but is not the
headline product outcome. Do not bypass this by calling the prepare operation
directly, and do not revive the removed Python pilot.

### MoonGate — provider and authority dashboard

```sh
cd /Users/kq/Workspace/moongate
MOONSUITE_WORKSPACE_ROOT="$QUAL_ROOT/moongate" \
moon run cmd/main -- start \
  --host 127.0.0.1 \
  --port 44114
```

Open `http://127.0.0.1:44114/ui/rabbita`.

Case `MG-UI-001`:

1. Click **Refresh** and confirm the visible update timestamp changes.
2. Click **Manual Connect** and confirm the connection state changes visibly.
3. Click **OpenAI Chat Copy**.
4. Confirm the copied endpoint is `/v1/chat/completions` on the local service.
5. Inspect provider health, route, and authority state without adding
   credentials.

Copying an endpoint proves operator guidance, not provider inference. A live
provider case requires separately authorized credentials, a real request,
usage evidence, and cost receipt.

Case `MG-UI-002`, honest no-provider state:

1. Select **Connection Graph**.
2. Confirm an unconfigured lane says **No provider saved** or
   **Waiting for a provider**.
3. Select **Providers** and confirm no credential is fabricated.
4. Do not save, test, or bind a provider.
5. Return to **Overview** and confirm provider-dependent readiness remains
   visibly conditional.

### MoonMold — governed spatial artifact

```sh
MOLD_ROOT="$QUAL_ROOT/moonmold"
mkdir -p "$MOLD_ROOT"
cd /Users/kq/Workspace/moonmold
npm --prefix ui/rabbita-moonmold install
npm run ui:build
npm run operator -- --workspace "$MOLD_ROOT" --port 44115
```

Open `http://127.0.0.1:44115/`.

Case `MMD-UI-001`:

1. Keep the provider `mock-reference`.
2. Inspect the request's units, coordinate frame, dimensions, references,
   authority, and idempotency.
3. Click **Execute reference path**.
4. Confirm a durable terminal receipt and separate review state appear.
5. Click **Reconcile same attempt** and confirm no new attempt is created.
6. Enter reviewer `UI Qualifier`.
7. Approve with note
   `Mock-reference digital artifact accepted for UI qualification`.
8. Click **Record named review**.
9. Confirm one review receipt binds the exact artifact digest.
10. Reload and reconcile the same attempt.

The deterministic reference provider proves workflow and lineage only. It does
not qualify Blender, fabrication, physical readiness, or a manufacturing
claim.

The 2026-07-31 run is `FAIL`: **Execute reference path** ended with
`JsonDecodeError((, Missing field reviews)` and **Latest operation receipt**
remained **Not available**. The named review case is `BLOCKED` until the host
and UI agree on the response schema and an exact receipt exists.

### MoonMoon — lunar simulation

```sh
cd /Users/kq/Workspace/moonmoon/ui/rabbita-moon
./node_modules/.bin/vite preview \
  --host 127.0.0.1 \
  --port 48766
```

Open `http://127.0.0.1:48766/first_trusted_square.html`.

Case `MM-UI-001`:

1. Confirm the page is **Operator** and the decision is blocked.
2. Open **Compare route candidates**.
3. Select **Direct traverse across measured LOLA patch**.
4. Confirm the context says the candidate is being inspected while mission
   selection remains unchanged.
5. Click **Review blocking evidence**.
6. Confirm source authority, motion handoff, and four controlling blockers.

The 2026-07-31 retained run is `PASS`.

### MoonProj — OPC task lifecycle

```sh
cd /Users/kq/Workspace/moonproj
warren dev frontend/opc \
  --public-dir frontend/opc_public \
  --port 44300
```

Open the URL printed by Warren, commonly:

```text
http://127.0.0.1:44300/__warren/preview/index.html?warren_reload=0
```

Case `MP-UI-001`:

1. Click **Moon 专案**.
2. Open **任务编排**.
3. Click **创建任务**.
4. Require a visible form and create/start/submit/accept lifecycle.

The 2026-07-31 run is `FAIL`: only an intent toast appeared, no lifecycle was
available:

```text
已记录「创建并分派任务」界面意图；证据写入 PostgreSQL 前不会产生正式业务影响。
```

The console also reported:

```text
Failed to execute 'observe' on 'MutationObserver':
parameter 1 is not of type 'Node'.
```

Case `MP-UI-002` remains a designed follow-up:

1. Select **通用模式 → 工作与交付 → 创建工作项**.
2. Enter name `UI-to-UI qualification`.
3. Enter acceptance
   `Visible accepted card with settlement boundary`.
4. Save, start, submit, and accept through visible controls.
5. Confirm the item finishes at **已接受** with **等待结算与入账**.

This would prove only the documented browser-session lifecycle, not
PostgreSQL, settlement, or accounting truth.

### MoonRobo — simulation-only cockpit

```sh
ROBO_ROOT="$(mktemp -d /tmp/moonsuite-ui-moonrobo.XXXXXX)"
cp -R /Users/kq/Workspace/moonrobo/examples/noetix-e1/. "$ROBO_ROOT/"
cd /Users/kq/Workspace/moonrobo
moon run cmd/main --target native -- \
  serve \
  "$ROBO_ROOT" \
  /Users/kq/Workspace/moonrobo/ui/rabbita-cockpit \
  127.0.0.1 \
  45290 \
  127.0.0.1 \
  45391
```

Leave port `45391` without a bridge process. Open
`http://127.0.0.1:45290/`.

Case `MR-UI-001`:

1. Open **MoonData**.
2. Click **Refresh Data**.
3. Inspect robot identity, readiness, validation, artifact-family counts, and
   canonical artifacts.
4. Return to **Operate** and confirm the bridge remains unavailable.

Case `MR-UI-002`:

1. Click **Evaluate Walk**.
2. Confirm **Safety Gate**, intent state, reason, and next evidence.
3. Stop before **Dry Run**, **Approve**, **Execute**, **Start Runtime**, or
   **Emergency Stop**.

The acceptance result is a visible safe denial. No physical command may be
sent.

### MoonTown — town composition and output

```sh
TOWN_ROOT="$(mktemp -d /tmp/moonsuite-ui-moontown.XXXXXX)"
cd /Users/kq/Workspace/moontown
MOONTOWN_SUITE_ROOT="$TOWN_ROOT" \
MOONTOWN_DESKTOP_STATIC_ROOT=/Users/kq/Workspace/moontown/src/ui/rabbita-town/dist \
MOONTOWN_OPERATOR_POLICY_PATH=/Users/kq/Workspace/moontown/assets/templates/operator-request-policy.json \
moon run src/cmd/desktop_server --target native
```

The current service binds to `127.0.0.1:17842`. Open:

```text
http://127.0.0.1:17842/index.html?seed=20260727
```

Case `MT-UI-001`:

1. Confirm the full-screen interactive Wenyu Valley canvas and the
   **MoonTown · 能源谷** badge are visible.
2. Exercise weather, simulation-speed, and tool controls without creating a
   civic job.
3. Select a civic building and inspect its runtime/work projection.
4. Open **看板**, inspect stale/blocked and MoonBook review truth, then return
   to the same map.
5. Confirm no empty state is replaced by unlabelled sample success.

Case `MT-UI-002` uses
`http://127.0.0.1:17842/index.html?seed=20260727&demo=1`: open the full guide,
start exploration, reopen the guide, and close it using the labelled control
or `Escape`.

### MoonVis — bundle resolution and drift

```sh
cd /Users/kq/Workspace/moonvis/ui/rabbita-moonvis
./node_modules/.bin/vite preview \
  --host 127.0.0.1 \
  --port 45198
```

Open `http://127.0.0.1:45198/`.

Case `MV-UI-001`:

1. Select product `moonrobo`.
2. Select channel `desktop`.
3. Confirm heading `moonrobo · desktop` and record digest and versions.
4. Click **simulate stale consumer**.
5. Confirm **DRIFT** and the exact version mismatches.
6. Click **current binding**.
7. Confirm the state returns to **ALIGNED**.

This proves manifest resolution and drift visibility, not a complete product
UI or accessibility acceptance.

### Public website — reinforcement-loop explanation

Open `https://vectie.github.io/`.

Case `SITE-UI-001`:

1. Click **Enter the evolution loop**.
2. Click **Verify**.
3. Confirm phase `04`, score `91 / 100`, and threshold `85`.
4. Click **Reward / revert**.
5. Confirm the next-cycle baseline is `research_brief@v13`.
6. Click **切换至中文** and confirm `lang=zh` without losing the selected phase.
7. Switch back to English and confirm the phase remains selected.

Record the deployed revision separately from the local source revision. A local
build does not prove the deployed page.

## 6. Consumer-proof cases

These cases avoid fake standalone applications.

### Bunnia / Rabbita

Generate the shipped WeChat mini-application:

```sh
cd /Users/kq/Workspace/bunnia
moon run cmd/main -- \
  build \
  --target wechat \
  --example moontown_miniapp \
  --strict \
  --budget large \
  --render-budget large \
  --out _build/ui-to-ui/bunnia/moontown_miniapp
```

Case `BU-UI-001` requires WeChat DevTools:

1. Import
   `/Users/kq/Workspace/bunnia/_build/ui-to-ui/bunnia/moontown_miniapp`.
2. Open **Discover**.
3. Tap **More** and confirm **More filters** appears.
4. Tap **Books** and confirm selected filter and result heading change.
5. Tap **Close**.
6. Reload the mini-program and repeat a filter change.

Case `BU-UI-002` adds a real isolated backend:

```sh
cd /Users/kq/Workspace/bunnia
node examples/moontown_miniapp/backend/local_backend.mjs \
  --host 127.0.0.1 \
  --port 18191 \
  --state "$QUAL_ROOT/bunnia-state.json" \
  --reset-state \
  --disable-retention-scheduler
```

In the mini-application:

1. Tap **Enter Town** and confirm first-visit state becomes visible identity.
2. Open **My**.
3. Tap **Refresh My Stuff**.
4. Confirm **Refreshing your inventory...** becomes
   **Your inventory is up to date.**
5. Reload and confirm the projection is not replaced with unlabelled sample
   success.

`moon run cmd/main -- build --target wechat` or a render snapshot can
corroborate framework output but cannot produce `CONSUMER-PROOF` by itself.
MoonMini is only an alias; do not record it as a second product.

For Rabbita's browser consumer proof, also operate a form, selection, dialog,
keyboard action, and host-backed status update in a shipped Rabbita product
such as MoonDesk, MoonCast, or MoonGate. Name the exact consumer and component
in the evidence.

### Lepusa

Package MoonGate as the smaller native consumer:

```sh
cd /Users/kq/Workspace/moongate
MACOSX_DEPLOYMENT_TARGET=11.0 moon build --target native --release

cd /Users/kq/Workspace/lepusa
MACOSX_DEPLOYMENT_TARGET=11.0 \
  moon build cmd/runtime --target native --release

LEPUSA_RUNTIME_EXECUTABLE=/Users/kq/Workspace/lepusa/_build/native/release/build/cmd/runtime/runtime.exe \
  moon run cmd/main --target native -- \
  bundle-write macos \
  _build/ui-to-ui/lepusa/moongate-bundle \
  --project /Users/kq/Workspace/moongate/lepusa.json \
  --json
```

Use Lepusa's generated distribution manifest to run its documented
`bundle-package-write` or local launch flow, then:

1. Launch the generated `MoonGate.app`, not only its browser URL.
2. Wait for real localhost readiness.
3. Select **Manual Connect**.
4. Under **OpenAI Chat**, click **Copy**.
5. Confirm `Copied /v1/chat/completions`.
6. Quit the app.
7. Confirm the supervised sidecar exits and no state was written into the app
   bundle.

Record the package manifest, host process, readiness result, and visible
quit result. A browser-only MoonGate pass cannot be relabelled as Lepusa proof.

### MoonChat

MoonChat intentionally has no standalone app. Qualify it through MoonFind's
producer/result projection and MoonBook's separate acceptance projection:

1. In MoonFind, open the review bundle produced by the exact upstream run.
2. Inspect stable participant IDs, claims, objections, evidence, and source
   digests.
3. Enter the bounded named-human research decision in MoonFind and return its
   exact receiver receipt to MoonFlow.
4. Execute MoonChat's separately declared append-only review operation.
5. Reload MoonFind and confirm the exact review record and
   `ready-for-bookkeeper` state.
6. Open MoonBook's existing Bookkeeper console and perform its own
   authority-bound acceptance; never reuse MoonChat's receipt as MoonBook
   authority.

If no consumer projection exists, use `BLOCKED`, not a separate MoonChat UI.

### MoonEdit

Through MoonDesk's text/code editor:

1. Open a copied text or code fixture through visible file navigation.
2. Edit and save.
3. Reload and confirm the edit.
4. In a separate fixture case, create a host-side conflicting revision.
5. Confirm the UI preserves and presents the conflict rather than silently
   overwriting it.

Current MoonEdit documentation says it does not own host persistence or UI.
If MoonDesk lacks this consumer flow, classify it `BLOCKED`.

### MoonFlow

Use MoonDesk's **Flow** and **Runs** views:

1. Visibly import a dependency-closed graph.
2. Inspect operation, schema, authority, owner, evidence, and review
   requirements.
3. Start the governed run through the visible control.
4. Confirm durable sequence, ready/runnable work, attempts, and recovery.
5. Open the operator action queue and dispatch only authorized work.
6. Reload or restart and confirm the same run and attempt recover.

The 63-stage run currently stops at step 5 because the operator action queue is
not published/available. It is therefore `BLOCKED` end to end.

### MoonLeaf

Through MoonDesk's office-document surface:

1. Copy a rights-safe DOCX, XLSX, or PPTX fixture into the isolated root.
2. Open it through visible file navigation.
3. Make one edit supported by the declared format capability.
4. Save, close, and reopen.
5. Confirm the supported semantic edit and retained unsupported-content
   warnings.
6. Compare only the fidelity MoonLeaf promises; do not claim exact visual or
   lexical round-trip where the format contract excludes it.

If MoonDesk has no office-document surface, classify the consumer case
`BLOCKED`.

### MoonLib

Use at least one visible consumer, preferably MoonDesk:

1. Import an external book into an isolated suite root.
2. Record the suite identity, product home, evidence path, and run identity
   shown by the UI.
3. Reload or restart.
4. Confirm the same identities and contained paths.
5. Attempt an out-of-root fixture path and require a visible safe denial.

This proves only the MoonLib contracts exercised by that consumer.

## 7. Main interproduct journeys

### IP-01 — 63-stage MoonFind graph in MoonDesk

Prepare an external MoonBook:

```sh
BOOK_ROOT="$FIXTURE_ROOT/robotics-book"
mkdir -p "$BOOK_ROOT"
cd /Users/kq/Workspace/moonbook
moon run --release cmd/main -- wiki init "$BOOK_ROOT"
```

MoonDesk currently requires root `book.json`, while MoonBook's initializer
writes `book.toml` and `wiki.toml`. Add only this compatibility file to the
external fixture:

```json
{
  "id": "robotics-book",
  "name": "Humanoid Robotics Suite UI Qualification"
}
```

Publish the fixture graph:

```sh
cd /Users/kq/Workspace/moonfind
moon run --release cmd/main -- publish-robotics-graph \
  "$BOOK_ROOT" \
  fixtures/humanoid-robotics-requests \
  fixtures/humanoid-robotics-capability-catalog.fixture.v1.json \
  2026-07-31T12:00:00Z
```

Start MoonDesk as described above, then:

1. **Desk → Import existing → Import from path**.
2. Enter `$BOOK_ROOT` and click **Import Path**.
3. Select **Humanoid Robotics Suite UI Qualification**.
4. Open **Flow**.
5. Confirm `Products · 63 / 63 nodes`.
6. Confirm 63 visible node cards, 11 executing product IDs, and one entry node,
   `understand-needs`.
7. Confirm the capability catalog is labelled fixture evidence and any
   unavailable MoonGate state remains visible.
8. Click **Fit** and confirm the full graph fits.
9. Zoom in and out; confirm the percentage changes.
10. Drag empty canvas space; confirm the canvas pans.
11. Drag **Move node understand-needs**; confirm only that node moves.
12. Click **Save composition** and confirm a visible completed state.
13. Click **Start governed run**.
14. Confirm the durable run state and initial runnable work.
15. Open the operator action queue.
16. Reload, reopen the imported book and Flow, and confirm the durable state.

Known 2026-07-31 outcome:

- import, 63-node rendering, Fit, zoom, node drag, pan, save, and start were
  visibly exercised;
- the durable projection reached sequence 64 and state `ready`;
- exactly one item, `understand-needs`, was runnable;
- the operator action queue reported `NOT PUBLISHED` / `UNAVAILABLE`;
- restart restored the imported book, 63 nodes, sequence 64, and the runnable
  projection;
- the moved node reset from `184px,142px` to `64px,72px`, so visual layout
  persistence failed.

Result: `BLOCKED` end to end at the operator action queue. Do not say that 63
stages executed.

### IP-02 — research to reviewed Bookkeeper learning

Intended chain:

```text
MoonFind
→ MoonTown participant books and challenge synthesis
→ MoonFlow
→ MoonClaw
→ MoonChat review projection
→ MoonBook / Bookkeeper
→ named-human Three-Gap decision
```

Operator steps:

1. In MoonFind, visibly select the exact source corpus.
2. Start governed cross-paper synthesis.
3. Open the typed **Open in MoonTown** handoff.
4. In MoonTown, inspect participant books, independent roles, source IDs,
   objections, and reviewable synthesis.
5. Open the correlated MoonFlow run and MoonClaw execution.
6. Open the MoonChat review consumer projection.
7. Record a named-human decision.
8. Open the correlated Bookkeeper outcome.
9. Inspect knowledge, capability, and outcome gaps.
10. Approve, reject, or defer the proposed learning.
11. Reload and confirm the review and learning receipt.

Current result: `BLOCKED` at MoonFind → MoonTown because the published
MoonFind surface lacks a visible typed handoff. Descriptive text and graph
nodes do not satisfy the step.

### IP-03 — MoonWiki to MoonCast production

Prepare a passive packet conforming to
`moonwiki.mooncast-needs-export.v1`. It must contain exact evidence and intent
references, rights, duration, budget, revision ceiling, payment milestones,
negative constraints, and:

```json
{
  "publication_authority": false,
  "provider_execution_authority": false
}
```

In MoonCast:

1. Open **Needs / Strategy**.
2. Paste the packet into **MoonWiki export packet**.
3. Click **Import immutable packet**.
4. Confirm complete, pending, immutable state, source IDs, versions, SHA-256
   digests, and provenance digest.
5. Enter actor, role, and ISO-8601 decision time.
6. Click **Confirm deliberate action**.
7. Click **Approve exact needs / strategy**.
8. Create project `ui-journey-project-001`.
9. Confirm the project → episode → scene → shot → asset graph and exact
   MoonWiki intent bindings.
10. Reload and confirm packet approval and project binding.
11. Complete G0–G5 and accepted-master evidence before preparing the MoonFlow
   handoff.
12. Open the correlated run in MoonDesk.

The intake portion and the full production handoff are separate assertions. A
fresh project correctly cannot jump directly to a final handoff.

The 2026-07-31 intake portion is `PASS`: packet
`ui-journey-needs-001` version 1 was named-approved and created
`ui-journey-project-001` revision 8 with one episode, three scenes, 15 shots,
and exact `ui-wiki-brief-1`, `ui-wiki-bible-1`, and `ui-wiki-script-1`
bindings. Reload preserved both records, and no provider or publication
authority was used. The complete IP-03 journey remains `BLOCKED` at production
and accepted-master handoff.

### IP-04 — safe robotics chain

From the imported Flow graph:

1. Open `plan-project` in MoonProj with the same run and operation ID.
2. Return its reviewed digital plan receipt to Flow.
3. Open `design-physical-assets` in MoonMold and return digital spatial
   artifact lineage.
4. Open `integrate-robot` in MoonRobo and confirm it says **digital model**.
5. Open `simulate-missions` in MoonMoon under sandbox authority.
6. Return to MoonRobo `readiness-inspect`; require observations and blockers,
   not physical readiness.
7. Open `visualize-deliverable` in MoonVis.
8. Return all correlated receipts to Flow.
9. Restart and confirm attempt recovery.
10. Require visible denial of physical command, publication, payment, or
    undeclared provider authority.

Current result: `BLOCKED` because Flow node cards do not provide a generic
**Open owning product** action and correlated return receipt. Do not add
robotics-specific branches to MoonDesk or MoonFlow to solve it.

### IP-05 — editing and native host

Intended chain:

```text
Visible file import
→ MoonDesk
→ MoonEdit or MoonLeaf
→ MoonLib-contained durable path
→ Rabbita rendering
→ Lepusa packaged host
→ close and reopen result
```

Run the relevant MoonEdit or MoonLeaf consumer case first in browser MoonDesk.
Then repeat it in the packaged Lepusa application. A complete pass must show
the same user-owned state after close/reopen and preserve any conflict or
fidelity warning.

## 8. Evidence package

Every run should end with:

```text
<product>/_build/ui-to-ui/<run-id>/
  run.json
  host.log
  browser-console.json
  failed-requests.json
  screenshots/
    01-start.png
    02-action.png
    03-result.png
    04-reload.png
  receipts/
```

Suggested `run.json`:

```json
{
  "case_id": "IP-01",
  "started_at": "2026-07-31T12:00:00+08:00",
  "finished_at": "2026-07-31T12:30:00+08:00",
  "products": [
    {
      "name": "moondesk",
      "commit": "<full-sha>",
      "dirty": false
    }
  ],
  "launch": {
    "command": "<exact command>",
    "url": "http://127.0.0.1:44063/",
    "isolated_root": "/tmp/<exact-root>",
    "viewport": "1440x1000"
  },
  "actions": [
    "Import Path",
    "open Flow",
    "Fit",
    "zoom in",
    "zoom out",
    "pan",
    "move understand-needs",
    "Save composition",
    "Start governed run"
  ],
  "assertions": {
    "visible_nodes": 63,
    "run_sequence": 64,
    "run_state": "ready",
    "runnable_items": [
      "understand-needs"
    ],
    "operator_action_queue": "unavailable"
  },
  "authority_withheld": [
    "provider credentials",
    "publication",
    "trading",
    "payment",
    "physical robot command"
  ],
  "result": "BLOCKED",
  "blocker": "operator action queue is not published/available"
}
```

`browser-console.json` should retain every warning/error with URL, timestamp,
and message. `failed-requests.json` should retain method, URL, status or network
error, initiating action, and whether the failure was expected. Never erase a
failure simply because the main screen still rendered.

For each interproduct transition, retain:

- source and destination product;
- operation and schema version;
- run and attempt ID;
- authority and claim ceiling;
- input and output digest;
- evidence or artifact reference;
- provider/adapter identity and health;
- required reviewer;
- receipt and return-to-source action.

## 9. Safe authority boundaries

The default local qualification explicitly withholds:

- provider credentials and paid inference;
- licensed market-data production use;
- broker and real-money trading;
- publication to any external destination;
- customer communication and contract acceptance;
- payment, settlement, or accounting mutation;
- physical robot bridges and vendor commands;
- fabrication or manufacturing approval.

Use deterministic, public-development, or mock-reference fixtures only where
the UI labels them accurately. A fixture cannot silently become commercial
evidence.

Named-human review is mandatory where the product claims acceptance. The agent
that creates an artifact cannot approve its own result. Bookkeeper may propose
Three-Gap learning, but a human approves, rejects, or defers it.

## 10. Clean up

1. Save final result and reload screenshots.
2. Export or copy the case-specific console warnings/errors and failed
   requests.
3. Copy only required durable receipts from the isolated root into the ignored
   evidence directory.
4. Stop each local host with `Control-C` in its launch terminal.
5. Verify its port is no longer listening:

   ```sh
   lsof -nP -iTCP:<port> -sTCP:LISTEN
   ```

6. Confirm no provider, broker, publication, payment, or robot process was
   started.
7. Remove temporary roots only after evidence references no longer depend on
   them:

   ```sh
   rm -rf "$QUAL_ROOT"
   ```

8. Run `git status --short` in every touched repository and confirm the test
   did not modify product source.

Do not commit or push transient UI-to-UI evidence unless the repository's
release policy explicitly calls for a sanitized evidence manifest. Never
commit secrets or user-owned data.

## 11. Final operator checklist

Before reporting `PASS`, answer yes to every applicable question:

- Did the case start from a visible control?
- Did the real host receive the action?
- Is the receiving product or consumer projection visible?
- Can the result be correlated to the same run and attempt?
- Is the durable evidence or intended denial visible?
- Are authority and review requirements visible?
- Did reload or restart preserve every state claimed as durable?
- Are console and failed-request records free of unexplained failures?
- Were credentials, publication, trading, payment, and physical authority kept
  outside the local run?
- Does the wording avoid claiming more than the fixture proves?

If any required answer is no, report the first missing boundary as `FAIL` or
`BLOCKED`. A smaller honest result is more useful than an all-green suite that
never crossed its real product boundaries.
