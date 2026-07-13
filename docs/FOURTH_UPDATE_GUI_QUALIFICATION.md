# Fourth Update GUI Qualification

**Track:** A — pure-user UI-to-UI qualification  
**Started:** 2026-07-13  
**Baseline:** `334a361d47d67f372b9adc50f7aa3c4874c1c2ab`  
**Evidence root:** `~/moonsuite/qualification/embodied-workspace/gui`

## Question

Can a person complete the Moon Suite lunar-robot journey from visible product
surfaces, with keyboard and pointer input, without a terminal, direct HTTP,
database edits, hidden state injection, or fabricated receipts?

The answer at the start of this track is **not yet**. MoonDesk already supports
a high-quality visible create, browse, edit, and review loop, but the complete
cross-product mission cannot yet be initiated and completed from user mode.
This report separates proven visible behavior from code-level or API evidence.

## Acceptance boundary

During a user journey, accepted actions are native application launch, visible
buttons and disclosures, pointer targeting, keyboard input, documented
shortcuts, visible file pickers, and user-facing approvals. Terminal commands,
HTTP inspection, and source/state inspection are permitted only after the
visible journey stops, for diagnosis. A diagnosed fix must be rerun from the
visible surface before it is accepted.

The first observed run used the native Lepusa MoonDesk window and macOS
accessibility-based pointer/keyboard control. It did not use DOM injection or
private product APIs. A later headless render was used only as a non-acceptance
visual regression check while macOS was locked.

## Baseline result

The observed user successfully:

1. opened MoonDesk in a fresh qualification workspace;
2. retried an initially stalled workspace connection with the visible Refresh
   action;
3. created `GUI Journey Robot` through the Add MoonBook disclosure;
4. opened its starter page in Wiki;
5. edited and saved mission intent and constitutional success criteria;
6. opened Code, entered a concrete helper request, and created a durable
   MoonCode session;
7. opened Flow and inspected its empty state.

The visible journey then stopped honestly:

- MoonCode showed only `Needs attention` even though durable data contained the
  actionable reason `MoonClaw daemon is not running`.
- The fresh workspace had no user-facing MoonClaw installation/configuration
  flow, so the coding request could not run from pure user mode.
- Flow could inspect existing runs but offered no visible compile/import action
  to create the first run.
- MoonGate model/data-boundary setup, MoonTown deliberation, MoonRobo build,
  and MoonMoon simulation had no complete visible path from this MoonDesk
  surface.

Therefore no claim is made that the full lunar-robot workflow passes pure-user
qualification.

## Improvements implemented

### Native startup recovery

In the native observed run, the shell remained at `No workspace` even while
the local host and workspace APIs were healthy; clicking Refresh recovered
immediately. The root cause was ordering: bootstrap code awaited the mounted
MoonBit application, whose event loop intentionally does not return, so the
native recovery installer below that import was unreachable. MoonDesk now
installs the ordinary Refresh activation and global shortcuts before importing
the application. While a workspace is loading, Desk also says
`Connecting to your MoonBooks…` and names Refresh as the visible recovery
action. No raw port, path, or service name appears in this user message.

### Visible MoonGate and MoonClaw recovery

Desk now gives MoonGate a user-facing authority summary: whether workspace AI
is ready, what it does and does not authorize, and the next setup action. When
an installed MoonClaw service is configured but stopped, the user can enable it
without editing a path or `service.json`. Code shows the same state beside the
saved request and offers Start and retry. The localhost API exposes only
bounded start/retry actions and reuses the existing daemon lifecycle logic.
The final pointer replay exposed a layout defect rather than an event defect:
MoonCode still declared two grid rows after the setup banner became a third
child, so the chat surface overlaid the visible recovery button. Keyboard/AX
focus could reach it while pointer hit-testing landed on chat. The runtime setup
state now declares an explicit third grid row. Coordinate-based CDP verified
that `elementFromPoint` resolves to the button; the in-app browser pointer gate
then passed Code → Open MoonGate setup → Desk with MoonGate visible.

### First executable work and suite handoffs

