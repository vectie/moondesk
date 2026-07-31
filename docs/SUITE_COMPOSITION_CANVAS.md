# MoonSuite composition canvas

MoonFind owns discovery and desired-capability graph intent. MoonDesk owns the
human desktop presentation: it renders the graph as a scrollable, zoomable
canvas, lets the operator inspect exact contracts, and records an explicit
selection. MoonFlow owns validation, scheduling, execution, reconciliation, and
recovery. No domain or orchestration policy belongs in MoonDesk.

## Accepted inputs

Only `flow/work-graph.json` with contract `moonsuite.work-model.v1` is an
executable source. MoonFind may also preserve
`moonfind.desired-capability-graph.v2` as `flow/desired-graph.json` for human
review, but MoonDesk never submits that intent artifact as if it were a
MoonFlow Work model.

Every executable node must resolve exactly against a
`moonflow.capability-catalog.v1`. MoonDesk resolves the explicit
`MOONFLOW_CAPABILITY_CATALOG` override first and otherwise uses the selected
book's `flow/capability-catalog.json`; repository inventory and friendly
product names are insufficient.

The canvas presents, rather than guesses:

- graph-local declaration ID and canonical operation reference;
- exact input and output schema references;
- requested authority, required claim, acceptance criteria, primary artifacts,
  and timeout;
- adapter claim ceiling, catalog/adapter identity, and validation status;
- review requirement and health evidence timestamps, reference, and digest;
- dependencies and typed primary request evidence.

Missing, expired, incompatible, or unpublished evidence is visibly
unavailable. A node cannot become executable because a similarly named product
is installed.

## Selection and execution

The operator can include or exclude declared nodes before a run. MoonDesk
persists only `flow/composition.json`, a generic selection overlay bound to the
source graph identity. Dependency closure is mandatory. On preparation,
MoonDesk compiles a content-digested selection with a distinct graph identity,
rebases permitted graph-relative artifacts safely to suite-root references, and
delegates catalog-backed validation and conformant import to MoonFlow using one
server-UTC evaluation timestamp. The selected/rebased graph receives a
deterministic compiled graph ID, declaration revision, and digest. Validation
and import consume one digest-pinned catalog snapshot rather than re-reading a
possibly changing catalog between commands.

```text
MoonFind desired graph + typed requests
  → executable moonsuite.work-model.v1
  → MoonDesk inspection + explicit node selection
  → dependency-closed, digest-bound composition
  → MoonFlow validate-work-graph-capabilities
  → MoonFlow import-conformant-graph
  → product adapters / sole MoonClaw runtime
  → evidence + named review
  → MoonBook Bookkeeper outcome
```

The source graph and earlier MoonFlow runs remain immutable. MoonDesk presents
run controls and receipts; pause, resume, cancel, and authority changes delegate
to MoonFlow's `control` command. MoonDesk does not write or rank MoonFlow
control state. Import evidence is retained at:

```text
.moonsuite/products/moondesk/moonflow-imports/<catalog-and-graph-digest>/
  capability-catalog.json
  validation-report.json
  import-receipt.json
```

Run autonomy, intervention-scorecard, and control projections are optional.
Missing persisted evidence appears as unavailable and does not enable controls.
Publication, trading, physical commands, and policy activation remain separate
authority decisions even if an operator starts the surrounding workflow from
MoonDesk.

## Canvas behavior

Canvas bounds and virtual extent are computed from the published graph rather
than fixed to a small example. Pan, zoom, node movement, reset, and Fit work for
large graphs, including the 63-stage robotics reference.

Continuation is derived only from graph dependencies and MoonFlow's
`runnable_item_ids`. MoonDesk has no hardcoded MoonTown, MoonRobo, MoonMoon, or
MoonMold continuation card. Catalog, validation, adapter, or health gaps remain
visible as unavailable instead of being replaced by product-inventory guesses.

## Product boundaries

- MoonDesk visualizes, selects, invokes published actions, and inspects state.
- MoonFind owns discovery and desired graph/canvas intent.
- MoonFlow validates, schedules, executes, reconciles, and recovers the graph.
- MoonGate resolves exact capability and authority; it is not a workflow node.
- MoonClaw is the sole agent runtime. MoonCode is a role/profile.
- MoonBook owns MoonWiki functionality, durable truth, and Bookkeeper closure.
- MoonTown owns civic coordination and reviewable cross-book synthesis.
- Domain products own meaningful operations, schemas, policy, and applications.

An installed product not declared by the current graph may appear in a generic
product inventory, but it does not produce a canvas node or continuation
action. This keeps finance, media, robotics, spatial, simulation, and other
domain semantics out of desktop and orchestration cores.

## Robotics reference

MoonFind's locally validated humanoid-robotics reference contains:

- 63 desired stages and 63 executable Work items;
- 43 unique exact operations;
- 63 typed primary request artifacts;
- 11 domain-product owners: MoonBook, MoonCast, MoonChat, MoonClaw, MoonFind,
  MoonMold, MoonMoon, MoonProj, MoonRobo, MoonTown, and MoonVis.

MoonFlow, MoonGate, and MoonLib are visible support-plane dependencies.
MoonEdit and MoonLeaf are reusable libraries where applicable. MoonFish is a
separate financial domain and is not inserted into robotics. MoonMini and
MoonStat are not active graph products; MoonStat is a retired identity whose
authority role belongs to MoonGate.

The local reference was accepted against a complete fixture catalog with 63
bindings and zero issues. That proves typed graph compatibility, not live
provider, customer, financial, or physical readiness. A production run still
requires host-published unexpired adapter health, real credentials, named
reviewers, rights/licensing evidence, calibrated simulation, safety evidence,
and a separately granted physical authority envelope. The default graph
contains no publication, trade/order, or physical robot-command operation.
