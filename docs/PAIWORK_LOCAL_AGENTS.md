# PaiWork local MoonBook Agents

PaiWork uses MoonDesk as the installed MoonBook catalog and MoonClaw as the
execution service. The local saved profile serves `/Users/kq/moonsuite` through
MoonDesk `127.0.0.1:4200` and PaiWork `127.0.0.1:4318`. The desktop profile
serves the app workspace through MoonDesk `127.0.0.1:4199` and PaiWork
`127.0.0.1:4319`. Each profile has its own MoonClaw daemon and MoonGate
instance (`15723` saved, `15724` desktop).

## Local service bindings

The paired MoonDesk and MoonClaw launch agents are
`com.vectie.moondesk.paiwork.{saved,desktop}` and
`com.vectie.moonclaw.paiwork.{saved,desktop}`. Their local plists live in
`~/Library/LaunchAgents`. PaiWork's existing two launch agents set
`MOONFISH_PAIWORK_MOONDESK_URL` to the corresponding MoonDesk origin.

MoonClaw runs as an **external service**, which MoonDesk supports for normal
MoonSuite workspaces. Its executable is a local source-built MoonClaw
`0.1.7+2801.9dfce310` at
`~/Library/Application Support/app.vectie.moondesk.paiwork.external/bin/moonclaw`.
This is separate from MoonDesk's managed runtime. The managed updater still
refuses installation without an isolated updater backend; the older managed
`0.1.3` binary is incompatible with the current MoonDesk control route.

Each profile has a separate private control configuration created with
`scripts/bootstrap-private-control.mbtx` from MoonClaw. The launch agents
pass only its path through `MOONDESK_EXECUTION_SANDBOX_CONFIG` and set the
matching `LEPUSA_APP_DATA_DIR`. The private configuration must never be copied
between workspace roots or included in a pack. MoonDesk authenticates control
requests and verifies the daemon instance on every response.

MoonClaw discovers the active MoonGate URL and default model from each
workspace's `.moonsuite/suite-status.json`. For the requested Ark route,
MoonGate's `openclaw` provider selection must expose
`deepseek-v4.1-flash` on `/openclaw/v1/models` and route completions through
the existing local provider credential. The saved profile's preexisting GLM
provider remains present but is not selected. Provider configuration backups
are beside each `providers.json` as `providers.json.before-paiwork-agent-ark`.

## APIs PaiWork requires

| Caller | Route | Required data |
| --- | --- | --- |
| PaiWork → MoonDesk | `GET /api/workspaces/metadata` | Contract and canonical `suite_root` for workspace binding. |
| PaiWork → MoonDesk | `GET /api/desktop/agents` | Agent passports: ID, name, status, book ID, capabilities, example tasks, skill and tool counts. |
| PaiWork → MoonDesk | `GET /api/moonclaw/daemon` | `running`, authenticated model readiness and selected model. |
| PaiWork → MoonDesk | `POST /api/moonclaw/chat` | Selected Agent workspace ID and user message. Returns task ID. |
| PaiWork → MoonDesk | `GET /api/moonclaw/tasks/{id}/events?cursor=start` | SSE answer and terminal events. |
| MoonClaw → MoonGate | `GET /openclaw/v1/models` | Live model catalog containing `deepseek-v4.1-flash`. |
| MoonClaw → MoonGate | `POST /openclaw/v1/chat/completions` | Ark-backed inference for the selected model. |

PaiWork exposes `GET /apps/moonfish/paiwork/api/v1/moondesk-agents` and accepts
`moondesk_agent_id` in `POST /apps/moonfish/paiwork/api/v1/ask`. The Agent
response is saved to the normal PaiWork chat state.

## Local verification, 2026-10-13

Both profile daemons reported `running: true` with model readiness `ready`
and `moongate/deepseek-v4.1-flash` selected. PaiWork reported 47 installed,
11 runnable passports in the saved profile and 43 installed, one runnable
passport in the desktop profile. A saved-profile `book-finance` request through
PaiWork `/api/v1/ask` completed and produced an assistant message in chat
`7041e485-ca86-4239-b575-9f6565b2c20d`; MoonGate recorded a successful
Ark DeepSeek request. No further inference run is needed for this smoke check.
That answer discussed the PaiWork-supplied evidence references `[1]` through
`[8]`, including duplicate filings, confirming that retrieval excerpts reached
the Agent through the existing PaiWork bridge.

The newer MoonClaw source is present in the original repository, but a narrow
daemon-only build remained in MoonBit link-core compilation for over nine
minutes with the installed September compiler and was stopped. The full CLI
build also fails in an unrelated gateway compiler invariant. The local
external service therefore uses the previously source-built compatible binary
described above until a supported current build is available.
