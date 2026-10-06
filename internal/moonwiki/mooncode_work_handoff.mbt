///|
/// The hints identify a read target. They grant no task or command mutation.
priv struct MoonCodeWorkTarget {
  session_id : String
  command_id : String
  book_root : String
}

///|
fn mooncode_work_target_from_query(request_path : String) -> MoonCodeWorkTarget {
  {
    session_id: decode_query_value(
      query_value(request_path, "session_id").unwrap_or(""),
    ),
    command_id: decode_query_value(
      query_value(request_path, "command_id").unwrap_or(""),
    ),
    book_root: decode_query_value(
      query_value(request_path, "book_root").unwrap_or(""),
    ),
  }
}

///|
fn mooncode_work_normalized_root(root : String) -> String {
  // pathx preserves a directory's trailing separator; handoff identity does not.
  for value = @pathx.normalize(root); value.length() > 1 &&
     value.has_suffix("/"); {
    continue value[:value.length() - 1].to_owned()
  } nobreak {
    value
  }
}

///|
fn mooncode_work_session_root(
  workspace_root : String,
  session_id : String,
  rows : Array[Json],
  workspaces : Array[@desk.DeskWorkspace],
) -> Result[String, String] {
  moonclaw_runtime_session_book_root_from_rows(
    mooncode_work_normalized_root(workspace_root),
    session_id,
    rows.map(row => {
      mooncode_session_with_field(
        row,
        "book_root",
        mooncode_work_normalized_root(
          json_string(
            row,
            "book_root",
            default=json_string(row, "workspace_root", default=""),
          ),
        ).to_json(),
      )
    }),
    workspaces.map(workspace => {
      @desk.workspace(
        id=workspace.id,
        name=workspace.name,
        root_path=mooncode_work_normalized_root(workspace.root_path),
        kind=workspace.kind,
      )
    }),
  )
}

///|
fn mooncode_work_failure(
  target : MoonCodeWorkTarget,
  status : Int,
  state : String,
  message : String,
) -> (Int, Json) {
  (
    status,
    {
      "schema": "moondesk.work-handoff.v1",
      "state": state,
      "message": message,
      "session_id": target.session_id,
      "original_command_id": target.command_id,
      "book_root": target.book_root,
    },
  )
}

///|
fn mooncode_work_workspace(
  target : MoonCodeWorkTarget,
  workspaces : Array[@desk.DeskWorkspace],
) -> Result[@desk.DeskWorkspace, (Int, Json)] {
  if target.session_id.is_empty() ||
    target.command_id.is_empty() ||
    !@pathx.is_absolute(target.book_root) {
    return Err(
      mooncode_work_failure(
        target, 400, "invalid_request", "An exact session_id, command_id and absolute book_root are required",
      ),
    )
  }
  let matches = workspaces.filter(workspace => {
    mooncode_work_normalized_root(workspace.root_path) ==
    mooncode_work_normalized_root(target.book_root)
  })
  if matches.length() == 0 {
    Err(
      mooncode_work_failure(
        target, 409, "unknown_workspace", "The requested MoonBook is not in the active MoonDesk library; select or discover the correct library and retry",
      ),
    )
  } else if matches.length() != 1 {
    Err(
      mooncode_work_failure(
        target, 409, "ambiguous_workspace", "The active MoonDesk catalog has multiple identities for this MoonBook",
      ),
    )
  } else {
    Ok(matches[0])
  }
}

///|
fn mooncode_work_scope_failure(
  target : MoonCodeWorkTarget,
  error : String,
) -> (Int, Json) {
  let (status, _) = mooncode_session_scope_error_status(error)
  let state = if status == 404 {
    "session_not_found"
  } else if error == "MoonCode session identifier is ambiguous across MoonBooks" {
    "ambiguous_session"
  } else if status == 409 {
    "unknown_workspace"
  } else {
    "runtime_unavailable"
  }
  mooncode_work_failure(target, status, state, error)
}

