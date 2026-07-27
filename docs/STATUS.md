# MoonDesk Status

Last updated: 2026-07-27.

The active finite productization program is
[`MOONDESK_PRODUCTIZATION_UPGRADE_PLAN.md`](MOONDESK_PRODUCTIZATION_UPGRADE_PLAN.md).
Phase 0 is complete locally. Its validation entrypoint, baseline metrics,
source-ownership inventory, contradiction audit, and retained clean-checkout
`scripts/validate.sh full` proof are complete. The proof and its explicit
cross-product/remote-evidence boundary are recorded in
[`FULL_VALIDATION_PROOF_2026-07-27.md`](FULL_VALIDATION_PROOF_2026-07-27.md).

The program baseline was 217 native tests, 303 UI JavaScript tests, 3
localization tests, 20 UI warnings, and 2,547 uncovered lines. Current local
evidence is 239/239 native and 402/402 UI tests with zero warnings; the current
localization suite passes 5/5. Coverage has not been remeasured.
The public MoonCode typed inventory and target are complete, but the Phase 3
public-contract implementation has not started. `.github/workflows/ci.yml`
exists locally and invokes full validation
for pull requests and pushes, but no run evidence is retained, so Phase 2 is not
complete. A separate local unsigned-preview workflow now wraps the native
release command with fresh-output immutability, portable release/update
manifests, exact SHA-256 coverage, eight positive/negative verifier fixtures,
release notes, and a consolidated changelog. A fresh macOS arm64 preview
candidate built and verified twice without mutation; a repeated wrapper call
was rejected with exit 69, and the lower-level command rejected the same
populated root without mutation. Exact local hashes, sizes, commands, and test
counts are retained in
[`PREVIEW_RELEASE_PROOF_2026-07-27.md`](PREVIEW_RELEASE_PROOF_2026-07-27.md).
This is local artifact evidence only: no remote workflow or hosted release
evidence is claimed.

