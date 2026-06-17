///|
pub fn session_record(
  session_id~ : String,
  workspace_id~ : String,
  workspace_name~ : String,
  workspace_root~ : String,
  task~ : Json,
  title~ : String,
  created_at~ : String,
  updated_at~ : String,
  last_message~ : String,
  initial_context_path~ : String,
  transcript~ : Array[Json],
) -> Json {
  {
    "id": session_id,
    "workspace_id": workspace_id,
    "workspace_name": workspace_name,
    "workspace_root": workspace_root,
    "cwd": workspace_root,
    "moonclaw_task_id": json_string(task, "id", default=""),
    "title": title,
    "model": json_string(task, "model", default=""),
    "status": json_string(task, "status", default="created"),
    "port": summary_json_int(task, "port", default=0),
    "web_search": json_bool(task, "web_search", default=false),
    "queued_count": json_array_items(task, "queued_messages").length(),
    "created_at": created_at,
    "updated_at": updated_at,
    "last_message": last_message,
    "transcript": Json::array(transcript),
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
  task~ : Json,
  title~ : String,
  created_at~ : String,
  updated_at~ : String,
  last_message~ : String,
  initial_context_path~ : String,
  transcript~ : Array[Json],
) -> Json {
  session_record(
    session_id=projected_session_id(workspace_id, title, created_at),
    workspace_id~,
    workspace_name~,
    workspace_root~,
    task~,
    title~,
    created_at~,
    updated_at~,
    last_message~,
    initial_context_path~,
    transcript~,
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
pub fn native_runtime_session_stub(
  workspace_root : String,
  session_id : String,
) -> Json {
  {
    "id": session_id,
    "workspace_id": session_id,
    "workspace_name": session_id,
    "workspace_root": workspace_root,
    "moonclaw_task_id": "",
    "mooncode_dispatch_mode": "moonclaw-native",
    "source": "moonclaw-native-session",
  }
}
