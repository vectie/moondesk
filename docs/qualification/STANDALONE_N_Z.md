# Standalone N-Z UI-to-UI qualification

- Qualification date: 2026-07-31
- Scope: MoonMoon, MoonProj, MoonRobo, MoonTown, MoonVis, and
  `vectie.github.io`
- Method: visible control to visible result in the shipped product surface

This report distinguishes journeys that were actually executed from journeys
that are only designed. A build, direct API request, renderer snapshot, or
in-memory update-function test is not a UI-to-UI pass.

For the latest product-owned cases and focused browser outcomes, use
[the consolidated 2026-07-31 report](CONSOLIDATED_UI_TO_UI_2026-07-31.md).
The case table and counts in this file remain historical evidence.

## Remediation addendum

The original cases and counts below remain the historical snapshot. A
same-day feature rerun subsequently established:

| Case | Follow-up result |
| --- | --- |
| `MP-UI-001` | `PASS` for the formal safe-denial boundary: the visible form now attempts the canonical task path, but missing signed gateway/PostgreSQL receipts leave zero formal tasks and a clear denial. A positive formal lifecycle remains `BLOCKED`. |
| `MP-UI-002` | `PASS` only as explicitly labelled browser-session state: visible create → start → submit → accept produced one accepted card and still said `SESSION-LOCAL / NOT POSTGRESQL EVIDENCE`. |
| `MR-UI-001` | `PASS` without the old sample fallback: the host-backed cockpit showed the exact isolated RoboBook and truthful `2/6` (`33%`) readiness. |
| `MR-UI-002` | `PASS` for safe denial: **Evaluate Walk** created a durable `waiting-for-dry-run` receipt, displayed **No command submitted**, and left approval/execution unavailable. |
| `MT-UI-001` | `PASS` for View, Editor, and Final Output mode navigation. The typed MoonFind intake also rendered exactly three participant books and explicitly remained **PENDING · NOT EXECUTED**. |

These narrow passes do not prove formal PostgreSQL MoonProj truth, MoonTown
participant execution/review, Bookkeeper closure, or a physical robot. See
[2026-07-31 remediation](REMEDIATION_2026-07-31.md) for exact evidence paths
and the remaining blockers. The baseline totals below are intentionally
unchanged.

## Tested source

| Product | Commit |
| --- | --- |
| MoonMoon | `c667b7a37bdb6c4457d9fc2761d4710d3f01657c` |
| MoonProj | `9ad0f11fbc66f0bcd0c4bec7c8a21803f5343452` |
| MoonRobo | `be42c0e6eb9b944e18c2f0456005f04a0088ff5e` |
| MoonTown | `8d0909e93afe955443fc2a44307427ea15ab79bb` |
| MoonVis | `a1894ee1cb5c44728aaf295cf352273415f0e75f` |
| `vectie.github.io` | `1f18f87e2a17b1500cee748e93f466caee2246be` |

## Result summary

| Case | User outcome | Result | Important conclusion |
| --- | --- | --- | --- |
| MM-UI-001 | Compare a lunar route without changing mission authority, then inspect the controlling block | `PASS` | Candidate inspection and mission authority remain visibly separate |
| MP-UI-001 | Create and advance a task from the Moon project surface | `FAIL` | The published control emits an intent notice but exposes no task form or lifecycle |
| MP-UI-002 | Advance a Basic OPC work item through acceptance | `NOT-RUN` | Designed to distinguish the general OPC lifecycle from the failed Moon project surface |
| MR-UI-001 | Inspect bounded MoonData readiness from the robot cockpit | `PASS` | Real MoonData refresh passed, with a prominent labelled-sample fallback limitation |
| MR-UI-002 | Evaluate a walk while physical dispatch remains unavailable | `NOT-RUN` | Designed safe-denial case; no physical action is permitted |
| MT-UI-001 | Move between public, editor, and output views of Wenyu Valley | `FAIL` | The requested viewport URL rendered Energy Valley and exposed none of the three mode controls |
| MT-UI-002 | Use the in-product Energy Valley guide | `PASS` | The guide visibly opened, closed through Start explore, and reopened |
| MV-UI-001 | Resolve a MoonRobo desktop visual bundle and detect consumer drift | `PASS` | Exact product/channel resolution and aligned-drift-aligned recovery passed |
| SITE-UI-001 | Explore the reinforcement loop and preserve state across language change | `PASS` | Verify, reward/revert, and bilingual state preservation passed on the deployed site |