Phase 1 implementation now includes a private six-state capability model,
honest daemon-to-state mapping, explicit host platform evidence,
plain-language capability-owned setup copy and actions, and structured Requests
automation mapping for running, configured/stopped, misconfigured, and
temporarily unavailable states. Requests remain saveable when automation is
degraded. The Town daemon lifecycle now supplies optional, structured
installation and platform evidence, so Requests can select all six
capability states without parsing status text; older responses retain their
prior mapping. The Home and Code setup surfaces now share the same six-state
classifier, plain-language summary, and action allowlist. Ordinary Home copy
contains no service, authority, daemon, platform, or installer vocabulary;
those exact diagnostics remain available in one closed `Technical details`
disclosure. Code now renders setup for every non-ready typed state, including
the previously unreachable temporarily-unavailable state when no status
response exists; the matching center layout row, retry action, stable state
key, and closed diagnostics appear together. Capability-focused tests pass
16/16, including independent public and technical subtree assertions and the
actual six-state Code renderer. The populated browser smoke retains a
`moondesk-first-use-copy-partial-proof.v1` fixture, and the matching
1440×900 screenshot was inspected at original resolution. That inspection
also exposed and removed a vague ready-state sentence from all six Code
details. This is bounded evidence for the rendered Home capability card, not
the complete rendered-copy audit. The authoritative English and Simplified
Chinese catalogs now cover the ordinary six-state Code-assistance eyebrow,
heading, titles, details, statuses, actions, and installation progress. Three
dead setup-topology keys were removed. The shared generator now preserves
exact-only accessibility-attribute translation and locale-specific system
language labels. The 26-string ordinary Code-assistance slice now also has
explicit `data-i18n` ownership in its three MoonBit render/model sources:
eyebrow, heading, titles, details, statuses, actions, installing label, and
progress sentence. Exhaustive typed state/action mappings use the exact catalog
keys, the technical disclosure owns none of those keys, and a source-extraction
test requires exact source/catalog parity plus generated Simplified Chinese
resolution for every key. Regeneration is reproducible, and localization
passes 5/5. This is one bounded source-owned migration, not the complete
rendered-literal and localization audit. The phase also
includes a private five-state cold-start classifier and honest Desk
first-use presentation, and 4/4 focused tests. A single navigation-vocabulary
source now drives the title bar, Pages activity rail, workspace summaries, and
high-level command palette. The seven primary destinations are distinct and
ordered Home, Pages, Code, Requests, Runs, Review, Publish; Flow and Packs are
secondary Commands destinations. Pages retains only Pages, Search, Inbox, and
Settings. Exact primary deep links, legacy aliases, Meta/Control+1 through +7,
and the compact disclosure are covered. A real
choose-library contract is now implemented with native manifest grants,
validated/persisted host activation, cancellation/error handling, and focused
host/UI tests. The browser-host clean-workspace quickstart now passes creation,
Pages save/reload, a canonical Code turn, honest Review/Publish zero states,
host restart, transcript restoration, and durable file-byte checks. Populated
and empty-library browser smokes also pass. The populated smoke now covers the
specified 1440×900, 1024×768, 390×844, and 320×700 viewports, with the narrow
case checking document overflow, pane overlap/order, table overflow, and
above-fold primary content. It also uses real CDP key events to open a
disclosure, close it with Escape, restore summary focus, and activate Pages
navigation. The clean-workspace quickstart now also completes its first useful
task entirely from natural document focus: real CDP Tab/Shift+Tab traversal
reaches the accessible book fields, creates and selects a MoonBook, opens
Pages and its Inbox composer, types a note, and saves durable Markdown with
Space/Enter activation. Its bounded focus trace contains 73 ordered entries,
and the same journey retains hard-reload and host-restart persistence proof.
The populated journey also proves the browser-zoom reflow
equivalent of a 1440×900 window at 200%: the exact 720×450 CSS viewport has no
document overflow or pane overlap, keeps the primary browser content
above-fold, preserves pane order and table confinement, and keeps the compact
primary destination control visible and keyboard-focusable. A separate
text-only 200% path now doubles the computed font size of all 401 rendered HTML
elements without changing viewport dimensions or device scale. At both
1440×900 and 320×700 it proves exact viewport/document widths, no horizontal
overflow or pane overlap, the correct desktop/compact primary navigation, and
unclipped headings, selected book, current path, history controls, and primary
folder actions. Its screenshots were visually inspected after repairing shell
grid containment, toolbar wrapping, inspector wrapping, and header ownership of
the language selector. A distinct one/many-book keyboard matrix now exercises
one selected MoonBook in the clean-workspace fixture and four choices in the
populated fixture at exactly 1440×900, 1024×768, 390×844, and 320×700. All
eight cases begin from natural document focus, use real Tab/Shift+Tab and
alternating Space/Enter events, preserve or deliberately round-trip focus,
prove row DOM/visual order, expose exactly one `aria-pressed="true"` choice,
agree with active class, URL, header identity, and Home content, and retain
the correct desktop/compact navigation without horizontal overflow or pane
overlap. All eight focused PNGs were visually inspected; the same combined run
passed the full populated smoke and clean-workspace hard-reload/host-restart
journey. The shared application shell now renders a native skip link, exactly
one named `main` landmark in every primary destination, two intentionally
duplicated and named navigation landmarks at desktop/compact breakpoints, and
one selected predicate shared by visual state, `aria-pressed`, and
`aria-current`. Destination changes have a factual polite/atomic announcement.
The eight typed state surfaces use isolated polite/atomic announcements whose
technical disclosures remain outside the live node. The current isolated
screen-reader proof covers 18 route cases—Home, Pages, Code, Requests, Runs,
Review, Publish, Flow, and Packs at 1440×900 and 390×844—plus the Commands
dialog at both viewports and two exact live-region sequences. Every route
requires one named main, one visible named primary navigation, coherent
selected/current state, an H1-led heading sequence, no unnamed actions or
exposed decorative glyphs, no duplicate role/name landmarks, and no shifted or
overflowing viewport. The nine-change destination trace is exact and ignores
Home Refresh; Pages emits exactly Loading → RecoverableError → Loading →
LegitimateZero without mutating the destination live region. Eight retained
PNGs were inspected. That work found and fixed unnamed complementary
landmarks, missing route H1s, an unnamed directory preview tab, exposed
palette/chevron glyphs, compact disclosure focus, and stale Flow/Packs header
rows. Four real-VoiceOver transcript rows remain pending after the user asked
to skip the system-caption capture. This is therefore strong semantic and
interaction automation, not a claim of spoken VoiceOver quality or complete
page-level focus order. The empty-library
smoke additionally traverses Requests, Runs,
Review, and Publish and keyboard-operates the compact destination control at
320×700. Runs distinguishes no book from no history; Publish does not claim
that generated output exists. The packaged macOS picker now has real
app-owned-panel, cancellation, exact rejection, valid-selection, and persisted
root evidence. Relaunch without pressing **Refresh** restores that root and its
ready book on the first rendered state. Every non-macOS platform remains open.
The configured-empty-library keyboard path through the first durable task is
complete at 1440×900, and the bounded one/many-book selection matrix is
complete at all four specified viewports. The responsive state matrix beyond
those bounded Home/cardinality cases, complete page-level focus order,
focused manual screen-reader, and packaged native keyboard gates remain open. See
[`NATIVE_LIBRARY_PICKER_ACCEPTANCE_2026-07-27.md`](NATIVE_LIBRARY_PICKER_ACCEPTANCE_2026-07-27.md).
The shared eight-state surface contract now has typed integrations in Home
file listing, selected file/page preview, Pages search, Review, Requests, Runs,
Publish, and Code session listing. Home file listing binds every response to the workspace, directory,
and monotonically increasing request generation that issued it. It ignores
stale navigation and superseded same-folder responses, clears rows when
changing location, and retains same-folder rows only while loading or after a
failed refresh. It distinguishes first use, loading, explicit empty success,
ready rows, stale retained rows, and recoverable failure. Review
distinguishes explicit empty success
from fetch failure and retains prior items as stale during a failed refresh.
Requests likewise distinguishes honest zero from failure, retains stale
records, keeps ledger errors separate from composer feedback, and leaves
request staging usable when automation is degraded. Runs now enters Loading on
explicit and automatic book selection, selects legitimate zero only after a
successful empty response, retains failed-refresh evidence as Stale, and uses
RecoverableError when no records exist. Publish independently distinguishes
readiness loading, explicit zero, ready queue evidence, stale retained
evidence, and recoverable failure; it cannot expose its output check after a
failed empty fetch. Raw errors remain behind Technical details. Code session
listing now distinguishes first use, active loading, successful
zero, ready rows, stale retained rows, and recoverable failure without
conflating transport state with runtime capability or canonical conversation
state. Its empty-group and empty-search copy appears only after a successful
listing. Selected preview now binds every response to workspace, path, and
monotonic generation, ignores late old-path and superseded same-path results,
retains same-path evidence during refresh and stale failure, and keeps host
diagnostics inside Technical details. Desk and Pages preview rendering no
longer infer transport state from English status text. The UI suite now passes
402/402; remaining primary-surface state integrations remain open.

