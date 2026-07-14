///|
fn projected_session_id(
  workspace_id : String,
  title : String,
  created_at : String,
) -> String {
  let digest = @crypto.bytes_to_hex_string(
    @crypto.sha256(
      @encoding/utf8.encode(workspace_id + ":" + title + ":" + created_at).to_fixedarray(),
    ),
  )
  "mooncode-" + digest[:16].to_owned()
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
  let session_id = projected_session_id(workspace_id, title, created_at)
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
    "port": json_int(runtime, "port", default=0),
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
pub fn native_runtime_session_projection(
  workspace_root : String,
  session_id : String,
) -> Json {
  {
    "id": session_id,
    "workspace_id": "",
    "workspace_name": "",
    "workspace_root": workspace_root,
    "cwd": workspace_root,
    "mooncode_runtime_session_id": session_id,
    "mooncode_runtime_mode": "moonclaw-native",
    "source": "moonclaw-canonical-session",
    "component": "mooncode",
    "protocol": protocol_version(),
  }
}

///|
pub fn session_response_defaults(session : Json) -> Json {
  json_without_field(
    @mooncore.session_response_defaults(
      session,
      default_title="MoonCode Session",
    ),
    "transcript",
  )
}

///|
fn normalized_listing_row(row : Json) -> Json? {
  guard json_string(row, "id", default="") != "" else { return None }
  let session_id = json_string(row, "id", default="")
  let summary = json_object_field_or_empty(row, "mooncode_summary")
  let workspace_root = json_string(
    row,
    "workspace_root",
    default=json_string(
      row,
      "book_root",
      default=json_string(row, "cwd", default=""),
    ),
  )
  Some(
    row
    |> json_with_field(
      "runtime_source",
      json_string(row, "source", default="moonclaw").to_json(),
    )
    |> json_with_field("source", "mooncode-runtime-session-listing".to_json())
    |> json_with_field("protocol", protocol_version().to_json())
    |> json_with_field("component", "mooncode".to_json())
    |> json_with_field(
      "workspace_id",
      json_string(row, "workspace_id", default="").to_json(),
    )
    |> json_with_field(
      "workspace_name",
      json_string(row, "workspace_name", default="").to_json(),
    )
    |> json_with_field("workspace_root", workspace_root.to_json())
    |> json_with_field("cwd", workspace_root.to_json())
    |> json_with_field(
      "title",
      json_string(row, "title", default=session_id).to_json(),
    )
    |> json_with_field("model", json_string(row, "model", default="").to_json())
    |> json_with_field(
      "status",
      json_string(row, "status", default="durable").to_json(),
    )
    |> json_with_field(
      "queued_count",
      json_int(row, "queued_count", default=0).to_json(),
    )
    |> json_with_field(
      "mooncode_runtime_session_id",
      json_string(row, "mooncode_runtime_session_id", default=session_id).to_json(),
    )
    |> json_with_field("mooncode_summary", {
      "event_count": json_int(
        summary,
        "event_count",
        default=json_int(row, "event_count", default=0),
      ),
      "verified_test_count": json_int(summary, "verified_test_count", default=0),
      "pending_diff_count": json_int(summary, "pending_diff_count", default=0),
    }),
  )
}

///|
pub fn runtime_session_listing_rows(payload : Json) -> Array[Json] {
  let source = match payload {
    Array(items) => [ for item in items => item ]
    Object(_) => json_array_items(payload, "sessions")
    _ => []
  }
  let rows : Array[Json] = []
  for row in source {
    match normalized_listing_row(row) {
      Some(normalized) => rows.push(normalized)
      None => ()
    }
  }
  rows
}
