# Standalone A-M UI-to-UI qualification

- Qualification date: 2026-07-31
- Scope: Bunnia/MoonMini, Lepusa, MoonBook, MoonCast, MoonChat, MoonClaw,
  MoonEdit, MoonFind, MoonFish, MoonFlow, MoonGate, MoonLeaf, MoonLib, and
  MoonMold
- Method: visible control to visible result in the shipped product or its
  named consumer

This report separates a launch-ready surface, a designed journey, and an
executed UI-to-UI result. A successful build, health probe, direct API call,
fixture export, rendered-string assertion, or source inspection is not a
UI-to-UI pass.

The worker that prepared this A-M report had no browser bound to it. It
launched the browser products on isolated ports, and the parent qualification
task subsequently performed the cases marked `PASS` or `FAIL` through a bound
browser. HTTP readiness alone was not relabelled as UI execution. Cases without
retained visible evidence remain `NOT-RUN`, `BLOCKED`, or `NOT-APPLICABLE`.

For the latest product-owned cases and focused browser outcomes, use
[the consolidated 2026-07-31 report](CONSOLIDATED_UI_TO_UI_2026-07-31.md).
The case table and counts in this file remain historical evidence.

## Remediation addendum

The source table, case results, and totals below are the preserved first
snapshot. They are not edited in place. A later same-day browser rerun closed
these scoped defects:

| Case | Follow-up result |
| --- | --- |
| `MCL-UI-001` | `PASS` — Cowork used its safe same-origin gateway, created **New chat**, and retained the conversation after reload. |
| `MM-UI-001`, `MM-UI-002` | `PASS` for the mock-digital boundary — execute, same-attempt reconcile, exact named review, and restart recovery all completed while physical authority remained false. |
| `MFS-UI-002` | `PASS` for a fixture paper watch — the visible named review created `monitor_only` with CNY entry/goal, expected upside, sale horizon/window, and invalidation; no investment-ready or broker effect exists. |
| `MC-UI-001` | `PASS` for needs→exact brief→G0; G1–G5, populated Cut Editor work, accepted master, and a real provider episode remain blocked. `MC-UI-002` remains the proven pre-G4 denial. |
| `MFI-UI-002` | `PASS` through durable terminal projection and typed MoonTown handoff publication; participant execution, named review, and Bookkeeper closure remain open. |
| `MFL-UI-001`, `MFL-UI-002` | `PASS` for saved/restarted node coordinates, restored Flow hydration, and one visible generic v2 action. The receiving-pack receipt and 63-stage execution remain blocked. |

See [2026-07-31 remediation](REMEDIATION_2026-07-31.md) for exact visible
actions, evidence paths, claim ceilings, and remaining production gates. The
historical totals in this report are intentionally unchanged.

## Tested source

| Product | Commit |
| --- | --- |
| Bunnia / MoonMini alias | `3f7466cc879c20d13f1729c2a0f5dfa9edac8bf3` |
| Lepusa | `763ba1ed986f66988b156f4ee2fe1c638697a27b` |
| MoonBook | `c7c563171c1e0d0638c150831e991c02a3de60ae` |
| MoonCast | `a9e4b106338340abfc73bd4b9df619d5f6ee840b` |
| MoonChat | `1d5c8f90c469682087c42c1ad1e97ae06b4eb612` |
| MoonClaw | `9a5fa453a8441f416fe417033ca5aa67a863cb81` |
| MoonEdit | `f3da583c82c2e6b7b8261b399d7e0865e1754233` |
| MoonFind | `960c8cf2763de286a1965aa09b418323a1f8b4db` |
| MoonFish | `5566146146dba32e2ebbbca55b8ca7d64f4fd43a` |
| MoonFlow | `f1b3154fe7c6075629cf466c4de773eb384f3cc2` |
| MoonGate | `21e62c0b2f19ec64f591350f0b27f9e8993126a9` |
| MoonLeaf | `f47aed40fcef9eb2c24f4b08fb5f48104b69c858` |
| MoonLib | `0373dfa7f2b846de9656484a9d3d3523daeadfc8` |
| MoonMold | `cb1c662ea668b4b56972958b81eb586678b7fece` |

## Product-shape inventory

| Product | Product shape | Standalone UI decision | Required visible proof | First current blocker |
| --- | --- | --- | --- | --- |
| Bunnia / MoonMini | Mini-application UI framework | No framework dashboard; MoonMini is only an alias | Generated WeChat mini-application | Requires WeChat DevTools; a browser page cannot emulate the shipped mini-app runtime |
| Lepusa | Native system-WebView application framework | No duplicate framework dashboard | Packaged MoonGate or MoonDesk window | Requires native packaged-window operation, not only the equivalent localhost page |
| MoonBook | Knowledge platform and Bookkeeper | Direct Rabbita UI | Browser UI, durable journal, named-review denial and reload | Debug build hits an AArch64 local-branch-range compiler failure; release build works |
| MoonCast | Media domain pack and production studio | Direct Studio, Cut Editor and client UI | Governed project, gate denial, populated cut, render and acceptance | Local project/gate UI is available; a real 3–8 minute provider episode is not yet commercially qualified |
| MoonChat | Portable conversation-review contract | Standalone UI intentionally excluded | MoonFind/MoonDesk review to MoonBook closure | Consumers declare the operation but do not yet expose a complete visible invocation and receipt |
| MoonClaw | Sole agent runtime | Direct Cowork/job UI | Durable visible session/job control | The served UI hardcodes gateway target `http://127.0.0.1:18123`, so a gateway launched on another port cannot create a session |
| MoonEdit | Text/code editor library | Standalone UI intentionally excluded | MoonDesk editor using MoonEdit | MoonDesk does not import MoonEdit and therefore cannot presently prove this library through UI |
| MoonFind | Research domain pack | Direct Rabbita research workspace | Prepared capability through MoonClaw, review and Bookkeeper handoff | Static UI has no host-published submit/reconcile/checkpoint URLs |
| MoonFish | Financial research domain pack | Direct pack-owned daily application, hosted by MoonDesk or service | Run, funnel, dossier, review, full recommendation and paper-only outcome | The UI can submit a fixture run but has no visible action that creates the released recommendation it knows how to render |
| MoonFlow | Generic orchestration platform | Domain UI intentionally excluded | MoonDesk Flow canvas/run projection | A real pass requires an unexpired host-published catalog and a real imported run, not the 63-node renderer alone |
| MoonGate | Provider/authority platform and operator app | Direct browser and Lepusa UI | Refresh, endpoint copy, provider/authority denial and suite projection | Provider-backed calls remain conditional on operator credentials and terms |
| MoonLeaf | Conservative OOXML library | Standalone UI intentionally excluded | MoonDesk office editor using MoonLeaf | MoonDesk currently owns a separate OOXML implementation and does not import MoonLeaf |
| MoonLib | Shared contract/runtime library | Standalone UI intentionally excluded | Named consumers preserve layout and DTO identity | UI evidence must identify the consuming MoonLib contract; a generic screen render is insufficient |
| MoonMold | Spatial-model domain pack | Direct Rabbita operator | Execute, reconcile, named review and physical-authority denial | Mock-reference execution currently fails decoding because the returned object lacks `reviews`; live Blender also remains unqualified |