See [Executable Book Architecture](EXECUTABLE_BOOK_ARCHITECTURE.md) for the
cross-repo product boundary: MoonBook owns executable books, MoonDesk owns the
human desktop shell, MoonTown owns scheduling and book-to-book coordination, and
MoonClaw owns bounded execution.

## Summary

MoonDesk is a usable local desktop shell for a single operator working against
selected MoonBook workspaces and explicitly configured MoonTown/MoonClaw
services. It has a Lepusa-hosted macOS bundle path, a browser development path,
a Rabbita desktop UI, scoped host APIs, MoonWiki book navigation, MoonCode
book-scoped coding/chat surfaces, MoonTown request/standing-goal surfaces,
daemon controls, and reusable book/tool scaffolding.

Domain-specific experiments have been removed from MoonDesk core. They are
useful as stress tests for information discovery and app-tool generation, but
they do not belong in the desktop shell. Similar domain workflows should now be
standalone MoonBook/MoonClaw skill or app-tool packs that MoonDesk can create,
configure, inspect, export, and launch through generic interfaces.

## Functional Readiness

| Area | Status | Notes |
| --- | --- | --- |
| Workspace discovery and Desk | Working | Discovers MoonBooks under `books`, exposes the active MoonSuite root when no MoonBooks exist yet, projects MoonBook virtual sections at the root, lists scoped entries with file metadata, shows directory breadcrumbs, entry counts, selection/access state, and opens common book paths. Plain folders are not advertised as workspaces. |
| Library selection | Working on macOS; other platforms open | A fresh packaged macOS build exposes an app-owned native panel. Real cancellation preserves the current library; an individual MoonBook is rejected with the host’s exact corrective message; a valid fixture library activates, lists its ready book, updates subsequent API requests, and persists its canonical root under the stable bootstrap location. The initial bootstrap waits until the UI runtime is mounted, and cold-start failure retries only the startup data-fetch batch without requiring manual Refresh or duplicating one-time observers. Relaunch restores the saved root and book on the first rendered state. Focused and full regressions pass. Other supported desktop platforms remain open. |
| Previews and raw files | Working | Markdown, HTML/site, JSON, image, text, and artifact previews are available through scoped routes. |
| Inbox notes, imports, and Markdown edits | Working | Creates markdown inbox notes, edits scoped `inbox/*` paths, saves scoped MoonWiki Markdown under `wiki/*` with live preview, imports URL/data-url content, and stages local file picker/drop/paste imports. |
| Search and context assembly | Working | Cross-book text search, favorites, recent paths, copy-to-inbox, saved views, path tags, review queues, and review diff summaries are present. |
| MoonTown submissions | Working | Stages request records, shows request ledger/town messages, creates standing-watch records, registers standing goals, runs daemon ticks, and exposes progress/event/review summaries. |
| Book pattern builder | Working | Uses a generic desktop book-pattern builder shell, a generic `/api/books/from-pattern` dispatcher, and a centralized built-in pattern registry for base type, creation backend, skills, template refs, output files, and standing-watch capability. The currently supported built-in pattern creates reusable PDF Evidence Watch `research-book` workspaces with source websites, cadence, notification rule, method page, skill pack, schemas, generated site placeholders, config JSON, publish receipts, and standing-watch registration. Missing or unsupported pattern ids are rejected instead of silently remapped to PDF Evidence Watch. |
| Domain-specific book packs | External by design | MoonDesk no longer ships built-in domain packs. Financial, policy, patent, academic-paper, standards, or other watch books should be distributed as standalone book/tool packs. |
| Portable app-tool export | Working | Exports app-tool books into `portable/app-tool/` with served entrypoint, manifest, copied assets, generated-site assets, discovered HTML/CSS/JS asset dependencies, skills, schemas, a portable offline API runtime where possible, and `serve.py` / `run-local.command` launchers. It also detects generated app books with `app/index.html` so experiments can be packaged standalone without domain-specific MoonDesk code. Export rewrites local root-absolute asset links such as `/assets/...` to bundle-relative paths so the same generated app can run in MoonDesk preview and in the standalone static host. Export success is separate from launch readiness: bundles with unsupported API calls are marked `auto_open_allowed: false` and are kept as inspection-only until the pack or generic runtime is fixed. Run the local static host or a native shell; raw `file://` opening is not a supported runtime for generated JavaScript modules. |
| MoonCode workspace | Working | Provides book-scoped coding/chat sessions, runtime queues, tool approval/readiness surfaces, change review, tests, package/export views, and MoonClaw daemon/model inspection. MoonClaw owns the runtime event log and command queue; MoonDesk keeps desktop projection records for UI state. Coding-intent prompt completion is now evidence-gated in the native runtime: model and explicit batches require mutation plus typed verification after the final change and every failure, requested tests require typed test proof, and the structured verdict controls completed versus failed terminal receipts. |
| Native app bundle | Working | `cmd/main bundle` creates a Lepusa-hosted `MoonDesk.app` with a bundled Lepusa runtime and bundled `moondesk-sidecar` supervised as the MoonDesk localhost service. Copy/configuration steps are ordered, integration failures stop the outer command with exit 1, a fresh positive package build completed cleanly, and a missing-UI negative build emitted no false success. The stale direct AppKit/WebKit launcher and browser-shell bundle paths have been removed; browser-based development uses `serve` or `desktop`. |
| Release distribution | Reproducible unsigned preview proven locally; production open | `cmd/main release` now returns failure for missing bundle/archive/runtime/DMG/hash/metadata prerequisites, refuses a nonempty release output, and writes portable release-root-relative metadata. `scripts/preview_release.sh` builds into a fresh path, generates exact sorted checksums once, and verifies the app, zip, DMG, runtime manifest, metadata, and notes twice. The local candidate and eight verifier fixtures pass. Remote tag evidence, Developer ID credentials, notarization, hosted updates, clean-machine validation, rollback, and long-running reliability proof remain open. |