Five executed cases passed, two executed cases failed, and two designed
follow-ups were not run. `FAIL` means the surface was executable but a required
visible assertion failed. `NOT-RUN` is not a pass.

## Safety and isolation

- No provider credentials were supplied.
- No publication, trading, accounting, customer, or external-message effect
  was authorized.
- No physical robot bridge was started.
- MoonRobo used a copied RoboBook fixture under `/tmp` and an intentionally
  absent bridge port.
- MoonTown used an empty, isolated suite root under `/tmp`.
- MoonProj's general OPC records are documented as browser-session state; they
  are not treated as PostgreSQL business truth.
- Screenshots and runtime records stay under each product's ignored
  `_build/ui-to-ui/` directory.

## MM-UI-001: inspect a lunar candidate and the controlling block

### User outcome

A mission designer can compare a measured corridor without accidentally
changing the mission-selected route, then open the evidence that prevents
motion.

### Launch

The executed run used the existing production bundle:

```sh
cd /Users/kq/Workspace/moonmoon/ui/rabbita-moon
./node_modules/.bin/vite preview \
  --host 127.0.0.1 \
  --port 48766
```

Open:

```text
http://127.0.0.1:48766/first_trusted_square.html
```

To rebuild first:

```sh
cd /Users/kq/Workspace/moonmoon/ui/rabbita-moon
npm install
npm run build
./node_modules/.bin/vite preview \
  --host 127.0.0.1 \
  --port 48766
```

### Visible actions

1. Confirm the page is **Operator** and the decision is blocked.
2. Open **Compare route candidates**.
3. Click **Direct traverse across measured LOLA patch**,
   `direct-lola-window`.
4. Read the route context above the candidate metrics.
5. Click **Review blocking evidence**.
6. Inspect **Evidence authority**, **Motion handoff**, and the controlling
   blockers.

### Acceptance assertions

- The context changes to **Inspecting candidate; mission selection unchanged**.
- The displayed score, maximum grade, roughness, and illumination evidence
  change to the inspected candidate.
- The mission-selected route remains authoritative.
- Four controlling blockers remain visible.
- Source authority and the mission-gated handoff are visible.
- The browser console contains no warning or error.

### Executed result

`PASS`

The candidate changed the inspection state but did not change mission
authority. The blocking-evidence action exposed the source and handoff boundary
and retained all four blockers. The browser console was empty.

Evidence:

- Run record:
  `/Users/kq/Workspace/moonmoon/_build/ui-to-ui/2026-07-31-nz-moonmoon/run.json`
- Console:
  `/Users/kq/Workspace/moonmoon/_build/ui-to-ui/2026-07-31-nz-moonmoon/browser-console.json`
- Route comparison:
  `/Users/kq/Workspace/moonmoon/_build/ui-to-ui/2026-07-31-nz-moonmoon/screenshots/01-route-comparison.png`
- Blocking evidence:
  `/Users/kq/Workspace/moonmoon/_build/ui-to-ui/2026-07-31-nz-moonmoon/screenshots/03-blocking-evidence.png`

### Designed follow-up

Navigate to **Moonbook & Guide**, ask **Can robot motion authorize a route?**,
and require an evidence-cited negative answer. This would qualify the
MoonBook-style explanation surface but is not part of MM-UI-001.

## MP-UI-001: create a task from Moon project mode

### User outcome

An operator should be able to create a task through the visible Moon project
surface and see that task enter a real, inspectable lifecycle.

### Launch

```sh
cd /Users/kq/Workspace/moonproj
warren dev frontend/opc \
  --public-dir frontend/opc_public \
  --port 44300
```

Open the Warren URL printed by the command. In this run it was:

```text
http://127.0.0.1:44300/__warren/preview/index.html?warren_reload=0
```

### Visible actions

1. Click **Moon 专案**.
2. Open **任务编排**.
3. Click **创建任务**.

### Expected assertions

- A task form becomes visible.
- The operator can provide a task result and acceptance definition.
- Saving creates a visible task record.
- Visible controls advance the same task through start, submission, and
  acceptance.

### Executed result

`FAIL`

The button produced only this intent notice:

> 证据写入 PostgreSQL 前不会产生正式业务影响

