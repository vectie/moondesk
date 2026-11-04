# Code Mode Test Plan

Use [MoonCode Workspace](MOONCODE.md) for the current ownership boundary and
the [discussion plan](mooncode-discussion-2026-11-04/CURRENT_PLAN.md) for the
historical design decisions. Goal, Goal Runtime, independent quality/no-change
protocols and desktop acceptance inference have been removed. Current execution
and evidence limits are documented in MoonClaw's executable-book runtime boundary.
The [agent machine and dynamic graph record](MOONCODE_AGENT_MACHINE_AND_DYNAMIC_GRAPH.md)
defines the later design direction; graph projection and complete dependency
analysis are not existing runtime guarantees.

## Scope

MoonClaw owns agent execution, tools, approvals, durable facts, and recovery.
MoonDesk owns input, canonical conversation display, artifact access, and local
presentation state. Tests must preserve that boundary.

Default to one primary agent completing authorized work without unnecessary
human intervention. Verification failures, invalid arguments, compaction, and
restart should lead to automatic repair or recovery where possible.

## Focused Scenarios

| Area | Behavior to verify |
| --- | --- |
| Delivery | The requested output is accessible and matches the described result. Relevant checks exercise the requested behavior. |
| Completion | Repairable gaps returned from `finish` continue the same agent. Plain success text, unrelated successful commands, and stale checks cannot establish completion. |
| Task changes | New instructions remain durable and supersede affected assumptions. A previous task revision cannot settle the revised task. |
| No change | Investigation and already-satisfied requests can finish with evidence without manufacturing a file modification. Explicit mutation requirements still apply. |
| Tool calls | Unknown tools, invalid arguments, and truncated calls do not execute. Errors return to the model for correction. |
| Working method | Check a real feature from request through change and verification. Test observable behavior, context continuity and recovery; matching prompt phrases cannot establish delivery quality. |
| Authority | Execution stays within the current grant. Rejected or pending approval does not become permission; changing an action cannot reuse unrelated authorization. |
| Recovery | Completed results are reused after restart. Uncertain side effects are reconciled before replay; unresolved outcomes remain explicit. |
| Empty model follow-up | The same claim can resume without milestones, including after rejected completion or restart. Progress state does not grant or deny completion. |
| Conversation | User input appears immediately. Work is shown only from runtime facts. Canonical turn identity and ordering survive refresh. |
| Concurrent responses | Stale, cross-session, or compact listing responses cannot overwrite a newer selected conversation or draft. |
| Connection failure | Reconnect retains the last accepted state; failure is distinct from a successful empty result. |
| Cancellation | Stop names the active command and reaches the runtime. A UI timer cannot claim an operation was cancelled. |
| Session lifecycle | Rename, archive, restore, and deletion follow runtime state; deleting a session does not delete MoonBook files. |

Choose scenarios affected by the change. Do not require packaging, UI review,
isolated snapshots, or human acceptance for every ordinary task.

## Test Locations

- `mooncode/core`: typed contracts, decoding, and pure state rules.
- `internal/mooncode`: runtime transport adaptation and canonical response handling.
- `internal/moonwiki`: HTTP/session/watch boundaries using temporary workspaces.
- `ui/rabbita-desk/main`: selection, drafts, optimistic input, stale responses,
  controls, and rendering.
- MoonClaw `internal/mooncode_tools`: pure execution properties and shell analysis.
- MoonClaw daemon tests: tool execution, completion, persistence, crash recovery,
  and commit followed by repair/checks in the same command.

Reuse existing fixtures and harnesses. Build temporary paths through MoonLib
contracts. Do not recreate a MoonDesk session store, event replay engine, or
acceptance reducer merely to make a test pass.

## Validation Entry Points

During implementation, check and test the changed package. For example:

```sh
moon check internal/mooncode --target native
moon test internal/mooncode --target native
```

MoonBit changes also require `moon info`, `moon fmt`, and inspection of the
generated interface diff. The repository entry points are:

```sh
scripts/validate.sh fast
scripts/validate.sh full
```

Full validation includes the production build and can update generated
artifacts. Run it for the finished implementation or release, after focused
checks. Documentation-only maintenance checks references and whitespace.

Keep behavioral tool, authority and recovery checks. Remove assertions for
retired protocols and prompt phrases with their implementations; preserve the
user-facing behavior in the remaining execution-path tests.

Revision-specific validation results and known release limitations belong in
[HANDOFF](../HANDOFF.md). Historical test counts are not pass criteria; run the
relevant checks against the source revision being delivered.

## Interactive And Model Evaluation

For conversation/UI changes, exercise the real interface with keyboard and
mouse input, multiple turns, narrow layouts, reload, reconnect, and applicable
approval/cancellation states. When an installed-app update is in scope,
verify the actual app as well as the browser preview.

Evaluate model behavior on representative tasks in isolated workspaces with
independent output checks. Compare deliverable quality, user intervention,
rework, latency, and total cost. Do not require live provider calls for ordinary
unit tests or infer task success solely from `finish`.

## Historical Evidence

The [July 10 journey report](MOONCODE_USER_JOURNEY_E2E_REPORT_2026-07-10.md) and
[July 15 lifecycle report](MOONCODE_SESSION_LIFECYCLE_E2E_2026-07-15.md) retain
their dated observations. Their test counts, models, ports, and results are
not current release or runtime evidence.
