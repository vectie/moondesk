# 2026-07-31 MoonSuite qualification remediation

This report is a follow-up to the 2026-07-31 qualification snapshot. It does
not rewrite the original case counts or erase failed and blocked observations.
Instead, it records the narrow assertions that were fixed and rerun through
visible product controls after that snapshot.

The follow-up used isolated local state and withheld provider credentials,
licensed market data, publication, trading, payment, fabrication, and physical
robot authority. A `PASS` below applies only to the named remediation
assertion. It is not a production-readiness claim.

This remediation matrix remains historical. The current product-owned cases,
interaction contracts, known gaps, and focused browser evidence are indexed in
[the consolidated 2026-07-31 report](CONSOLIDATED_UI_TO_UI_2026-07-31.md).

## Baseline → fix → UI rerun matrix

| Product / case | Preserved baseline | Remediation | Visible rerun and result |
| --- | --- | --- | --- |
| MoonDesk + MoonFlow, `MFL-UI-001`, `MFL-UI-002`, `IP-01` | The 63-node canvas worked, but a moved node reset after restart. Run sequence 64 recovered with one runnable item, but no operator action was projected. | Persist validated node coordinates; make the node grip keyboard-operable; hydrate composition, runs, and v2 actions when a restored session opens directly in Flow; project generic manifest-owned actions without domain branches. | Imported a canonical `book.toml` / `wiki.toml` book with no fixture-only `book.json`; rendered 63/63 nodes across 11 products; moved `understand-needs` by keyboard from `64,72` to `72,104`; saved, restarted, and recovered the exact position. Run sequence 64 returned with one ready item and one visible **Open moonbook** action. Layout persistence and restored action projection are `PASS`; actual receiving-product execution and receipt return remain `BLOCKED`. |
| MoonClaw, `MCL-UI-001` | Cowork was served on one port but targeted hard-coded gateway port `18123`, so the first durable chat could not be created. | Resolve an explicitly safe gateway when configured and otherwise use the current same origin; reject unsafe host and downgrade combinations. | The Cowork UI visibly showed gateway `http://127.0.0.1:4411`, created **New chat**, and retained that conversation after reload. Same-origin durable-chat remediation is `PASS`. |
| MoonMold, `MM-UI-001`, `MM-UI-002` | Mock-reference execution failed because a missing `reviews` field could not be decoded; no exact operation receipt existed for reconcile or named review. | Decode absent/null review collections as empty, bind the receipt to the exact ordered input digest, and keep execution, reconcile, and named review as separate durable operations. | Clicked **Execute reference path**, reconciled the same attempt, recorded reviewer `UI Qualifier`, and restarted. The exact operation receipt and one named-review receipt recovered; `mock-reference`, `physical_authority: false`, and **NO FABRICATION · NO PHYSICAL AUTHORITY** remained visible. Both mock-digital remediation assertions are `PASS`; Blender, engineering acceptance, manufacturing, and physical authority are not qualified. |
| MoonFish, `MFS-UI-001`, `MFS-UI-002` | A verified fixture run survived reload, but the UI could not turn its funnel/dossier data into a named governed release. | Add a multi-security deterministic fixture, hard rejections, policy ranking, bull/bear dossiers, input/result digest binding, and a named paper-only review that can emit only `monitor_only`. | Submitted the fixture through the visible workflow, selected `600519.SH`, attested paper-only review, and approved the paper watch. The release visibly showed observation `CNY 1462.00`, entry `CNY 1440.00–CNY 1480.00`, goal `CNY 1635.20`, expected upside `12.00%`, a `45`-session horizon, sale window `2026-07-27 → 2026-09-25`, invalidation, policy/catalyst scores, reviewer, and `monitor_only`. The governed fixture recommendation is `PASS`; it is not investment-ready and has no broker/order path. |
| MoonCast, `MC-UI-001`, `MC-UI-002`, `IP-03` | MoonWiki intake and project creation worked, but G0 correctly rejected the missing exact brief approval. The Cut Editor correctly denied import before G4. | Project gate readiness and exact reasons from the kernel; make needs, strategy, exact brief approval, and G0 evidence visible without bypassing earlier gates. | Imported and deliberately approved the immutable needs packet, approved the exact brief, created the intake-bound project, and recorded G0. Revision 10 visibly showed a 4-minute, 1-episode/20-shot graph, G0 `PASSED`, and G1 next. This intake→brief→G0 subjourney is `PASS`. The Cut Editor remains a separate governed boundary: pre-G4 denial remains `PASS`, while a populated edit, render, G1–G5, client acceptance, and a real 3–8 minute provider episode remain `BLOCKED`. |
| MoonRobo, `MR-UI-001`, `MR-UI-002` | MoonData refresh passed with a degraded sample fallback because the host omitted a product-home field; the walk safe-denial case had not run. | Publish the complete product-home snapshot, including the MoonClaw routine-runs path, and preserve fail-closed receipt-backed command review. | The cockpit visibly identified `noetix-e1-lab-01` and the isolated RoboBook, reported truthful readiness `2/6` (`33%`, `needs-foundation`), and did not substitute the sample root. **Evaluate Walk** created a durable `waiting-for-dry-run` receipt; **Approve** and **Execute** remained unavailable and the page said **No command submitted**. Truthful readiness and dry-run denial are `PASS`; no physical bridge or robot command was used. |
| MoonFind, `MFI-UI-001`, `MFI-UI-002` | The static workspace failed closed but had no host-published submit/reconcile/checkpoint URLs or visible MoonTown handoff. | Add a MoonBit host with durable workspace/journal projection, same-origin ports, terminal-state recovery, and a versioned run-bound MoonTown handoff. | Reloaded the terminal projection without the stale-session decode failure. The UI visibly showed the durable completed analysis (`3` papers, `3` summaries, `1` falsifiable idea), `needs-review` revision 6, and a ready **Open typed handoff in MoonTown** control. Durable terminal projection and typed handoff publication are `PASS`; the retained terminal fixture is not a live provider run, and named review/Bookkeeper closure are not complete. |
| MoonTown, `MT-UI-001`, MoonFind receiving subjourney | The requested viewport rendered the wrong experience and exposed none of View, Editor, or Output mode controls. No MoonFind handoff was visibly received. | Split the viewport route into explicit modes and add a fail-closed, query-bound typed civic-handoff intake panel. | Operated **View Mode**, **Editor Mode**, and **Final Output** through visible controls. Opening MoonFind's handoff displayed the run-bound salon, exactly three invited participant books, and the explicit status **PENDING · NOT EXECUTED**. Mode navigation and truthful intake are `PASS`; participant execution, reducer synthesis, review acceptance, returned result, and Bookkeeper learning are not claimed. |
| MoonProj, `MP-UI-001`, `MP-UI-002` | The formal Moon project button emitted only an intent notice, and the Basic OPC acceptance lifecycle had not been run. | Add the formal task form and canonical create/start/accept/report boundaries; advance formal state only from audit/event receipts. Keep the general Basic OPC lifecycle explicitly session-local. | In Moon project mode, the completed form failed closed when the signed gateway/PostgreSQL receipt was unavailable and created no fake formal task: safe-denial is `PASS`, but a positive formal lifecycle remains `BLOCKED`. In general mode, visible create → start → submit → accept controls produced one **Accepted** card with **waiting for settlement and posting** and an explicit `SESSION-LOCAL / NOT POSTGRESQL EVIDENCE` banner; `MP-UI-002` is `PASS` only for that browser-session lifecycle. |

