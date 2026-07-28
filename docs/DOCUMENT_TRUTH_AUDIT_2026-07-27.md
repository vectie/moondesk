# Active-document Truth Audit — 2026-07-27

## Scope and evidence boundary

This documentation-only audit compares every document in the active reading
order in [`README.md`](README.md) with [`STATUS.md`](STATUS.md) and current local
evidence. It does not convert historical migration records into current plans.

Confirmed local evidence is deliberately bounded:

- `scripts/validate.sh fast` passes **217/217 native tests** and **305/305 UI
  tests**, with **zero warnings**.
- **3/3 localization tests** are recorded.
- The baseline metrics and source-ownership inventory are complete.
- The MoonCode public-surface inventory and typed-contract target are complete;
  implementation of that target has **not started**.
- [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) is active for pull
  requests and pushes and invokes `scripts/validate.sh full`. GitHub retains a
  successful `Required repository validation` pull-request job in run
  [`30314186808`](https://github.com/vectie/moondesk/actions/runs/30314186808)
  at commit `faebef38bf9d0e732089d7d9e0f8ccf1023a71f3`, followed by a successful
  default-branch push job in run
  [`30316790583`](https://github.com/vectie/moondesk/actions/runs/30316790583)
  at merge commit `083e1729e5602146071c06fc5992c74acf608547`.
- A clean-checkout `scripts/validate.sh full` transcript is now retained in
  [`FULL_VALIDATION_PROOF_2026-07-27.md`](FULL_VALIDATION_PROOF_2026-07-27.md).
  It closes local Phase 0 without claiming cross-product or remote evidence.

No unsigned-preview workflow run is retained. Phase 2 remains open for an
immutable preview-tag run and uploaded artifact, read-only verification of the
downloaded artifact, and independent clean-checkout reproduction/comparison of
the tagged version. No clean-machine, signing, notarization, hosted-update, or
release evidence is claimed.

## Active reading-order audit

| Active document | Role | Classification | Confirmed contradiction | Correction made | Remaining limitation |
| --- | --- | --- | --- | --- | --- |
| [`PLAN.md`](PLAN.md) | Product model, user flow, non-goals, and engineering bar | Current product contract | None confirmed | None | Product intent is not completion evidence. |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | Package ownership, HTTP surface, and cross-product boundaries | Current architecture contract | None confirmed | None | Architecture statements do not prove clean-checkout validation or remote CI. |
| [`DESK_MODE_DESIGN.md`](DESK_MODE_DESIGN.md) | Desk/file/workspace behavior | Current design contract | None confirmed | None | Design scope is not release evidence. |
| [`WIKI_MODE_UX_PLAN.md`](WIKI_MODE_UX_PLAN.md) | Wiki UX hierarchy and implementation gates | Current scoped UX plan | None confirmed | None | Its own gates require their own evidence. |
| [`WIKI_MODE_USER_E2E_PLAN.md`](WIKI_MODE_USER_E2E_PLAN.md) | Wiki user journeys and acceptance methodology | Current acceptance plan | None confirmed | None | Planned E2E evidence is not implied by local fast validation. |
| [`MOONCODE.md`](MOONCODE.md) | Code-mode contract and MoonClaw handoff | Current product contract | None confirmed | None | Contract text does not establish typed-target implementation. |
| [`MOONCODE_CLEAN_ARCHITECTURE_UPGRADE.md`](MOONCODE_CLEAN_ARCHITECTURE_UPGRADE.md) | Conversation/runtime upgrade record | Historical upgrade record; not a current productization plan | None confirmed | Classification clarified by this audit; content unchanged | Must remain historical and must not direct current phase status. |
| [`MOONCODE_OPENSEEK_ALIGNMENT_PLAN.md`](MOONCODE_OPENSEEK_ALIGNMENT_PLAN.md) | Conversation/thinking/live-update correction record | Historical alignment record; not a current productization plan | None confirmed | Classification clarified by this audit; content unchanged | Must remain historical and must not become a current plan. |
| [`MOONCODE_TYPED_CONTRACT_TARGET.md`](MOONCODE_TYPED_CONTRACT_TARGET.md) | Phase 3.1 inventory, target, decisions, and migration slices | Current completed design/inventory target | Any reading that treats the completed target as implemented is false | Current-status documents now distinguish completed inventory/target from implementation not started | Phase 3 implementation and its evidence remain outstanding. |
| [`STATUS.md`](STATUS.md) | Canonical current implementation state and known gaps | Current status | “Only [Phase 0's] validation-entrypoint slice is complete” omitted completed baseline metrics, ownership, typed inventory/target, and contradiction-audit work; fast evidence did not state 217/217 native explicitly | Updated to state all confirmed local evidence and, after isolated validation, local Phase 0 completion | No remote run evidence exists. |
| [`BASELINE_2026-07-27.md`](BASELINE_2026-07-27.md) | Reproducible starting/current evidence and metrics | Historical starting baseline plus bounded current local evidence | Phase 0 close conditions were stale as the audit and full proof were added | Linked both retained records and marked local Phase 0 complete | Current coverage remains unmeasured. |
| [`DOCUMENT_TRUTH_AUDIT_2026-07-27.md`](DOCUMENT_TRUTH_AUDIT_2026-07-27.md) | Contradiction ledger and evidence boundary | Current Phase 0 audit record | New document; no prior contradiction | Added and linked immediately after the baseline | Records local evidence only and cannot establish remote CI or release readiness. |
| [`FULL_VALIDATION_PROOF_2026-07-27.md`](FULL_VALIDATION_PROOF_2026-07-27.md) | Clean-checkout full-gate transcript | Current Phase 0 validation evidence | New document; no prior contradiction | Added after the isolated full gate passed twice with an empty final status | Cross-product roots were absent; no remote CI or release evidence is established. |
| [`ROADMAP.md`](ROADMAP.md) | Active product tracks and future gates | Current roadmap | None confirmed | None | Roadmap sequencing is not proof that a gate passed. |
| [`MOONDESK_PRODUCTIZATION_UPGRADE_PLAN.md`](MOONDESK_PRODUCTIZATION_UPGRADE_PLAN.md) | Authoritative phased productization plan | Current plan | The phase overview and immediate-action list did not distinguish completed local actions 1–5 from the remaining work; Phase 2 wording could be read as repository CI configuration proving CI execution | Recorded the completed local Phase 0 slices, moved completed actions out of the next-action list, then recorded the retained full proof; Phase 2 remains open without run evidence | Phase 2 needs retained PR/push run evidence. |
| [`MOONSUITE_LAYOUT_MIGRATION_PLAN.md`](MOONSUITE_LAYOUT_MIGRATION_PLAN.md) | Migration plan and validation record | Historical migration record | None confirmed | Historical classification retained | Must not be used as the current plan or current status source. |

## Gate conclusion

The **contradiction-audit gate is complete**. The subsequently retained
clean-checkout full transcript closes **local Phase 0**. The local CI workflow
configuration is real, but Phase 2 remains open because no pull-request or push
run evidence is retained. Historical migration records remain historical.
