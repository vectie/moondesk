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
  @moonfiles.write_json_record_file(
    mooncode_session_record_path(workspace_root, session_id),
    session,
  )
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
fn append_mooncode_transcript_message(
  session : Json,
  role~ : String,
  content~ : String,
  status~ : String,
  created_at? : String = @async.now().to_string(),
) -> Json {
  @mooncode.append_transcript_message(
    session,
    role~,
    content~,
    status~,
    created_at~,
  )
}

///|
async fn enrich_mooncode_session_for_response(
  workspace_root : String,
  session : Json,
) -> Json {
  let session = mooncode_session_response_defaults(session)
  attach_mooncode_session_projection(workspace_root, session)
}