## Current Product Boundary

MoonDesk should stay generic:

- create/configure/edit books and app-tools
- render MoonWiki and MoonCode surfaces
- route user intent to MoonTown and MoonClaw
- show files, previews, diffs, logs, receipts, and readiness
- export portable per-book app-tool bundles
- package generated domain experiments as external served app-tool artifacts

MoonDesk should not own:

- market-specific seed lists
- domain schemas that age over time
- domain output workbooks
- scraping/extraction logic for one vertical
- source-discovery prompts that belong to MoonClaw skills
- acceptance rules that belong to MoonBook/Bookkeeper

That split keeps old experiments from becoming product debt.

Old domain experiments used during testing belong outside this repository as
external packs. They are useful for validating whether MoonClaw can discover
sources and generate an app/tool, but failures in a generated app should be
fixed in that pack or in the generic app-tool runtime, not by adding market
logic, seed lists, or domain APIs back into MoonDesk. The generic portable
runtime now supports copied book-file reads through read-only workspace
`raw`, `file`, `site`, and `preview` API shapes; unsupported domain APIs still
block `auto_open_allowed` so broken app packs are visible instead of pretending
to be launchable. Portable bundles also resolve copied files relative to the
injected runtime script, which lets the same generated app run inside
MoonDesk's nested preview route and as a standalone served static bundle.

