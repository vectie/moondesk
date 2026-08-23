# MoonDesk general-agent contract

This document records the user-facing boundary between MoonDesk and the
MoonClaw general agent. It is intentionally separate from the wiki content
model: the normal experience is a chat box beside the document viewer, while
the five-stage review/improvement/validation work remains an internal agent
concern.

## Implemented flow

1. A user selects a workspace document and optionally opens **Attach workspace
   file**. The picker searches the current MoonBook, accepts a trailing `@file`
   mention, and supports dragging a file row or search result onto the chat
   drop target. Attaching records an existing workspace-relative path; it does
   not import, copy, or mutate the file. Dropping an arbitrary operating-system
   file is intentionally not treated as an implicit import.
2. `POST /api/moonclaw/chat` validates the workspace, selected document, and
   attachments with the confined existing-path resolver. The server rejects
   directories, paths outside the workspace, oversized messages, more than 32
   attachments, and overlong attachment paths.
3. MoonDesk sends MoonClaw a general-agent prompt with a model-only
   `<user_mentions>` envelope. The prompt explicitly keeps MoonCode and
   internal pipeline vocabulary out of the user conversation.
4. The browser opens the same-origin
   `GET /api/moonclaw/tasks/<task-id>/events` stream. MoonDesk’s native host
   supplies the private execution token and instance binding; the browser
   never receives either credential.
5. The UI consumes bounded batches of SSE events and renders assistant deltas
   in the chat. `Failed` and `PostConversation` terminate the stream. A stream
   transport error becomes a normal status message instead of an unbounded
   polling loop. Search and viewer requests carry monotonic generations, so a
   late response cannot replace a newer workspace selection or file query.

## Package/viewer boundary

MoonLeaf `0.1.6` is now the preferred bounded ZIP/OPC session for DOCX, XLSX,
and PPTX opens. Its diagnostics are copied to the document model and only
warnings requiring attention are shown in the popup. The existing projection
parser remains as a compatibility fallback for deliberately minimal legacy
fixtures; this is not a semantic sandbox and does not replace MoonFort’s
execution boundary.

## Harness responsibilities

MoonClaw remains the owner of model/tool execution, output budgets, retries,
parallel read-only scheduling, atomic multi-edit semantics, and artifact
spill. MoonDesk owns only the browser-facing projection: bounded event queues,
workspace path validation, credential isolation, and quiet warning display.
Any change to those execution contracts must preserve this split and add a
focused native test plus a UI check before release.

The current rollout flags, planner metrics contract, benchmark cases, and
MoonGate aggregation mapping are recorded in MoonClaw’s
`docs/HARNESS_EFFICIENCY_TRIALS.md` and `../moongate/docs/MOONCLAW_HARNESS_METRICS.md`.
MoonDesk’s Office viewer follows the same lifecycle boundary: refresh starts a
new generation, dispose is idempotent, and neither operation silently discards
unsaved edits.

Binary previews use a separate digest-bound artifact handle. The preview JSON
keeps its legacy raw body for compatibility, but includes `artifact_url` and
`artifact_digest` metadata for the UI. Image elements use native lazy loading;
the `/api/workspaces/<id>/artifact` endpoint confines the path to the selected
workspace, re-hashes the current bytes, and rejects missing or stale digests.
Portable app-tool snapshots do not advertise this native-only route, so an
offline bundle falls back to its existing static preview behavior.
