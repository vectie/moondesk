# MoonDesk product feature program

MoonDesk should let a person inspect, change, run, discuss, and review code in one continuous workspace, then keep the resulting code, documents, data, applications, and recurring work together in a MoonBook. This program implements the feature comparison requested on October 13, 2026. The user authorized implementation across MoonDesk and MoonClaw with multiple agents.

## Scope and reference baseline

| Product | Local reference | Relevant strengths |
| --- | --- | --- |
| MoonDesk | `1cc25bfe` plus existing working-tree changes | Editable source, book-scoped conversations, local and PR review, Office/data workflows, declared work graphs, hosted pack apps, durable results |
| OpenSeek | `08546760` | Integrated graphical coding, interactive terminals, contextual feedback, semantic review, browser and document annotations |
| Codex | `12cca49c8` | Agent execution controls, goals, conversation branching, queue management, skills/plugins/MCP, context management |
| Open WebUI | `f8ae8a6c3`, 0.12.0 | Knowledge retrieval, model presets, rich conversations, skill editing/versioning, shared work, calendar, voice |

The Codex comparison covers its checked-in CLI/TUI/runtime/app-server. OpenSeek's rich editor is explicitly a read-only viewer; MoonDesk already has direct editing. Open WebUI's connected terminal requires a terminal service, and separately advertised Computer/desktop repositories are not part of this inventory. Runtime capabilities count as desktop features only when a connected user workflow exposes them.

Feature work is the scope. Security expansion, distribution certification, release gates, CI expansion, and reliability campaigns are not phases of this program. Existing behavior and unrelated working-tree edits must be preserved.

## Existing features to extend

- General and book-scoped Code sessions; search, rename, archive, restore, delete; canonical replay; stop, guide, queue; model and reasoning controls; image input.
- Multiple editable source buffers, save, undo/redo, find/replace, local completion/highlighting, Markdown/JSON operations; saved MoonBit compiler diagnostics and navigation through the configured execution service.
- Repository changes, local review notes, reviewed state, PR context/checks, isolated PR checkout, public conversation and line comments, retained drafts.
- Command evidence, browser preview/evidence, approach comparison, job history, skill inventory, conversation export, scheduled Code work.
- DOCX/XLSX/PPTX item editing, document conversations, follow-up queues and review threads; JSON/JSONL/CSV/TSV/XLSX table views and transformations.
- Work-graph composition, declared plan authoring/dependencies, run/results surfaces, book templates, hosted pack apps, portable export and book learning.

## Feature comparison and implementation ledger

Status vocabulary: **Existing**, **In progress**, **Pending**, **Implemented**, **Verified**, **External dependency**. Implemented requires a connected action and real state; Verified additionally identifies the targeted check or observed user journey. A button, test fixture, design, or adapter declaration alone does not complete a feature.

### Phase 1 Continuous coding workspace

| ID | User capability | Reference or gap | Status | Owner |
| --- | --- | --- | --- | --- |
| C01 | Stable source/diff/preview beside conversation; remembered focus/layout | Tools previously competed above Code conversation | Implemented | integration |
| C02 | Interactive terminal tabs scoped to book/worktree, surviving navigation/reload | Former Terminal asked MoonCode to execute commands | Verified | terminal |
| C03 | Terminal input, resize, interrupt, scrollback/search and selected-output context | OpenSeek terminal integration | Verified | terminal |
| C04 | Select code, document text, table data, browser element or output and Ask/Change/Explain | Unified source context; element picker on MoonDesk-served previews | Implemented | integration |
| C05 | Visible removable context chips; preserve draft across navigation | Per-book/chat presentation state | Implemented | integration |
| C06 | Edit, remove, reorder, send next or guide now from Code queue | Canonical MoonClaw journal and dispatch | Implemented | agent_control |
| C07 | Prompt history and quote a transcript selection | Explicit recall and selected-text attachment | Implemented | integration |
| C08 | Next-message suggestions accepted explicitly without sending | Contextual suggestions from actual work; no provider prediction claim | Verified | terminal |
| C09 | Source navigation history, source/diff position, inline references/diagnostics | Persisted locations and result navigation | Verified | review |
| C10 | Language support beyond MoonBit where available | Real JS/TS language service across open buffers | Verified | review |

