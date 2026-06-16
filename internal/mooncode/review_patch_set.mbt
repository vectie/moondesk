///|
// MoonCode patch-set review and runtime execution projection.

///|
pub fn patch_set_manifest(
  session : Json,
  events : Array[Json],
  recorded_at~ : String,
  manifest_path~ : String,
  absolute_manifest_path~ : String,
) -> Json {
  let patches = patch_set_entries(events)
  let accepted_count = count_patch_review_state(patches, "accepted")
  let rejected_count = count_patch_review_state(patches, "rejected")
  let applied_count = count_patch_review_state(patches, "applied")
  let reverted_count = count_patch_review_state(patches, "reverted")
  let pending_count = count_patch_review_state(patches, "pending")
  let runtime_applied_count = count_patch_execution_state(patches, "applied")
  let runtime_reverted_count = count_patch_execution_state(patches, "reverted")
  let runtime_pending_count = count_patch_execution_state(patches, "pending")
  {
    "kind": "mooncode-patch-set",
    "protocol": "mooncode.v1",
    "status": patch_set_status(
      accepted_count, rejected_count, applied_count, reverted_count, pending_count,
    ),
    "execution_status": patch_execution_set_status(
      runtime_applied_count, runtime_reverted_count, runtime_pending_count,
    ),
    "session_id": json_string(session, "id", default=""),
    "workspace_id": json_string(session, "workspace_id", default=""),
    "workspace_name": json_string(session, "workspace_name", default=""),
    "task_id": json_string(session, "moonclaw_task_id", default=""),
    "recorded_at": recorded_at,
    "manifest_path": manifest_path,
    "absolute_manifest_path": absolute_manifest_path,
    "patches": Json::array(patches),
    "patch_count": patches.length(),
    "accepted_patch_count": accepted_count,
    "rejected_patch_count": rejected_count,
    "applied_patch_count": applied_count,
    "reverted_patch_count": reverted_count,
    "pending_patch_count": pending_count,
    "runtime_applied_patch_count": runtime_applied_count,
    "runtime_reverted_patch_count": runtime_reverted_count,
    "runtime_pending_patch_count": runtime_pending_count,
    "runtime_patch_proof_count": count_patch_execution_proofs(events),
    "last_command_packet": summary_json_object_field_or_empty(
      session, "mooncode_last_command_packet",
    ),
    "last_review_receipt": summary_json_object_field_or_empty(
      session, "mooncode_last_review_receipt",
    ),
    "change_set_manifest": summary_json_object_field_or_empty(
      session, "mooncode_last_change_set_manifest",
    ),
    "owner": review_artifact_owner("moonbook"),
    "next_runtime_step": "MoonClaw or standalone MoonCode should turn this patch set into explicit staged hunks with apply/revert and verified test gates.",
  }
}

///|
pub fn patch_set_entries(events : Array[Json]) -> Array[Json] {
  let entries : Array[Json] = []
  let seen : Map[String, Bool] = {}
  for event in events {
    if json_string(event, "lane", default="") != "diff" {
      continue
    }
    let path = json_string(event, "path", default="")
    let id = if path == "" {
      json_string(event, "id", default="patch:\{event.stringify()}")
    } else {
      path
    }
    if seen.get(id).unwrap_or(false) {
      continue
    }
    seen[id] = true
    entries.push(patch_set_event_entry(event, events))
  }
  entries
}

///|
pub fn count_patch_review_state(patches : Array[Json], state : String) -> Int {
  let mut count = 0
  for patch in patches {
    if json_string(patch, "review_state", default="") == state {
      count += 1
    }
  }
  count
}

///|
pub fn count_patch_execution_state(
  patches : Array[Json],
  state : String,
) -> Int {
  let mut count = 0
  for patch in patches {
    if json_string(patch, "execution_state", default="") == state {
      count += 1
    }
  }
  count
}

///|
pub fn count_patch_execution_proofs(events : Array[Json]) -> Int {
  let mut count = 0
  for event in events {
    if patch_execution_event_kind(event) != "" &&
      json_string(event, "status", default="") != "failed" {
      count += 1
    }
  }
  count
}

///|
fn patch_set_status(
  accepted_count : Int,
  rejected_count : Int,
  applied_count : Int,
  reverted_count : Int,
  pending_count : Int,
) -> String {
  if reverted_count > 0 {
    "reverted"
  } else if applied_count > 0 {
    "applied"
  } else if rejected_count > 0 {
    "rejected"
  } else if pending_count > 0 {
    "pending"
  } else if accepted_count > 0 {
    "accepted"
  } else {
    "empty"
  }
}

///|
fn patch_execution_set_status(
  applied_count : Int,
  reverted_count : Int,
  pending_count : Int,
) -> String {
  if reverted_count > 0 {
    "reverted"
  } else if pending_count > 0 && applied_count > 0 {
    "partial"
  } else if applied_count > 0 {
    "applied"
  } else {
    "pending"
  }
}

