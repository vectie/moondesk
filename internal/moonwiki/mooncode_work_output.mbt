///|
fn mooncode_output_field(value : Json, key : String) -> Json {
  match value {
    Object(fields) => fields.get(key).unwrap_or(Json::null())
    _ => Json::null()
  }
}

///|
fn mooncode_output_text(value : Json, key : String) -> String {
  match mooncode_output_field(value, key) {
    String(text) => text
    _ => ""
  }
}

///|
fn mooncode_output_items(value : Json, key : String) -> Array[Json] {
  match mooncode_output_field(value, key) {
    Array(items) => items
    _ => []
  }
}

///|
fn mooncode_output_path_valid(path : String) -> Bool {
  !path.is_empty() &&
  path.length() <= 4096 &&
  !path.has_prefix("/") &&
  !path.contains("\\") &&
  !path.contains("\u0000") &&
  !path.split("/").any(part => part == "" || part == "." || part == "..")
}

///|
/// Query hints never grant access or select a delivery result. Match all three
/// fields against the already resolved native command's observed output refs.
fn mooncode_work_output_projection(descriptor : Json, hint : Json) -> Json {
  if hint is Null {
    return Json::null()
  }
  let command = mooncode_output_text(hint, "command_id")
  let path = mooncode_output_text(hint, "path")
  let evidence = mooncode_output_text(hint, "evidence_id")
  let failure : Json = {
    "state": "unavailable",
    "message": "The exact output reference could not be verified. Refresh the original result and retry.",
  }
  if command.is_empty() ||
    evidence.is_empty() ||
    !mooncode_output_path_valid(path) ||
    mooncode_output_text(descriptor, "state") != "ready" {
    return failure
  }
  let original = mooncode_output_text(
    mooncode_output_field(descriptor, "original_command"),
    "command_id",
  )
  let records = if command == original {
    [mooncode_output_field(descriptor, "original_result")]
  } else {
    mooncode_output_items(descriptor, "continuations").filter(record => {
      let source = mooncode_output_field(record, "source")
      mooncode_output_text(record, "command_id") == command &&
      mooncode_output_text(record, "admission") == "accepted" &&
      mooncode_output_text(record, "input_status") == "verified" &&
      mooncode_output_text(source, "original_command_id") == original &&
      mooncode_output_text(source, "session_id") ==
      mooncode_output_text(descriptor, "session_id")
    })
  }
  if records.length() != 1 ||
    mooncode_output_text(records[0], "command_id") != command ||
    !mooncode_output_items(records[0], "output_refs").any(item => {
      mooncode_output_text(item, "command_id") == command &&
      mooncode_output_text(item, "path") == path &&
      mooncode_output_text(item, "evidence_id") == evidence
    }) {
    return failure
  }
  {
    "state": "ready",
    "command_id": command,
    "path": path,
    "evidence_id": evidence,
    "workspace_id": mooncode_output_text(
      mooncode_output_field(descriptor, "workspace"),
      "id",
    ),
    "content_scope": "current_workspace_bytes",
    "message": "This reference was observed in the exact command. Open reads the current workspace file; later edits may have changed its bytes.",
  }
}
