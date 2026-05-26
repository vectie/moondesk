# Moondesk Status

Last validated: 2026-05-26.

## Summary

Moondesk is a usable local alpha for a single operator working against an
existing Moontown/MoonBook/MoonClaw checkout. The desk, scoped host APIs,
Moontown request flow, managed daemon lifecycle controls, and self-contained
macOS bundle all have working implementations. The latest slice replaces the
browser-shell-only package with a native AppKit/WebKit window launcher, keeps a
browser-shell fallback via `bundle --shell browser`, and includes
release/update manifests, DMG creation, LaunchAgent install/remove/status
flows, event/failure/review queues, local file import staging, richer review
diffs, expanded operating analytics, and a Codex-like Agents activity.

The current `.app` is a foreground native macOS window. The bundle executable
is an AppKit/WebKit launcher, and the MoonBit HTTP host runs as an internal
`moondesk-host` helper from the same bundle. Browser dev mode remains available
through `serve`/`desktop` and as an explicit fallback shell.
Developer ID notarization is wired through `cmd/main release`, but real
distribution still depends on external Apple credentials, update hosting, and
clean-machine validation.

## Standalone App Answer

Moondesk is standalone at the host/package level and now owns a native macOS
window in the packaged app.

- Standalone today: `cmd/main bundle` creates `Moondesk.app` with a native
  AppKit/WebKit launcher, the internal `moondesk-host` MoonBit executable, and
  bundled UI assets. Launching the bundle does not require `moon run`, Cargo,
  Rust, Tauri, or a dev server.
- Windowing decision: the bundled app opens a real macOS window and loads the
  local Rabbita UI in WebKit. `bundle --shell browser` preserves the previous
  browser-shell behavior for fallback/debug use.
- Release-ready shape exists: `cmd/main release` creates a release manifest,
  update manifest, zip, and DMG, verifies signing, and can submit the zip
  through Apple notarytool when a real keychain profile is supplied.
- Production distribution dependency: a real notarized artifact still requires
  Developer ID credentials, hosting the update manifest/artifacts, and validating
  the installed app on a clean machine.

## Functional Readiness

| Area | Status | Notes |
| --- | --- | --- |
| Workspace discovery and explorer | Working | Discovers MoonBooks under `.moontown/books`, lists scoped entries, and opens common book paths. |
| Previews and raw files | Working | Markdown, HTML/site, JSON, image, text, and artifact previews are available through scoped routes. |
| Inbox notes | Working | Creates markdown inbox notes, edits scoped `inbox/*` paths, imports URLs/data-url attachments, and stages local file picker/drop/paste imports into `inbox/imports`. |
| Search and context assembly | Working first slice | Cross-book text search, favorites, recent paths, copy-to-inbox, saved views, path tags, review queues, and review diff summaries are present. Richer output-library navigation can still be refined. |
| Moontown submissions | Working first slice | Stages request records, shows request ledger and town messages, creates standing-watch records, runs one daemon tick, and exposes progress plus event/failure/review summaries. |
| MoonClaw agent sessions | Working | The Agents activity lists per-book sessions, starts or connects to the MoonClaw daemon through a native MoonClaw executable, creates/reuses the book-scoped task for the workspace root, sends contextual user messages, folds saved MoonClaw assistant/tool/failure events and workspace `.moonclaw/log.jsonl` progress rows into the transcript, supports web-search/model selection, cancels active task work, and persists local session metadata under `.moontown/moondesk-agent-sessions/`. |
| Background daemon lifecycle | Working | UI/API support status, start, stop, restart, desired-state supervision policy, reconcile-on-status restart, LaunchAgent install/remove/status, persisted state, and log paths under `.moontown/moondesk-daemon/`. Log rotation and multi-root daemon governance are still hardening work. |
| MoonClaw run/artifact projection | Working first slice | Lists visible run workspaces and common artifacts, aggregate progress counts/latest run status, event records, result summaries, and failure/review signals. |
| Daily operating surface | Working first slice | Shows counts, cadence list, due-tick calendar, watcher outcome mix, browser notifications, saved views, tags, event/review analytics, review queue, and an ICS export. Trend charts and external calendar subscription polish are optional refinements. |
| Scoped desktop helpers | Working first slice | Finder reveal is scoped under the selected workspace. Browser launch is still implemented for `desktop` and `bundle --shell browser`. Local file picker/drop/paste import is staged through host APIs. Open-with-external-app remains future polish. |
| Native packaging | Working local distribution | `bundle` builds the native MoonBit host helper plus an AppKit/WebKit launcher, copies bundled UI resources, writes absolute runtime config, signs with `codesign` by default, creates a zip, and bundled launch opens a native window. `release` writes release/update manifests, verifies signing, creates a DMG, and can submit the archive through `xcrun notarytool --keychain-profile`. |

## How Far To Fully Functioning