///|
fn patch_set_event_entry(event : Json, events : Array[Json]) -> Json {
  let path = json_string(event, "path", default="")
  let diff = json_string(event, "diff", default="")
  let packet = summary_json_object_field_or_empty(event, "command_packet")
  let review_state = patch_review_state_for_path(path, events)
  let execution_state = patch_execution_state_for_path(path, events)
  let hunks = patch_hunks(path, diff, events)
  let runtime_proof_count = patch_execution_event_count(path, "", events)
  {
    "id": json_string(event, "id", default=""),
    "path": path,
    "title": json_string(event, "title", default=""),
    "status": json_string(event, "status", default=""),
    "review_state": review_state,
    "execution_state": execution_state,
    "created_at": json_string(event, "created_at", default=""),
    "detail": json_string(event, "detail", default=""),
    "diff": diff,
    "diff_present": diff != "",
    "hunks": Json::array(hunks),
    "hunk_count": hunks.length(),
    "command": json_string(event, "command", default=""),
    "command_id": json_string(packet, "command_id", default=""),
    "accepted_review_count": patch_review_event_count(path, "accept", events),
    "rejected_review_count": patch_review_event_count(path, "reject", events),
    "applied_review_count": patch_review_event_count(
      path, "apply_patch", events,
    ),
    "reverted_review_count": patch_review_event_count(
      path, "revert_patch", events,
    ),
    "runtime_applied_count": patch_execution_event_count(
      path, "runtime.patch_applied", events,
    ),
    "runtime_reverted_count": patch_execution_event_count(
      path, "runtime.patch_reverted", events,
    ),
    "runtime_proof_count": runtime_proof_count,
    "execution_verified": execution_state == "applied" ||
    execution_state == "reverted",
    "package_review_count": patch_review_event_count(path, "package", events),
    "gate_status": patch_review_gate_status(
      review_state, execution_state, runtime_proof_count,
    ),
    "next_action": patch_review_next_action(
      review_state, execution_state, runtime_proof_count,
    ),
    "blocked_reason": patch_review_blocked_reason(
      review_state, execution_state, runtime_proof_count,
    ),
  }
}

///|
fn test_run_entry(event : Json) -> Json {
  let command = json_string(event, "command", default="")
  let packet = summary_json_object_field_or_empty(event, "command_packet")
  {
    "id": json_string(event, "id", default="test:\{event.stringify()}"),
    "title": json_string(event, "title", default="Test/build run"),
    "kind": json_string(event, "kind", default=""),
    "status": json_string(event, "status", default=""),
    "run_state": test_run_state(event),
    "created_at": json_string(event, "created_at", default=""),
    "path": json_string(event, "path", default=""),
    "command": command,
    "exit_code": summary_json_int(event, "exit_code", default=0),
    "detail": json_string(event, "detail", default=""),
    "target": test_run_target(event),
    "verified": test_event_is_completed(event) && !test_event_failed(event),
    "command_id": json_string(packet, "command_id", default=""),
  }
}

///|
fn test_run_target(event : Json) -> String {
  let command = json_string(event, "command", default="")
  if command != "" {
    return command
  }
  let path = json_string(event, "path", default="")
  if path != "" {
    return path
  }
  json_string(event, "id", default="test:\{event.stringify()}")
}

///|
fn patch_hunks(
  path : String,
  diff : String,
  events : Array[Json],
) -> Array[Json] {
  let hunks : Array[Json] = []
  if diff == "" {
    return hunks
  }
  let lines : Array[String] = diff
    .split("\n")
    .map(line => line.to_owned())
    .collect()
  let mut current_header = ""
  let current_lines : Array[String] = []
  let mut hunk_index = 0
  let flush = fn() {
    if current_header != "" || current_lines.length() > 0 {
      hunk_index += 1
      hunks.push(
        patch_hunk_record(
          path, hunk_index, current_header, current_lines, events,
        ),
      )
      current_lines.clear()
      current_header = ""
    }
  }
  for line in lines {
    if line.has_prefix("@@") {
      flush()
      current_header = line
    } else if current_header != "" ||
      line.has_prefix("+") ||
      line.has_prefix("-") ||
      line.has_prefix(" ") {
      current_lines.push(line)
    }
  }
  flush()
  if hunks.length() == 0 {
    hunks.push(patch_hunk_record(path, 1, "synthetic", lines, events))
  }
  hunks
}

