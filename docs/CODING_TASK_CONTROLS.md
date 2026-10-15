# Coding task controls

MoonDesk's **Task, queue and agents** panel keeps the conversation, its plan,
pending messages and delegated work together. MoonClaw remains the owner of the
conversation and its execution history.

## Everyday workflows

- **Up next:** edit a message before it starts, move it up or down, or remove it.
  Image attachments stay attached when the text changes. Once execution claims
  a message, use guidance for the running task instead.
- **Goal and plan:** set the task objective and concrete completion outcomes.
  This uses MoonClaw's existing goal runtime. Save a working plan or add it to
  the composer with **Implement this plan**.
- **Questions:** an agent can ask a structured question, offer short choices,
  and wait for a typed answer. Answers are durable and become model context.
  Answering also restarts the runtime service when it is no longer running.
- **Try another approach:** fork completed turns into an independent native
  conversation. The original chat continues. **Edit and retry from here** forks
  before a selected turn and restores its original text and images as a draft.
  Files are shared within the same book; a conversation fork is not a Git
  worktree or a file rollback.
- **Agent team:** inspect delegated worker status and results, open the worker
  chat, send guidance, or stop it. These controls operate on real worker links
  created by MoonClaw's worker tools.
- **Context and recap:** inspect the current book/model, conversation recap and
  measured token usage. Save an explicit working recap to replace earlier
  completed turns in future model requests. The full journal remains available.
- **Personal preferences:** explicitly save, edit or clear preferences used
  across coding books. They live in MoonClaw's home, separately from book
  instructions (`AGENTS.md`) and book learning.

## Create and edit images

Choose a configured model whose provider supports the Responses
`image_generation` tool, describe the image, and optionally attach reference
images. Generation runs in the background while the coding workspace remains
usable. Finished PNG files are saved under `artifacts/images/` in the book.

The result offers a preview, an open/download link, **Edit this image**, and
**Use in task**. Editing sends the selected image pixels with the new prompt.
Provider credentials come from the existing model configuration; this panel
does not maintain another credential store. A provider that lacks image
generation reports an actionable error. An interrupted job is shown as
interrupted after a daemon restart.

The provider request follows the official [Responses image-generation
guide](https://developers.openai.com/api/docs/guides/tools-image-generation).
Availability depends on the selected provider and account. Local tests use an
HTTP fixture and write the returned PNG bytes to an actual temporary book.

## Realtime voice

Provider voice uses the selected coding provider's existing credentials to
obtain a temporary WebRTC session token. The browser connects directly to the
provider's realtime call endpoint. The current coding context is included;
the voice companion discusses the task and can hand a coding request to the
conversation's agent, then report the returned result.
Provider/account realtime support is required. The adapter follows the official
[WebRTC guide](https://developers.openai.com/api/docs/guides/realtime-webrtc).

## Implementation

- Desktop HTTP proxy: `internal/moonwiki/mooncode_task_controls.mbt`.
- Desktop presentation: `ui/rabbita-desk/mooncode-task-controls-runtime.js`.
- Native API: `POST /v1/code/sessions/{session}/task-controls`.
- Native queue, plan and projection: MoonClaw `cmd/daemon/mooncode_task_controls.mbt`.
- Native branching/context: MoonClaw `cmd/daemon/mooncode_task_fork.mbt`.
- Native question tool: MoonClaw `cmd/daemon/mooncode_task_questions.mbt`.
- Native image jobs: MoonClaw `cmd/daemon/mooncode_image_studio.mbt`.
- Native voice credentials: `POST /v1/mooncode/realtime-session`, MoonClaw
  `cmd/daemon/mooncode_realtime.mbt`.

Queue mutations are appended atomically to the existing journal and projected
into command order before runtime claim selection. Branches copy settled native
commands and their results; pending commands are not replayed. A MoonClaw binary
built with these endpoints is required for the desktop controls.