## Result summary

| Case | User outcome | Result | Important conclusion |
| --- | --- | --- | --- |
| BU-UI-001 | Operate a generated mini-app through Bunnia runtime patches | `NOT-RUN` | WeChat DevTools execution remains required |
| BU-UI-002 | Refresh the generated app through its real local backend | `NOT-RUN` | Designed as the backend-bound Bunnia consumer proof |
| LE-UI-001 | Operate MoonGate inside a Lepusa native window | `NOT-RUN` | The localhost browser proof cannot substitute for native-host proof |
| MB-UI-001 | Switch locale and replay the Bookkeeper journal | `PASS` | Locale round-trip, replay completion, refresh count 2 and coherent reload were visible |
| MB-UI-002 | Observe named-authority denial | `PASS` | The fresh book showed no reviewer authority and the exact CLI next step |
| MC-UI-001 | Create a governed 3–8 minute project and record G0 | `FAIL` | Project creation passed, but G0 correctly remained blocked by exact brief approval |
| MC-UI-002 | Attempt Cut Editor import before G4 | `PASS` | The visible editor import was rejected by canonical G4 approval enforcement |
| MC-UI-003 | Cut, render, review and accept a complete episode | `BLOCKED` | Requires rights-cleared media or a real provider-produced G4 project |
| MCH-UI-001 | Record a portable conversation review through a consumer | `BLOCKED` | No complete visible consumer call chain is published |
| MCL-UI-001 | Create and reload a durable Cowork conversation | `FAIL` | The UI targeted hardcoded port 18123 instead of the served gateway on 4317 |
| ME-UI-001 | Edit, undo, redo, save and reopen text/code through MoonEdit | `BLOCKED` | MoonDesk does not consume MoonEdit |
| ME-UI-002 | Resolve a three-way conflict through a named human choice | `BLOCKED` | Host-owned conflict UI is not integrated |
| MFI-UI-001 | See fail-closed capability preparation in MoonFind | `PASS` | The visible unavailable control failed closed without a provider, session or acceptance |
| MFI-UI-002 | Complete research, review and Bookkeeper handoff | `BLOCKED` | Host submit/reconcile/checkpoint ports are absent |
| MFS-UI-001 | Submit the verified MoonFish fixture through MoonClaw | `PASS` | Run `moonfish-5e6813247924aefe491e56e0` survived reload with partial policy |
| MFS-UI-002 | Review ticker, entry, target, upside and sale horizon | `BLOCKED` | No visible action creates an operator release record |
| MFL-UI-001 | Inspect and manipulate a 63-stage Flow composition | `FAIL` | Visible canvas mechanics passed, but moved-node layout reset after restart |
| MFL-UI-002 | Import, restart and recover a real MoonFlow run | `BLOCKED` | Run sequence 64 recovered with one runnable item, but no authority-bound operator action was published |
| MG-UI-001 | Refresh MoonGate and copy a compatible endpoint | `PASS` | Refresh and visible `/v1/chat/completions` copy feedback passed |
| MG-UI-002 | Observe honest no-provider connection state | `PASS` | The graph showed no saved provider/waiting state without mutation or model call |
| ML-UI-001 | Edit, save as copy and reopen a DOCX | `BLOCKED` | Current MoonDesk office code is not MoonLeaf |
| ML-UI-002 | Preserve an XLSX formula and PPTX slide identity | `BLOCKED` | Same ownership/integration blocker |
| MLB-UI-001 | Preserve canonical MoonSuite/book identity across reload | `NOT-RUN` | Must be attributed to a named MoonLib consumer |
| MM-UI-001 | Execute and reconcile a mock-reference spatial request | `FAIL` | Execution ended in a missing-`reviews` JSON decode error and produced no operation receipt |
| MM-UI-002 | Bind a named review while physical authority stays denied | `BLOCKED` | Named review was not attempted because no exact operation receipt existed |

`BLOCKED`, `NOT-RUN`, and `NOT-APPLICABLE` are not passes.

Current totals: `PASS` 7, `FAIL` 4, `BLOCKED` 10, `NOT-RUN` 4.

## Isolated launch board

These services were started with no provider credentials, licensed market
bundle, publication destination, broker, payment path, Blender process, or
physical bridge. The HTTP checks only established launch readiness.

| Product | URL | Isolated state root | Launch readiness |
| --- | --- | --- | --- |
| MoonCast | `http://127.0.0.1:4312/apps/mooncast/studio` | `/tmp/moonsuite-ui-qualification-am/mooncast` | `/health` returned 200 |
| MoonFind | `http://127.0.0.1:4313/` | Static checked-in projection; no host mutation | Vite root returned 200 |
| MoonGate | `http://127.0.0.1:4314/ui/rabbita` | `/tmp/moonsuite-ui-qualification-am/moongate` | `/health` returned 200 |
| MoonMold | `http://127.0.0.1:4315/` | `/tmp/moonsuite-ui-qualification-am/moonmold` | `/api/status` returned 200 |
| MoonBook | `http://127.0.0.1:4316/apps/moonbook/` | `/tmp/moonsuite-ui-qualification-am/moonbook` | UI returned 200 |
| MoonClaw | `http://127.0.0.1:4317/ui#/cowork` | `/tmp/moonsuite-ui-qualification-am/moonclaw` | `/health` and `/ui` returned 200 |
| MoonFish | `http://127.0.0.1:4318/apps/moonfish/daily` | `/tmp/moonsuite-ui-qualification-am/moonfish` | Native health reported ready |

