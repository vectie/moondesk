# Packaged MoonFlow repair — 2026-10-22

## Cause

The “service unavailable” state came from an unimplemented integration, not a
stopped network service. The old execution-sandbox client always returned
unavailable; the capability endpoint also hardcoded command availability to
false. Finder-launched MoonDesk did not include a native MoonFlow executable or
inherit a developer shell's source-checkout environment.

## Changes

- Bundle native MoonFlow beside `moondesk-sidecar`; generated live bundle
  resources include both executables. Resolve the installed executable from
  `LEPUSA_APP_DIR`, with an explicit executable override for host configuration.
- Connect graph validation/import, run control, collaboration inspection and
  handover listing to MoonFlow's existing native commands.
- Use the same installed executable for existing planning, single-step and
  exact-result review bridges. Retain existing execution semantics.
- Read the library-local single-step configuration by default from
  `.moonsuite/products/moondesk/flow-runtime/single-step.json`.
- Permit selection of the exact Mold operation from current native v3 run
  projections, which omit `adapter_id` before runtime adapter resolution.
- Offer the first Pause for a newly imported run. Native Flow defines the
  initial state as running and writes `control.json` on the first intervention.
- Keep collaboration recovery on the current surface with an icon refresh
  action. Localize member kinds, statuses and roles.
- Fold the workflow editor and result metadata into disclosures. Use a compact
  filename with a file icon to inspect output. Keep full paths in tooltips and
  result details. Add consistent result typography, spacing and corners.

## Actual installed-app verification

Application: `/Applications/MoonDesk.app`, native WKWebView, backend port 4201.
The existing library was recorded before selecting a separate verification
library at `/Users/kq/moonsuite/qualification/desktop-flow-20261022/workspace`.
No user books or filenames were modified by this verification.

The fixture preparation command is `moon run scripts/prepare-desktop-flow-check.mbtx`.
It creates isolated input, capability health/catalog, host configuration and
explicit local test identities. It does not import or execute a Flow run.

Actions performed through the native app:

1. Refresh Desk and open the `Flow verification` MoonBook in Flow.
2. Import its one-step workflow. Native Flow persisted run
   `desktop-flow-check-r1`, with `create-model` ready and zero attempts.
3. Select the step; Pause and Resume. The app reflected both states and native
   Flow persisted the control record.
4. Run the selected digital step. Native Flow invoked the real MoonGate and
   MoonMold executables, retained the attempt and reached **Review**.
5. Open `operation-receipt.json` in Flow. The result inspector reported verified
   retained bytes and showed the actual `moonmold.spatial-operation-receipt.v1`
   receipt with outcome `applied`.
6. Open Packs → Collaboration. The native owner-validated snapshot displayed
   one test member. Apply a second test membership using the bundled MoonFlow
   owner CLI; refresh in MoonDesk and reopen the drawer. It displayed two records.
7. Close and reopen the installed app. Flow restored the same completed action;
   its saved projection still had exactly one attempt. The retained receipt
   opened again, and Collaboration restored both members with localized roles.
8. Fetch the exact download URL exposed by the native result viewer. The
   downloaded file's SHA-256 matched the recorded output digest.

The first execution was correctly rejected before creating an attempt because
the test envelope used a zero model-token budget. The fixture was corrected to
the required positive value (1); retry used the same action ID. The local
reference model operation makes no external model call.

Retained action: `followup-f531b851-11e0-4fd6-8166-f896c3ac1712`.
Output SHA-256:
`d9e659e381b657d81db434929b4ecd58e0e05ab15287ee100c4acb50b2455059`.

## Scope of the evidence

Execution used MoonMold's native reference model operation. Its evidence is
`fixture-reference-only`, with `production_qualified=false` and
`physical_authority=false`. Review was not approved and no dependent work ran.
This verifies the packaged UI → Desk → native Flow → Gate → Mold → saved result
path; it does not qualify Blender, external services or physical execution.

Collaboration remains a read-only MoonDesk view of validated MoonFlow records.
The verification covers owner-side mutation, app refresh, and saved-state reads;
it does not claim that MoonDesk provides an invitation or membership editor.
Legacy generic operator handoff execution is separate from the native routes
repaired here.

## Focused checks

- Native service bridge and packaging tests: 28 passed.
- Capability, import/control receipt and single-step host tests: 12 passed.
- UI selection, recovery, retained results, owner summary, Flow state and Packs:
  36 passed.
- Locale regression suite: 20 passed.
- Native and JS `moon info`, `moon fmt`, release builds and `git diff --check`.
- Installed app signed ad hoc and checked with `codesign --verify --deep --strict`.

The optional compiled-UI fixture crossing reports unconfigured in the focused
unit run; the actual installed-app crossing above supplies separate native
verification evidence. These results are not a claim that the entire repository
test suite was run.

Evidence is saved in `docs/design/flow-packaged-20261022/`, including the native
collaboration screenshot, service capability response and one-attempt result
projection.

The original packaged-app library was restored after verification:
`~/Library/Application Support/app.vectie.moondesk.lepusa.live/workspace`
(44 MoonBooks). The separate verification library remains available for inspecting
the saved test run. The updated app was reopened after installation.
