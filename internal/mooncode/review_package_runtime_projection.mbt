///|
fn count_package_runtime_state_for_manifest(
  manifest : Json,
  events : Array[Json],
  state : String,
) -> Int {
  let mut count = 0
  for event in events {
    if package_runtime_event_state(event) == state &&
      json_string(event, "status", default="") != "failed" &&
      package_runtime_event_matches_manifest(manifest, event) {
      count += 1
    }
  }
  count
}

///|
fn package_runtime_event_matches_manifest(
  manifest : Json,
  event : Json,
) -> Bool {
  let path = json_string(event, "path", default="")
  if path == "" {
    return false
  }
  if package_runtime_path_matches(
      path,
      json_string(manifest, "context_path", default=""),
    ) ||
    package_runtime_path_matches(
      path,
      json_string(manifest, "manifest_path", default=""),
    ) ||
    package_runtime_path_matches(
      path,
      json_string(manifest, "review_receipt_path", default=""),
    ) {
    return true
  }
  for candidate in json_array_items(manifest, "candidate_paths") {
    match candidate {
      String(candidate_path) =>
        if package_runtime_path_matches(path, candidate_path) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn package_runtime_path_matches(path : String, target : String) -> Bool {
  target != "" &&
  (
    path == target ||
    path.has_prefix(target + "/") ||
    target.has_prefix(path + "/")
  )
}

///|
fn package_runtime_event_state(event : Json) -> String {
  match json_string(event, "kind", default="") {
    "runtime.package_verified" => "verified"
    "runtime.package_built" => "built"
    _ => ""
  }
}
