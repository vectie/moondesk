///|
fn mooncode_session_record_path(
  workspace_root : String,
  session_id : String,
) -> String {
  @pathx.join(
    mooncode_session_log_dir(workspace_root, session_id),
    "record.json",
  )
}

///|
async fn read_mooncode_session_records(workspace_root : String) -> Array[Json] {
  let records : Array[Json] = []
  let root = mooncode_sessions_dir(workspace_root)
  for session_id in @moonfiles.read_directory_names(root, include_hidden=false) {
    if !mooncode_valid_session_id(session_id) {
      continue
    }
    match read_mooncode_session_record(workspace_root, session_id) {
      Some(record) => records.push(record)
      None => ()
    }
  }
  records
}

///|
async fn read_mooncode_session_record(
  workspace_root : String,
  session_id : String,
) -> Json? {
  if !mooncode_valid_session_id(session_id) {
    return None
  }
  let path = mooncode_session_record_path(workspace_root, session_id)
  match @moonfiles.read_json_record_file(path) {
    Some(record) =>
      if json_string(record, "id", default="") == session_id &&
        json_string(record, "component", default="") == "mooncode" {
        Some(record)
      } else {
        None
      }
    None => None
  }
}

///|
async fn write_mooncode_session_record(
  workspace_root : String,
  session : Json,
) -> Unit {
  let session_id = json_string(session, "id", default="")
  if !mooncode_valid_session_id(session_id) {
    fail("invalid MoonCode session id: \{session_id}")
  }
  if json_string(session, "component", default="") != "mooncode" {
    fail("invalid MoonCode session record")
  }
  let compact = mooncode_compact_session_record(
    mooncode_session_storage_record(session),
  )
  @moonfiles.write_json_record_file(
    mooncode_session_record_path(workspace_root, session_id),
    compact,
  )
}

///|
fn mooncode_session_storage_record(session : Json) -> Json {
  match session {
    Object(fields) => {
      let next : Map[String, Json] = {}
      for key, value in fields {
        if !mooncode_session_response_only_field(key) {
          next[key] = value
        }
      }
      Json::object(next)
    }
    _ => session
  }
}

///|
fn mooncode_session_response_only_field(key : String) -> Bool {
  key == "mooncode_events" ||
  key == "mooncode_summary" ||
  key == "mooncode_conversation" ||
  key == "mooncode_command_events" ||
  key == "mooncode_event_log_path" ||
  key == "mooncode_append_log_count" ||
  key == "mooncode_command_log_path" ||
  key == "mooncode_command_log_count" ||
  key == "mooncode_runtime_command_log_path" ||
  key == "mooncode_runtime_command_log_count" ||
  key == "mooncode_runtime_receipt_log_path" ||
  key == "mooncode_runtime_receipt_log_count" ||
  key == "transcript"
}

///|
fn mooncode_compact_session_record(session : Json) -> Json {
  match session {
    Object(fields) => {
      let next : Map[String, Json] = {}
      for key, value in fields {
        next[key] = if mooncode_session_field_needs_manifest_ref(key) {
          mooncode_manifest_ref(value)
        } else if key == "mooncode_session_snapshot" {
          mooncode_manifest_ref(value)
        } else {
          value
        }
      }
      Json::object(next)
    }
    _ => session
  }
}

///|
fn mooncode_session_field_needs_manifest_ref(key : String) -> Bool {
  key == "mooncode_last_change_set_manifest" ||
  key == "mooncode_last_patch_set_manifest" ||
  key == "mooncode_last_tool_approvals_manifest" ||
  key == "mooncode_last_test_runs_manifest" ||
  key == "mooncode_last_action_plan_manifest" ||
  key == "mooncode_last_runtime_evidence_manifest" ||
  key == "mooncode_last_eval_report_manifest" ||
  key == "mooncode_last_runtime_handoff_manifest" ||
  key == "mooncode_last_package_manifest" ||
  key == "mooncode_last_package_index_manifest"
}

///|
fn mooncode_manifest_ref(manifest : Json) -> Json {
  match manifest {
    Object(_) => {
      let reference : Map[String, Json] = {}
      for
        key in [
          "kind", "protocol", "status", "session_id", "workspace_id", "workspace_name",
          "recorded_at", "manifest_path", "absolute_manifest_path", "snapshot_path",
          "receipt_path", "package_path", "index_path",
        ] {
        let value = json_string(manifest, key, default="")
        if value != "" {
          reference[key] = value.to_json()
        }
      }
      match json_object_field(manifest, "resume_contract") {
        Some(value) => reference["resume_contract"] = value
        None => ()
      }
      match json_object_field(manifest, "runtime_consumer") {
        Some(value) => reference["runtime_consumer"] = value
        None => ()
      }
      Json::object(reference)
    }
    _ => manifest
  }
}

///|
fn mooncode_session_with_field(
  session : Json,
  key : String,
  value : Json,
) -> Json {
  @mooncode.session_with_field(session, key, value)
}

///|
fn mooncode_session_response_defaults(session : Json) -> Json {
  @mooncode.session_response_defaults(session)
}

///|
async fn enrich_mooncode_session_for_response(
  workspace_root : String,
  session : Json,
) -> Json {
  let session = mooncode_session_response_defaults(session)
  attach_mooncode_session_projection(workspace_root, session)
}