///|
fn mooncode_work_command_projection(
  target : MoonCodeWorkTarget,
  workspace : @desk.DeskWorkspace,
  claims : Json,
) -> (Int, Json) {
  if json_string(claims, "kind", default="") != "mooncode-runtime-claim-state" ||
    json_string(claims, "protocol", default="") != "mooncode.v1" {
    return mooncode_work_failure(
      target, 503, "invalid_native_response", "Native runtime did not return a command-claim record",
    )
  }
  if json_string(claims, "session_id", default="") != target.session_id ||
    mooncode_work_normalized_root(json_string(claims, "book_root", default="")) !=
    mooncode_work_normalized_root(workspace.root_path) {
    return mooncode_work_failure(
      target, 409, "identity_mismatch", "Native command source did not match the requested session and MoonBook",
    )
  }
  let matches : Array[(Json, String)] = []
  for
    (key, status) in [
      ("claimable_commands", "claimable"),
      ("claimed_commands", "claimed"),
      ("order_blocked_commands", "order-blocked"),
      ("delivered_commands", "delivered"),
      ("invalid_commands", "invalid"),
    ] {
    guard json_object_field(claims, key) is Some(Array(items)) else {
      return mooncode_work_failure(
        target, 503, "invalid_native_response", "Native command listing is incomplete; retry when the runtime is available",
      )
    }
    for item in items {
      if json_string(item, "command_id", default="") == target.command_id {
        matches.push((item, status))
      }
    }
  }
  if matches.length() == 0 {
    return mooncode_work_failure(
      target, 404, "command_not_found", "The original command is not in the native journal yet; retain this target and retry",
    )
  }
  if matches.length() != 1 {
    return mooncode_work_failure(
      target, 409, "identity_mismatch", "Native journal returned multiple records for the requested command",
    )
  }
  let (item, claim_status) = matches[0]
  let command = json_object_field_or_empty(item, "command")
  let packet = json_object_field_or_empty(command, "packet")
  let action = json_string(command, "command", default="")
  if json_string(item, "session_id", default="") != target.session_id ||
    json_string(command, "session_id", default="") != target.session_id ||
    json_string(packet, "command_id", default="") != target.command_id ||
    mooncode_work_normalized_root(json_string(command, "book_root", default="")) !=
    mooncode_work_normalized_root(workspace.root_path) ||
    json_string(command, "protocol", default="") != "mooncode.v1" ||
    action.is_empty() ||
    json_string(item, "action", default="") != action ||
    json_string(item, "claim_status", default="") != claim_status {
    return mooncode_work_failure(
      target, 409, "identity_mismatch", "The captured native command identity does not match the requested work",
    )
  }
  let receipt = json_object_field_or_empty(item, "receipt")
  let receipt_status = json_string(receipt, "status", default="")
  if !receipt_status.is_empty() &&
    (
      json_string(receipt, "session_id", default="") != target.session_id ||
      json_string(receipt, "command_id", default="") != target.command_id
    ) {
    return mooncode_work_failure(
      target, 409, "identity_mismatch", "The native receipt belongs to a different command",
    )
  }
  (
    200,
    {
      "schema": "moondesk.work-handoff.v1",
      "state": "ready",
      "message": "The exact original native command is available for inspection",
      "workspace": { "id": workspace.id, "root_path": workspace.root_path },
      "session_id": target.session_id,
      "original_command": {
        "command_id": target.command_id,
        "action": action,
        "claim_status": claim_status,
        "receipt_status": receipt_status,
        "model": json_string(command, "model", default=""),
        "context_path": json_string(command, "context_path", default=""),
      },
    },
  )
}

