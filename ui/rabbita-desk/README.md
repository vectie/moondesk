# Moondesk Rabbita UI

Browser-mode desktop shell for Moondesk. The shell includes Explorer, Search,
Inbox, MoonCode, Town, Runs, and Settings activities. MoonCode talks to
`/api/mooncode/*` for book-scoped coding sessions, while daemon/model inspection
uses the host `/api/moonclaw/*` routes.

## Source Layout

- `main/main.mbt`: browser externs and app bootstrap only.
- `main/app_shell_model.mbt`: activity, workspace mode, drawer, and preview-tab
  shell declarations.
- `main/app_model.mbt`: top-level app `Model` and `Msg` declarations.
- `main/app_workspace_model.mbt`: saved view, tag, and search DTOs.
- `main/app_town_model.mbt`: Town, progress, event, and review DTOs.
- `main/app_inbox_model.mbt`: inbox and browser local-import DTOs.
- `main/app_daemon_model.mbt`: daemon, LaunchAgent, reveal, and native helper
  DTOs.
- `main/app_book_runtime_model.mbt`: book-pattern builder, publish result, and
  portable runtime DTOs.
- `main/app_state.mbt`: activity slug/mode helpers and static activity/drawer
  button lists.
- `main/app_initial_model.mbt`: initial top-level model construction.
- `main/app_book_pattern_state.mbt`: book-pattern defaults, selected pattern,
  and book id helpers.
- `main/app_mooncode_state.mbt`: selected MoonCode session and runtime-label
  helpers.
- `main/app_workspace_state.mbt`: selected workspace/path helpers, renderer
  guards, recent-path memory, and string-list toggles.
- `main/app_update.mbt`: top-level message router and command-reference test
  block.
- `main/app_update_navigation_actions.mbt`: activity, workspace, path, drawer,
  and quick-open navigation actions.
- `main/app_update_town_actions.mbt`: Town request draft and submission actions.
- `main/app_update_daemon_actions.mbt`: daemon, LaunchAgent, dispatch, and
  reveal actions.
- `main/app_update_inbox_actions.mbt`: inbox draft, URL/local import,
  dropped-file polling, and context-link actions.
- `main/app_update_workspace_surface_actions.mbt`: search, favorites, saved
  views, tags, notifications, and refresh actions.
- `main/app_update_results.mbt`: result reducer router.
- `main/app_update_workspace_results.mbt`: workspace, preview, saved view,
  tag, run, and search result handling.
- `main/app_update_town_results.mbt`: Town messages, requests, standing goals,
  analytics, progress, events, review rows, request submission, and standing-goal
  creation results.
- `main/app_update_inbox_results.mbt`: inbox save/import and local-file import
  results.
- `main/app_update_daemon_results.mbt`: daemon lifecycle, LaunchAgent, dispatch,
  reveal, and native helper results.
- `main/app_update_book_runtime_results.mbt`: book-pattern publish and portable
  app-tool export results.
- `main/app_update_book_builder_actions.mbt`: book-pattern, standing goal, and
  portable app-tool builder actions delegated from the top-level reducer.
- `main/app_update_mooncode_actions.mbt`: MoonCode action reducer router.
- `main/app_update_mooncode_session_actions.mbt`: session selection, composer
  draft state, model/web-search controls, and send-message flow.
- `main/app_update_mooncode_command_actions.mbt`: queued command, path command,
  message command, and preflight-override dispatch.
- `main/app_update_mooncode_runtime_actions.mbt`: runtime loop/service,
  claim/ack, and post-runtime refresh flows.
- `main/app_update_mooncode_tool_actions.mbt`: tool authorization probe flow.
- `main/app_update_mooncode_poll_actions.mbt`: MoonCode polling refresh batch.
- `main/app_update_mooncode_results.mbt`: MoonCode result reducer routing table.
- `main/app_update_mooncode_session_results.mbt`: MoonClaw daemon/model,
  capability, and MoonCode session-list result handling.
- `main/app_update_mooncode_stream_results.mbt`: MoonCode stream checkpoint and
  runtime event-sink result handling.
- `main/app_update_mooncode_artifact_results.mbt`: MoonCode review artifact,
  readiness, evidence, queue, replay, and preflight snapshot result handling.
- `main/app_update_mooncode_runtime_results.mbt`: MoonCode runtime dispatch,
  claim, ack, session creation, and command completion result handling.
- `main/app_json_helpers.mbt`, `main/app_json_projection_helpers.mbt`,
  `main/app_status_helpers.mbt`, and `main/app_url_helpers.mbt`: shared UI
  data extraction, status text, and URL helpers.
- `main/commands.mbt`: browser effects, notifications, and local import
  polling.
- `main/commands_fetch.mbt`: non-MoonCode read/fetch commands.
- `main/commands_mutation.mbt`: inbox/import/preference/Town mutation
  commands.
- `main/commands_book_builder.mbt`: book-pattern builder and portable app-tool
  commands.
- `main/commands_daemon.mbt`: daemon, LaunchAgent, dispatch, and reveal
  commands.
- `main/commands_reload.mbt`: workspace reload command batch composition.
- `main/mooncode_bootstrap_commands.mbt`: MoonClaw daemon/model probes and
  MoonCode capability fetches.
- `main/mooncode_session_fetch_commands.mbt`: MoonCode session lists, streams,
  stream checkpoints, change/review/test/package/readiness fetches.
- `main/mooncode_session_mutation_commands.mbt`: session creation, composer
  dispatch, command posting, steer/prompt selection, and MoonCode polling.
- `main/mooncode_runtime_commands.mbt`: runtime event, handoff, evidence,
  command-queue, preflight, claim, replay, supervisor, and service commands.