### Phase 2 Complete review loop

| ID | User capability | Reference or gap | Status | Owner |
| --- | --- | --- | --- | --- |
| R01 | Browse Git history and review a selected commit/base | Git history and base/commit comparison | Implemented | review |
| R02 | Split/unified comparison, hunk navigation and skip reviewed changes | Persisted view/position and viewed hunks | Verified | review |
| R03 | Token/tree semantic comparison where supported | Token highlights; structural comparison for JSON | Verified | review |
| R04 | Read, reply to and resolve PR discussions | Connected GitHub account required for remote actions | Implemented | review |
| R05 | Turn findings into coding tasks and inspect resulting changes | Canonical command correlation, resulting diff, manual verification | Implemented | review |
| R06 | Agent review for working tree, branch, commit or custom scope | Selected review scope passed into the ordinary Code task | Verified | review |
| R07 | Git operation/worktree navigation suited to daily coding | Stage/unstage/commit, branches, worktree creation/open | Implemented | review |

### Phase 3 Agent task control

| ID | User capability | Reference or gap | Status | Owner |
| --- | --- | --- | --- | --- |
| A01 | Fork a conversation from a selected point | Native history fork | Implemented | agent_control |
| A02 | Ask a side question while implementation continues | New independent chat from completed history | Implemented | agent_control |
| A03 | Persistent conversation goal and readable plan | Goal/plan injected into subsequent turns | Implemented | agent_control |
| A04 | Team view with agent progress, task/result navigation and steering | Canonical workers, child chats, guidance and stop | Implemented | agent_control |
| A05 | Inspect context, summarize/recap and continue long work | Editable recap replaces earlier request context; journal retained | Implemented | agent_control |
| A06 | Compare approaches and continue the chosen result | Side-by-side answers/results and continue selected conversation | Implemented | integration |
| A07 | Show usage, active commands and work results with the task | Measured usage, command evidence, task/result navigation | Implemented | agent_control |
| A08 | Conversation revert/edit/regenerate where canonical runtime supports it | Fork before selected turn, edit and retry with original images | Implemented | agent_control |
| A09 | Structured questions and clear plan-to-implementation transition | Native ask_user tool, persisted question/answer and plan action | Implemented | agent_control |

### Phase 4 Reusable coding setup

| ID | User capability | Reference or gap | Status | Owner |
| --- | --- | --- | --- | --- |
| S01 | Browse, read, create/edit and install/import skills | Multi-file skill editor and import into real skill home | Implemented | setup |
| S02 | Supporting skill files, export, version comparison/restore | Save history, compare and restore as a new version | Implemented | setup |
| S03 | Model/provider presets with readable controls and per-book defaults | Existing connected models; defaults apply to new chats | Implemented | setup |
| S04 | Manage instructions, selected knowledge and tools in one setup view | Book AGENTS.md, knowledge, skills and integration tabs | Verified | setup |
| S05 | Discover/configure MCP and other integrations through runtime | Real remote HTTP JSON/SSE tool discovery and dispatch | Implemented | setup |
| S06 | Reusable prompt templates and versioned model/tool configuration | Saved prompts, before/after comparison and restoration | Implemented | setup |
| S07 | Knowledge library with original/extracted text, retrieval and citations | Ranked text plus optional provider embeddings and hybrid similarity | Implemented | setup |
| S08 | Personal memory alongside book-specific learning | Explicit cross-book preferences loaded by MoonClaw | Implemented | agent_control |
| S09 | Multiple model responses and useful comparison/usage view | Same read-only prompt, separate chosen models, actual answers/usage | Implemented | integration |

