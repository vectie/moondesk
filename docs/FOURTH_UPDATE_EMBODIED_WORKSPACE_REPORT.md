# Fourth Update: Embodied Workspace Qualification

**Status:** functionally accepted; publication remains gated by the independent
72-hour unattended-autonomy soak.

## Goal

The fourth update tested one bounded lunar-robot project as a pure-user,
executable-document journey and added two missing workspace capabilities:

1. a quiet keyboard-and-pointer MoonDesk flow that exposes product state without
   exposing internal orchestration;
2. MoonMold, a governed spatial-modeling product backed by real Blender output;
3. an embedded browser surface for preview, responsive inspection, evidence,
   recovery, and MoonCode handoff without leaving MoonDesk.

The run intentionally grants no manufacturing authority, actuator command, or
physical effect. A printable file is a digital manufacturing candidate only.

## Canonical input

The canonical MoonBook is `/Users/kq/moonsuite/books/unified-lunar-robot`.
Its executable Flow revision r14 contains eight typed stages:

1. MoonWiki research;
2. MoonTown deliberation;
3. MoonClaw helper execution;
4. MoonMold live spatial modeling;
5. MoonRobo digital build planning;
6. MoonRobo digital validation;
7. MoonMoon simulation assessment;
8. MoonBook audit and learning.

Inputs include the goal, an evidence-backed service-bay plan, explicit unknowns,
authority and data-boundary envelopes, and user-visible quality criteria. The
helper's typed JSON requirement belongs to the executable document, not a hidden
or benchmark-specific prompt.

## Trial history

- **r11 rejected:** the first run used a nested workspace and the external model
  worker could not resolve its catalog. The input moved to the canonical book
  root; no compatibility shim was retained.
- **r12 rejected:** MoonMold emitted a raw-file digest where MoonFlow required an
  artifact-set digest. MoonMold now computes the portable digest over the ordered
  reference-and-file-digest set, and its attestor independently re-hashes it.
- **r13 rejected:** the helper serialized numbers and booleans as strings, then
  MoonMold exposed summary evidence that an independent reviewer could not
  verify. Automatic recovery corrected the helper. MoonMold was generalized to
  expose per-file references, digests, sizes, concrete unknowns, fixed-bridge
  provenance, and a digital-only claim ceiling. The retry also revealed that a
  shared draft path could not safely support revision; drafts now use bounded
  replaceable atomic writes while results, attestations, and finals remain
  immutable.
- **r14 accepted after bounded automatic recovery:** Wiki, Town, helper, and
  MoonMold were accepted. The MoonRobo build review timed out without a receipt.
  Child run `unified-lunar-robot-r14-auto-recovery-28` reused those four accepted
  checkpoints, invalidated the failed checkpoint and its three dependents, and
  accepted build, validate, simulate, and audit. The projection is 8/8 accepted
  with zero required, normal-manual, or hidden-orchestration interventions.

Failures remain evidence. No rejected revision was erased or relabeled.

## Product outputs

- **MoonDesk:** one selected-book Work/Flow surface, compact revision history,
  installed-product handoffs, physical-effect boundary, embedded browser,
  responsive controls, durable evidence, operator control, and scoped MoonCode
  recovery.
- **MoonMold:** real `.blend`, GLB, STL, render, bridge manifest, and immutable
  live evidence created by Blender 4.5.11 LTS through a fixed audited bridge.
- **MoonFlow:** accepted projection, criterion reviews, checkpoint migration,
  automatic-recovery lineage, and unattended scorecard.
- **MoonBook / Bookkeeper:** eight structural procedures, four promoted after
  repeat evidence and four retained as candidates; three encountered execution
  gaps are recorded as resolved while information, cognition, and execution
  gaps remain explicit.
- **MoonRobo / MoonMoon:** digital build, validation, and simulation assessments;
  none assert physical readiness.

## Pure-user UX findings

The real keyboard-and-pointer journey found issues unit tests did not:

- a Code layout overlaid a third setup action, so its visible hit target did not
  navigate; the grid was corrected and replayed in the visible browser;
- an enabled Town action conflicted with `Adapter pending`; unavailable product
  actions are now unambiguous;
- ten expanded Flow revision cards obscured the current result; the latest
  revision is primary and older revisions are compact history;
- Flow originally showed the latest run across the whole suite after the user
  selected a MoonBook. History and counts are now scoped to the selected book;
- a visible “evidence captured” message initially exceeded durable host proof;
  the browser path now persists attributable evidence before claiming capture;
- executable HTML first opened a separate tab and failed parent-DOM isolation;
  **Preview / Run here** now stays in the book's isolated embedded surface.

The accepted GUI shows the selected `Unified Lunar Robot` book, five relevant
revisions, the recovered r14 result first, 8/8 accepted, installed handoff state,
and the explicit false physical-authority boundary.

## Quality rules learned

- Scope every projection to the object the user selected.
- Put quality requirements in the executable document and keep hidden
  orchestration at zero.
- Expose reviewer-verifiable artifact evidence, not a producer's summary.
- Preserve accepted checkpoints; invalidate only a failed node and its
  dependents.
- Keep drafts safely replaceable but keep results and attestations immutable.
- Distinguish styled, engineering, simulation, manufacturing-candidate, and
  physical-effect representations at every handoff.
- Promote memory only after repeated success or explicit review; retain open
  gaps even after the execution succeeds.
- A visible success message must be backed by durable evidence.
- GUI qualification is a product gate because hit targets, focus, layout, and
  disclosure cannot be proven by model tests alone.

## Verification

- MoonDesk JavaScript suite: 527/527 passed.
- MoonDesk native suite: 545/545 passed.
- MoonDesk production build and desktop/tablet/mobile browser smokes passed.
- MoonMold adapter suite: 22/22 passed, with live tests separately bounded.
- MoonMold MoonBit suite: 10/10 on each supported target.
- Embodied robot audit: 10/10 accepted.
- Workspace boundary audit: 25 repositories accepted, Blender accepted, zero
  forbidden active-path leaks.

The immutable third-update soak is not part of this branch and has not been
modified. Merge, publication, and final product rerating remain gated until it
completes 72 clean wall-clock hours and the final audit verifies remote heads.
