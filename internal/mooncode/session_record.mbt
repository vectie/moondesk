///|
pub fn session_record(
  session_id~ : String,
  workspace_id~ : String,
  workspace_name~ : String,
  workspace_root~ : String,
  runtime~ : Json,
  title~ : String,
  created_at~ : String,
  updated_at~ : String,
  last_message~ : String,
  initial_context_path~ : String,
) -> Json {
  {
    "id": session_id,
    "workspace_id": workspace_id,
    "workspace_name": workspace_name,
    "workspace_root": workspace_root,
    "cwd": workspace_root,
    "mooncode_runtime_session_id": session_id,
    "title": title,
    "model": json_string(runtime, "model", default=""),
    "status": json_string(runtime, "status", default="created"),
    "port": summary_json_int(runtime, "port", default=0),
    "web_search": json_bool(runtime, "web_search", default=false),
    "queued_count": json_array_items(runtime, "queued_messages").length(),
    "created_at": created_at,
    "updated_at": updated_at,
    "last_message": last_message,
    "component": "mooncode",
    "protocol": protocol_version(),
    "mooncode_session_kind": "coding",
    "mooncode_initial_context_path": initial_context_path,
  }
}

///|
pub fn projected_session_record(
  workspace_id~ : String,
  workspace_name~ : String,
  workspace_root~ : String,
  runtime~ : Json,
  title~ : String,
  created_at~ : String,
  updated_at~ : String,
  last_message~ : String,
  initial_context_path~ : String,
) -> Json {
  session_record(
    session_id=projected_session_id(workspace_id, title, created_at),
    workspace_id~,
    workspace_name~,
    workspace_root~,
    runtime~,
    title~,
    created_at~,
    updated_at~,
    last_message~,
    initial_context_path~,
  )
}

///|
pub fn projected_session_id(
  workspace_id : String,
  title : String,
  created_at : String,
) -> String {
  let seed = workspace_id + ":" + title + ":" + created_at
  let digest = @crypto.bytes_to_hex_string(
    @crypto.sha256(@encoding/utf8.encode(seed).to_fixedarray()),
  )
  "mooncode-" + digest[:16].to_owned()
}

///|
pub fn native_runtime_session_projection(
  workspace_root : String,
  session_id : String,
) -> Json {
  {
    "id": session_id,
    "workspace_id": session_id,
    "workspace_name": session_id,
    "workspace_root": workspace_root,
    "mooncode_runtime_session_id": session_id,
    "mooncode_runtime_mode": "moonclaw-native",
    "source": "moonclaw-native-session-projection",
  }
}

///|
pub fn session_response_defaults(session : Json) -> Json {
  session_without_field(
    @mooncore.session_response_defaults(
      session,
      default_title="MoonCode Session",
    ),
    "transcript",
  )
}

///|
fn session_without_field(session : Json, key : String) -> Json {
  match session {
    Object(fields) => {
      let next : Map[String, Json] = {}
      for existing_key, value in fields {
        if existing_key != key {
          next[existing_key] = value
        }
      }
      Json::object(next)
    }
    _ => session
  }
}
