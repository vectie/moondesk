# MoonSuite UI-to-UI qualification

This directory defines and records user-visible qualification for the published
MoonSuite source products. Publishing source or building a UI is not the same
as proving a user journey. A result is a UI-to-UI pass only when a person can
start with a visible control and observe the intended result, evidence, or
denial in a visible product surface.

## Qualification rule

A qualifying journey has all of these properties:

1. It starts from a documented product URL or packaged application.
2. The user performs the meaningful action through visible controls.
3. The application crosses its real host boundary rather than replacing it
   with an in-memory model or browser-side response injection.
4. The final state is visible and can be related to durable evidence.
5. Denied authority and unavailable capability states are tested where they
   are part of the product contract.
6. Reload or restart is tested when the result claims durability.
7. Browser console and failed-request evidence are retained.

The following do not count as UI-to-UI by themselves:

- `moon check`, `moon test`, or an `npm` build;
- Rabbita `render_to_string` assertions;
- direct calls to an update function;
- direct API calls that bypass the visible initiating control;
- pre-seeding the application model after the page has loaded;
- counting source records without confirming rendered UI state;
- a screenshot without a reproducible action and acceptance assertion.

An isolated fixture may prepare the input state. The user must still choose,
import, submit, approve, or otherwise operate that input through the visible
application.

## Result vocabulary

| Result | Meaning |
| --- | --- |
| `PASS` | The complete visible journey and its required boundary assertions passed. |
| `FAIL` | The journey was executable but a required visible or durable assertion failed. |
| `BLOCKED` | The journey could not reach its first meaningful user action because a named prerequisite or product boundary is missing. |
| `NOT-RUN` | The journey is designed but has not been executed. |
| `CONSUMER-PROOF` | A library, service, or framework has no standalone UI and was exercised through a named visible consumer. |
| `NOT-APPLICABLE` | A standalone UI would contradict the product contract; the required proof belongs to a consumer journey. |

`BLOCKED`, `NOT-RUN`, and `NOT-APPLICABLE` are not passes.

## 2026-07-31 qualification snapshot

- A–M standalone/consumer cases: 7 `PASS`, 4 `FAIL`, 10 `BLOCKED`,
  4 `NOT-RUN`.
- N–Z standalone cases: 5 `PASS`, 2 `FAIL`, 2 `NOT-RUN`.
- The 63-stage MoonDesk canvas visibly imported and rendered all nodes,
  exercised Fit/zoom/drag/pan/save, created run sequence 64, and recovered the
  run after restart. End-to-end execution remains `BLOCKED` because MoonFlow
  published no authority-bound operator action; moved-node layout also failed
  to persist.
- MoonWiki → MoonCast intake is a proven subjourney: the named-approved packet,
  exact creative source bindings, and 1-episode/3-scene/15-shot project
  survived reload. The full media-to-MoonFlow journey remains `BLOCKED` until
  G0–G5 production and accepted-master evidence exist.

These counts describe case results, not product readiness. Read the detailed
reports before treating a product as usable.

## 2026-07-31 remediation follow-up

The original snapshot and counts above remain the historical baseline. A
same-day feature-remediation rerun subsequently proved these narrower
assertions:

- MoonDesk retained the moved 63-stage node position across service restart,
  restored the Flow projection directly, and displayed one generic v2 operator
  action.
- MoonClaw retained a same-origin Cowork conversation; MoonMold retained an
  exact operation, reconcile result, and named review.
- MoonFish created a named `monitor_only` fixture paper watch with entry,
  target, upside, horizon, sale window, and invalidation; MoonCast reached G0
  only after exact needs and brief approval.
- MoonRobo truthfully showed `2/6` readiness and a durable dry-run-required
  denial; MoonFind published a durable terminal projection and typed MoonTown
  handoff.
- MoonTown exposed View, Editor, and Final Output modes and labelled the
  three-book intake **pending, not executed**; MoonProj exposed a safe formal
  denial and a separately labelled session-local accepted lifecycle.

These follow-up results do not recalculate the baseline totals. Full
cross-product execution/receipts and production gates remain open. See
[the remediation report](REMEDIATION_2026-07-31.md) for the
baseline→fix→rerun matrix, exact evidence paths, and remaining blockers.

