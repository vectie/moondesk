///|
pub fn change_set_manifest(
  session : Json,
  events : Array[Json],
  recorded_at~ : String,
  manifest_path~ : String,
  absolute_manifest_path~ : String,
) -> Json {
  let diff_events = change_set_lane_entries(events, "diff")
  let test_events = change_set_lane_entries(events, "test")
  let artifact_events = change_set_lane_entries(events, "artifact")
  let review_events = change_set_lane_entries(events, "review")
  let accepted_count = count_review_command(events, "accept")
  let rejected_count = count_review_command(events, "reject")
  {
    "kind": "mooncode-change-set",
    "protocol": "mooncode.v1",
    "status": review_state(diff_events.length(), accepted_count, rejected_count),
    "session_id": json_string(session, "id", default=""),
    "workspace_id": json_string(session, "workspace_id", default=""),
    "workspace_name": json_string(session, "workspace_name", default=""),
    "task_id": json_string(session, "moonclaw_task_id", default=""),
    "recorded_at": recorded_at,
    "manifest_path": manifest_path,
    "absolute_manifest_path": absolute_manifest_path,
    "diffs": Json::array(diff_events),
    "tests": Json::array(test_events),
    "artifacts": Json::array(artifact_events),
    "reviews": Json::array(review_events),
    "diff_count": diff_events.length(),
    "test_count": test_events.length(),
    "artifact_count": artifact_events.length(),
    "review_count": review_events.length(),
    "accepted_review_count": accepted_count,
    "rejected_review_count": rejected_count,
    "pending_diff_count": pending_diff_count(
      diff_events.length(),
      accepted_count,
      rejected_count,
    ),
    "verified_test_count": count_verified_tests(events),
    "failed_test_count": count_failed_tests(events),
    "last_command_packet": summary_json_object_field_or_empty(
      session, "mooncode_last_command_packet",
    ),
    "last_review_receipt": summary_json_object_field_or_empty(
      session, "mooncode_last_review_receipt",
    ),
    "last_package_manifest": summary_json_object_field_or_empty(
      session, "mooncode_last_package_manifest",
    ),
    "owner": review_artifact_owner("moonbook"),
    "next_runtime_step": "MoonClaw or standalone MoonCode should promote this change set into verified patch staging, tests, and packaged MoonBook code.",
  }
}

///|
pub fn tool_approvals_manifest(
  session : Json,
  events : Array[Json],
  recorded_at~ : String,
  manifest_path~ : String,
  absolute_manifest_path~ : String,
) -> Json {
  let approvals = tool_approval_entries(events)
  let approved_count = count_tool_approval_state(approvals, "approved")
  let rejected_count = count_tool_approval_state(approvals, "rejected")
  let pending_count = count_tool_approval_state(approvals, "pending")
  {
    "kind": "mooncode-tool-approvals",
    "protocol": "mooncode.v1",
    "status": if rejected_count > 0 {
      "rejected"
    } else if pending_count > 0 {
      "pending"
    } else if approved_count > 0 {
      "approved"
    } else {
      "empty"
    },
    "session_id": json_string(session, "id", default=""),
    "workspace_id": json_string(session, "workspace_id", default=""),
    "workspace_name": json_string(session, "workspace_name", default=""),
    "task_id": json_string(session, "moonclaw_task_id", default=""),
    "recorded_at": recorded_at,
    "manifest_path": manifest_path,
    "absolute_manifest_path": absolute_manifest_path,
    "approvals": Json::array(approvals),
    "approval_count": approvals.length(),
    "pending_approval_count": pending_count,
    "approved_approval_count": approved_count,
    "rejected_approval_count": rejected_count,
    "last_command_packet": summary_json_object_field_or_empty(
      session, "mooncode_last_command_packet",
    ),
    "last_review_receipt": summary_json_object_field_or_empty(
      session, "mooncode_last_review_receipt",
    ),
    "owner": {
      "ui": "moondesk",
      "runtime": "moonclaw",
      "review": "moonbook",
      "extractable_component": "mooncode",
    },
    "next_runtime_step": "MoonClaw or standalone MoonCode should enforce these tool approval decisions before executing policy/review-gated tools.",
  }
}

///|
pub fn change_set_lane_entries(
  events : Array[Json],
  lane : String,
) -> Array[Json] {
  let entries : Array[Json] = []
  for event in events {
    if json_string(event, "lane", default="") == lane {
      entries.push(change_set_event_entry(event))
    }
  }
  entries
}

///|
pub fn change_set_event_entry(event : Json) -> Json {
  let packet = summary_json_object_field_or_empty(event, "command_packet")
  {
    "id": json_string(event, "id", default=""),
    "kind": json_string(event, "kind", default=""),
    "title": json_string(event, "title", default=""),
    "status": json_string(event, "status", default=""),
    "path": json_string(event, "path", default=""),
    "command": json_string(event, "command", default=""),
    "exit_code": summary_json_int(event, "exit_code", default=0),
    "created_at": json_string(event, "created_at", default=""),
    "detail": json_string(event, "detail", default=""),
    "diff": json_string(event, "diff", default=""),
    "command_id": json_string(packet, "command_id", default=""),
  }
}

///|
pub fn count_package_runtime_proofs(events : Array[Json]) -> Int {
  let mut count = 0
  for event in events {
    if package_runtime_event_state(event) != "" &&
      json_string(event, "status", default="") != "failed" {
      count += 1
    }
  }
  count
}

///|
pub fn count_package_runtime_state(events : Array[Json], state : String) -> Int {
  let mut count = 0
  for event in events {
    if package_runtime_event_state(event) == state &&
      json_string(event, "status", default="") != "failed" {
      count += 1
    }
  }
  count
}

///|
fn review_artifact_owner(artifact_owner : String) -> Json {
  {
    "ui": "moondesk",
    "runtime": "moonclaw",
    "artifact": artifact_owner,
    "review": "moonbook",
    "extractable_component": "mooncode",
  }
}