### Phase 5 Code documents and data together

| ID | User capability | Reference or gap | Status | Owner |
| --- | --- | --- | --- | --- |
| D01 | Shared contextual feedback across code/document/table/browser/output | Origin-preserving selection and next-message context | Implemented | integration |
| D02 | Stronger document/table preview and edit-to-result navigation | Existing Office/data editing plus linked results and conversations | Implemented | workspace_features |
| D03 | Task result bundle containing code, preview, documents and data | Results inbox joins actual tasks, files and scheduled outputs | Verified | workspace_features |
| D04 | Return to, reuse and export generated applications/artifacts | Duplicate templates with data, editable HTML export and existing packs | Verified | workspace_features |
| D05 | Image generation/editing as a connected artifact workflow | Async provider image jobs, book artifacts, preview/edit/reuse | Implemented | agent_control |
| D06 | Rich note editing and selected-text AI revision | Markdown formatting toolbar, keyboard shortcuts and rewrite selection | Verified | workspace_features |

### Phase 6 Recurring and shared work

| ID | User capability | Reference or gap | Status | Owner |
| --- | --- | --- | --- | --- |
| W01 | Flexible schedule editor with calendar and linked results | Daily/weekdays/weekly in IANA zones, once, edit, run now | Verified | workspace_features |
| W02 | Result inbox connecting recurring work to its conversation/artifacts | Linked scheduled Code results and background document outputs | Verified | workspace_features |
| W03 | Shared document review, assignment, replies and resolution | Reopen/reassign/filter, retained reply drafts and updates | Implemented | workspace_features |
| W04 | Shared conversation, live updates, presence and channels | Book rooms, replies/reactions and presence on the shared server | Implemented | workspace_features |
| W05 | Voice input and realtime task conversation | Browser voice turns plus optional provider WebRTC with task handoff | Implemented | terminal / agent_control |
| W06 | Video/screen context when useful to the task | Live capture preview and explicitly attached frames | Verified | terminal |
| W07 | Calendar events/reminders and readable recurrence controls | Book events, recurrence, in-app reminders and iCalendar alarms | Implemented | workspace_features |
| W08 | Responsive keyboard/touch access to the completed journeys | Mobile pane controls, natural scrolling, keyboard access and touch targets; 375 × 740 browser check passes | Verified | integration |

## Interaction design

Use the established neutral desktop palette, existing icons and compact controls. Navigation remains book/task oriented. Source, diff, preview, conversation and terminal maintain predictable positions. A user can focus any pane and return to the previous arrangement. Narrow layouts select one work surface at a time with explicit tabs and reachable composer controls.

Selections become removable context chips naming their origin. Ask, Change and Explain preserve the draft and navigate to the right conversation. Feedback should keep its source location so the user can revisit it. Review findings link to implementation and then to the resulting diff. Completed tasks expose concrete outputs, rather than asking users to browse internal execution records.

User-facing language answers: What am I making? What is happening? What changed? What can I inspect? What should I do next? Runtime identifiers and diagnostic contracts belong in details, not ordinary labels.

## Ownership and integration

- `terminal`: terminal service and UI.
- `review`: Git history, review and PR discussions.
- `agent_control`: canonical MoonClaw changes plus task/queue/fork/team controls.
- `setup`: skills, models, instructions and integrations.
- `workspace_features`: documents, data/results, schedules and shared work.
- `integration`: common layout/context, shared route wiring, outstanding feature waves and final journey verification.

MoonClaw remains the canonical conversation and execution owner. Existing product-owned schedules and files retain their owners. New UI reads and mutates real service state. Shared files are integrated by the parent agent to avoid overlapping rewrites. Existing dirty files are preserved.

## Validation and completion

