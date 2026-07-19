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
and runtime configuration. It publishes only entries whose pack ids match,
whose manifest declares at least one `app_entrypoints` item, and whose URL uses
HTTP or HTTPS. The generic MoonDesk launcher renders the returned catalog; it
does not know any pack id, domain route, provider, credential, or business rule.

The launcher opens the same-origin `/pack-apps/<pack-id>/` route. MoonDesk
proxies only to an explicitly configured loopback `service_url`; this prevents
the desktop browser from navigating to a different origin and avoids exposing a
general-purpose server-side request proxy. Pack UIs use relative API/media URLs
so their subresources remain under the mounted route.

The runtime file is deliberately not part of pack installation. Ports and URLs
are environment/deployment concerns and can change without reinstalling a pack.