No task form, created task, or create/start/submit/accept lifecycle appeared.
The browser console also reported:

```text
Uncaught TypeError: Failed to execute 'observe' on 'MutationObserver':
parameter 1 is not of type 'Node'.
```

This is not a backend prerequisite block: the visible surface was available
and its primary action was executable. The published UI itself did not provide
the promised task journey.

Evidence:

- Run record:
  `/Users/kq/Workspace/moonproj/_build/ui-to-ui/2026-07-31-nz-moonproj/run.json`
- Console:
  `/Users/kq/Workspace/moonproj/_build/ui-to-ui/2026-07-31-nz-moonproj/browser-console.json`
- Intent-only result:
  `/Users/kq/Workspace/moonproj/_build/ui-to-ui/2026-07-31-nz-moonproj/screenshots/03-create-task-intent-only.png`

### Product implication

MoonProj currently shows a project-control concept, not a complete task
application. An intent toast must not be described as task creation, and the
MutationObserver failure must be fixed before this journey can qualify.

## MP-UI-002: Basic OPC work acceptance

Result: `NOT-RUN`

This case intentionally uses the general OPC product surface rather than the
failed Moon project projection.

### Visible actions

1. Select **通用模式**.
2. Open **工作与交付**.
3. Click **创建工作项**.
4. Enter:

   - 工作名称: `UI-to-UI qualification`
   - 验收标准: `Visible accepted card with settlement boundary`

5. Click **保存工作项**.
6. Confirm the card appears in **待定义**.
7. Click **开始执行** and confirm it moves to **进行中**.
8. Click **提交验收** and confirm it moves to **待验收**.
9. Click **接受结果**.
10. Confirm it moves to **已接受** and displays
    **等待结算与入账**.

### Acceptance boundary

This would prove the browser-session lifecycle only. It would not prove
PostgreSQL persistence, accounting, cash settlement, or an independently
authorized acceptance receipt.

## MR-UI-001: inspect MoonData from the robotics cockpit

Result: `PASS`, with a degraded-source limitation

### User outcome

An operator can inspect the selected robot's canonical data and validation
pressure without starting a runtime or sending a robot command.

### Isolated launch

```sh
cd /Users/kq/Workspace/moonrobo
ROBOBOOK_ROOT="$(mktemp -d /tmp/moonsuite-ui-nz-moonrobo.XXXXXX)"
cp -R examples/noetix-e1/. "$ROBOBOOK_ROOT/"
moon run cmd/main --target native -- \
  serve \
  "$ROBOBOOK_ROOT" \
  /Users/kq/Workspace/moonrobo/ui/rabbita-cockpit \
  127.0.0.1 \
  45290 \
  127.0.0.1 \
  45391
```

Port `45391` is deliberately left without a bridge process.

Executed-run fixture:

```text
/tmp/moonsuite-ui-nz-moonrobo.J1Ql6g
```

Open:

```text
http://127.0.0.1:45290/
```

### Visible actions

1. Read the persistent robot identity and runtime state.
2. Click the **MoonData** top-level view.
3. Click **Refresh Data**.
4. Inspect readiness, validation, artifact-family counts, and the canonical
   artifact inventory.
5. Return to **Operate** and confirm the bridge remains unavailable.

### Acceptance assertions

- Only the MoonData view is mounted after selection.
- Refresh produces a visible completed status rather than leaving an
  indefinite spinner.
- Robot model, dataset, validation, and catalog facts are visible.
- No raw fixture payload is interpreted by browser code.
- Bridge/runtime controls remain unavailable or gated.
- No physical command is dispatched.
- The browser console and failed-request list identify any missing optional
  services without hiding them behind sample success.

### Executed result

The MoonData view mounted through the visible top-level control, and
**Refresh Data** completed. The isolated workspace truthfully remained
`not-initialized` with zero artifacts. No dry run, approval, execution,
runtime-start, emergency-stop, or physical command control was used. The
browser console contained no warning or error.

The pass is limited to the MoonData navigation, real refresh boundary, and
honest empty state. The cockpit also used its labelled sample fallback because
the host snapshot omitted:

```text
product_status.product_homes.moonclaw_robot_routine_runs_path
```

Therefore this result does not qualify a complete source-backed cockpit
snapshot, initialized MoonData catalog, populated artifact inventory, robot
runtime, or physical bridge.

Evidence:

- Run record:
  `/Users/kq/Workspace/moonrobo/_build/ui-to-ui/2026-07-31-moondata/run.json`
- Console:
  `/Users/kq/Workspace/moonrobo/_build/ui-to-ui/2026-07-31-moondata/browser-console.json`
- Screenshots: none retained for this run.

## MR-UI-002: safe-denial walk evaluation

Result: `NOT-RUN`

This case stops before dry run, approval, or execution.

### Visible actions

1. Open **Operate**.
2. Click **Evaluate Walk**.
3. Read **Safety Gate**, intent status, and the next required evidence.
4. Do not click **Dry Run**, **Approve**, **Execute**, **Start Runtime**, or
   **Emergency Stop**.

### Acceptance assertions

- The visible result is blocked or not ready while the bridge is absent.
- A reason and next evidence step are visible.
- No UI state claims that a physical walk occurred.
- Only evidence under the isolated RoboBook may be written.

## MT-UI-001: inspect, edit, and retrieve Wenyu Valley

Result: `FAIL`

### User outcome

An operator can use one town model in three explicit modes: public inspection,
town-level composition, and output retrieval.

### Isolated launch

```sh
cd /Users/kq/Workspace/moontown
SUITE_ROOT="$(mktemp -d /tmp/moonsuite-ui-nz-moontown.XXXXXX)"
MOONTOWN_SUITE_ROOT="$SUITE_ROOT" \
MOONTOWN_DESKTOP_STATIC_ROOT=/Users/kq/Workspace/moontown/src/ui/rabbita-town/dist \
MOONTOWN_OPERATOR_POLICY_PATH=/Users/kq/Workspace/moontown/assets/templates/operator-request-policy.json \
moon run src/cmd/desktop_server --target native
```

The desktop service currently binds to fixed localhost port `17842`.

Executed-run root:

```text
/tmp/moonsuite-ui-nz-moontown.t56wv4
```

Open:

```text
http://127.0.0.1:17842/viewport.html?assets=generated&mode=view&v=wenyu
```

### Visible actions

1. In **View** mode, inspect the town map and visible building links.
2. Select **Editor** in the **Viewport mode** control.
3. Inspect module placement, entrance, runtime state, validation, and the
   **MoonTown / MoonDesk Boundary**.
4. Select **Output**.
5. Inspect the MoonBook output/review surface and MoonDesk handoff context.
6. Select **View** to return to the public town surface.

### Acceptance assertions

- One URL and one town projection drive all three modes.
- Each selected mode has a visible selected state.
- Editor mode describes town/module composition and does not pretend to be a
  deep prompt, skill, file, or agent editor.
- Output mode shows real empty/offline state when the fresh suite root contains
  no accepted book outputs.
- Returning to View removes editor/output chrome.
- No missing runtime data is replaced with unlabelled sample success.

### Executed result

The requested `viewport.html` URL remained in the address bar, but the shipped
surface rendered the Energy Valley demo. It exposed no **View**, **Editor**, or
**Output** control, so the first meaningful mode action could not be performed.
The console contained no warning or error, but a clean console does not turn
the wrong surface into a pass.

Evidence:

- Run record:
  `/Users/kq/Workspace/moontown/_build/ui-to-ui/2026-07-31/run.json`
- Console:
  `/Users/kq/Workspace/moontown/_build/ui-to-ui/2026-07-31/browser-console.json`
- Screenshots: none retained for this run.

MoonTown needs either a working standalone viewport entry or documentation
that points at the actual route exposing those controls.

## MT-UI-002: Energy Valley guide

Result: `PASS`

Open:

```text
http://127.0.0.1:17842/?demo=1
```

1. If onboarding appears, click **先看完整操作指南**.
2. Confirm the guide explains metrics, build controls, persistence, and reset.
3. Click **开始探索**.
4. Reopen **指南** from the town surface.
5. Close it with the labelled close control or press `Escape`.

The pass condition is a recoverable guide flow, not merely the presence of
guide text in source.

The guide opened visibly, explained the real-runtime versus demo boundary,
closed through **开始探索**, and reopened through the labelled **指南**
control. The browser console contained no warning or error.

Evidence:

- Run record:
  `/Users/kq/Workspace/moontown/_build/ui-to-ui/2026-07-31/run.json`
- Console:
  `/Users/kq/Workspace/moontown/_build/ui-to-ui/2026-07-31/browser-console.json`
