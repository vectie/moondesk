# MoonDesk Status

Last updated: 2026-06-30.

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
| Previews and raw files | Working | Markdown, HTML/site, JSON, image, text, and artifact previews are available through scoped routes. |
| Inbox notes, imports, and Markdown edits | Working | Creates markdown inbox notes, edits scoped `inbox/*` paths, saves scoped MoonWiki Markdown under `wiki/*` with live preview, imports URL/data-url content, and stages local file picker/drop/paste imports. |
| Search and context assembly | Working | Cross-book text search, favorites, recent paths, copy-to-inbox, saved views, path tags, review queues, and review diff summaries are present. |
| MoonTown submissions | Working | Stages request records, shows request ledger/town messages, creates standing-watch records, registers standing goals, runs daemon ticks, and exposes progress/event/review summaries. |
| Book pattern builder | Working | Uses a generic desktop book-pattern builder shell, a generic `/api/books/from-pattern` dispatcher, and a centralized built-in pattern registry for base type, creation backend, skills, template refs, output files, and standing-watch capability. The currently supported built-in pattern creates reusable PDF Evidence Watch `research-book` workspaces with source websites, cadence, notification rule, method page, skill pack, schemas, generated site placeholders, config JSON, publish receipts, and standing-watch registration. Missing or unsupported pattern ids are rejected instead of silently remapped to PDF Evidence Watch. |
| Domain-specific book packs | External by design | MoonDesk no longer ships built-in domain packs. Financial, policy, patent, academic-paper, standards, or other watch books should be distributed as standalone book/tool packs. |
| Portable app-tool export | Working | Exports app-tool books into `portable/app-tool/` with served entrypoint, manifest, copied assets, generated-site assets, discovered HTML/CSS/JS asset dependencies, skills, schemas, a portable offline API runtime where possible, and `serve.py` / `run-local.command` launchers. It also detects generated app books with `app/index.html` so experiments can be packaged standalone without domain-specific MoonDesk code. Export rewrites local root-absolute asset links such as `/assets/...` to bundle-relative paths so the same generated app can run in MoonDesk preview and in the standalone static host. Export success is separate from launch readiness: bundles with unsupported API calls are marked `auto_open_allowed: false` and are kept as inspection-only until the pack or generic runtime is fixed. Run the local static host or a native shell; raw `file://` opening is not a supported runtime for generated JavaScript modules. |
| MoonCode workspace | Working | Provides book-scoped coding/chat sessions, runtime queues, tool approval/readiness surfaces, change review, tests, package/export views, and MoonClaw daemon/model inspection. MoonClaw owns the runtime event log and command queue; MoonDesk keeps desktop projection records for UI state. |
| Native app bundle | Working | `cmd/main bundle` creates a Lepusa-hosted `MoonDesk.app` with a bundled Lepusa runtime and bundled `moondesk-sidecar` supervised as the MoonDesk localhost service. The stale direct AppKit/WebKit launcher and browser-shell bundle paths have been removed; browser-based development uses `serve` or `desktop`. |
| Release distribution | Hardening needed | `cmd/main release` creates zip/DMG/update metadata for the Lepusa app, including the generated `lepusa/runtime.json` path and hash, and can submit notarization when credentials exist; real production still requires Developer ID credentials, hosted updates, clean-machine validation, and long-running reliability proof. |

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
