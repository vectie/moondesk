# MoonDesk traffic routing

MoonDesk has one fail-closed AI traffic path:

```text
MoonDesk browser → MoonDesk native host → authenticated MoonClaw control API
                                         → live MoonGate OpenClaw route
                                         → configured model provider
```

The native host never sends prompts, model requests, tool arguments, or provider credentials directly to a model provider. MoonDesk accepts only models named `moongate/<model-id>`. MoonCode planning commands with an empty or non-MoonGate selector are rejected before they reach MoonClaw. General document chat obtains MoonClaw's live MoonGate route, pins new tasks to its reported default model, and refuses legacy conversations whose stored model is not a MoonGate selector.

## Runtime contract

MoonClaw owns the authenticated `GET /v1/moongate-route` control endpoint. Its `moonclaw.moongate-route.v1` response is computed from MoonGate's current suite discovery record and live `/openclaw/v1/models` catalog. It reports ready only when at least one live model exists. MoonDesk does not fall back to MoonClaw's standalone provider catalog when this route is missing or down.

The browser receives only MoonDesk same-origin APIs. The private MoonClaw token and instance binding remain in the native host. Every successful protected response must carry the expected `X-MoonClaw-Instance-ID`.

Provider handoff is deliberately fail-closed at this boundary. MoonDesk validates the bounded one-time-code envelope and relays it only to the authenticated MoonClaw control plane; it never contacts LunaNexa or accepts a provider secret.

The companion MoonClaw deployment owns that explicit operation at
`POST /v1/provider-handoff`: redeem against the administrator-pinned
`MOONDESK_LUNANEXA_ISSUER`, validate the secret-bearing receipt, and use
MoonGate's local control authority to install and bind `lunanexa-lease`. The
browser fragment is removed before the same-origin request, and the browser
payload contains only `client_id` plus the single-use code. A failed install
must never cause MoonDesk to fall back to a direct provider route.

MoonDesk starts its managed MoonClaw with a clean environment. It explicitly
allowlists only `MOONDESK_LUNANEXA_ISSUER` and `MOONGATE_CONTROL_TOKEN` for
this operation; unrelated ambient provider credentials are still excluded.

## Other local data planes

“AI traffic” means prompts, agent turns, model selection, provider inference, and their control/stream events. The following local product data planes are deliberately not tunneled through a model gateway:

- sandbox diagnostics and promotion: MoonDesk → MoonClaw → MoonFort;
- MoonTown owner records: MoonDesk → the loopback MoonTown owner API;
- installed pack UI/assets: browser → MoonDesk → a validated loopback pack service;
- local document previews: browser → MoonDesk's same-origin preview host.

These paths carry no model prompts or provider inference. They remain loopback-only, typed, bounded, and separately authenticated or path-confined. `scripts/validate-traffic-routing.sh` enumerates every production native HTTP client so a new unclassified transport fails CI review.

## Verification

Run:

```sh
MOONCLAW_ROOT=../moonclaw scripts/validate-traffic-routing.sh
node scripts/benchmark_moonclaw_moongate_route.mjs
```

The benchmark starts real release MoonDesk and MoonClaw processes against a controlled loopback MoonGate catalog. It checks both the private route and the browser-facing same-origin API for authenticated instance binding, model filtering, invalid-token rejection, and fail-closed behavior when MoonGate disappears. It also enforces broad latency regression limits.

Reference run on 2026-08-29 (200 private-route requests and 100 full MoonDesk requests per throughput case):

| Case | p50 | p95 | p99 | Throughput |
|---|---:|---:|---:|---:|
| Sequential live route | 0.643 ms | 0.839 ms | 1.538 ms | 1,479.9 req/s |
| 20-way concurrent live route | 2.589 ms | 3.960 ms | 4.823 ms | 5,009.5 req/s |
| MoonDesk sequential live route | 1.967 ms | 2.428 ms | 2.766 ms | 489.6 req/s |
| MoonDesk 20-way concurrent live route | 20.005 ms | 21.321 ms | 21.572 ms | 938.5 req/s |
| Invalid control token | 0.301 ms | 0.379 ms | 0.623 ms | 3,186.8 req/s |
| MoonGate unavailable | 504.011 ms | 505.656 ms | 518.003 ms | 2.0 req/s |
| MoonDesk with MoonGate unavailable | 506.755 ms | 509.565 ms | 509.565 ms | 2.0 req/s |

The unavailable case is intentionally a live connection attempt rather than a stale-success cache. Its one-request failure latency is bounded to 1 second by the benchmark gate; normal UI polling is five seconds, so the failure probe cannot create a retry storm.
