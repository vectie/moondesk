///|
pub fn runtime_claim_consumer_contract_json(session_id : String) -> Json {
  {
    "consumer": "moonclaw",
    "endpoint": "/api/mooncode/sessions/\{session_id}/runtime-claim",
    "method": "POST",
    "request": {
      "consumer_id": "moonclaw-runtime",
      "max_count": 1,
      "force": false,
      "lease_expires_at": "optional ISO-8601 timestamp supplied by the consumer",
      "now": "optional ISO-8601 clock used to recover expired claims deterministically",
    },
    "claim_status": "runtime-claimed",
    "ack_endpoint": "/api/mooncode/sessions/\{session_id}/runtime-replay",
    "authorization_rule": "commands whose tool_authorization snapshot has runtime_may_execute=false, pending approvals, or rejected approvals are not claimable and block later non-delivered rows until a later command record carries an approving snapshot",
    "ordering_rule": "claim returns pending valid commands in runtime-commands.jsonl order; delivered receipts are skipped, but active claimed, invalid, or tool-authorization-blocked earlier commands block later non-delivered rows unless the active claim expires; force=true is only for lease recovery and does not bypass tool authorization",
    "duplicate_guard": "commands with delivered receipts are never claimable; active claimed receipts block later work unless force=true; expired claimed receipts and failed runtime receipts become claimable without force; blocked tool authorization never becomes claimable without an approving snapshot",
    "owner": runtime_owner_record(),
  }
}

///|
pub fn runtime_replay_consumer_contract_json(session_id : String) -> Json {
  {
    "consumer": "moonclaw",
    "reference": "mooncode/runtime-replay",
    "stdin": "JSONL lines from pending_mooncode_jsonl or pending_commands[*].mooncode_command",
    "stdout": "MoonCode protocol JSONL runtime events normalized by Moondesk into MoonCode lanes",
    "claim": "POST /api/mooncode/sessions/\{session_id}/runtime-claim with {consumer_id,max_count,force,lease_expires_at,now} to atomically mark commands as runtime-claimed before execution",
    "ack": "POST /api/mooncode/sessions/\{session_id}/runtime-replay with {consumer_id,command_id,status,detail,events[]} or {receipts:[...]} to append runtime receipts and optional stream events",
    "session_id": session_id,
    "required_order": "one ordered queue; do not start a later prompt before earlier pending prompt/steer/cancel records are handled",
    "authorization_rule": "do not consume pending_commands whose tool_authorization snapshot has runtime_may_execute=false; resolve tool approvals first",
    "duplicate_guard": "skip command ids with runtime-accepted, runtime-acknowledged, runtime-completed, active runtime-claimed receipts, or blocked tool authorization; active earlier claims, invalid earlier commands, and tool-authorization-blocked earlier commands block later non-delivered rows; expired claims and failed runtime receipts are retryable",
    "event_sink": "\{@moonsuite.product_display_artifact("mooncode", "sessions/<session-id>/events.jsonl")} or /v1/code/sessions/<session-id>/stream",
  }
}