- Screenshots: none retained for this run.

## MV-UI-001: resolve a visual bundle and detect drift

Result: `PASS`

### User outcome

A product designer can select a product/channel adaptation, see the exact
resolved bundle, and make version drift visible.

### Launch

```sh
cd /Users/kq/Workspace/moonvis/ui/rabbita-moonvis
./node_modules/.bin/vite preview \
  --host 127.0.0.1 \
  --port 45198
```

Open:

```text
http://127.0.0.1:45198/
```

To rebuild:

```sh
cd /Users/kq/Workspace/moonvis/ui/rabbita-moonvis
npm install
npm run build
./node_modules/.bin/vite preview \
  --host 127.0.0.1 \
  --port 45198
```

### Visible actions

1. Under **PRODUCT**, click `moonrobo`.
2. Under **CHANNEL**, click `desktop`.
3. Confirm the context heading is `moonrobo · desktop`.
4. Record the bundle digest, versions, adaptation dial, product adaptation,
   and channel contract.
5. Under **DRIFT PROBE**, click **simulate stale consumer**.
6. Confirm the banner changes from **ALIGNED** to **DRIFT** and lists version
   mismatches.
7. Click **current binding**.
8. Confirm the banner returns to **ALIGNED**.

### Acceptance assertions

- Product, channel, and drift controls have visible selected states.
- Changing product/channel changes the resolved manifest facts.
- Drift is not presented as an accessibility pass or accepted UI.
- Restoring the current binding returns the original aligned result.
- The claim ceiling remains visible: a resolved manifest is not a composed
  product UI.

### Executed result

Selecting `moonrobo` and `desktop` produced:

```text
moonrobo · desktop
sha256:5f08f34c87aab591c73c45e4d64a926d4035fc5df1972bf7007a6e857bf6ae6b
```

The stale-consumer control changed **ALIGNED** to **DRIFT** and exposed both
exact mismatches:

```text
token-version-drift: expected 0.9.0, resolved 1.0.0
asset-version-drift: expected 0.9.0, resolved 1.0.0
```

Selecting **current binding** restored **ALIGNED**. The claim ceiling remained
visible and the browser console contained no warning or error.

Evidence:

- Run record:
  `/Users/kq/Workspace/moonvis/_build/ui-to-ui/2026-07-31/run.json`
- Console:
  `/Users/kq/Workspace/moonvis/_build/ui-to-ui/2026-07-31/browser-console.json`
- Screenshots: none retained for this run.

## SITE-UI-001: explore the deployed reinforcement loop

Result: `PASS`

### User outcome

A visitor can understand how a failed or successful task changes the next
software baseline, then switch language without losing the selected phase.

### Published URL

```text
https://vectie.github.io/
```

The tested source commit is `1f18f87e2a17`; qualification must record if the
deployed content does not match that revision.

### Visible actions

1. Click **Enter the evolution loop**.
2. In **Agent software loop**, click **Verify**.
3. Confirm the visible phase is `04`, the candidate is under evaluation, and
   the illustrative result is `91 / 100` against threshold `85`.
4. Click **Reward / revert**.
5. Confirm the visible next-cycle baseline is
   `research_brief@v13`.
6. Click the language control **切换至中文**.
7. Confirm the same phase remains selected, the explanatory content is
   Chinese, and the URL contains `lang=zh`.
8. Switch back to English and confirm the selected phase is still preserved.

### Acceptance assertions

- Tabs are operated through their visible controls.
- Phase content changes with the selected tab.
- The loop distinguishes verified reward from rollback with retained learning.
- Language navigation does not reset the selected loop phase.
- No broken assets, console errors, or failed same-origin requests appear.

### Executed result

**Verify** visibly showed phase `04`, the illustrative score `91 / 100`, and
threshold `85`. **Reward / revert** showed phase `05` and next baseline
`research_brief@v13`.

Switching to Chinese retained phase `05` at:

```text
https://vectie.github.io/?lang=zh#loop
```

Switching back to English retained the same phase at:

```text
https://vectie.github.io/?lang=en#loop
```

The browser console contained no warning or error.

Evidence:

- Run record:
  `/Users/kq/Workspace/vectie.github.io/_build/ui-to-ui/2026-07-31/run.json`
- Console:
  `/Users/kq/Workspace/vectie.github.io/_build/ui-to-ui/2026-07-31/browser-console.json`
