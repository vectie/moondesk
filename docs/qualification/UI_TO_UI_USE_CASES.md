# MoonDesk UI-to-UI use cases

This file is the stable product-standard entrypoint. The detailed, current
matrix and procedures remain in
[CONSOLIDATED_UI_TO_UI_2026-07-31.md](CONSOLIDATED_UI_TO_UI_2026-07-31.md).

MoonDesk owns four ordinary user journeys:

1. **Open work** — choose a book or workspace, inspect its files and state,
   perform a bounded edit/review action, and recover context after reload.
2. **Run a pack** — discover a generic installed entrypoint, open the
   product-owned application, and return without MoonDesk interpreting its
   domain records.
3. **Compose work** — load a `moonsuite.work-model.v1`, understand the outcome
   and current phase, select a dependency-closed slice, and validate it against
   the exact catalog.
4. **Operate and recover** — delegate start/pause/resume/cancel to MoonFlow,
   inspect correlated evidence, restart the host over the same root, and
   require the same run/action projection.

Each journey records start, action, result, meaningful denial, and recovery.
The [operator handbook](OPERATOR_HANDBOOK.md) gives exact launch instructions.
The [interproduct journeys](INTERPRODUCT_JOURNEYS.md) define receiving-product
receipt criteria. A 63-node render is not a 63-stage execution result.
