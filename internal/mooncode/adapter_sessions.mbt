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
    "archived": false,
  }
}

///|
pub fn session_response_defaults(session : Json) -> Json {
  json_without_field(
    @mooncore.session_response_defaults(
      json_with_field(
        session,
        "archived",
        json_bool(session, "archived", default=false).to_json(),
      ),
      default_title="MoonCode Session",
    ),
    "transcript",
  )
}

///|
pub fn selected_session_response(session : Json) -> Result[Json, String] {
  let projected = session_response_defaults(session)
  match @mooncode_core.decode_mooncode_selected_session(projected) {
    Supported(summary) =>
      Ok(@mooncode_core.encode_mooncode_session_summary(summary))
    UnsupportedVersion(version) =>
      Err("Unsupported MoonCode selected session contract version \{version}")
    Malformed(error) => Err(error)
  }
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
      "updated_at",
      listing_scalar_text(row, "updated_at").to_json(),
    )
    |> json_with_field(
      "queued_count",
      json_int(row, "queued_count", default=0).to_json(),
    )
    |> json_with_field(
      "mooncode_runtime_session_id",
      json_string(row, "mooncode_runtime_session_id", default=session_id).to_json(),
    )
    |> json_with_field(
      "archived",
      json_bool(row, "archived", default=false).to_json(),
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
fn listing_scalar_text(row : Json, key : String) -> String {
  match @mooncore.json_object_field(row, key) {
    Some(String(value)) => value
    Some(value) => value.stringify()
    None => ""
  }
}

///|
pub fn runtime_session_listing_rows(
  payload : Json,
) -> Result[Array[Json], String] {
  let (protocol, source) = match payload {
    Array(items) => (None, [ for item in items => item ])
    Object(fields) => {
      let protocol = match fields.get("protocol") {
        None => None
        Some(String(protocol)) => Some(protocol)
        Some(_) => return Err("listing protocol must be a string")
      }
      guard fields.get("sessions") is Some(Array(items)) else {
        return Err("listing sessions must be an array")
      }
      (protocol, [ for item in items => item ])
    }
    _ => return Err("listing payload must be an array or object")
  }
  let rows : Array[Json] = []
  for row in source {
    match normalized_listing_row(row) {
      Some(normalized) => rows.push(normalized)
      None => return Err("session id is invalid")
    }
  }
  let normalized_payload : Json = match protocol {
    Some(protocol) =>
      Json::object({ "protocol": protocol, "sessions": Json::array(rows) })
    None => Json::array(rows)
  }
  match @mooncode_core.decode_mooncode_session_listing(normalized_payload) {
    Supported(summaries) =>
      Ok(
        summaries.map(summary => {
          @mooncode_core.encode_mooncode_session_summary(summary)
        }),
      )
    UnsupportedVersion(version) =>
      Err("Unsupported MoonCode session listing contract version \{version}")
    Malformed(error) => Err(error)
  }
}