Exact launch commands are included in the cases below. Choose new ports when
rerunning rather than assuming these listeners are still alive.

## Safety and authority boundary

- No browser request may call a model, publisher, broker, payment provider,
  licensed-data provider, Blender process, or physical device in this local
  qualification.
- MoonFish is research and paper-only. A fixture must remain visibly
  `recommendation_eligible: false`.
- MoonCast local fixture rendering does not prove creative quality, rights, or
  client acceptance.
- MoonMold mock-reference output must remain labelled mock evidence and must
  never imply Blender, manufacturing, or physical authority.
- MoonFind's fixture or static projection must not be presented as a live
  MoonClaw run.
- A denial is a valid UI result only when the user initiates the denied action
  visibly and sees the reason and next step.

## BU-UI-001: generated mini-app interaction

Result: `NOT-RUN`

No WeChat DevTools UI run was retained for this case. The layout-persistence
failure belonged to the MoonFlow canvas case, not Bunnia. MoonMini remains a
symlink alias of Bunnia rather than a second product.

### User outcome

A user can operate a Bunnia-generated mini-application and see a real WeChat
runtime patch change the visible page.

### Generate

```sh
cd /Users/kq/Workspace/bunnia
moon run cmd/main -- \
  build \
  --target wechat \
  --example moontown_miniapp \
  --strict \
  --budget large \
  --render-budget large \
  --out _build/ui-to-ui/am/moontown_miniapp
```

The generation step completed for this source revision and wrote 39 files. It
is preparation, not the UI pass.

### Visible actions in WeChat DevTools

1. Import
   `/Users/kq/Workspace/bunnia/_build/ui-to-ui/am/moontown_miniapp`.
2. Open the **Discover** tab.
3. Tap **More**.
4. Confirm the **More filters** panel appears.
5. Tap **Books** and confirm the selected filter and result heading change.
6. Tap **Close** and confirm the extra panel disappears.
7. Reload the mini-program and repeat one filter change.

### Acceptance assertions

- The shipped generated page, not a source preview, receives every tap.
- The selected filter has a visible state.
- The result heading/list responds to the selected filter.
- No DevTools state injection or direct update-function call is used.
- MoonMini is not recorded as a second product; it is only an alias.

## BU-UI-002: local backend refresh

Result: `NOT-RUN`

### Start the isolated backend

```sh
cd /Users/kq/Workspace/bunnia
node examples/moontown_miniapp/backend/local_backend.mjs \
  --host 127.0.0.1 \
  --port 18191 \
  --state /tmp/moonsuite-ui-qualification-am/bunnia/state.json \
  --reset-state \
  --disable-retention-scheduler
```

### Visible actions

1. In the generated mini-app, tap **Enter Town**.
2. Confirm the first-visit control becomes the visible town identity.
3. Open **My**.
4. Tap **Refresh My Stuff**.
5. Confirm **Refreshing your inventory...** becomes
   **Your inventory is up to date.**
6. Reload and confirm the session/inventory projection is not replaced with an
   unlabelled sample success.

This case is the real backend consumer proof. A backend `--smoke` command alone
does not satisfy it.

## LE-UI-001: Lepusa native consumer proof

Result: `NOT-RUN`

Lepusa is a framework, so its release proof belongs to a packaged consumer.
MoonGate is the preferred small consumer because its same Rabbita dashboard is
available in both a browser and a Lepusa system-WebView window.

### Prepare and package

```sh
cd /Users/kq/Workspace/moongate
MACOSX_DEPLOYMENT_TARGET=11.0 moon build --target native --release

cd /Users/kq/Workspace/lepusa
MACOSX_DEPLOYMENT_TARGET=11.0 \
  moon build cmd/runtime --target native --release

LEPUSA_RUNTIME_EXECUTABLE=/Users/kq/Workspace/lepusa/_build/native/release/build/cmd/runtime/runtime.exe \
  moon run cmd/main --target native -- \
  bundle-write macos \
  _build/ui-to-ui/am/moongate-bundle \
  --project /Users/kq/Workspace/moongate/lepusa.json \
  --json
```

Use the generated distribution manifest to run the corresponding
`bundle-package-write` or local launch flow documented by Lepusa. Do not count
the localhost page as Lepusa proof.

### Visible actions in the native window

1. Launch the generated `MoonGate.app`.
2. Wait for the real localhost readiness result.
3. Select **Manual Connect**.
4. Under **OpenAI Chat**, click **Copy**.
5. Confirm `Copied /v1/chat/completions`.
6. Quit the app.
7. Confirm the supervised MoonGate sidecar exits and no state was written
   inside the application bundle.

### Acceptance assertions

- The window is a real system WebView created by Lepusa.
- Packaged resources and localhost supervision work.
- Clipboard action produces visible feedback.
- Quit tears down supervised services.
- A browser-only MoonGate pass may be reused for product behavior, but cannot
  be relabelled as this native-host pass.

## MB-UI-001: MoonBook locale and durable replay

Result: `PASS`

Evidence:
`/Users/kq/Workspace/moonbook/_build/ui-to-ui/2026-07-31`

### Launch

The debug command currently fails in the Moon compiler with
`Aarch64_assemble local branch target is out of range`. The release profile is
the working launch path:

```sh
cd /Users/kq/Workspace/moonbook
moon run --release cmd/main -- \
  wiki init /tmp/moonsuite-ui-qualification-am/moonbook

moon run --release cmd/main -- \
  serve /tmp/moonsuite-ui-qualification-am/moonbook \
  -n 127.0.0.1 \
  -p 4316
```

Open `http://127.0.0.1:4316/apps/moonbook/`.

### Visible actions

1. Click **简体中文** and confirm the interface labels change.
2. Click **English** and confirm they change back.
3. Scroll to **Governed loop operator**.
4. Click **Replay durable journal**.
5. Confirm
   **Replay complete; the served projection is refreshing.**
6. Record the refresh count, reload, and confirm the fresh-book state remains
   coherent.

### Acceptance assertions

- Locale changes are visible and reversible.
- Replay crosses the server boundary and returns a visible result.
- Replay does not create accepted knowledge or reviewer authority.
- Browser console and failed requests are retained.

The browser changed locale from `en-US` to `zh-Hans` and back to `en-US`.
**Replay durable journal** returned the exact completion message, the visible
refresh count became 2, and reload retained a coherent fresh-book projection.
The browser recorded zero console warnings or errors.