- Screenshots: none retained for this run.

### Designed product-navigation follow-up

Open the **MoonRobo** or **MoonTown** product page through a visible product
link, use browser Back, and confirm the product grid and language are
preserved. This is designed but not part of SITE-UI-001.

## How these products interact

| Producer | Consumer | What may cross the boundary | What must not cross |
| --- | --- | --- | --- |
| MoonMoon | MoonRobo | Bounded simulation result, provenance, uncertainty, blockers | Route authority or proof of physical readiness |
| MoonProj | MoonFlow/MoonBook | Project, cost, acceptance, and reviewed business artifacts | Agent runtime, provider policy, or silent accounting truth |
| MoonRobo | MoonBook/MoonFlow | Robot model refs, safety decisions, replay, telemetry, receipts | Ungated vendor commands or self-approved physical authority |
| MoonTown | MoonFlow/MoonClaw/MoonBook | Coordination request, participant books, synthesis state, review candidate | A second agent runtime or self-accepted knowledge |
| MoonVis | Every product UI | Versioned token/asset bundle, provenance, adaptation and contrast expectations | Product workflow, accessibility acceptance, or domain UI ownership |
| Public site | People | Product catalog, maturity, architecture and learning-loop explanation | Runtime control or claims that local alpha equals production proof |

The user-visible chain for a safe robotics scenario is:

```text
MoonTown or MoonDesk requests work
→ MoonFlow owns durable attempts and recovery
→ MoonClaw is the sole agent runtime
→ MoonMoon returns bounded lunar simulation evidence
→ MoonRobo applies robot and physical-safety policy
→ MoonBook retains reviewed evidence
→ MoonVis supplies only the selected visual bundle
→ a named human accepts, rejects, or defers
```

## How to repeat a UI-to-UI run

### 1. Record the source revision

```sh
git -C /Users/kq/Workspace/<product> rev-parse HEAD
```

Do not describe a browser result as proof for a later untested commit.

### 2. Create transient evidence storage

```sh
RUN_ID="2026-07-31-<case-id>"
RUN_ROOT="/Users/kq/Workspace/<product>/_build/ui-to-ui/$RUN_ID"
mkdir -p "$RUN_ROOT/screenshots" "$RUN_ROOT/receipts"
```

Keep customer data, credentials, licensed datasets, and unclear-rights media
out of the run directory.

### 3. Use a unique port and isolated state

- Give every local UI its own port.
- Copy fixtures to `/tmp`; do not test against the canonical product data.
- Point every supported suite/data-root environment variable at that copy.
- Leave real provider, broker, publication, and robot bridges disconnected
  unless a separate authorized acceptance run explicitly requires them.

### 4. Capture the start, action, and result

Save:

```text
screenshots/01-start.png
screenshots/02-action.png
screenshots/03-result.png
```

The screenshots supplement the action record. They do not replace it.

### 5. Use only visible controls

Click, type, drag, select, import, approve, or reject in the product. Do not:

- call update functions directly;
- inject a response into the page;
- set the application model from developer tools;
- call the final API instead of clicking its initiating control; or
- infer success from source strings.

### 6. Check authority and durability

- If a result claims persistence, reload or restart and reopen it.
- If a result is intentionally browser-session state, label it that way and
  do not claim durable storage.
- For a denied action, require a visible reason and next step.
- For robotics, require simulation-only or safe-denial evidence and confirm no
  physical command occurred.

### 7. Retain diagnostics

Save browser warnings/errors as `browser-console.json` and failed requests as
`failed-requests.json`. An optional unavailable service may be an expected
failed request, but it must be explained rather than omitted.

### 8. Write `run.json`

Minimum shape:

```json
{
  "product": "moonvis",
  "commit": "<full commit>",
  "case_id": "MV-UI-001",
  "url": "http://127.0.0.1:45198/",
  "actions": [
    "select moonrobo",
    "select desktop",
    "simulate stale consumer",
    "restore current binding"
  ],
  "assertions": [
    "context and digest changed",
    "DRIFT listed version mismatches",
    "ALIGNED returned after restore"
  ],
  "result": "PASS",
  "external_effects": "none"
}
```

### 9. Stop local services

Return to each launch terminal and press `Control-C`. Verify the selected ports
no longer listen. Temporary roots may then be removed after retaining any
required receipts in the ignored evidence directory.