- `main/mooncode_tool_authorization_commands.mbt`: tool approval fetches and
  authorization probe commands.
- `main/moonwiki_views.mbt`: MoonWiki activity rail, shared side-pane labels,
  and activity-to-pane routing.
- `main/moonwiki_workspace_views.mbt`: workspace card, section tabs, and file
  tree rendering.
- `main/moonwiki_search_views.mbt`: cross-book search form and result list.
- `main/moonwiki_inbox_views.mbt`: inbox note editor, import controls, and
  local intake preview.
- `main/moonwiki_run_views.mbt`: MoonClaw run list and progress summary.
- `main/moonwiki_settings_views.mbt`: settings side pane, saved views, review
  queue, cadence calendar, analytics, and export snapshot.
- `main/moonwiki_town_views.mbt`: Town request form and top-level composition.
- `main/moonwiki_book_builder_views.mbt`: book-pattern builder and config
  preview.
- `main/moonwiki_town_status_views.mbt`: live progress, event list, and shared
  label helpers.
- `main/moonwiki_daemon_lifecycle_views.mbt`: daemon and LaunchAgent controls.
- `main/moonwiki_town_record_views.mbt`: standing-goal and request lists.
- `main/moonwiki_preview_center_views.mbt`: preview tabs, raw/site/image/text
  preview body, warnings, and preview toolbar.
- `main/moonwiki_inspector_views.mbt`: selection inspector, tags, review diff,
  favorites, and request composer.
- `main/moonwiki_drawer_views.mbt`: bottom drawer tabs, request/message/run,
  MoonCode, and recent path drawers.
- `main/moonwiki_command_palette_views.mbt`: command palette, title bar, and
  workspace-mode switch.
- `main/moonwiki_shell_views.mbt`: final app-shell composition only.
- `main/mooncode_model.mbt`: core MoonCode session, message, and event DTOs.
- `main/mooncode_daemon_model.mbt`: MoonClaw daemon/model availability DTOs.
- `main/mooncode_summary_model.mbt`: MoonCode summary, readiness, and eval
  report DTOs.
- `main/mooncode_runtime_model.mbt`: runtime handoff, command queue, dispatch,
  replay, event-sink, and claim DTOs.
- `main/mooncode_capabilities_model.mbt`: capability, boundary, runtime
  contract, tool contract, and extraction DTOs.
- `main/mooncode_review_model.mbt`: change-set, patch-set, approval, test-run,
  package-candidate, stream, and authorization DTOs.
- `main/mooncode_action_model.mbt`: action-plan, command preflight, and runtime
  evidence DTOs.
- `main/mooncode_stream_parser.mbt`: MoonCode incremental stream parser.
- `main/mooncode_views.mbt`: MoonCode shell, session picker, center surface,
  and composer.
- `main/mooncode_lifecycle_views.mbt`: resume, steering, cancel, patch, and
  package lifecycle panels.
- `main/mooncode_transcript_views.mbt`: transcript, stream event transcript,
  and preflight rendering.
- `main/mooncode_command_views.mbt`: command queue and queued-command controls.
- `main/mooncode_runtime_feed_views.mbt`: runtime command feed, lifecycle, and
  command-feed rows.
- `main/mooncode_runtime_replay_views.mbt`: runtime replay state and replay
  rows.
- `main/mooncode_runtime_sink_views.mbt`: runtime event sink, command-scoped
  progress, unscoped runtime events, and sink events.
- `main/mooncode_action_plan_views.mbt`: action plan, recommended commands,
  acceptance gates, runtime evidence, and command evidence rows.
- `main/mooncode_runtime_claim_views.mbt`: runtime claim/lease controls,
  runtime service state, claim rows, and manual ack controls.
- `main/mooncode_runtime_dispatch_receipt_views.mbt`: dispatch receipts, ack
  audit, proof gates, and dispatch-state classification.
- `main/mooncode_runtime_execution_views.mbt`: shared execution summaries,
  tool policies, and runtime execution checklists.
- `main/mooncode_event_views.mbt`: event lanes, live tail, shared info chips,
  and lane rows.
- `main/mooncode_eval_report_views.mbt`: MoonCode eval-report evidence panel.
- `main/mooncode_runtime_handoff_views.mbt`: runtime handoff summary and
  resume-contract panel.
- `main/mooncode_runtime_handoff_detail_views.mbt`: runtime turn packet,
  supervisor, execution plan, consumer status, and shared handoff status class.
- `main/mooncode_review_views.mbt`: review queue plus shared event helpers.
- `main/mooncode_change_set_views.mbt`: durable MoonBook change-set panel.
- `main/mooncode_patch_set_views.mbt`: file patch-set and hunk review panel.
- `main/mooncode_test_run_views.mbt`: test/build run panel.
- `main/mooncode_package_candidate_views.mbt`: MoonBook package candidate and
  source inventory panels.
- `main/mooncode_tool_review_views.mbt`: tool authorization and approval panels.
- `main/mooncode_inspector_views.mbt`: MoonCode inspector shell, runtime
  controls, model picker, and drawer summary.
- `main/mooncode_capability_views.mbt`: capability contract, runtime boundary,
  engine readiness, extraction roles, command specs, and tool contract panels.
- `main/mooncode_readiness_views.mbt`: readiness audit, summary counters,
  checklist rendering, and eval-readiness check panels.

The warning baseline is intentionally clean:

- `moon check --target native` from the repository root.
- `moon check --target js` from `ui/rabbita-desk`.
- `npm run build` from `ui/rabbita-desk`.

```bash
npm run dev
npm run build
```
