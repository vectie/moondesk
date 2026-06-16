///|
// MoonCode test-run manifest projection.

///|
pub fn test_runs_manifest(
  session : Json,
  events : Array[Json],
  recorded_at~ : String,
  manifest_path~ : String,
  absolute_manifest_path~ : String,
) -> Json {
  let runs = test_run_entries(events)
  let passed_count = count_test_run_state(runs, "passed")
  let failed_count = count_test_run_state(runs, "failed")
  let running_count = count_test_run_state(runs, "running")
  let queued_count = count_test_run_state(runs, "queued")
  {
    "kind": "mooncode-test-runs",
    "protocol": "mooncode.v1",
    "status": if failed_count > 0 {
      "failed"
    } else if running_count > 0 {
      "running"
    } else if queued_count > 0 {
      "queued"
    } else if passed_count > 0 {
      "passed"
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
    "runs": Json::array(runs),
    "run_count": runs.length(),
    "passed_run_count": passed_count,
    "failed_run_count": failed_count,
    "running_run_count": running_count,
    "queued_run_count": queued_count,
    "verified_run_count": count_verified_tests(events),
    "last_command_packet": summary_json_object_field_or_empty(
      session, "mooncode_last_command_packet",
    ),
    "change_set_manifest": summary_json_object_field_or_empty(
      session, "mooncode_last_change_set_manifest",
    ),
    "patch_set_manifest": summary_json_object_field_or_empty(
      session, "mooncode_last_patch_set_manifest",
    ),
    "owner": {
      "ui": "moondesk",
      "runtime": "moonclaw",
      "artifact": "moonbook",
      "test": "moonbook",
      "extractable_component": "mooncode",
    },
    "next_runtime_step": "MoonClaw or standalone MoonCode should execute these commands directly, stream stdout/stderr, and attach exact test/build logs.",
  }
}

///|
pub fn test_run_entries(events : Array[Json]) -> Array[Json] {
  let entries : Array[Json] = []
  let seen : Map[String, Bool] = {}
  for event in events {
    if json_string(event, "lane", default="") != "test" {
      continue
    }
    let key = test_run_target(event)
    if seen.get(key).unwrap_or(false) {
      continue
    }
    seen[key] = true
    entries.push(test_run_entry(event))
  }
  entries
}

///|
pub fn test_run_state(event : Json) -> String {
  let status = json_string(event, "status", default="")
  if test_event_failed(event) {
    "failed"
  } else if test_event_is_completed(event) {
    "passed"
  } else if status == "running" || status == "started" {
    "running"
  } else {
    "queued"
  }
}

///|
pub fn count_test_run_state(runs : Array[Json], state : String) -> Int {
  let mut count = 0
  for run in runs {
    if json_string(run, "run_state", default="") == state {
      count += 1
    }
  }
  count
}
