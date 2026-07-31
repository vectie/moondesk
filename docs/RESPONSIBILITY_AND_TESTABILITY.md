# MoonDesk responsibility and testability

MoonDesk is the visible operator shell. It owns navigation, workspace and file
presentation, pack-app hosting, review controls, service-state presentation,
and the composition canvas. It does not own domain policy, book truth, agent
reasoning, workflow execution, provider authority, or civic synthesis.

| User-visible responsibility | Owning evidence | Proportional verification |
| --- | --- | --- |
| Open and preserve selected work context | MoonDesk workspace projection and durable UI state | open → change context → reload; process restart is recorded separately |
| Host a pack application | installed manifest entrypoint plus same-origin host record | open from Packs and verify the product-owned route and identity |
| Present reviews and authority | exact source record; MoonDesk never grants on its own | approve/deny through the owning protocol and correlate its receipt |
| Compose product work | desired graph, compiled capability catalog, validation report, import receipt | render, select, validate, import, then prove MoonFlow owns the run |
| Operate a run | MoonFlow control/status receipts | invoke one control and require recovered MoonFlow state after restart |

The UI must show missing catalogs, adapters, providers, reviewers, or authority
as actionable unavailable states. A displayed node, installed product, route,
or button never proves an executable capability.

The authoritative architecture is [ARCHITECTURE.md](ARCHITECTURE.md), the
current readiness decision is [STATUS.md](STATUS.md), and browser qualification
is indexed in
[qualification/UI_TO_UI_USE_CASES.md](qualification/UI_TO_UI_USE_CASES.md).
