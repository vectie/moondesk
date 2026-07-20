# MoonSuite composition canvas

MoonDesk owns the visual control surface, not orchestration. The MoonFlow
workspace renders a pack-authored executable Work graph as a scrollable,
zoomable canvas. Work nodes remain owned by their products and retain their
typed operation, authority, evidence, acceptance, and dependency contracts.

The operator can include or exclude declared nodes before a run. MoonDesk
persists only `flow/composition.json`, a generic selection overlay bound to the
source graph identity. On import, the host validates dependency closure,
compiles a content-digested graph, and gives it a distinct run and declaration
revision. The source graph and earlier MoonFlow runs remain immutable.

```text
pack-owned Work graph
  → MoonDesk canvas + explicit node selection
  → dependency-closed composition overlay
  → digest-bound compiled graph
  → MoonFlow durable execution
  → product adapters / MoonClaw runtime
  → evidence + review + Bookkeeper outcome
```

The canvas deliberately distinguishes the control plane from job nodes:

- MoonDesk visualizes, selects, invokes published actions, and inspects state.
- MoonFlow validates and advances the durable graph.
- MoonClaw is the single agent runtime used by product adapters.
- MoonBook owns source intent and accepted Bookkeeper learning.
- domain packs define meaningful operations and connections.

An installed product that is not declared by the current pack is visible in
the product palette as “not declared by this pack.” MoonDesk does not invent a
placeholder operation for it. This makes missing integration explicit without
putting robotics, finance, AIGC, or other domain semantics into the desktop or
orchestration cores.

For humanoid robotics, Moonfind publishes
`workflows/humanoid-robotics-suite.v1.json`. It connects MoonWiki, Moonfind,
MoonTown, MoonChat, MoonProj, MoonCode, MoonMini, MoonMold, MoonRobo, MoonMoon,
MoonStat, MoonGate, MoonVis, MoonCast, and MoonBook. MoonDesk, MoonFlow, and MoonClaw appear as the control
plane rather than pretending to be domain work products.

Physical execution remains separate. A graph may contain a physical-effect
node only when the owning adapter exists and MoonGate grants a bounded physical
authority envelope. Canvas inclusion is never authority.
