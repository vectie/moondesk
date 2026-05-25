# Moondesk Status

Last validated: 2026-05-25.

## Summary

Moondesk is a usable local alpha for a single operator working against an
existing Moontown/MoonBook/MoonClaw checkout. The browser-hosted desk, scoped
host APIs, Moontown request flow, managed daemon lifecycle controls, and
self-contained macOS bundle all have working implementations. The latest slice
adds explicit browser launch for desktop/bundled runs, supervised daemon
policy, live progress summaries, URL/import inbox staging, saved views, tags,
calendar export, and a repeatable release/notarization command path.

It is not yet a polished Codex-style desktop app. The current `.app` is a
self-contained native MoonBit host that serves the Rabbita UI from bundled
resources and opens the browser explicitly rather than owning a native WebView
window. Developer ID notarization is wired through `cmd/main release`, but real
distribution still depends on external Apple credentials and release policy.

## Functional Readiness

| Area | Status | Notes |
| --- | --- | --- |
| Workspace discovery and explorer | Working | Discovers MoonBooks under `.moontown/books`, lists scoped entries, and opens common book paths. |
| Previews and raw files | Working | Markdown, HTML/site, JSON, image, text, and artifact previews are available through scoped routes. |
| Inbox notes | Working first slice | Creates markdown inbox notes, edits scoped `inbox/*` paths, and imports URLs/data-url attachments into `inbox/imports`. Binary drag/drop, pasted image decoding, and richer metadata are still pending. |
| Search and context assembly | Working first slice | Cross-book text search, favorites, recent paths, copy-to-inbox, saved views, and path tags are present. Review/diff workflows and richer output-library navigation are pending. |
| Moontown submissions | Working first slice | Stages request records, shows request ledger and town messages, creates standing-watch records, runs one daemon tick, and exposes live progress summaries. Deeper Moontown acknowledgement/event streams are still pending. |
| Background daemon lifecycle | Working first slice | UI/API support status, start, stop, restart, desired-state supervision policy, and reconcile-on-status restart for `moon run cmd/main -- daemon run`; state and logs are persisted under `.moontown/moondesk-daemon/`. LaunchAgent template generation exists; full launchctl install UX, log rotation, and multi-root daemon policies are pending. |
| MoonClaw run/artifact projection | Working first slice | Lists visible run workspaces and common artifacts, plus aggregate progress counts/latest run status. Live event streaming and richer failure triage are pending. |
| Daily operating surface | Working first slice | Shows counts, cadence list, due-tick calendar, watcher outcome mix, browser notifications, saved views, tags, and an ICS export. Trend charts and external calendar subscription polish are pending. |
| Scoped desktop helpers | Working first slice | Finder reveal is scoped under the selected workspace. Explicit browser launch is implemented for desktop/bundled runs. Open-with-external-app, drag/drop from Finder, and clipboard image ingestion are pending. |
| Native packaging | Working local distribution | `bundle` builds a native MoonBit executable, copies bundled UI resources, writes absolute runtime config, signs with `codesign` by default, creates a zip, and bundled launch opens the browser. `release` writes a manifest and can submit the archive through `xcrun notarytool --keychain-profile`. DMG/install flow, auto-update, and native window ownership are pending. |

## How Far To Fully Functioning

For local browser-hosted use, Moondesk is roughly 90 percent of the planned
M0-M6 scope: M0-M4 are functionally complete for local use, and M5-M6 now have
usable first slices for saved views, tags, progress, calendar export, and daily
operations.

For a production desktop app comparable to Codex, Moondesk is closer to 70
percent: the host, UI, local APIs, daemon controls, supervision policy, and
self-contained bundle exist, but the remaining work is product hardening,
native window ownership, signed release operations, and long-running reliability
rather than core data plumbing.

## Remaining Work

High-priority work before calling it fully functioning:

- Add a native WebView/window shell if Moondesk should feel fully standalone
  instead of browser-launched.
- Run the `release` notarization path with real Developer ID credentials and
  decide the DMG/install/auto-update policy.
- Turn the LaunchAgent template into a user-facing install/uninstall flow.
- Reconcile Moondesk-managed daemon state with any independently running
  Moontown daemon.
- Add event-stream progress projection from Moontown and MoonClaw, including
  clearer failure states.
- Add drag/drop file import, pasted image decoding, and richer metadata controls
  for the inbox.
- Add richer output library navigation and review/diff workflows.
- Add trend analytics and calendar subscription polish.

## Current Validation Checklist

The current tree should be considered healthy when these pass:

```sh
moon check
moon test
moon info
moon -C ui/rabbita-desk check --target js
npm --prefix ui/rabbita-desk run build
moon run cmd/main -- bundle ../moontown --ui ui/rabbita-desk/dist --out /tmp/moondesk-native-bundle-check --port 4299
codesign --verify --deep --strict /tmp/moondesk-native-bundle-check/Moondesk.app
```

Manual smoke checks:

- `GET /api/town/daemon/status` returns daemon state.
- `POST /api/town/daemon/supervision` persists desired-state policy.
- `GET /api/town/progress` and `GET /api/moonclaw/progress` return live
  summaries.
- `GET /api/town/calendar.ics` returns a valid calendar payload.
- `POST /api/town/daemon/start` starts the Moontown daemon.
- `POST /api/town/daemon/stop` stops it and final status reports `running:
  false`.
- Running `Moondesk.app/Contents/MacOS/moondesk` from outside the repo serves
  bundled UI resources and can still reach the configured workspace root.