## MB-UI-002: reviewer-authority denial

Result: `PASS`

Evidence:
`/Users/kq/Workspace/moonbook/_build/ui-to-ui/2026-07-31`

1. In **Governed loop operator**, inspect the authority area.
2. Confirm the fresh book says
   **No active reviewer authority. Install one with `moonbook bookkeeper
   authority install`.**
3. Select **Governed review**.
4. Confirm no UI control silently installs or assumes reviewer authority.

The pass condition is the visible denial and next step. Installing authority by
CLI would be a separate explicitly authorized fixture setup.

The fresh book visibly reported no active reviewer authority and named
`moonbook bookkeeper authority install` as the CLI next step. No authority was
installed or inferred through the UI, and the browser recorded zero console
warnings or errors.

## MC-UI-001: governed project and G0

Result: `FAIL` — partial mechanics pass

Evidence:
`/Users/kq/Workspace/mooncast/_build/ui-to-ui/2026-07-31-governed-project`

### Launch

```sh
cd /Users/kq/Workspace/mooncast
MOONCAST_RABBITA_DIST=/Users/kq/Workspace/mooncast/ui/rabbita-mooncast/dist \
MOONCAST_DATA_ROOT=/tmp/moonsuite-ui-qualification-am/mooncast \
MOONCAST_HOST=127.0.0.1 \
MOONCAST_PORT=4312 \
moon run cmd/studio
```

Open `http://127.0.0.1:4312/apps/mooncast/studio`.

### Visible actions

1. Enter:

   - Project id: `uiq-episode-001`
   - Title: `UI Qualification Episode`
   - Payable objective: `Approved 3-minute product explainer master`
   - Audience: `Design partners`
   - Channels: `review-only`
   - Rights owner: `UI Qualification Owner`
   - Duration seconds: `180`
   - Maximum budget CNY: `20000`

2. Click **Rights remain pending** and confirm it becomes
   **Rights owner confirmed**.
3. Click **Create governed project**.
4. Confirm the project appears in the project rail and the status says
   **Project and seven governed creative drafts created.**
5. Confirm the resulting projection contains project revision 8, one episode,
   three scenes, 15 shots and seven drafts.
6. In **Named human authority**, enter actor `UI Qualifier`, role
   `producer`, and a current ISO-8601 decision time.
7. Click **Confirm deliberate action**.
8. Click G0 **Record evidence gate**.
9. Observe the visible status
   **Gate G0: exact_brief_approval_required**.

### Acceptance assertions

- Project creation crossed the native MoonBit host and produced the expected
  governed project graph.
- No draft becomes approved merely because the project was created.
- G0 requires explicit human confirmation.
- G0 does not grant client or publication authority.

The project-creation mechanics passed. The complete case failed because the
designed journey incorrectly assumed that project creation also satisfied exact
brief approval. MoonCast correctly refused G0. A future rerun must visibly
approve the exact brief revision before recording G0; it must not bypass that
step or weaken the gate.

## MC-UI-002: Cut Editor early-import denial

Result: `PASS`

Evidence:
`/Users/kq/Workspace/mooncast/_build/ui-to-ui/2026-07-31-governed-project`

1. Open `http://127.0.0.1:4312/editor`.
2. Under **G4 production project**, enter `uiq-episode-001`.
3. Click **Import / open G4**.
4. Confirm the editor says:
   **Production import rejected. Error canonical G4 approval is required before
   editor import**.
5. Return to Studio and confirm the project gate rail is unchanged.

The exact project ID was submitted through the visible G4 field and button.
The canonical approval denial was visible, and the browser recorded zero
console warnings or errors. Creating an editor fixture through a direct API
would bypass the user journey and does not count.

## MC-UI-003: complete cut, render and acceptance

Result: `BLOCKED`

A commercial MoonCast pass requires rights-cleared source assets or a
provider-produced project that has legitimately reached G4. Once that
prerequisite exists, perform the complete user journey:

1. Open the exact G4 project in **Mooncast Cut Editor**.
2. Select takes and place them on the visible timeline.
3. Use trim, split, ripple, transitions, clip effects and audio controls.
4. Add subtitles and at least one frame-accurate review comment.
5. Use source/program preview and confirm any WebGL/Canvas fallback label.
6. Create the exact preview; wait for the visible job receipt and play the
   resulting media.
7. Export the complete 180–480 second master.
8. Promote it only with the named editor authority.
9. Complete technical, creative and rights review.
10. Create a one-time client URL in Studio.
11. In the client page, add an annotation and approve or request revision for
    the exact build.
12. Download the accepted delivery package and inspect provenance, subtitles,
    labels and rights records.

Do not promote this case until the output is a real complete episode, not the
procedural fixture or the project-free utility concatenator.

## MCH-UI-001: MoonChat through a visible consumer

Result: `BLOCKED`

MoonChat correctly has no standalone chat application. The required consumer
journey is:

```text
MoonFind or MoonDesk visibly selects a source artifact
→ constructs moonchat/conversation-review-bundle@1.0.0
→ invokes moonchat/conversation.review.record@0.1.0
→ shows the immutable review record and pending/accepted status
→ MoonBook separately decides whether to import it
```

### Required visible actions

1. Select a versioned source artifact in MoonFind or MoonDesk.
2. Open **Conversation review**.
3. Enter named reviewers, questions, objections and explicit decision scope.
4. Click the visible submit control.
5. Inspect operation ID, source digest, event receipt and claim ceiling.
6. Reload and confirm the append-only record remains.
7. Open MoonBook and make a separate closure/import decision.

Current code publishes the MoonChat operation in MoonFind's desired robotics
graph, but there is no complete visible consumer invocation. A graph node or a
library test is not consumer proof.

## MCL-UI-001: durable Cowork conversation

Result: `FAIL`

Evidence:
`/Users/kq/Workspace/moonclaw/_build/ui-to-ui/2026-07-31-cowork`

### Launch

```sh
cd /Users/kq/Workspace/moonclaw
moon run --release cmd/main -- \
  gateway start \
  --home /tmp/moonsuite-ui-qualification-am/moonclaw \
  --cwd /tmp/moonsuite-ui-qualification-am/moonclaw/workspace \
  --port 4317
```

Open `http://127.0.0.1:4317/ui#/cowork`.

### Intended visible actions

