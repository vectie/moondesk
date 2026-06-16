///|
// MoonCode patch review and execution state projection.

///|
pub fn patch_review_state_for_path(
  path : String,
  events : Array[Json],
) -> String {
  if patch_review_event_count(path, "revert_patch", events) > 0 {
    "reverted"
  } else if patch_review_event_count(path, "apply_patch", events) > 0 {
    "applied"
  } else if patch_review_event_count(path, "reject", events) > 0 {
    "rejected"
  } else if patch_review_event_count(path, "accept", events) > 0 {
    "accepted"
  } else {
    "pending"
  }
}

///|
pub fn patch_execution_state_for_path(
  path : String,
  events : Array[Json],
) -> String {
  if patch_execution_event_count(path, "runtime.patch_reverted", events) > 0 {
    "reverted"
  } else if patch_execution_event_count(path, "runtime.patch_applied", events) >
    0 {
    "applied"
  } else {
    "pending"
  }
}

///|
pub fn patch_review_target_matches(
  target : String,
  event_path : String,
) -> Bool {
  target == "" ||
  event_path == "" ||
  event_path == target ||
  event_path == patch_review_parent_target(target) ||
  event_path.has_prefix(target + "#hunk-")
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