///|
/// Native I/O is injected as a GET. This boundary cannot submit, start or resume
/// work. Optional local context inspection reads only C0's captured reference.
async fn mooncode_resolve_work_handoff(
  workspace_root : String,
  workspaces : Array[@desk.DeskWorkspace],
  target : MoonCodeWorkTarget,
  read : async (String) -> Result[Json, String],
  include_session? : Bool = false,
  include_context? : Bool = false,
  include_continuations? : Bool = false,
  continuation_id? : String = "",
) -> (Int, Json) {
  let workspace = match mooncode_work_workspace(target, workspaces) {
    Ok(value) => value
    Err(result) => return result
  }
  let listing = match
    read(
      @mooncode.moonclaw_native_session_listing_endpoint(
        workspace_root,
        include_books=true,
      ),
    ) {
    Ok(value) => value
    Err(error) =>
      return mooncode_work_failure(target, 503, "runtime_unavailable", error)
  }
  let rows = match @mooncode.runtime_session_listing_rows(listing) {
    Ok(value) => value
    Err(error) =>
      return mooncode_work_failure(
        target, 503, "invalid_native_response", error,
      )
  }
  let root = match
    mooncode_work_session_root(
      workspace_root,
      target.session_id,
      rows,
      workspaces,
    ) {
    Ok(value) => value
    Err("Unknown MoonCode session") => {
      let archived = match
        read(
          @mooncode.moonclaw_native_archived_session_listing_endpoint(
            workspace_root,
            include_books=true,
          ),
        ) {
        Ok(value) => value
        Err(error) =>
          return mooncode_work_failure(
            target, 503, "runtime_unavailable", error,
          )
      }
      let archived_rows = match
        @mooncode.runtime_session_listing_rows(archived) {
        Ok(value) => value
        Err(error) =>
          return mooncode_work_failure(
            target, 503, "invalid_native_response", error,
          )
      }
      match
        mooncode_work_session_root(
          workspace_root,
          target.session_id,
          archived_rows,
          workspaces,
        ) {
        Ok(root) => {
          if mooncode_work_normalized_root(root) !=
            mooncode_work_normalized_root(workspace.root_path) {
            return mooncode_work_failure(
              target, 409, "workspace_mismatch", "The archived session belongs to another MoonBook",
            )
          }
          return mooncode_work_failure(
            target, 409, "session_archived", "The requested native session is archived; this read does not restore it",
          )
        }
        Err(error) => return mooncode_work_scope_failure(target, error)
      }
    }
    Err(error) => return mooncode_work_scope_failure(target, error)
  }
  if mooncode_work_normalized_root(root) !=
    mooncode_work_normalized_root(workspace.root_path) {
    return mooncode_work_failure(
      target, 409, "workspace_mismatch", "The requested session belongs to another MoonBook",
    )
  }
  let claims = match
    read(
      @mooncode.moonclaw_native_runtime_claim_endpoint(
        target.session_id,
        workspace.root_path,
      ),
    ) {
    Ok(value) => value
    Err(error) =>
      return mooncode_work_failure(target, 503, "runtime_unavailable", error)
  }
  let (status, descriptor) = mooncode_work_command_projection(
    target, workspace, claims,
  )
  if status != 200 {
    return (status, descriptor)
  }
  let context = workspace_context(workspace_root)
  let descriptor = mooncode_session_with_field(
    descriptor,
    "resume_scope",
    [
      context.suite_root,
      context.books_root,
      context.books_root,
      workspace.id,
      workspace.root_path,
    ].to_json(),
  )
  let descriptor = if include_session {
    mooncode_work_read_transcript(
      workspace_root, workspace, target, descriptor, read,
    ).1
  } else {
    descriptor
  }
  let descriptor = if include_context {
    descriptor
    |> mooncode_session_with_field(
      "context",
      mooncode_work_read_context(workspace, descriptor),
    )
  } else {
    descriptor
  }
  let descriptor = if include_continuations {
    mooncode_work_with_continuations(
      target, workspace, descriptor, claims, continuation_id, read,
    )
  } else {
    descriptor
  }
  (200, descriptor)
}

///|
async fn handle_mooncode_work_handoff(
  workspace_root : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let target = mooncode_work_target_from_query(request_path)
  // This candidate only reads existing daemon metadata. Do not use the ordinary
  // session-listing helper here: it may auto-start a managed daemon.
  let daemon = moonclaw_model_route_daemon_candidate(workspace_root)
  let workspaces = discover_workspaces(workspace_root)
  let continuation_id = decode_query_value(
    query_value(request_path, "continuation_id").unwrap_or(""),
  )
  let (status, payload) = mooncode_resolve_work_handoff(
    workspace_root,
    workspaces,
    target,
    path => moonclaw_get_json(daemon, path),
    include_session=query_value(request_path, "include_session") == Some("true"),
    include_context=query_value(request_path, "include_context") == Some("true"),
    include_continuations=true,
    continuation_id~,
  )
  let payload = if status == 503 {
    mooncode_work_saved_unavailable(
      target, workspaces, continuation_id, payload,
    )
  } else {
    payload
  }
  let output_hint : Json = if [
      "output_command", "output_path", "output_evidence",
    ].any(key => query_value(request_path, key) is Some(_)) {
    {
      "command_id": decode_query_value(
        query_value(request_path, "output_command").unwrap_or(""),
      ),
      "path": decode_query_value(
        query_value(request_path, "output_path").unwrap_or(""),
      ),
      "evidence_id": decode_query_value(
        query_value(request_path, "output_evidence").unwrap_or(""),
      ),
    }
  } else {
    Json::null()
  }
  let output = mooncode_work_output_projection(payload, output_hint)
  let output = if mooncode_output_text(output, "state") == "ready" {
    let root = mooncode_output_text(
      mooncode_output_field(payload, "workspace"),
      "root_path",
    )
    match
      resolve_workspace_existing_path(
        root,
        mooncode_output_text(output, "path"),
      ) {
      Some((absolute, _)) if (@fs.kind(absolute) catch { _ => Directory }) ==
        Regular => output
      _ =>
        {
          "state": "unavailable",
          "message": "The referenced current file is missing or outside the readable workspace.",
        }
    }
  } else {
    output
  }
  let payload = mooncode_session_with_field(payload, "output", output)
  let reason = match status {
    200 => "OK"
    400 => "Bad Request"
    404 => "Not Found"
    409 => "Conflict"
    _ => "Service Unavailable"
  }
  conn.send_response(status, reason, extra_headers={
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store",
  })
  if !(method_ is Head) {
    conn.write(payload.stringify())
  }
  conn.end_response()
}