1. Click **New Chat**.
2. Confirm a new sidebar session is selected.
3. Confirm the visible notice is **Conversation created.**
4. Record the session identity.
5. Reload the page.
6. Confirm the same session is listed and can be reopened.
7. Use **Search conversations** to find it.

### Acceptance assertions

- Session creation crosses the gateway and writes durable MoonClaw state.
- Reload proves the session is not only browser state.
- No model turn is sent in this case.
- A successful session is execution state, not accepted knowledge.

Do not press **Send** unless the qualification explicitly supplies an approved
MoonGate provider route and data-use policy. The local no-credential run is
designed to prove session/runtime behavior without an external model effect.

### Executed result

The Cowork UI was served on port 4317, but its visible runtime target remained
hardcoded to `http://127.0.0.1:18123`. Clicking **New Chat** returned the
visible unable-to-reach-gateway failure, so no session was created and the
reload assertions could not begin. No model call was made, and the browser
recorded zero console warnings or errors. The UI must derive or receive its
gateway origin before this case can pass on an isolated port.

## ME-UI-001: MoonEdit text/code consumer proof

Result: `BLOCKED`

MoonEdit is a library and should be proved through MoonDesk:

1. Use a visible picker to open a text/code file in an isolated book.
2. Type a multi-line edit.
3. Click **Undo** and confirm the exact prior revision.
4. Click **Redo** and confirm the edit returns.
5. Save.
6. Close and reopen the file through visible controls.
7. Confirm the saved text and revision identity.

MoonDesk currently has no `vectie/moonedit` dependency or MoonEdit package
import. Its existing code editing cannot therefore be claimed as MoonEdit
consumer proof.

## ME-UI-002: three-way conflict and named resolution

Result: `BLOCKED`

The required host journey is:

1. Open revision A through MoonDesk.
2. Make local revision B.
3. Cause a separately versioned remote revision C in the isolated fixture.
4. Attempt save/reload through the UI.
5. Confirm MoonEdit reports the exact base/local/remote identities and
   overlapping conflict ranges.
6. Choose local, remote, or a reviewed merged proposal through visible
   controls.
7. Require named-human acceptance before applying an agent proposal.
8. Reopen and verify the selected result and conflict receipt.

MoonEdit already owns the deterministic merge contract. The missing work is the
MoonDesk adapter and conflict-resolution UI, not another editor core.

## MFI-UI-001: MoonFind fail-closed capability preparation

Result: `PASS`

Evidence:
`/Users/kq/Workspace/moonfind/_build/ui-to-ui/2026-07-31-fail-closed`

### Launch

```sh
cd /Users/kq/Workspace/moonfind/ui/rabbita-moonfind
npm run dev -- --host 127.0.0.1 --port 4313 --strictPort
```

Open `http://127.0.0.1:4313/`.

### Visible actions

1. Inspect **Research execution**.
2. Confirm the page says it is waiting for host-published capability and
   MoonClaw ports.
3. Click **Capability preparation unavailable**.
4. Confirm the visible error is
   **No prepared MoonFind capability execution was published by the host.**
5. Confirm no MoonClaw session, provider call, or accepted research result is
   fabricated.

This is a negative pass candidate only. Do not use stale session keys in the
checked-in static projection as live evidence.

The visible unavailable button returned the exact error above. It created no
provider call, MoonClaw session or acceptance record, and the browser recorded
zero console warnings or errors. The surrounding checked-in projection still
contains stale DeepSeek and user-path data; that projection is not evidence of
a current execution.

## MFI-UI-002: complete governed research loop

Result: `BLOCKED`

The positive journey requires a host to publish the prepared execution and
generic URLs from MoonFind's durable state:

1. Select permitted papers or an isolated full-text packet through visible
   controls.
2. Confirm provider-use, PDF-isolation, digest and page/section evidence.
3. Click **Submit installed capability**.
4. Observe the exact operation, attempt and request identity.
5. Reconcile the same attempt if state is pending or unknown.
6. Click **Run exact MoonClaw command** only after command-ready.
7. Observe the persisted Cowork session and run.
8. Complete named-human review with an explicit claim subset or change request.
9. Inspect the MoonTown challenge/synthesis receipt.
10. Open MoonBook and close the outcome through Bookkeeper.
11. If a learning proposal exists, route it to MoonFlow canary/shadow and keep
    promotion separately reviewed.

The current Rabbita page has no `capability_submit_url`,
`capability_reconcile_url`, or `capability_checkpoint_url`. Those missing host
ports are the first blocker. Consequently the positive loop and the typed
MoonFind-to-MoonTown synthesis handoff remain `BLOCKED`; MFI-UI-001 proves only
the fail-closed negative path.

## MFS-UI-001: verified fixture through MoonClaw

Result: `PASS`

Evidence:
`/Users/kq/Workspace/moonfish/_build/ui-to-ui/2026-07-31-fixture`

### Install and launch

```sh
cd /Users/kq/Workspace/moonbook
moon run --release cmd/main -- \
  pack install \
  /Users/kq/Workspace/moonfish/moonpack \
  /tmp/moonsuite-ui-qualification-am/moonfish \
  /Users/kq/Workspace/moonfish/testdata/moonfish-host-profile.json

cd /Users/kq/Workspace/moonfish
MOONFISH_BOOK_ROOT=/tmp/moonsuite-ui-qualification-am/moonfish/book \
MOONFISH_PACK_ROOT=/Users/kq/Workspace/moonfish/moonpack \
MOONCLAW_PACK_RUNNER=/Users/kq/Workspace/moonclaw/_build/native/release/build/vectie/moonclaw/cmd/pack_workflow_runner/pack_workflow_runner.exe \
moon run --target native --release cmd/moonfish_service -- \
  --workspace-root /tmp/moonsuite-ui-qualification-am/moonfish \
  --port 4318
```

The install profile grants the pack's declared ceiling, including an external
tool declaration, but the runtime invocation policy used here grants only
`SandboxExecution`.

Open `http://127.0.0.1:4318/apps/moonfish/daily`.

### Visible actions

1. Confirm **Native runtime ready**.
2. Leave **Verified fixture** and the fixed fixture session selected.
3. Set **Named reviewer** to `UI Qualifier`.
4. Click **Submit to MoonClaw**.
5. Confirm the status includes the run ID and says MoonClaw executed the job
   and MoonBook recorded the result.
6. Confirm **Durable workflow runs** adds the exact run.
7. Reload and confirm the run remains.
8. Confirm policy is partial/not followed and the fixture is not investment
   ready.

