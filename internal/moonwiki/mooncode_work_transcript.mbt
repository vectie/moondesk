///|
fn mooncode_work_transcript_result(
  descriptor : Json,
  state : String,
  message : String,
  session? : Json = Json::null(),
) -> (Int, Json) {
  (
    200,
    descriptor
    |> mooncode_session_with_field("transcript", {
      "state": state,
      "message": message,
    })
    |> mooncode_session_with_field("session", session),
  )
}

///|
fn mooncode_work_transcript_projection(
  workspace_root : String,
  workspace : @desk.DeskWorkspace,
  target : MoonCodeWorkTarget,
  descriptor : Json,
  record : Json,
) -> (Int, Json) {
  if json_string(record, "kind", default="") != "mooncode-session-record" ||
    json_string(record, "protocol", default="") != @mooncode.protocol_version() {
    return mooncode_work_transcript_result(
      descriptor, "invalid_native_response", "Native source did not return a session record; the original work remains resolved",
    )
  }
  if json_string(record, "session_id", default="") != target.session_id ||
    mooncode_work_normalized_root(json_string(record, "book_root", default="")) !=
    mooncode_work_normalized_root(workspace.root_path) {
    return mooncode_work_transcript_result(
      descriptor, "identity_mismatch", "Native transcript belongs to another session or MoonBook; no unrelated history was opened",
    )
  }
  let conversation = moonclaw_runtime_record_conversation(record)
  if json_string(conversation, "session_id", default="") != target.session_id {
    return mooncode_work_transcript_result(
      descriptor, "identity_mismatch", "Native conversation does not match this session; no unrelated history was opened",
    )
  }
  if @mooncode_core.decode_mooncode_conversation(conversation) is Err(_) {
    return mooncode_work_transcript_result(
      descriptor, "invalid_native_response", "Native transcript has no valid canonical conversation; the original work remains resolved",
    )
  }
  // Proj commands capture book_root, not a Desk workspace ID. Empty or stale
  // conversation workspace hints must not override the verified active catalog.
  let session = moonclaw_runtime_full_session_from_record(
      workspace_root, record,
    )
    |> mooncode_session_with_field("workspace_id", workspace.id.to_json())
    |> mooncode_session_with_field("workspace_name", workspace.name.to_json())
    |> mooncode_session_with_field(
      "workspace_root",
      workspace.root_path.to_json(),
    )
    |> mooncode_session_with_field("cwd", workspace.root_path.to_json())
  match @mooncode.selected_session_response(session) {
    Ok(session) =>
      mooncode_work_transcript_result(
        descriptor,
        "ready",
        "Canonical native conversation is available for inspection",
        session~,
      )
    Err(error) =>
      mooncode_work_transcript_result(
        descriptor, "invalid_native_response", error,
      )
  }
}

///|
async fn mooncode_work_read_transcript(
  workspace_root : String,
  workspace : @desk.DeskWorkspace,
  target : MoonCodeWorkTarget,
  descriptor : Json,
  read : async (String) -> Result[Json, String],
) -> (Int, Json) {
  match
    read(
      @mooncode.moonclaw_native_session_show_endpoint(
        target.session_id,
        workspace.root_path,
      ),
    ) {
    Ok(record) =>
      mooncode_work_transcript_projection(
        workspace_root, workspace, target, descriptor, record,
      )
    Err(error) =>
      mooncode_work_transcript_result(descriptor, "runtime_unavailable", error)
  }
}
