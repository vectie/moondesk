///|
// MoonCode patch lifecycle summary for header-level diff review visibility.

///|
pub fn session_patch_lifecycle(events : Array[Json]) -> Json {
  let patches = patch_set_entries(events)
  let pending_count = count_patch_review_state(patches, "pending")
  let accepted_count = count_patch_review_state(patches, "accepted")
  let rejected_count = count_patch_review_state(patches, "rejected")
  let applied_count = count_patch_review_state(patches, "applied")
  let reverted_count = count_patch_review_state(patches, "reverted")
  let partial_count = count_patch_review_state(patches, "partial")
  let runtime_applied_count = count_patch_execution_state(patches, "applied")
  let runtime_reverted_count = count_patch_execution_state(patches, "reverted")
  let runtime_pending_count = count_patch_execution_state(patches, "pending")
  let runtime_partial_count = count_patch_execution_state(patches, "partial")
  let gate_counts = patch_lifecycle_gate_counts(patches)
  let rows = [ for patch in patches => patch_lifecycle_row(patch) ]
  {
    "kind": "mooncode-patch-lifecycle",
    "protocol": protocol_version(),
    "patch_count": patches.length(),
    "status": patch_set_status(
      accepted_count, rejected_count, applied_count, reverted_count, pending_count,
      partial_count,
    ),
    "execution_status": patch_execution_set_status(
      runtime_applied_count, runtime_reverted_count, runtime_pending_count, runtime_partial_count,
    ),
    "pending_patch_count": pending_count,
    "accepted_patch_count": accepted_count,
    "rejected_patch_count": rejected_count,
    "applied_patch_count": applied_count,
    "reverted_patch_count": reverted_count,
    "partial_patch_count": partial_count,
    "runtime_applied_patch_count": runtime_applied_count,
    "runtime_reverted_patch_count": runtime_reverted_count,
    "runtime_pending_patch_count": runtime_pending_count,
    "runtime_partial_patch_count": runtime_partial_count,
    "runtime_patch_proof_count": count_patch_execution_proofs(events),
    "needs_review_count": summary_json_int(
      gate_counts,
      "needs_review_count",
      default=0,
    ),
    "runtime_needed_count": summary_json_int(
      gate_counts,
      "runtime_needed_count",
      default=0,
    ),
    "runtime_proven_count": summary_json_int(
      gate_counts,
      "runtime_proven_count",
      default=0,
    ),
    "blocked_count": summary_json_int(gate_counts, "blocked_count", default=0),
    "ready_count": summary_json_int(gate_counts, "ready_count", default=0),
    "latest_status": patch_lifecycle_latest_status(rows),
    "next_step": patch_lifecycle_next_step(patches, gate_counts),
    "rows": Json::array(rows),
    "rule": "Patch lifecycle is derived from MoonCode patch-set entries. Moondesk renders this summary and review controls, while MoonClaw or standalone MoonCode must perform apply/revert mutations and emit runtime.patch_applied/runtime.patch_reverted proof.",
  }
}

///|
fn patch_lifecycle_gate_counts(patches : Array[Json]) -> Json {
  let mut needs_review_count = 0
  let mut runtime_needed_count = 0
  let mut runtime_proven_count = 0
  let mut blocked_count = 0
  let mut ready_count = 0
  let mut partial_count = 0
  for patch in patches {
    match json_string(patch, "gate_status", default="") {
      "needs-review" => needs_review_count += 1
      "runtime-needed" => runtime_needed_count += 1
      "runtime-proven" => runtime_proven_count += 1
      "blocked" => blocked_count += 1
      "ready" => ready_count += 1
      "partial" => partial_count += 1
      _ => ()
    }
  }
  {
    "needs_review_count": needs_review_count,
    "runtime_needed_count": runtime_needed_count,
    "runtime_proven_count": runtime_proven_count,
    "blocked_count": blocked_count,
    "ready_count": ready_count,
    "partial_count": partial_count,
  }
}

///|
fn patch_lifecycle_row(patch : Json) -> Json {
  {
    "path": json_string(patch, "path", default=""),
    "title": json_string(patch, "title", default=""),
    "review_state": json_string(patch, "review_state", default="pending"),
    "execution_state": json_string(patch, "execution_state", default="pending"),
    "gate_status": json_string(patch, "gate_status", default=""),
    "next_action": json_string(patch, "next_action", default=""),
    "blocked_reason": json_string(patch, "blocked_reason", default=""),
    "created_at": json_string(patch, "created_at", default=""),
    "hunk_count": summary_json_int(patch, "hunk_count", default=0),
    "runtime_proof_count": summary_json_int(
      patch,
      "runtime_proof_count",
      default=0,
    ),
    "diff_present": json_bool(patch, "diff_present", default=false),
  }
}

///|
fn patch_lifecycle_latest_status(rows : Array[Json]) -> String {
  if rows.length() == 0 {
    return "idle"
  }
  let latest = rows[rows.length() - 1]
  let gate = json_string(latest, "gate_status", default="")
  if gate != "" {
    gate
  } else {
    json_string(latest, "review_state", default="pending")
  }
}

///|
fn patch_lifecycle_next_step(
  patches : Array[Json],
  gate_counts : Json,
) -> String {
  if patches.length() == 0 {
    return "No file diffs have been recorded for patch review."
  }
  let needs_review_count = summary_json_int(
    gate_counts,
    "needs_review_count",
    default=0,
  )
  let runtime_needed_count = summary_json_int(
    gate_counts,
    "runtime_needed_count",
    default=0,
  )
  let runtime_proven_count = summary_json_int(
    gate_counts,
    "runtime_proven_count",
    default=0,
  )
  let blocked_count = summary_json_int(gate_counts, "blocked_count", default=0)
  let partial_count = summary_json_int(gate_counts, "partial_count", default=0)
  if needs_review_count > 0 {
    "Accept or reject pending patch targets before packaging or committing."
  } else if runtime_needed_count > 0 {
    "Dispatch apply_patch or revert_patch through MoonClaw and wait for runtime proof."
  } else if partial_count > 0 {
    "Finish remaining hunk-level review or runtime proof before packaging or committing."
  } else if blocked_count > 0 {
    "Rejected patch targets block apply/package until the operator accepts them again."
  } else if runtime_proven_count > 0 {
    "Run tests or build after runtime-proven patch execution."
  } else {
    "Patch review lifecycle is settled for the visible patch rows."
  }
}