The boundary validator enforces this across MoonDesk, MoonClaw, MoonBook, and
MoonTown. Market-specific examples must remain in external packs even when they
are useful regression fixtures; product runtime code and core docs should keep
only generic book-pattern, MoonCode, MoonWiki, and app-tool contracts. Cross-repo
validation requires explicit checkout roots through `MOONCLAW_ROOT`,
`MOONBOOK_ROOT`, and `MOONTOWN_ROOT`; MoonDesk tooling should not assume sibling
repository layout or local-machine executable paths. Put `moon` on `PATH`, or
set `MOON=/path/to/moon` when running validation from an environment without a
MoonBit CLI path.

## Validation Commands

Use these checks before handoff:

```sh
moon fmt
moon check --target all --warn-list +unnecessary_annotation --diagnostic-limit 1000
moon test --target native --warn-list +unnecessary_annotation --diagnostic-limit 1000
moon info --target native
moon info --target js
(cd ui/rabbita-desk && moon check --target js --warn-list +unnecessary_annotation --diagnostic-limit 1000)
npm --prefix ui/rabbita-desk run build
git diff --check
MOONCLAW_ROOT=/path/to/moonclaw MOONBOOK_ROOT=/path/to/moonbook MOONTOWN_ROOT=/path/to/moontown scripts/validate-core-boundaries.sh
```