Flow's empty state now acts on the selected MoonBook. Prepare selected MoonBook
locates its ordinary `flow/draft-work-graph.json` or `flow/work-graph.json` and
hands it to the explicitly enabled MoonFlow service. Missing declaration and
missing service remain visible, typed outcomes rather than fabricated runs.
Every Flow state also carries stable selected-book/run cards for MoonTown,
MoonRobo, MoonMoon, and MoonMold. MoonTown can open with context now; adapters
that have not landed say `Adapter pending` or `Installed · handoff pending` and
do not imply authority.

### Explainable MoonCode failure

MoonCode now decodes the existing optional `last_message` and
`mooncode_runtime_detail` fields. A failed, queued, or running session gets a
compact live status card. Failed work says that the request was saved but no
coding work ran. A closed `Why?` disclosure reveals the runtime reason and the
next user action. A second closed `Technical evidence` disclosure preserves the
session/runtime identity and evidence counts for developer diagnosis.

The transcript empty state now agrees with failure state instead of asking the
user to “start” a prompt that was already saved.

### Quiet Flow by default

Flow keeps outcome, next actions, blockers, readiness, and high-level metrics
in the default user scan path. Authority/budget/intervention controls are under
`Operator controls`; protocol identifiers, source identity, runtime receipts,
and item-level evidence are under `Technical evidence`. The evidence remains
present and keyboard reachable but no longer competes with the next action.

### Keyboard access

Native macOS focus traversal skipped several visually obvious buttons under
the machine's current keyboard-navigation setting. MoonDesk now provides and
announces stable global shortcuts:

- `Command/Ctrl+1`: Desk
- `Command/Ctrl+2`: Wiki
- `Command/Ctrl+3`: Code
- `Command/Ctrl+4`: Flow
- `Command/Ctrl+K`: Commands

Plain typing and shifted accelerator combinations are not intercepted.

## Disclosure policy and persistence proposal

This branch does not create a competing suite-wide disclosure contract. It
uses local nested disclosures that map cleanly to the shared levels being
defined by MoonLib:

- **User:** result, next action, blocker, important decision, stop/retry.
- **Operator:** authority, budget, recovery, control, rejected evidence.
- **Developer:** raw identity, protocol, event/evidence counts, source digest.

The future shared preference should be stored as a user/workspace presentation
preference, never in MoonBook truth and never in a run authority envelope. It
should default to User, persist across restart for that MoonDesk profile, and
temporarily elevate for a specific disclosure without changing the global
preference. Deep links may request a lower layer but must not silently grant
authority or reveal secrets. Redaction policy applies equally at every layer.

## General quality policy

These changes are state-driven and product-generic. They do not match robot
phrasing, a fixture ID, a screenshot, or a model response. A weak result does
not advance: change user-visible input or fix the product, rerun from the
nearest honest checkpoint, compare results, and record why the improvement
generalizes. Runtime wording tests assert semantic state, not pixel-perfect
model prose.

## Remaining integration dependencies

Track A cannot pass its complete journey until shared product work supplies:

1. visible MoonGate model/data-boundary setup and current-authority summary;
2. a user-facing installed-product/service setup path that can connect or start
   MoonClaw without editing `service.json`;
3. a visible declaration compile/import path that creates the first MoonFlow
   run;
4. MoonTown proposal/deliberation and promotion navigation attached to the
   selected MoonBook and run;
5. MoonRobo build/validation and MoonMoon simulation entry points with shared
   identity and evidence;
6. Track C's durable browser evidence, takeover, recovery, and replay layer;
   its visible isolated Preview/Run and scoped MoonCode handoff now pass;
7. MoonMold surfaces once Track B's contracts and first building path land.

The pure-user qualification must be rerun after those integrations. Unit tests,
headless DOM checks, API responses, or an accepted unattended backend run do
not substitute for that visible run.

## Verification

Current implementation checks:

```text
cd ui/rabbita-desk
moon fmt
moon info
moon check --target js --warn-list +unnecessary_annotation
moon test --target js
```

The JS suite passes 520/520 with no warnings. Native tests pass 536/536 with one
pre-existing deprecated assertion warning. The production build, native bundle
check, endpoint smokes, and the coordinate-based empty Desk browser smoke pass.
Rendered native and in-app browser pointer replays both prove Code → Open
MoonGate setup → Desk. Native automatic book loading remains a hardening gate,
with visible Refresh still an honest recovery. Track C's visible C1/C2 fixture
passes, while C3/C4 durable host evidence and replay remain separate gates.