### Acceptance assertions

- The visible button reaches the installed pack through MoonClaw.
- MoonBook retains separate request and result records.
- No broker/order/external-delivery action exists.
- The fixture never becomes a released recommendation merely because the job
  succeeded.

Visible submission created run `moonfish-5e6813247924aefe491e56e0`.
MoonClaw executed it, MoonBook recorded it, and reload retained the durable
run. Policy remained visibly partial. The browser recorded zero console
warnings or errors.

## MFS-UI-002: complete recommendation review

Result: `BLOCKED`

Evidence of the current boundary:
`/Users/kq/Workspace/moonfish/_build/ui-to-ui/2026-07-31-fixture`

The intended MoonFish deliverable is not merely a ticker. The visible record
must contain:

- security and exchange;
- evidence cutoff and next valid exchange session;
- observation and entry range;
- deterministic goal price;
- gross and after-cost expected increase rate;
- planned sale window and the installed 40–65-session horizon;
- invalidation, staged/full/forced exits and expiry;
- factor score, catalyst, bear case and contradictory evidence;
- liquidity/accessibility risk;
- exact policy ID, version and digest;
- named-human release decision.

### Required visible journey

1. Start the daily run.
2. Inspect the hard-filter rejection funnel.
3. Compare ranked candidates and factor contributions.
4. Open the full dossier and independent bear review.
5. Approve, reject or abstain as a named reviewer.
6. Create the paper-only recommendation plan.
7. Inspect all fields above.
8. Add it to the paper account only after review.
9. Reload and later record outcome/Three-Gap evidence.

The current Daily Research Desk can render an existing operator release record,
but exposes no visible control to create one from the completed run. Calling
`operator.daily-record.prepare` directly would bypass the UI. Therefore the
headline recommendation journey is currently blocked after run creation. The
empty state **No named release has been recorded. Moonfish will not fabricate
a stock.** and the absence of a paper account are honest, but they are not the
completed product outcome.

## MFL-UI-001: 63-stage MoonFlow canvas

Result: `NOT-RUN`

MoonFlow intentionally has no domain application. Use MoonDesk's Flow
projection with a selected MoonBook that contains MoonFind's exact robotics
graph and evaluated catalog.

### Visible actions

1. Open the selected MoonBook in MoonDesk.
2. Select **Flow**.
3. Confirm the **Composition canvas** renders exactly 63 nodes.
4. Open **Products** and confirm the selected/total node count and participating
   products.
5. Click **Fit** and confirm every node is visible.
6. Click `+` and `−`; confirm the visible zoom readout changes.
7. Drag empty canvas space to pan.
8. Drag a node by its `⠿` handle and confirm its position changes.
9. Attempt to exclude a dependency that still has selected dependents and
   confirm the control is disabled.
10. Exclude and re-include a valid leaf; confirm the visible state changes.
11. Click **Save composition**.
12. Reload and confirm the saved selection and node placement survive.

### Acceptance assertions

- The canvas is operated through real pointer and button events.
- Every node shows exact operation, input/output contracts, authority, claim,
  adapter and health evidence.
- The graph is not described as executable if the catalog is unavailable,
  stale or invalid.
- A source count or `render_to_string` test does not count.

### Executed result

The 2026-07-31 run visibly rendered 63 nodes for 11 product IDs, exercised
Fit, zoom `6% → 8% → 7%`, background pan, node drag, and **Save composition**,
and produced no browser console warnings/errors. After a host restart, the
book, graph, and run returned, but `understand-needs` reset from its moved
coordinates `184px,142px` to `64px,72px`.

The case is `FAIL` because its required node-placement persistence assertion
failed. Leaf exclusion/re-inclusion remains a designed follow-up and is not
claimed as executed.

## MFL-UI-002: import, restart and recovery

Result: `BLOCKED`

1. With a complete unexpired catalog, click **Start governed run**.
2. Confirm MoonDesk delegates exact graph validation and import to MoonFlow.
3. Confirm the first dependency-ready item is visible.
4. Execute only a published authority-bound action.
5. Stop and restart the MoonFlow host after a durable checkpoint.
6. Reload MoonDesk.
7. Confirm the same run, attempt identity, evidence and next action return.
8. For unknown effects, click reconcile rather than retry.
9. Confirm no non-idempotent effect is duplicated.

### Executed result

The visible **Start governed run** action created durable run sequence 64 with
63 total items and `understand-needs-v3` as the one initial runnable item.
Stopping and restarting the host restored the same run and runnable
projection. The run then displayed **NOT PUBLISHED** / **UNAVAILABLE** because
MoonFlow had not published authority-bound operator handoffs.

This case remains `BLOCKED`: restart recovery is proven, but no runnable work
could be dispatched or reconciled through a visible generic action. The
fixture catalog also remains explicitly non-production evidence.

Evidence:

```text
/Users/kq/Workspace/moondesk/_build/ui-to-ui/2026-07-31-63-stage
```

## MG-UI-001: MoonGate refresh and endpoint copy

Result: `PASS`

Evidence:
`/Users/kq/Workspace/moongate/_build/ui-to-ui/2026-07-31`

### Launch

```sh
cd /Users/kq/Workspace/moongate
MOONSUITE_WORKSPACE_ROOT=/tmp/moonsuite-ui-qualification-am/moongate \
moon run cmd/main -- \
  start \
  --host 127.0.0.1 \
  --port 4314
```

Open `http://127.0.0.1:4314/ui/rabbita`.

### Visible actions

1. Click **Refresh**.
2. Confirm the visible updated time changes and the dashboard remains
   connected.
3. Select **Manual Connect**.
4. Under **OpenAI Chat**, click **Copy**.
5. Confirm `Copied /v1/chat/completions` and the toast.
6. Select **Suite** and inspect observed product/integration state.

This case configures no provider and sends no model request.

The visible refresh completed, **Manual Connect** exposed **OpenAI Chat**, and
clicking **Copy** returned **Copied /v1/chat/completions**. The browser recorded
zero console warnings or errors.

## MG-UI-002: honest no-provider state

Result: `PASS`

Evidence:
`/Users/kq/Workspace/moongate/_build/ui-to-ui/2026-07-31`

1. Select **Connection Graph**.
2. Confirm an unconfigured app lane says **No provider saved** or
   **Waiting for a provider**.