Each feature is verified at its meaningful boundary: queue ordering and dispatch, actual terminal input/output, persistent skill edits, Git discussions, document results, and layout/keyboard interaction. Use targeted tests and source checks during development. Native tests use stripped output because the previous investigation identified debug linking as the bottleneck. Shared build/format/interface operations are coordinated rather than duplicated by each agent.

The final pass runs relevant MoonBit checks/tests, `moon info`, `moon fmt`, the production UI build, and browser checks of the changed user journeys. Existing APIs and public interface diffs are reviewed. Completion is reported per feature with remaining dependencies named; no phase is declared complete because its UI shell exists.

## Delivery record and user guides

The implementation spans MoonDesk, MoonClaw's canonical conversation/provider runtime, and MoonTown's existing schedule owner. A book remains the place where code, conversations, documents, knowledge, applications and recurring results meet.

- [Terminal, voice, screen context and suggested next steps](PRODUCT_TERMINAL_AND_MEDIA.md)
- [Review, Git operations and source navigation](PRODUCT_REVIEW_AND_EDITOR.md)
- [Coding setup, skills, models, MCP and knowledge](PRODUCT_SETUP_AND_KNOWLEDGE.md)
- [Task controls, personal preferences and image generation](PRODUCT_TASK_CONTROL_AND_IMAGES.md)
- [Documents, results, shared rooms and calendars](PRODUCT_WORKSPACE_FEATURES.md)

### Integrated journeys checked in the isolated Coding-demo book

- A real terminal accepted input, reported a TTY, ran in the book directory, returned searchable output, attached selected output to the draft, survived page reload and closed on request.
- Book instructions saved through Coding setup and remained in the actual book's `AGENTS.md`.
- A Markdown source was extracted into the knowledge library, found through a phrase query, and attached to the composer with its source citation and extracted line range.
- Git history returned the actual fixture commit, author, subject and parent information.
- Shared room messages, replies, reactions and presence persisted through the running service. A weekday calendar event retained its file link and reminder.

The fixture lives under `_build/product-preview`; it is separate from the user's running MoonDesk library. No GitHub comments, provider model requests, microphone/camera captures or paid image calls were made in these checks.

### Verification boundaries

Tests exercise actual PTY behavior, native persistence/dispatch, provider protocol loopback servers, the real TypeScript compiler API, and browser interactions. A local protocol fixture proves the request/response integration; it does not prove that an arbitrary configured provider supports that capability. GitHub discussions require a connected account. Image generation, embeddings and provider voice require a compatible configured endpoint/model. Hardware capture requires the browser's user permission.

Terminal sessions survive navigation/reload while the backend runs; they do not survive its restart. JS/TS semantic navigation covers opened buffers. Structural review currently supports JSON. Knowledge citations identify extracted text. Shared rooms serve people connected to the same MoonDesk server. Calendar export supplies recurrence and alarms to an external calendar app for reminders after MoonDesk closes. These boundaries are documented in the corresponding guides.

### Build integration fixes

The UI now selects its `main` MoonBit package explicitly. The Rabbita Vite resolver is invoked only for the generated entry, avoiding repeated MoonBit compilation for every ordinary JavaScript import. The first successful integrated production build after this correction completed in 58.93 seconds. Native verification uses stripped linking. The existing source replacement call was updated to MoonEdit's current count-returning API, and an HTTP test header type was updated to the current dependency interface.

### Final checks

| Boundary | Result |
| --- | --- |
| MoonDesk production native source | `moon check cmd/main --target native` passes; stripped executable build passes |
| UI production source and bundle | JS check and production Vite build pass; final mobile bundle build 59.53 seconds |
| MoonDesk focused native feature suite | 10/10 pass: setup, knowledge, rooms, calendar, Git review and comparisons |
| Comparison recovery follow-up | 3/3 native tests pass, including retaining one accepted model response |
| MoonClaw runtime | 12 distinct focused native tests pass across two runs: queue/fork/questions/memory, MCP, images, realtime and embeddings |
| MoonTown schedules | 12/12 native tests pass; updated scheduling-server executable builds |
| JavaScript runtime groups | Workspace group 50/50; composer/comparison/media group 27/27; editor/review group 15/15; final media/realtime/suggestions group 13/13. Groups overlap and are not additive. |
| Formatting and interfaces | Relevant MoonDesk/UI/MoonClaw/MoonTown packages formatted and interfaces generated; expected new terminal/Git/schedule APIs inspected |
| Whitespace | `git diff --check` passes |

