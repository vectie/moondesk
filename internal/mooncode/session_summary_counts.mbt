///|
// Session summary metric counters for MoonCode event and artifact projections.

///|
pub fn count_lane(events : Array[Json], lane : String) -> Int {
  let mut count = 0
  for event in events {
    if json_string(event, "lane", default="") == lane {
      count += 1
    }
  }
  count
}

///|
pub fn count_review_command(events : Array[Json], command : String) -> Int {
  let mut count = 0
  for event in events {
    if json_string(event, "lane", default="") == "review" &&
      json_string(event, "command", default="") == command &&
      json_string(event, "status", default="") != "failed" {
      count += 1
    }
  }
  count
}

///|
pub fn count_command_events(events : Array[Json], command : String) -> Int {
  let seen : Map[String, Bool] = {}
  let mut count = 0
  for event in events {
    if json_string(event, "command", default="") == command &&
      json_string(event, "status", default="") != "failed" {
      let id = json_string(
        summary_json_object_field_or_empty(event, "command_packet"),
        "command_id",
        default=json_string(event, "id", default="event:\{count}"),
      )
      if !seen.get(id).unwrap_or(false) {
        seen[id] = true
        count += 1
      }
    }
  }
  count
}

///|
pub fn count_steer_settlements(events : Array[Json]) -> Int {
  let mut count = 0
  for event in events {
    let kind = json_string(event, "kind", default="")
    if kind == event_steer_applied() || kind == event_steer_dropped() {
      count += 1
    }
  }
  count
}

///|
pub fn count_deferred_steers(events : Array[Json]) -> Int {
  let mut count = 0
  for event in events {
    if json_string(event, "kind", default="") == event_steer_deferred() {
      count += 1
    }
  }
  count
}

///|
pub fn pending_steer_count(
  steer_command_count : Int,
  steer_settlement_count : Int,
) -> Int {
  if steer_command_count > steer_settlement_count {
    steer_command_count - steer_settlement_count
  } else {
    0
  }
}

///|
pub fn count_command_packets(events : Array[Json]) -> Int {
  let seen : Map[String, Bool] = {}
  let mut count = 0
  for event in events {
    match summary_json_object_field(event, "command_packet") {
      Some(packet) =>
        if json_string(packet, "protocol", default="") == protocol_version() {
          let command_id = json_string(
            packet,
            "command_id",
            default="packet:\{packet.stringify()}",
          )
          if !seen.get(command_id).unwrap_or(false) {
            seen[command_id] = true
            count += 1
          }
        }
      None => ()
    }
  }
  count
}

///|
pub fn count_review_receipts(events : Array[Json]) -> Int {
  let mut count = 0
  for event in events {
    if json_string(event, "lane", default="") == "review" &&
      json_string(event, "kind", default="").has_prefix("receipt.") {
      count += 1
    }
  }
  count
}

///|
pub fn count_package_manifests(events : Array[Json]) -> Int {
  count_kind(events, "package.manifest")
}

///|
pub fn count_package_index_manifests(events : Array[Json]) -> Int {
  count_kind(events, "package.index")
}

///|
pub fn count_change_set_manifests(events : Array[Json]) -> Int {
  count_kind(events, "change_set.manifest")
}

///|
pub fn count_patch_set_manifests(events : Array[Json]) -> Int {
  count_kind(events, "patch_set.manifest")
}

///|
pub fn count_tool_approvals_manifests(events : Array[Json]) -> Int {
  count_kind(events, "tool_approvals.manifest")
}

///|
pub fn count_test_runs_manifests(events : Array[Json]) -> Int {
  count_kind(events, "test_runs.manifest")
}

///|
pub fn count_eval_report_manifests(events : Array[Json]) -> Int {
  count_kind(events, "eval_report.manifest")
}

///|
pub fn count_runtime_evidence_manifests(events : Array[Json]) -> Int {
  count_kind(events, "runtime_evidence.manifest")
}

///|
pub fn count_runtime_handoff_manifests(events : Array[Json]) -> Int {
  count_kind(events, "runtime.handoff")
}

///|
pub fn count_runtime_commit_proofs(events : Array[Json]) -> Int {
  count_kind(events, "runtime.commit_created")
}

///|
pub fn count_verified_tests(events : Array[Json]) -> Int {
  let mut count = 0
  for event in events {
    if json_string(event, "lane", default="") == "test" &&
      test_event_is_completed(event) &&
      !test_event_failed(event) {
      count += 1
    }
  }
  count
}

///|
pub fn count_failed_tests(events : Array[Json]) -> Int {
  let mut count = 0
  for event in events {
    if json_string(event, "lane", default="") == "test" &&
      test_event_failed(event) {
      count += 1
    }
  }
  count
}

///|
pub fn test_event_is_completed(event : Json) -> Bool {
  let status = json_string(event, "status", default="")
  status == "done" || status == "completed" || status == "passed"
}

///|
pub fn test_event_failed(event : Json) -> Bool {
  json_string(event, "status", default="") == "failed" ||
  summary_json_int(event, "exit_code", default=0) > 0
}

///|
pub fn count_source_bound_packages(
  session : Json,
  package_manifest_count : Int,
) -> Int {
  if package_manifest_count == 0 {
    return 0
  }
  let manifest = summary_json_object_field_or_empty(
    session, "mooncode_last_package_manifest",
  )
  let index = summary_json_object_field_or_empty(
    session, "mooncode_last_package_index_manifest",
  )
  if json_string(index, "kind", default="") == "mooncode-package-index" {
    summary_json_int(index, "source_bound_package_count", default=0)
  } else if json_string(manifest, "source_inventory_status", default="") ==
    "source-bound" &&
    summary_json_int(manifest, "source_present_count", default=0) > 0 {
    1
  } else {
    0
  }
}

///|
pub fn pending_diff_count(
  diff_count : Int,
  accepted_count : Int,
  rejected_count : Int,
) -> Int {
  let reviewed = accepted_count + rejected_count
  if diff_count > reviewed {
    diff_count - reviewed
  } else {
    0
  }
}

///|
pub fn review_state(
  diff_count : Int,
  accepted_count : Int,
  rejected_count : Int,
) -> String {
  if rejected_count > 0 {
    "rejected"
  } else if accepted_count > 0 {
    "accepted"
  } else if diff_count > 0 {
    "pending"
  } else {
    "empty"
  }
}

///|
fn count_kind(events : Array[Json], kind : String) -> Int {
  let mut count = 0
  for event in events {
    if json_string(event, "kind", default="") == kind {
      count += 1
    }
  }
  count
}