3. Select **Providers**.
4. Confirm no provider credential is fabricated.
5. Do not save, test or bind a provider.
6. Return to **Overview** and confirm provider-dependent readiness remains
   visibly conditional.

The pass condition is an honest blocked connection graph. A built-in compatible
route is not the same as a configured, tested upstream provider.

The visible Connection Graph showed **No provider saved** and
**Waiting for a provider**. No provider state was mutated and no model call was
made. The browser recorded zero console warnings or errors.

## ML-UI-001: MoonLeaf DOCX consumer proof

Result: `BLOCKED`

The required MoonDesk consumer journey is:

1. Open a rights-safe DOCX through a visible file picker.
2. Inspect MoonLeaf's supported-subset and security diagnostics.
3. Change one exact paragraph run.
4. Choose **Save as Copy**.
5. Close and reopen the copy through visible controls.
6. Confirm the edited text and preserved unsupported package parts.
7. Confirm macros, signatures, encryption and unsupported layout are not
   claimed as preserved.

MoonDesk currently implements its own OOXML parsing/editing under
`internal/moonwiki/office_documents.mbt`; it does not import
`vectie/moonleaf`. That UI may qualify MoonDesk, but cannot qualify MoonLeaf.
Replace the duplicate implementation with a host adapter to MoonLeaf before
promoting this case.

## ML-UI-002: MoonLeaf XLSX and PPTX consumer proof

Result: `BLOCKED`

After the same ownership fix:

1. Open a safe XLSX, change one supported cell, save as copy and reopen it.
2. Confirm sheet identity, supported style and the existing formula remain.
3. Open a safe PPTX, change one supported text object and basic geometry.
4. Save as copy and reopen it.
5. Confirm slide order and unrelated package members remain.
6. Preserve visible diagnostics for unsupported charts, animations,
   recalculation and external relationships.

These are two format cases, not proof of full Microsoft Office fidelity.

## MLB-UI-001: MoonLib consumer proof

Result: `NOT-RUN`

MoonLib has no service or UI. A qualifying consumer path must expose which
MoonLib contract is being exercised.

### Canonical layout case

1. Start MoonDesk with an isolated suite root.
2. Create or import a MoonBook through visible controls.
3. Inspect the visible suite/book location.
4. Select the book, reload MoonDesk and confirm the same canonical identity is
   restored.
5. Create a harmless note, then inspect its visible path.
6. Confirm state remains below the selected suite/book root and no sibling
   checkout path leaks into product state.

### Conversation-contract case

1. Create a MoonClaw Cowork session from its visible UI.
2. Open the same session projection in MoonDesk.
3. Inspect the shared conversation/session identity.
4. Reload both consumers and confirm the identity remains stable.

The run record must name the consumed MoonLib package and contract version.
Merely noting that both pages rendered does not establish MoonLib conformance.

## MM-UI-001: execute and reconcile a spatial request

Result: `FAIL`

Evidence:
`/Users/kq/Workspace/moonmold/_build/ui-to-ui/2026-07-31`

### Launch

```sh
cd /Users/kq/Workspace/moonmold
npm run operator -- \
  --workspace /tmp/moonsuite-ui-qualification-am/moonmold \
  --port 4315
```

Open `http://127.0.0.1:4315/`.

### Intended visible actions

1. Confirm backend preference is `mock-reference`.
2. Confirm the banner says
   **NO FABRICATION · NO PHYSICAL AUTHORITY**.
3. Click **Execute reference path**.
4. Confirm
   **Terminal receipt is durable. Named review remains separate.**
5. Inspect backend qualification, latest receipt and representation lineage.
6. Click **Reconcile same attempt**.
7. Confirm reconciliation completes without replaying a new attempt.

### Acceptance assertions

- The visible request uses the fixed MoonBit adapter path.
- Browser input cannot select a script, shell, URL or physical target.
- Mock output remains labelled mock-reference.
- Reconciliation retains the original attempt identity.

### Executed result

The visible backend remained `mock-reference` and physical authority remained
false. Clicking **Execute reference path** ended with
`JsonDecodeError((, Missing field reviews)`. **Latest operation receipt**
remained **Not available**, so reconciliation could not establish the intended
receipt identity. The browser recorded zero console warnings or errors. This
is a product-contract failure between the returned mock-reference object and
the operator decoder, not a Blender or physical-execution failure.

## MM-UI-002: exact named review and physical denial

Result: `BLOCKED`

Evidence:
`/Users/kq/Workspace/moonmold/_build/ui-to-ui/2026-07-31`

Continue from MM-UI-001:

1. Enter reviewer `UI Qualifier`.
2. Leave decision `approve`.
3. Enter notes
   `Mock-reference digital artifact accepted for UI qualification`.
4. Click **Record named review**.
5. Confirm **1 durable review receipt(s)** and inspect the exact receipt
   binding.
6. Reload.
7. Confirm the review remains and the physical-authority banner is unchanged.

Approval accepts only the exact digital mock artifact. It does not upgrade the
backend to Blender, certify engineering geometry, authorize manufacturing, or
grant a physical effect.

Named review was not attempted because MM-UI-001 produced no exact operation
receipt to bind. The `mock-reference` label and false physical-authority state
remained visible. The correct next step is to repair receipt decoding and
rerun execution; fabricating or manually injecting a receipt would invalidate
the authority proof.

## A-M interaction ownership

