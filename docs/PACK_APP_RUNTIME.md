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
general-purpose server-side request proxy. Requests must also stay within the
manifest's first app entrypoint path. An HTML entrypoint may load sibling assets
from its containing directory. Pack UIs use relative API/media URLs so their
subresources remain under the mounted route.

The proxy forwards JSON requests and explicit `application/octet-stream`
requests, including PaiWork Skill ZIP imports. Request bodies are capped at
20 MiB and exceedance returns HTTP 413. The byte stream and content type are
preserved for binary requests; other write requests must contain valid JSON.

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

## Bind a service to the active workspace and pack version

Packs that expose an identity endpoint may declare it in the installed
`pack.json`:

```json
{
  "app_runtime_identity": {
    "contract": "example-pack.runtime-identity.v1",
    "path": "/apps/example-pack/studio/api/v1/runtime-identity"
  }
}
```

The path must be beneath the first declared app entrypoint. The endpoint
returns JSON containing `contract`, `pack_id`, `version`, and `workspace_ref`.
`workspace_ref` is `sha256:` followed by the lowercase SHA-256 hex digest of
the UTF-8 bytes of the canonical absolute workspace path, with no trailing
newline. This avoids returning the operator's local path to the browser.

When the declaration is present, MoonDesk checks the endpoint over the
configured loopback service before marking the pack `configured` or proxying a
request. The response must match the declared contract, active pack ID and
version, installed manifest version, and current workspace digest. A missing,
unavailable, malformed, or mismatched identity makes the catalog entry
`configuration_invalid` and prevents the proxy from opening it. Packs without
this optional declaration retain the earlier structural runtime check.

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