## Evidence index

The exact retained screenshots for this follow-up are:

| Assertion | Evidence |
| --- | --- |
| 63-stage restored layout | `/Users/kq/Workspace/moondesk/_build/ui-to-ui/2026-07-31-63-stage-remediation/root-browser-final.png` |
| Restored v2 action queue | `/Users/kq/Workspace/moondesk/_build/ui-to-ui/2026-07-31-63-stage-remediation/root-browser-action-queue.png` |
| Pre-fix restored-session hydration failure | `/Users/kq/Workspace/moondesk/_build/ui-to-ui/2026-07-31-63-stage-remediation/root-browser-run.png` |
| Structured MoonDesk remediation record | `/Users/kq/Workspace/moondesk/_build/ui-to-ui/2026-07-31-63-stage-remediation/run.json` |
| Same-origin durable Cowork chat | `/Users/kq/Workspace/moonclaw/_build/ui-to-ui/2026-07-31-remediation/same-origin-persisted-chat.png` |
| MoonMold reconcile and named review | `/Users/kq/Workspace/moonmold/_build/ui-to-ui/2026-07-31-remediation/reconciled-and-reviewed.png` |
| MoonMold restart recovery | `/Users/kq/Workspace/moonmold/_build/ui-to-ui/2026-07-31-remediation/recovered-operation-and-review.png` |
| Governed MoonFish paper watch | `/Users/kq/Workspace/moonfish/_build/ui-to-ui/2026-07-31-remediation/governed-paper-watch.png` |
| Prior durable MoonWiki intake binding | `/Users/kq/Workspace/mooncast/_build/ui-to-ui/2026-07-31-interproduct-intake/run.json` |
| MoonCast needs, brief, and G0 | `/Users/kq/Workspace/mooncast/_build/ui-to-ui/2026-07-31-remediation/needs-brief-g0.png` |
| MoonCast canonical pre-G4 Cut Editor denial | `/Users/kq/Workspace/mooncast/_build/ui-to-ui/2026-07-31-governed-project/run.json` |
| MoonRobo truthful readiness | `/Users/kq/Workspace/moonrobo/_build/ui-to-ui/2026-07-31-remediation/truthful-readiness.png` |
| MoonRobo durable dry-run denial | `/Users/kq/Workspace/moonrobo/_build/ui-to-ui/2026-07-31-remediation/walk-denied-dry-run-required.png` |
| MoonFind terminal projection and handoff | `/Users/kq/Workspace/moonfind/_build/ui-to-ui/2026-07-31-remediation/durable-run-and-typed-handoff.png` |
| MoonTown pending salon intake | `/Users/kq/Workspace/moontown/_build/ui-to-ui/2026-07-31-remediation/moonfind-handoff-pending-salon.png` |
| MoonTown three modes and handoff boundary | `/Users/kq/Workspace/moontown/_build/ui-to-ui/2026-07-31-remediation/viewport-modes.png` |
| MoonProj formal safe-denial | `/Users/kq/Workspace/moonproj/_build/ui-to-ui/2026-07-31-remediation/formal-task-safe-denial.png` |
| MoonProj session-local accepted lifecycle | `/Users/kq/Workspace/moonproj/_build/ui-to-ui/2026-07-31-remediation/session-local-accepted-direct.png` |

