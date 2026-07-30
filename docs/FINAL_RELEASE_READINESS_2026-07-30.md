# MoonDesk final release-readiness decision

Date: 2026-07-30

## Decision

**Not ready.**

The productization program is closed with an explicit no-go decision. Phases
0–8 have passed their recorded repository or hosted gates. Phase 9's
repository-owned release path is implemented and locally validated, but its
external exit gate is not complete. The current tree also does not satisfy the
final warning-clean or latest-commit hosted-CI criteria.

This report does not treat unsigned local output as evidence of Developer ID
signing, Apple notarization, Gatekeeper acceptance, hosted updates,
clean-machine behavior, lifecycle recovery, or a 24-hour soak.

## Phase audit

| Phase | Result | Retained evidence |
| --- | --- | --- |
| 0. Current truth | Complete locally | [`BASELINE_2026-07-27.md`](BASELINE_2026-07-27.md), [`FULL_VALIDATION_PROOF_2026-07-27.md`](FULL_VALIDATION_PROOF_2026-07-27.md), the ownership map in the program plan, and `scripts/validate.sh` |
| 1. Product clarity | Complete locally | [`PHASE_1_CLOSURE_2026-07-27.md`](PHASE_1_CLOSURE_2026-07-27.md), [`FIRST_RUN_AND_VOCABULARY.md`](FIRST_RUN_AND_VOCABULARY.md), and [`NATIVE_LIBRARY_PICKER_ACCEPTANCE_2026-07-27.md`](NATIVE_LIBRARY_PICKER_ACCEPTANCE_2026-07-27.md) |
| 2. CI and preview release | Complete | [`PREVIEW_RELEASE_PROOF_2026-07-27.md`](PREVIEW_RELEASE_PROOF_2026-07-27.md) records mandatory hosted CI and reproducible preview evidence for its accepted commit |
| 3. Typed MoonCode contract | Complete | The reviewed generated `mooncode/core/pkg.generated.mbti` surface and the Phase 3 gate record in the program plan |
| 4. Package boundaries | Complete locally | [`PHASE4_PACKAGE_OWNERSHIP_MAP.md`](PHASE4_PACKAGE_OWNERSHIP_MAP.md) |
| 5. Security | Complete locally | [`PHASE5_SECURITY_EVIDENCE.md`](PHASE5_SECURITY_EVIDENCE.md) |
| 6. Observability | Complete locally | [`PHASE6_OPERATOR_EVIDENCE.md`](PHASE6_OPERATOR_EVIDENCE.md) |
| 7. Editing workspaces | Complete locally | [`PHASE7_EDITING_EVIDENCE.md`](PHASE7_EDITING_EVIDENCE.md) |
| 8. UX quality | Complete locally | The Phase 8 gate record in [`MOONDESK_PRODUCTIZATION_UPGRADE_PLAN.md`](MOONDESK_PRODUCTIZATION_UPGRADE_PLAN.md), including retained automated localization, accessibility, reduced-motion, keyboard, and responsive evidence |
| 9. Native distribution | Repository path complete; exit gate blocked | [`PHASE9_NATIVE_DISTRIBUTION_REPORT.md`](PHASE9_NATIVE_DISTRIBUTION_REPORT.md), [`PHASE9_RELEASE_OPERATIONS.md`](PHASE9_RELEASE_OPERATIONS.md), the evidence schema/checklists, and the non-credentialed release smoke |

## Current validation

On 2026-07-30, `TMPDIR="$PWD/_build/tmp" sh scripts/validate.sh full`
completed every functional stage before the expected clean-tree assertion:

- 338/338 native tests passed
- 501/501 UI tests passed
- 6/6 localization tests passed
- 8/8 release-verifier tests passed
- Phase 9 non-credentialed release smoke passed
- production UI build passed
- generated-interface verification passed
- whitespace validation passed

The run reported 331 MoonBit warnings during the root check. Its final
clean-tree assertion failed because the Phase 9 changes and pre-existing user
documentation edits were intentionally uncommitted at the time of the run.
Phase 9 was then committed without including those unrelated documentation
edits.

## Release blockers

| Blocker | Owner | Target date | Required evidence to clear |
| --- | --- | --- | --- |
| Warning-clean release criterion is not met; the root check reports 331 warnings | Core Engineering | 2026-08-14 | A warning-clean mandatory check, with intentional compatibility warnings governed by an explicit checked policy |
| The latest local `main` commits do not yet have retained mandatory hosted-CI evidence | Release Engineering | 2026-08-07 | Green hosted CI tied to the exact candidate commit and immutable run URL |
| Developer ID signing, hardened runtime, notarization, and stapling are unproved | Release Engineering | 2026-08-07 | Credentialed artifact identity, `codesign` details, notarization result, stapler validation, and immutable hashes |
| Gatekeeper acceptance is unproved on clean supported Macs | macOS QA | 2026-08-12 | Clean-machine `spctl` and normal-launch results on minimum and current supported macOS |
| Stable/preview hosting and the clean-machine matrix are unproved | Release Operations and macOS QA | 2026-08-14 | Immutable hosted URLs/checksums plus completed schema-valid clean-machine evidence |
| Install, update, interrupted-update, rollback, removal, and user-data preservation are unproved | macOS QA | 2026-08-18 | Schema-valid lifecycle evidence with before/after user-data hashes |
| The frozen 24-hour lifecycle/resource soak has not run | Reliability Engineering | 2026-08-21 | Raw samples and a schema-valid report passing `config/phase9-soak-thresholds.json` |

## Re-entry rule

Do not change this decision to **Ready** because repository-local checks pass
or because a candidate package exists. Reopen the decision only when every row
above has retained evidence tied to one immutable candidate commit. At that
point, rerun the full validator from a clean checkout, publish the final release
notes and candidate artifacts, and replace this decision with a dated Ready
record.

There is no post-release roadmap in this no-go record: every remaining item
listed above is release-blocking rather than deferred product scope.
