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
  "app_url": "http://127.0.0.1:4300/apps/example-pack/studio"
}
```

`GET /api/desktop/pack-apps` joins the active pointer, installed `pack.json`,
and runtime configuration. It publishes only entries whose pack ids match,
whose manifest declares at least one `app_entrypoints` item, and whose URL uses
HTTP or HTTPS. The generic MoonDesk launcher renders the returned catalog; it
does not know any pack id, domain route, provider, credential, or business rule.

The runtime file is deliberately not part of pack installation. Ports and URLs
are environment/deployment concerns and can change without reinstalling a pack.