The restarted MoonDesk composition was also corroborated at:

```text
/tmp/moonsuite-remediation-ui.aZ0qye/suite/books/robotics-book/flow/composition.json
sha256:225794c9f2420bc3ebead2b31247db7a7dcacc124935f2d72ceb1f285d7e1d1d
```

The MoonDesk `run.json` records the scoped remediation as `PASS` and preserves
`overall_ip_01_status: BLOCKED`. `root-browser-run.png` is the failure evidence
that exposed the restored-session hydration defect; the corrected final-state
evidence is `root-browser-final.png` plus
`root-browser-action-queue.png`.

## Remaining release and production blockers

The remediation closes only the observed defects named in the matrix above.
It does not claim that every MoonSuite feature or integration gap is closed,
and it does not close these independent qualification gates:

1. MoonFish still needs licensed point-in-time live data, a
   survivorship-bias-free after-cost backtest, and at least 120 forward-only
   shadow sessions before any evidence of edge exists.
2. MoonCast still needs rights-cleared real providers, a complete 3–8 minute
   episode, populated Cut Editor work, G1–G5 evidence, accepted-master
   delivery, and measured unit economics.
3. MoonTown still needs actual participant execution, independent challenge,
   reducer synthesis, named review, returned receipts, and MoonBook
   Bookkeeper/Three-Gap closure.
4. The 63-stage loop still needs receiving-pack execution, durable receiver
   receipts, return-to-Flow evidence, recovery across those effects, and
   complete acceptance. A visible **Open moonbook** action is only the first
   handoff projection.
5. MoonProj still needs its signed/authenticated gateway, PostgreSQL-backed
   task and audit receipts, and a positive formal create/start/submit/accept
   rerun.
6. MoonRobo still needs separately authorized hardware, safety cases,
   calibrated telemetry, physical bridge qualification, and named physical
   approval. No local fixture can grant those.
7. MoonMold still needs real Blender/provider qualification and independently
   reviewed engineering evidence before manufacturing or fabrication claims.
8. MoonDesk release still needs Developer ID signing, notarization,
   Gatekeeper/clean-machine evidence, update/rollback qualification, and the
   production lifecycle soak.