| Target | Readiness | Meaning |
| --- | --- | --- |
| Local native-window daily use | 95% | The planned M0-M7 workflow is implemented for a single operator: browse, preview, search, inbox/import, submit, talk to MoonClaw in book-scoped sessions, supervise daemon actions, inspect runs, use saved views/tags/review queues, and export cadence. |
| Self-contained local `.app` bundle | 95% | The bundle contains the AppKit/WebKit launcher, internal native MoonBit host, and UI assets, launches without `moon run`, declares native-window mode, and has release/update manifests plus DMG output. |
| Production native-window desktop app | 85% | Core data plumbing, local workflow surfaces, release packaging, native windowing, and daemon install UX exist. Remaining work is mostly real credentialed notarization, artifact hosting/update policy, clean-machine validation, and long-running reliability testing. |
| Multi-user or organization-grade deployment | 50% | There is not yet a hardened permissions model, fleet distribution, remote policy, multi-root daemon governance, audit log, or support/update story. |

The practical answer: Moondesk is already useful as a local single-user alpha
and close to functionally complete for the native-window desktop target. It now
matches the core Codex-style packaging shape: a normal macOS app window backed
by a bundled local host.

Current assessment after the M7 agent-console pass:

- Feature-complete for local single-user native-window use except daily-use
  polish and long-running reliability hardening.
- Standalone as a self-contained local `.app`; production distribution still
  depends on real signing/notarization credentials, hosted update artifacts,
  and clean-machine validation.
- Not organization-grade yet because multi-root governance, hardened
  permission policy, audit trails, remote policy, and support/update operations
  are not implemented.

## Remaining Work

High-priority work before calling it production-ready:

- Run the `release` notarization path with real Developer ID credentials and
  validate the DMG/zip on a clean macOS account.
- Host `updates.json` and artifacts somewhere durable, then decide whether
  Moondesk only publishes update metadata or also owns an in-app updater.
- Add log rotation and multi-root policy for long-running LaunchAgent use.
- Reconcile Moondesk-managed daemon state with any independently running
  Moontown daemon.
- Deepen output-library navigation, direct MoonClaw SSE event-stream rendering
  beyond the current saved/logged event projection, trend analytics, and
  calendar subscription polish after more real workspace usage.

## Full Functioning Criteria

Moondesk can be called fully functioning for the intended single-user desktop
scope when these are true:

- A user can install and launch it without a terminal. Implemented for bundle
  creation; still needs clean-machine validation.
- Native AppKit/WebKit windowing is the default packaged desktop shell.
  Implemented. Browser-shell launch remains available as fallback.
- The shipped artifact is signed, notarized, and reproducible from documented
  release commands. Implemented except for real credentialed notarization.
- The daemon can be installed, supervised, inspected, and removed from the UI.
  Implemented for the Moontown LaunchAgent and Moondesk-managed daemon loop.
- A user can talk to MoonClaw from Moondesk in the selected book/workspace
  context. Implemented through the Agents activity and `/api/agents/*` bridge.
- Inbox import covers URL, text/data URL, file picker, drag/drop, and pasted
  files/images. Implemented as staged inbox imports.
- Moontown/MoonClaw progress includes event records and actionable failure/review
  states. Implemented as polling summaries, queues, and agent transcript
  projection from saved/logged MoonClaw events.
- Search, saved views, tags, run artifacts, output libraries, and review/diff
  workflows are usable for repeated daily work. Implemented first slices; polish
  continues with real use.
- The validation checklist below passes on a fresh machine or clean workspace.

## Current Validation Checklist

The current tree should be considered healthy when these pass:

```sh
moon check
moon test
moon info
moon -C ui/rabbita-desk check --target js
npm --prefix ui/rabbita-desk run build
moon run cmd/main -- release ../moontown --ui ui/rabbita-desk/dist --out /tmp/moondesk-release-check --port 4299 --skip-sign --no-dmg
moon run cmd/main -- bundle ../moontown --ui ui/rabbita-desk/dist --out /tmp/moondesk-native-bundle-check --port 4299
codesign --verify --deep --strict /tmp/moondesk-native-bundle-check/Moondesk.app
```

Manual smoke checks:

- `GET /api/town/daemon/status` returns daemon state.
- `POST /api/town/daemon/supervision` persists desired-state policy.
- `GET /api/town/progress` and `GET /api/moonclaw/progress` return live
  summaries.
- `GET /api/town/events`, `GET /api/moonclaw/events`, and
  `GET /api/review/items` return event/review projections.
- `GET /api/workspaces/:id/review-diff?path=...` returns a line-level review
  comparison for review files.
- `GET|POST /api/town/daemon/agent` reports and manages the Moontown
  LaunchAgent install state.
- `GET /api/agents/daemon`, `GET /api/agents/models`, and
  `GET /api/agents/sessions?workspace=...` return MoonClaw agent state.
- `POST /api/agents/sessions` starts a book-scoped MoonClaw task and sends the
  initial message.
- `POST /api/agents/sessions/:id/message` sends a follow-up contextual message.
- `POST /api/agents/sessions/:id/cancel` cancels active MoonClaw task work.
- `GET /api/town/calendar.ics` returns a valid calendar payload.
- `POST /api/town/daemon/start` starts the Moontown daemon.
- `POST /api/town/daemon/stop` stops it and final status reports `running:
  false`.
- Running `open Moondesk.app` from outside the repo opens the native window,
  starts `Contents/MacOS/moondesk-host`, serves bundled UI resources, and can
  still reach the configured workspace root.
