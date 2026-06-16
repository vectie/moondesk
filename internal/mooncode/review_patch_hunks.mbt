///|
// MoonCode patch diff hunk extraction and hunk-level review projection.

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
fn patch_hunk_target(path : String, hunk_id : String) -> String {
  if path == "" {
    hunk_id
  } else {
    path + "#" + hunk_id
  }
}
