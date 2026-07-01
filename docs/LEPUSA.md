# Lepusa Integration

Moondesk keeps the current desktop shell intact while Lepusa becomes the native
host boundary. The integration is intentionally isolated under
`desktop/lepusa/moondesk/` and exposed through `cmd/main lepusa`.

The default Lepusa manifest is:

```text
desktop/lepusa/moondesk/lepusa.json
```

It points at a small packaged static app in:

```text
desktop/lepusa/moondesk/dist/
```

## Commands

Run from the Moondesk repository:

```bash
moon run cmd/main --target native -- bundle --skip-sign --no-archive
moon run cmd/main --target native -- lepusa smoke macos --strict
moon run cmd/main --target native -- lepusa live-smoke macos --strict
moon run cmd/main --target native -- lepusa live-build macos --strict
moon run cmd/main --target native -- lepusa live-session macos --strict
moon run cmd/main --target native -- lepusa live-launch macos --strict
moon run cmd/main --target native -- lepusa live-bundle-check macos
moon run cmd/main --target native -- lepusa bundle-check macos
moon run cmd/main --target native -- lepusa verify macos --strict
moon run cmd/main --target native -- lepusa run macos
moon run cmd/main --target native -- lepusa bundle-plan macos
moon run cmd/main --target native -- lepusa build macos
moon run cmd/main --target native -- lepusa asset
moon run cmd/main --target native -- lepusa runtime-session macos
moon run cmd/main --target native -- lepusa runtime-launch macos
moon run cmd/main --target native -- lepusa runtime-asset
moon run cmd/main --target native -- lepusa launch-session macos
moon run cmd/main --target native -- lepusa launch macos
```

The fresh MoonSuite layout smoke seeds a temporary workspace with a MoonBook
under `books/`, including `book/moonbook-ui-state.json` and
`book/site/generated/index.html`, then runs Lepusa `live-smoke` against that
root:

```bash
scripts/lepusa_fresh_books_smoke.sh
```

`bundle` is Lepusa-only. It builds `moondesk-lepusa.app` under the selected
`--out` directory, starts from the generated localhost manifest, and forwards
the bundle workspace/UI choices into that manifest:

```bash
moon run cmd/main --target native -- bundle .. --ui ui/rabbita-desk/dist --out dist --port 4199
```

`release` builds through the same Lepusa path and writes release metadata that
records `native_host: "lepusa"`, `native_window: true`, plus the generated
`Contents/Resources/lepusa/runtime.json` path and hash.

By default `bundle` uses the published Lepusa dependency fetched under
`.mooncakes/vectie/lepusa`. Point it at a local checkout with:

```bash
moon run cmd/main --target native -- bundle --lepusa /path/to/lepusa
```

The old direct AppKit/WebKit native launcher and browser-shell bundle paths are
removed. Native packaging now goes through Lepusa. Use `serve` or `desktop` for
browser-based development.

`smoke` is the preferred integration gate. It builds Lepusa's native runtime,
verifies the integration `lepusa.json`, writes the native bundle, checks the
generated runtime launch session, and resolves the packaged asset from the
generated runtime manifest. It then runs `bundle-check` to prove the generated
app carries the launcher, bundled runtime, bundled Moondesk sidecar, runtime
manifest, platform metadata, and packaged entrypoint it needs to start without
resolving a global `lepusa-runtime`. It does not open a long-running window, so
it is suitable for repeatable local validation.

`live-smoke`, `live-build`, `live-session`, `live-launch`, and
`live-bundle-check` generate a temporary `lepusa.json` under the selected build
directory and use a `localhost` source instead of packaged static assets. The
generated manifest launches the bundled Moondesk sidecar with:

```text
<app>/Contents/MacOS/moondesk-sidecar serve <workspace-root> --ui <ui-dir> --host 127.0.0.1 --port <serve-port>
```

The wrapper builds `cmd/main` as the sidecar and copies it into the generated app
bundle after Lepusa writes the bundle. This proves Lepusa can carry Moondesk as a
supervised localhost sidecar without requiring `moon run` at app launch time. Use
`live-smoke` for a repeatable non-window test, `live-build` to write the
standalone bundle, `live-session` to inspect the generated launch session, and
`live-launch` to open the generated native-hosted Moondesk app. Override the
development sidecar port with:

```bash
moon run cmd/main --target native -- lepusa live-build macos --serve-port 4512
```

The generated live manifest uses `/__moondesk_health` as the sidecar readiness
path. That endpoint returns a small JSON payload with the service name,
normalized UI root, and workspace root, so Lepusa can wait for the host without
depending on the full app page load.

Override the workspace or UI used by the generated sidecar with:

```bash
moon run cmd/main --target native -- lepusa live-build macos --workspace-root .. --ui ui/rabbita-desk/dist
```

The wrapper defaults to the published Lepusa dependency fetched under
`.mooncakes/vectie/lepusa`. Override it with:

```bash
moon run cmd/main --target native -- lepusa verify macos --lepusa /path/to/lepusa
```

`build`, `bundle-write`, and the `live-*` build commands default to
`_build/lepusa/moondesk`, which stays out of source control. Override it with:

```bash
moon run cmd/main --target native -- lepusa live-build macos --out /tmp/moondesk-lepusa
```

`asset` resolves the packaged integration entrypoint by default:

```text
lepusa://packaged/main/index.html
```

Override the asset checked by `asset`, `runtime-asset`, or `smoke` with:

```bash
moon run cmd/main --target native -- lepusa smoke macos --asset lepusa://packaged/main/app.css
```

After `build` or `live-build`, `runtime-session`, `runtime-launch`, and
`runtime-asset` use the generated bundle manifest by default. For macOS that
path is:

```text
_build/lepusa/moondesk/moondesk-lepusa.app/Contents/Resources/lepusa/runtime.json
```

Override it with `--manifest` when checking another built bundle.

`build` first builds Lepusa's `cmd/runtime` binary, then writes the packaged
static Moondesk Lepusa app. `live-build` builds the same native bundle shape but
uses the generated localhost manifest so the app opens the current Moondesk
workspace server. On macOS the generated `.app` includes
`Contents/MacOS/lepusa-runtime`, so the launcher no longer depends on a globally
installed runtime. The launcher still falls back to `PATH` for older or
manually assembled bundles.

Run the generated app executable directly when you want to open the native
window without going through the wrapper:

```bash
_build/lepusa/moondesk/moondesk-lepusa.app/Contents/MacOS/moondesk-lepusa
```

Equivalent wrapper command:

```bash
moon run cmd/main --target native -- lepusa live-launch macos
```

## Boundary

This is a standalone adapter, not a UI migration:

- Moondesk owns the product workflow and existing server/runtime.
- Lepusa owns native WebView planning, launch readiness, and bundle contracts.
- The Moondesk Lepusa app is app-neutral and contains no MoonBook or domain-specific
  logic.
- The existing Rabbita UI package is not modified by this integration.