Built artifacts remain in the development trees. The installed/running packaged services have not been replaced. MoonDesk's updated runtime features require the corresponding updated MoonClaw and MoonTown executables. The full MoonClaw CLI currently encounters an existing compiler lowering failure in the unrelated gateway server; its coding daemon has a dedicated composition root using the same runtime. See the task-control guide for that build and the exact limitation.

| Runnable artifact | Path |
| --- | --- |
| MoonDesk server | `_build/native/debug/build/vectie/moondesk/cmd/main/main.exe` |
| MoonDesk production UI | `ui/rabbita-desk/dist/` |
| MoonClaw coding daemon | `../moonclaw/_build/native/debug/build/cmd/mooncode_daemon/mooncode_daemon.exe` |
| MoonTown scheduling server | `../moontown/_build/native/debug/build/vectie/moontown/cmd/desktop_server/desktop_server.exe` |

The dedicated MoonClaw daemon build and version smoke check pass. It accepts the same desktop daemon launch arguments and delegates to the same runtime. No gateway workaround or experimental routing changes remain.

After the user unlocked the Mac, the final 375 × 740 browser recheck passed on the 59.53-second production bundle. Focus chat reveals the composer; natural scrolling exposes the full draft, controls and expanded media panel. Page width stays at 375 pixels with no horizontal overflow. Chat focus and exact draft text survive reload. Split view returns to the work pane, and returning to chat preserves the draft. Keyboard Tab moves from the composer to the next enabled model control. The viewport override was reset afterward. No microphone/camera permissions or provider requests were needed for this layout check.

## Last month changes informing this program

- OpenSeek: predictions, prompt/shell history, quote selection, terminal `!` mode, browser element mentions/CDP, local previews, PDF/Office context, unified annotations, review shortcuts, session fork, durable scratch files.
- Codex: richer agent command-center navigation/pinning, message boards, realtime voice, preserved agent state/capabilities, optional prediction forks and plugin interaction refinements.
- Open WebUI 0.11.4/0.12.0: shared-chat replies/forks, realtime voice/avatar, model controls/versioning, multi-file skill history, knowledge file browser, prompt comparison, experimental tool search, channel queues and Office generation.
- MoonDesk: September Code review/media/jobs/schedule implementation, October document conversation/review integration, expanded tables and declared-plan composition.

## Source map

- MoonDesk: `ui/rabbita-desk/main/mooncode_views.mbt`, `source-editor-runtime.js`, `workspace-features-runtime.js`, `main/mooncode_developer_tools_views.mbt`, `main/git_repository_views.mbt`, `main/moonflow_plan_authoring.mbt`, `internal/moonwiki/api_mooncode_router.mbt`, `internal/moonwiki/document_*`, `internal/moonwiki/workspace_table_*`.
- OpenSeek: `../openseek/desktop/README.md`, `editor/README.md`, `desktop/frontend/terminal`, `desktop/frontend/browser_annotation.mbt`, `desktop/frontend/github_review/README.md`, `desktop/frontend/fileeditor`.
- Codex: `../codex/codex-rs/tui/src/slash_command.rs`, `app-server-protocol/src/protocol/common.rs`, `features/src/lib.rs`, `memories/README.md`.
- Open WebUI: `../owb/CHANGELOG.md`, `README.md`, `backend/open_webui/routers/{skills,automations,terminals,memories}.py`, `src/lib/components/chat`, `src/lib/components/notes`.