## Current consolidated focused pass

The product-owned qualification guides are consolidated in
[the current 2026-07-31 UI-to-UI report](CONSOLIDATED_UI_TO_UI_2026-07-31.md).
It preserves the baseline and remediation history above while separating
current observed passes, expected governed blocks, and untested coordinator
steps. It also provides one proportional operator runbook for the research,
creative, financial, physical-product, and lunar-evidence journeys.

Do not infer an end-to-end pass from a passed product slice. In particular,
MoonFind's receiver receipt is not MoonChat execution or MoonBook acceptance;
MoonChat intentionally has no standalone UI; MoonProj lacks exact
plan-artifact review; and MoonMold/MoonRobo do not yet share one portable
engineering envelope.

## Product test lanes

| Product | Product shape | Required UI lane |
| --- | --- | --- |
| Bunnia / Rabbita | UI framework; MoonMini is only an alias | generated mini-application consumer proof |
| Lepusa | native application host | packaged MoonDesk or MoonGate consumer proof |
| MoonBook | knowledge product | existing MoonBook Rabbita UI containing the Bookkeeper console |
| MoonCast | media pack and studio | direct Rabbita Studio and Editor |
| MoonChat | portable review contract, no application | MoonFind producer/result projection plus MoonBook consumer proof |
| MoonClaw | sole agent runtime | direct Rabbita job/Cowork UI and MoonDesk MoonCode projection |
| MoonDesk | operator desktop | direct Rabbita desktop or packaged Lepusa application |
| MoonEdit | editor library, no application | MoonDesk text/code editor consumer proof |
| MoonFind | research pack | direct Rabbita research workspace and MoonDesk graph handoff |
| MoonFish | financial research pack | direct daily-research application; paper-only effects |
| MoonFlow | orchestration platform, no domain UI | MoonDesk Flow/run projection consumer proof |
| MoonGate | provider and authority platform | direct operator dashboard |
| MoonLeaf | document library, no application | MoonDesk office-document editor consumer proof |
| MoonLib | shared contract library, no application | cross-product contract and durable-layout consumer proof |
| MoonMold | spatial-model pack | direct Rabbita spatial operator |
| MoonMoon | lunar simulation product | direct Rabbita simulation |
| MoonProj | OPC operating product | direct Rabbita OPC UI |
| MoonRobo | robotics product | direct Rabbita cockpit, simulation authority only |
| MoonTown | civic orchestration product | direct Rabbita town console |
| MoonVis | design system and inspector | direct Rabbita bundle inspector |
| vectie.github.io | public product catalog | deployed website navigation |

MoonStat is retired and is not a qualification target. MoonMini is not a
separate product.

## Evidence layout

Store transient evidence outside tracked source:

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

`run.json` should record:

- product and commit;
- test-case ID;
- start and finish timestamps;
- launch command and isolated data root;
- browser URL and viewport;
- visible actions;
- visible and durable assertions;
- result and blocker, if any;
- paths or digests for evidence;
- whether external credentials, publication, trading, or physical authority
  were intentionally withheld.

Do not commit credentials, customer data, licensed market data, private
documents, or generated media whose rights are not clear.

## Documents

- [Operator handbook](OPERATOR_HANDBOOK.md) explains how to prepare, execute,
  observe, and record each class of journey.
- [Product interaction map](PRODUCT_INTERACTION_MAP.md) explains ownership and
  cross-product call chains.
- [Standalone A-M report](STANDALONE_A_M.md) records Bunnia through MoonMold.
- [Standalone N-Z report](STANDALONE_N_Z.md) records MoonMoon through the
  public website.
- [Interproduct journeys](INTERPRODUCT_JOURNEYS.md) records the research,
  media, finance, and robotics loops.
- [2026-07-31 remediation](REMEDIATION_2026-07-31.md) records the
  baseline→fix→visible-rerun follow-up without rewriting the historical case
  counts.
- [2026-07-31 consolidated focused pass](CONSOLIDATED_UI_TO_UI_2026-07-31.md)
  indexes the latest product-owned guides, current status, detailed
  user-operable journeys, interaction contracts, and remaining gaps.

Reports must distinguish what was actually executed from what is merely
designed.
