# Pack app runtime discovery

MoonDesk discovers pack applications without importing domain code. Installed
pack manifests remain owned by each pack, and deployment-local runtime files
tell MoonDesk where those applications are currently served.

For each active pack pointer at:

```text
<workspace>/.moonsuite/packs/active/<pack-id>.json
```

an operator or local service may create:

```text
<workspace>/.moonsuite/pack-apps/<pack-id>.json
```

with this contract:

```json
{
  "contract": "moonsuite.pack-app-runtime.v1",
  "pack_id": "example-pack",
  "app_url": "http://127.0.0.1:4300/apps/example-pack/studio",
  "service_url": "http://127.0.0.1:4300"
}
```

`GET /api/desktop/pack-apps` joins the active pointer, installed `pack.json`,
and optional runtime configuration. Pack Home shows every valid installed pack,
including workflow-only packs and packs whose app service still needs setup.
This prevents "not running" from looking like "not installed."

Catalog entries have one of four operator-visible states:

- `configured`: the declared app is safely mounted and can be opened;
- `configuration_required`: the pack declares an app but has no runtime file;
- `configuration_invalid`: the runtime file is mismatched or unsafe;
- `workflow_only`: the pack deliberately has no standalone app entrypoint.

The generic MoonDesk launcher renders this catalog; it does not know any pack
id, domain route, provider, credential, or business rule. It also reports
manifest-declared workflow, tool, and app-surface counts so operators can tell
what was installed without opening implementation files.

Packs may also declare a generic Pack Home area in `pack.json`:

```json
{
  "app_area": {
    "id": "finance.example",
    "category": "finance",
    "label": "Finance"
  }
}
```

All three fields are required when `app_area` is present. `id` is a normalized
lowercase identifier that may use dots for namespacing, `category` is a
normalized lowercase pack-style identifier, and `label` is operator-facing
text. Pack Home displays the label and exposes the identifiers as generic data
attributes; it does not branch on known categories or pack ids. Existing
manifests may omit `app_area`. A malformed declaration fails closed and the
affected pack is excluded from the catalog rather than being silently assigned
to a guessed area.

Until the shared pack manifest codec preserves `app_area` during installation,
packs that need the area after installation also declare one evaluation
artifact:

```json
{
  "id": "moondesk-app-area",
  "version": "1.0.0",
  "path": "apps/app-area.json"
}
```

The referenced file uses the exact `moonsuite.pack-app-area.v1` contract and
contains the same `app_area` object. MoonDesk resolves this generically from the
installed pack root. The path must be normalized and relative, the resolved file
must remain inside that root, and duplicate, missing, malformed, or wrong-version
declarations fail closed. A preserved top-level `app_area` takes precedence, so
the compatibility artifact can be removed after the shared codec carries the
field end to end.

The launcher opens the same-origin `/pack-apps/<pack-id>/` route. MoonDesk
proxies only to an explicitly configured loopback `service_url`; this prevents
the desktop browser from navigating to a different origin and avoids exposing a
general-purpose server-side request proxy. Pack UIs use relative API/media URLs
so their subresources remain under the mounted route.

Runtime discovery is fail-closed. MoonDesk accepts only the exact
`moonsuite.pack-app-runtime.v1` contract, normalized lowercase pack ids, an
absolute traversal-free manifest entrypoint, and a loopback `app_url` that is
exactly `service_url + entrypoint_path`. Encoded path separators, dot segments,
userinfo-shaped authorities, remote hosts, and mismatched active-pointer file
names are rejected before proxying.

The runtime file is deliberately not part of pack installation. Ports and URLs
are environment/deployment concerns and can change without reinstalling a pack.
It is durable workspace state rather than daemon memory: MoonDesk rereads the
active pointer, manifest, and runtime file for every launch request. After a
MoonDesk restart it therefore recovers the same configuration, while an edited,
removed, stale, or newly unsafe record fails closed instead of being retained in
an in-memory cache.

## Visible operator flow

Pack Home is the normal entry surface:

```text
Packs → Open pack → pack-owned Rabbita application
      → Advanced controls → selected MoonBook composition in MoonFlow
```

Opening a pack follows its same-origin `launch_url`. Inspecting composition does
not open the pack UI; it opens the selected MoonBook's typed graph, where the
operator can include or exclude dependency-safe nodes. Pack UI and graph
composition are intentionally separate so ordinary work is not presented as an
orchestration debugger.
