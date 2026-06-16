///|
pub fn command_preflight_selected_patch(
  context_path : String,
  patch_entries : Array[Json],
) -> Json {
  if context_path == "" {
    return command_preflight_patch_summary(
      context_path, false, "", "", "", "", "",
    )
  }
  for patch in patch_entries {
    if json_string(patch, "path", default="") == context_path {
      return command_preflight_patch_summary(
        context_path,
        true,
        json_string(patch, "review_state", default="pending"),
        json_string(patch, "execution_state", default="pending"),
        json_string(patch, "gate_status", default="needs-review"),
        json_string(patch, "next_action", default="review"),
        json_string(patch, "blocked_reason", default=""),
      )
    }
    for hunk in json_array_items(patch, "hunks") {
      if json_string(hunk, "target", default="") == context_path {
        return command_preflight_patch_summary(
          context_path,
          true,
          json_string(hunk, "review_state", default="pending"),
          json_string(hunk, "execution_state", default="pending"),
          json_string(hunk, "gate_status", default="needs-review"),
          json_string(hunk, "next_action", default="review"),
          json_string(hunk, "blocked_reason", default=""),
        )
      }
    }
  }
  command_preflight_patch_summary(context_path, false, "", "", "", "", "")
}

///|
fn command_preflight_patch_summary(
  context_path : String,
  matched : Bool,
  review_state : String,
  execution_state : String,
  gate_status : String,
  next_action : String,
  blocked_reason : String,
) -> Json {
  {
    "context_path": context_path,
    "matched": matched,
    "review_state": review_state,
    "execution_state": execution_state,
    "gate_status": gate_status,
    "next_action": next_action,
    "blocked_reason": blocked_reason,
    "runtime_proven": execution_state == "applied" ||
    execution_state == "reverted" ||
    gate_status == "runtime-proven",
  }
}

///|
pub fn command_preflight_selected_patch_blocking_reason(
  action : String,
  context_path : String,
  patch_entries : Array[Json],
) -> String {
  let selected_patch = command_preflight_selected_patch(
    context_path, patch_entries,
  )
  if !json_bool(selected_patch, "matched", default=false) {
    return ""
  }
  let review_state = json_string(selected_patch, "review_state", default="")
  let execution_state = json_string(
    selected_patch,
    "execution_state",
    default="",
  )
  let gate_status = json_string(selected_patch, "gate_status", default="")
  if review_state == "rejected" {
    return "selected patch was rejected: \{context_path}"
  }
  match action {
    "package" =>
      if !json_bool(selected_patch, "runtime_proven", default=false) {
        "apply selected patch and record MoonClaw runtime proof before package: \{context_path} is \{gate_status}"
      } else {
        ""
      }
    "commit" =>
      if review_state != "accepted" &&
        review_state != "applied" &&
        review_state != "reverted" {
        "accept selected patch before commit: \{context_path} is \{review_state}"
      } else if execution_state != "applied" && execution_state != "reverted" {
        "record MoonClaw patch execution proof before commit: \{context_path} is \{execution_state}"
      } else {
        ""
      }
    _ => ""
  }
}

///|
pub fn command_preflight_has_patch_target(
  patch_entries : Array[Json],
  target : String,
) -> Bool {
  command_preflight_patch_target_state(patch_entries, target) != ""
}

///|
pub fn command_preflight_patch_target_state(
  patch_entries : Array[Json],
  target : String,
) -> String {
  for patch in patch_entries {
    if json_string(patch, "path", default="") == target {
      return json_string(patch, "review_state", default="pending")
    }
    for hunk in json_array_items(patch, "hunks") {
      if json_string(hunk, "target", default="") == target {
        return json_string(hunk, "review_state", default="pending")
      }
    }
  }
  ""
}