///|
fn patch_hunk_record(
  path : String,
  index : Int,
  header : String,
  lines : Array[String],
  events : Array[Json],
) -> Json {
  let mut added = 0
  let mut removed = 0
  let mut context = 0
  for line in lines {
    if line.has_prefix("+") && !line.has_prefix("+++") {
      added += 1
    } else if line.has_prefix("-") && !line.has_prefix("---") {
      removed += 1
    } else {
      context += 1
    }
  }
  let hunk_id = "hunk-\{index}"
  let target = patch_hunk_target(path, hunk_id)
  let review_state = patch_review_state_for_path(target, events)
  let execution_state = patch_execution_state_for_path(target, events)
  let runtime_proof_count = patch_execution_event_count(target, "", events)
  {
    "id": hunk_id,
    "index": index,
    "target": target,
    "header": header,
    "review_state": review_state,
    "execution_state": execution_state,
    "added_lines": added,
    "removed_lines": removed,
    "context_lines": context,
    "line_count": lines.length(),
    "preview": trim_event_text(lines.join("\n")),
    "accepted_review_count": patch_review_event_count(target, "accept", events),
    "rejected_review_count": patch_review_event_count(target, "reject", events),
    "applied_review_count": patch_review_event_count(
      target, "apply_patch", events,
    ),
    "reverted_review_count": patch_review_event_count(
      target, "revert_patch", events,
    ),
    "runtime_applied_count": patch_execution_event_count(
      target, "runtime.patch_applied", events,
    ),
    "runtime_reverted_count": patch_execution_event_count(
      target, "runtime.patch_reverted", events,
    ),
    "runtime_proof_count": runtime_proof_count,
    "gate_status": patch_review_gate_status(
      review_state, execution_state, runtime_proof_count,
    ),
    "next_action": patch_review_next_action(
      review_state, execution_state, runtime_proof_count,
    ),
    "blocked_reason": patch_review_blocked_reason(
      review_state, execution_state, runtime_proof_count,
    ),
  }
}

///|
fn patch_review_gate_status(
  review_state : String,
  execution_state : String,
  runtime_proof_count : Int,
) -> String {
  if review_state == "rejected" {
    "blocked"
  } else if execution_state == "applied" || execution_state == "reverted" {
    "runtime-proven"
  } else if review_state == "applied" ||
    review_state == "reverted" ||
    (runtime_proof_count == 0 && review_state == "accepted") {
    "runtime-needed"
  } else if review_state == "pending" {
    "needs-review"
  } else {
    "ready"
  }
}

///|
fn patch_review_next_action(
  review_state : String,
  execution_state : String,
  runtime_proof_count : Int,
) -> String {
  if review_state == "rejected" {
    "none"
  } else if execution_state == "applied" {
    "run_tests"
  } else if execution_state == "reverted" {
    "review"
  } else if review_state == "pending" {
    "accept-or-reject"
  } else if review_state == "accepted" {
    "apply_patch"
  } else if review_state == "applied" || review_state == "reverted" {
    if runtime_proof_count > 0 {
      "run_tests"
    } else {
      "await-runtime-proof"
    }
  } else {
    "review"
  }
}

///|
fn patch_review_blocked_reason(
  review_state : String,
  execution_state : String,
  runtime_proof_count : Int,
) -> String {
  if review_state == "rejected" {
    "Operator rejected this patch target; accept it again before applying or packaging."
  } else if execution_state == "applied" {
    "Runtime applied this patch target; run tests before package or commit."
  } else if execution_state == "reverted" {
    "Runtime reverted this patch target; review the diff before applying again."
  } else if review_state == "applied" || review_state == "reverted" {
    if runtime_proof_count > 0 {
      "Runtime proof is present; run tests before package or commit."
    } else {
      "Operator requested patch execution; MoonClaw or standalone MoonCode must emit runtime proof."
    }
  } else if review_state == "accepted" {
    "Accepted by operator and ready for MoonClaw or standalone MoonCode to apply."
  } else {
    ""
  }
}

///|
fn patch_hunk_target(path : String, hunk_id : String) -> String {
  if path == "" {
    hunk_id
  } else {
    path + "#" + hunk_id
  }
}

///|
fn patch_review_event_count(
  path : String,
  command : String,
  events : Array[Json],
) -> Int {
  let mut count = 0
  for event in events {
    if json_string(event, "lane", default="") != "review" ||
      json_string(event, "command", default="") != command ||
      json_string(event, "status", default="") == "failed" {
      continue
    }
    let event_path = json_string(event, "path", default="")
    if patch_review_target_matches(path, event_path) {
      count += 1
    }
  }
  count
}

///|
fn patch_execution_event_count(
  path : String,
  kind : String,
  events : Array[Json],
) -> Int {
  let mut count = 0
  for event in events {
    let event_kind = patch_execution_event_kind(event)
    if event_kind == "" || json_string(event, "status", default="") == "failed" {
      continue
    }
    if kind != "" && event_kind != kind {
      continue
    }
    let event_path = json_string(event, "path", default="")
    if patch_review_target_matches(path, event_path) {
      count += 1
    }
  }
  count
}

///|
fn patch_execution_event_kind(event : Json) -> String {
  let kind = json_string(event, "kind", default="")
  match kind {
    "runtime.patch_applied" | "runtime.patch_reverted" => kind
    _ => ""
  }
}

///|
fn patch_review_parent_target(target : String) -> String {
  if !target.contains("#hunk-") {
    return target
  }
  let parts : Array[String] = target
    .split("#hunk-")
    .map(part => part.to_owned())
    .collect()
  if parts.length() == 0 {
    target
  } else {
    parts[0]
  }
}