| Producer | Consumer | What may cross | What must not cross |
| --- | --- | --- | --- |
| Bunnia | WeChat mini-app products | Generated UI tree, events, patches, assets and diagnostics | Moontown or product-domain policy in framework core |
| Lepusa | MoonGate/MoonDesk | Packaged assets, scoped bridge routes and supervised localhost service | Product policy or unrestricted native bridge access |
| MoonFind | MoonTown/MoonClaw/MoonBook | Evidence packet, exact research command, synthesis handoff and review proposal | Direct provider call or self-approved capability |
| MoonChat | MoonFind/MoonBook | Versioned review bundle and append-only review record | Live agent runtime or automatic knowledge acceptance |
| MoonFish | MoonFlow/MoonClaw/MoonBook | Deterministic research request, bounded text tasks, review evidence and outcomes | Score/target changes by an LLM, broker order or profit promise |
| MoonCast | MoonFlow/MoonClaw/MoonGate/MoonBook | Typed stage work, provider plan, immutable assets, delivery and outcome evidence | Second runtime, provider credentials, client/publication self-approval |
| MoonFlow | MoonDesk | Read-only run/composition projection and opaque published action IDs | Domain policy or client-supplied authority/path |
| MoonGate | MoonClaw and product hosts | Provider/capability health, usage and authority policy | Human acceptance or domain result truth |
| MoonEdit | MoonDesk | Revisioned editor state, effects and conflict receipts | Filesystem permission or host UI ownership |
| MoonLeaf | MoonDesk | Neutral document scenes, diagnostics and verified copy | Office-wide fidelity claim or host file authority |
| MoonLib | all consumers | Policy-free paths, identifiers and versioned DTOs | Daemon behavior or domain semantics |
| MoonMold | MoonFlow/MoonDesk | Typed spatial request, artifacts, lineage, validation and digital review | Script execution, fabrication or robot authority |
| MoonBook | MoonDesk/MoonFlow | Accepted truth, Bookkeeper Three-Gap records and reviewed proposals | Model runtime, workflow execution or automatic promotion |
| MoonClaw | MoonFlow/product adapters | Agent run, tool attempt, artifact and runtime receipt | Domain acceptance or workflow ownership |

## What is lagging behind

The visible gaps cluster around product handoffs:

1. **MoonFind is a rich static research workspace without its production
   host.** The browser has the correct fail-closed code, but the suite does not
   publish the prepared capability and checkpoint ports needed for a positive
   run.
2. **MoonFish stops one screen too early.** It can submit an installed fixture
   and can render a full target/upside/sale-window record, but cannot visibly
   turn the run into that reviewable record. The missing funnel/dossier/release
   interaction is a major feature gap, not test hardening.
3. **MoonCast's system breadth exceeds its populated-production proof.** The
   project graph, gates and cut editor exist, and the visible G0/G4 denials are
   correctly strict. The operator path must expose exact brief approval before
   G0, then carry one rights-cleared 3–8 minute project through actual timeline
   editing, render, client review and delivery.
4. **MoonChat is architecturally correct but operationally invisible.** Its
   contract exists, yet no consumer presents a complete review invocation and
   receipt.
5. **MoonEdit and MoonLeaf are not consumed by MoonDesk.** MoonDesk duplicates
   editor/document behavior, so its UI cannot qualify the libraries. This is
   both integration debt and an ownership-risk signal.
6. **MoonFlow's 63-stage canvas is not the run.** Node rendering, Fit, pan,
   zoom and drag are important product behavior, but execution proof begins
   only with an unexpired catalog, conformant import, durable attempt and
   restart recovery.
7. **Framework release proof is still manual.** Bunnia needs a repeatable
   WeChat DevTools lane; Lepusa needs a packaged native-window lane. Browser
   equivalence is useful but not sufficient.
8. **MoonLib needs attributable UI evidence.** It is widely imported, but the
   run record must name the exact shared contract being proved.
9. **MoonClaw's Cowork origin is not portable.** The UI served from port 4317
   still targeted port 18123, preventing the first durable session action.
   Gateway origin must be injected or derived from the serving origin.
10. **MoonMold's operator and mock-reference receipt disagree.** The returned
    object lacks the decoder's required `reviews` field, so execution cannot
    produce the exact receipt needed by reconcile or named review.

## How to execute and record these cases

### 1. Pick one case and freeze the source

```sh
git -C /Users/kq/Workspace/<product> rev-parse HEAD
```

If the commit differs from this report, record the new value. Do not claim a
result for untested later code.

### 2. Create evidence storage

```sh
RUN_ID="2026-07-31-<case-id>"
RUN_ROOT="/Users/kq/Workspace/<product>/_build/ui-to-ui/$RUN_ID"
mkdir -p "$RUN_ROOT/screenshots" "$RUN_ROOT/receipts"
```

Use `/tmp` for mutable suite, book, provider, media and application state.
Keep only the qualification evidence under ignored `_build/ui-to-ui`.

### 3. Start with isolated state and a unique port

- Never point a test at a customer's real book, market bundle, media project,
  provider configuration or robot.
- Keep provider credentials absent unless the case explicitly authorizes a
  live-provider acceptance run.
- Leave broker, publication, payment, Blender and physical bridges absent.
- Record the exact launch command and service log.

### 4. Capture the visible journey

Save:

```text
screenshots/01-start.png
screenshots/02-action.png
screenshots/03-result.png
```

For a drag, timeline edit, mini-app interaction or native window, add the
intermediate screenshots needed to make the state change unambiguous.

### 5. Do not bypass the UI

Do not:

- call the final API instead of clicking its visible control;
- inject model state or a network response;
- preseed a completed result after page load;
- call a Rabbita update function directly;
- infer a result from a source string or source count; or
- describe a health probe as the user journey.

A fixture may prepare inputs before launch. The user must still choose, submit,
approve, reject, edit, import or reconcile through the shipped surface.

### 6. Check durability and authority

- Reload every result that claims persistence.
- Restart the owning service when the case claims recovery.
- Confirm a named review is separate from generation or execution.
- Confirm denied actions show a reason and next step.
- Confirm no fixture upgrades its own authority or claim ceiling.

### 7. Retain diagnostics

Save browser console messages and failed requests:

```text
browser-console.json
failed-requests.json
```

An intentionally absent provider or bridge may produce a known failed request.
Record and explain it; do not omit it.

### 8. Write `run.json`

Minimum example:

```json
{
  "product": "moonfish",
  "commit": "5566146146dba32e2ebbbca55b8ca7d64f4fd43a",
  "case_id": "MFS-UI-001",
  "url": "http://127.0.0.1:4318/apps/moonfish/daily",
  "isolated_root": "/tmp/moonsuite-ui-qualification-am/moonfish",
  "actions": [
    "set named reviewer to UI Qualifier",
    "submit verified fixture to MoonClaw",
    "reload the page"
  ],
  "assertions": [
    "run id became visible",
    "durable run survived reload",
    "fixture remained not investment ready",
    "no named recommendation was fabricated"
  ],
  "result": "PASS",
  "external_effects": "none"
}
```

Use `FAIL` when the controls were operable but a required assertion failed.
Use `BLOCKED` only when a named prerequisite prevented the first meaningful
action. Never convert an empty or partial result into a pass.

### 9. Stop services

After every shared browser worker finishes, stop the launch processes with
`Control-C`, confirm their ports no longer listen, and retain only the evidence
needed for the report.
