# Task control, images and voice implementation

2026-10-13 product feature program. User guide: [Coding task controls](CODING_TASK_CONTROLS.md).

## Delivered user workflows

| Feature | Behavior |
| --- | --- |
| Queue | Edit, remove, move up/down, Send next. Changes survive reload. Guide now converts an unclaimed text message to native steering atomically; attachments remain their own turn. |
| Goals and plans | Existing MoonClaw goal runtime; saved working plan; transfer the plan into the composer for implementation. |
| Branches | Native journal-backed forks; side questions; edit and retry forks before the selected turn and restores text/images. Pending source work is never replayed. |
| Team | Actual linked worker status/results, open child conversation, steer, stop. |
| Context | Book/model, settled and active conversation context, measured usage, explicit recap used in later model requests. |
| Preferences | User-editable preferences in MoonClaw home, injected per turn; clear removes their future influence. |
| Questions | `ask_user` tool, choice/freeform UI, durable answers, planner consumes answer before later tool work. |
| Images | Configured provider Responses image generation, reference image editing, background job status, saved PNG previews/downloads/reuse. |
| Voice adapter | Configured provider realtime client secret request, WebRTC endpoint and expiry returned to browser. Terminal/media module owns the browser experience. |

## Runtime ownership and integration

MoonDesk owns presentation and HTTP forwarding. MoonClaw's existing session
journal owns all conversation, queue, fork, question and image job records.
There is no second desktop conversation store.

MoonDesk integration:

- `internal/moonwiki/mooncode_task_controls.mbt` forwards
  `POST /api/mooncode/sessions/:id/task-controls` through authenticated native
  control transport, resolving the session's actual book root.
- `ui/rabbita-desk/mooncode-task-controls-runtime.js` mounts on
  `[data-mooncode-task-controls][data-session-id]`; bootstrap calls
  `installMoonCodeTaskControls()` and loads `styles/mooncode-task-controls.css`.
- The Code view mounts the panel above the transcript. Disclosure state and
  unsaved field drafts survive periodic refreshes.
- `moondesk:open-code-session` carries `{sessionId,draft,images}` for native
  forks. `moondesk:add-context` places plans and selected results into the
  coding composer. The shared application bridge owns session navigation.

MoonClaw runtime files:

- `cmd/daemon/mooncode_task_controls.mbt`: queue mutation/projection, task state,
  real worker controls, preference storage, image loading.
- `cmd/daemon/mooncode_task_fork.mbt`: native forks and per-turn context.
- `cmd/daemon/mooncode_task_questions.mbt`: durable interactive questions.
- `cmd/daemon/mooncode_image_studio.mbt`: provider requests, job events, PNG files.
- `cmd/daemon/mooncode_realtime.mbt`: provider ephemeral voice credentials.
- `mooncode_session_journal.mbt` applies queue mutations before runtime claim
  and conversation projection. Runtime turn/planner/tool registration consume
  task context, preferences and `ask_user`.
- `daemon_serve.mbt` routes task controls, MCP, knowledge and realtime endpoints.

## Product dependencies and boundaries

The desktop requires an updated MoonClaw binary containing these routes. Image
and provider voice features need a configured provider/account supporting the
respective API. They reuse provider configuration; no additional image/voice
credential store is introduced. Generated PNG files live in the selected book's
`artifacts/images/`; General chat images use its native session book and can
still be previewed and downloaded through the task-control endpoint.

Conversation forks share book files. They do not rewind file changes or create
Git worktrees. Working recaps change future request context while preserving
the complete journal. Voice discusses the task and can hand a coding request
to the coding conversation, then report the returned execution result.

## Verification

The first focused native suite passed **9/9**: queue/fork/question/preferences,
MCP HTTP/session flow and AGENTS reload, Responses image generation/editing
and saved PNG bytes. The follow-up focused suite also passed **9/9**, covering
the added Guide now transition, image download, realtime ephemeral credentials
and hybrid embeddings. Fixtures
use local HTTP servers and temporary books; no paid provider call is used.

JavaScript syntax checks pass for the task controls runtime. MoonBit formatting
and package interface generation are part of final integration validation.

## Native desktop daemon artifact

`moon build cmd/mooncode_daemon --target native --strip` in the MoonClaw
repository builds the dedicated desktop daemon entry point. It uses the same
`@daemon.start` runtime and accepts the same `daemon --serve … --port …` launch
arguments and `version` command as the full CLI. This keeps gateway and terminal
UI dependencies out of the desktop runtime executable.

Build succeeded. Artifact:
`../moonclaw/_build/native/debug/build/cmd/mooncode_daemon/mooncode_daemon.exe`
(approximately 20 MiB). Its `version` command returned
`0.1.7+2802.a94d7f58`. Package interface generation also completed with no errors.

The full `cmd/main` CLI build currently encounters a compiler internal invariant
failure in the existing `gateway/server/request.mbt` function during
`core+eliminate-regex` (duplicate generated binders). No experimental gateway
changes were retained. The dedicated daemon avoids that unrelated package.
The user's running packaged services are not replaced by this build.
