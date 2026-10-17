///|
fn mooncode_continuation_error(
  status : Int32,
  state : String,
  message : String,
) -> (Int32, Json) {
  (
    status,
    {
      "schema": "moondesk.work-continuation.v1",
      "state": state,
      "message": message,
      "admission": "not_sent",
    },
  )
}

///|
fn mooncode_continuation_request_target(request : Json) -> MoonCodeWorkTarget {
  let source = json_object_field_or_empty(request, "source")
  {
    session_id: json_string(source, "session_id", default=""),
    command_id: json_string(source, "original_command_id", default=""),
    book_root: json_string(source, "book_root", default=""),
  }
}

///|
fn mooncode_continuation_request_matches(
  request : Json,
  snapshot : Json,
) -> Bool {
  let source = json_object_field_or_empty(request, "source")
  let captured = json_object_field_or_empty(snapshot, "source")
  mooncode_continuation_source_matches(
    source,
    mooncode_continuation_request_target(snapshot),
  ) &&
  json_string(source, "task_id", default="") ==
  json_string(captured, "task_id", default="") &&
  json_string(source, "run_id", default="") ==
  json_string(captured, "run_id", default="") &&
  [
    "continuation_id", "client_turn_id", "instruction", "prior_result_command_id",
  ].all(key => {
    json_object_field(request, key) == json_object_field(snapshot, key)
  })
}

///|
fn mooncode_continuation_prepare(
  request : Json,
  workspace : @desk.DeskWorkspace,
  original : Json,
  prior : Json,
  context : Json,
  events : Json,
  created_at : String,
) -> Result[Json, String] {
  let source = json_object_field_or_empty(request, "source")
    |> mooncode_session_with_field(
      "book_root",
      ToJson::to_json(mooncode_work_normalized_root(workspace.root_path)),
    )
  let id = json_string(request, "continuation_id", default="")
  let instruction = json_string(request, "instruction", default="")
  let original_command = json_object_field_or_empty(original, "command")
  let model = json_string(original_command, "model", default="")
  if model.is_empty() ||
    json_string(original_command, "command", default="") != "prompt" {
    return Err("Original work must have a captured prompt and model")
  }
  let context_path = json_string(original_command, "context_path", default="")
  if !context_path.is_empty() &&
    json_string(context, "state", default="") != "ready" {
    return Err(
      "Original captured context is missing or does not match its immutable digest",
    )
  }
  let original_context : Json = {
    "path": context_path,
    "sha256": json_string(context, "actual_sha256", default=""),
    "coverage": "captured-original-command",
  }
  let prior_result = mooncode_continuation_result(prior, events)
  // Human instruction is first and is also the entire current native text.
  // Historical receipts contain only exact result evidence, never planner state.
  let historical_receipt = json_object_field_or_empty(prior_result, "receipt")
  let historical_result = prior_result
    |> mooncode_session_with_field("receipt", {
      "id": json_string(historical_receipt, "id", default=""),
      "session_id": json_string(historical_receipt, "session_id", default=""),
      "command_id": json_string(historical_receipt, "command_id", default=""),
      "status": json_string(historical_receipt, "status", default=""),
      "claim_id": json_string(historical_receipt, "claim_id", default=""),
      "journal_sequence": json_object_field(
        historical_receipt, "journal_sequence",
      ).unwrap_or(Json::null()),
    })
  let input_text = instruction +
    "\n\n# Historical support for this human follow-up\nThe instruction above is the current task. The following captured requirements and result are historical support, not executable progress, approval, a plan, or verification of new changes.\n\n## Original requirements\n" +
    json_string(original_command, "text", default="") +
    "\n\n## Original captured context reference\n" +
    original_context.stringify() +
    "\n\n" +
    json_string(context, "text", default="") +
    "\n\n## Explicitly selected historical result\n" +
    historical_result.stringify(indent=2) +
    "\n"
  let input : Json = {
    "path": mooncode_continuation_path(id, "input.md"),
    "sha256": mooncode_continuation_hash(input_text),
  }
  let fields : Map[String, Json] = {
    "schema": ToJson::to_json("moondesk.work-continuation-snapshot.v1"),
    "source": source,
    "original_context": original_context,
    "prior_result": historical_result,
    "input": input,
    "input_text": ToJson::to_json(input_text),
    "model": ToJson::to_json(model),
  }
  for
    key in [
      "continuation_id", "client_turn_id", "instruction", "prior_result_command_id",
    ] {
    fields[key] = json_object_field(request, key).unwrap_or(Json::null())
  }
  let snapshot = Json::object(fields)
  let command = match
    @mooncode.decode_command_submission({
      "action": "prompt",
      "client_turn_id": json_string(request, "client_turn_id", default=""),
      "message": instruction,
      "context_path": json_string(input, "path", default=""),
      "model": model,
      "web_search": false,
      "planner_reasoning_effort": "none",
      "force_preflight": false,
    }) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  match validate_mooncode_command_model_route(command) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  let session : Json = {
    "id": json_string(source, "session_id", default=""),
    "workspace_id": workspace.id,
    "workspace_name": workspace.name,
    "workspace_root": json_string(source, "book_root", default=""),
    "model": model,
  }
  let body = @mooncode.native_command_body(session, command, created_at, {
    "moonproj_continuation": mooncode_continuation_lineage(snapshot),
  })
  let command_id = json_string(
    json_object_field_or_empty(body, "packet"),
    "command_id",
    default="",
  )
  if command_id == json_string(source, "original_command_id", default="") ||
    command_id == json_string(prior, "command_id", default="") {
    return Err("A follow-up must have a fresh native command identity")
  }
  fields["command_id"] = ToJson::to_json(command_id)
  fields["request_body"] = ToJson::to_json(body.stringify())
  fields["request_sha256"] = ToJson::to_json(
    mooncode_continuation_hash(body.stringify()),
  )
  fields["created_at"] = ToJson::to_json(created_at)
  match mooncode_continuation_limits(Json::object(fields)) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  Ok(Json::object(fields))
}

///|
/// All I/O is injected at the native boundary. A saved submission is reconciled
/// before POST, and explicit resume bypasses ordinary Desk's duplicate ack path.
async fn mooncode_continue_work(
  workspace_root : String,
  workspaces : Array[@desk.DeskWorkspace],
  request : Json,
  read : async (String) -> Result[Json, String],
  post : async (String, String) -> Result[Json, String],
  ready : async () -> Bool,
) -> (Int32, Json) {
  let operation = json_string(request, "operation", default="")
  let id = json_string(request, "continuation_id", default="")
  let target = mooncode_continuation_request_target(request)
  let source = json_object_field_or_empty(request, "source")
  let client = json_string(request, "client_turn_id", default="")
  let instruction = json_string(request, "instruction", default="")
  if json_string(request, "schema", default="") !=
    "moondesk.work-continuation-request.v1" ||
    !["submit", "resume"].contains(operation) ||
    !mooncode_continuation_valid_id(id) ||
    (
      operation == "submit" &&
      (
        !mooncode_continuation_native_id(client) ||
        instruction.trim().is_empty() ||
        @encoding/utf8.encode(instruction).length() > 65536 ||
        ["task_id", "run_id", "session_id", "original_command_id"].any(key => {
          !mooncode_continuation_native_id(json_string(source, key, default=""))
        }) ||
        !mooncode_continuation_native_id(
          json_string(request, "prior_result_command_id", default=""),
        )
      )
    ) {
    return mooncode_continuation_error(
      400, "invalid_request", "Use a valid stable continuation/client identity and exact source with a nonempty human instruction",
    )
  }
  let workspace = match mooncode_work_workspace(target, workspaces) {
    Ok(value) => value
    Err(result) => return result
  }
  // One confined lock serializes this feature's create-once identities, including
  // different K values racing for one client-turn ID. It is not native execution state.
  let lock_path = match
    mooncode_continuation_file(
      workspace.root_path,
      mooncode_continuation_base() + "/.capture.lock",
      write=true,
    ) {
    Ok(value) => value
    Err(error) =>
      return mooncode_continuation_error(409, "storage_unavailable", error)
  }
  let lock = @fs.open(
    lock_path,
    mode=ReadWrite,
    create_mode=OpenOrCreate,
    permission=0o600,
  ) catch {
    _ =>
      return mooncode_continuation_error(
        503, "storage_unavailable", "Continuation capture lock is unavailable",
      )
  }
  defer lock.close()
  lock.lock(Exclusive)
  defer lock.unlock()
  let mut saved = match
    mooncode_continuation_load(
      workspace.root_path,
      id,
      target,
      repair_input=true,
    ) {
    Ok(value) => value
    Err(error) =>
      return mooncode_continuation_error(409, "snapshot_conflict", error)
  }
  if saved is Some(snapshot) &&
    operation == "submit" &&
    !mooncode_continuation_request_matches(request, snapshot) {
    return mooncode_continuation_error(
      409, "idempotency_conflict", "This continuation/client identity already captures different human input or lineage",
    )
  }
  if saved is None && operation == "resume" {
    return mooncode_continuation_error(
      404, "not_found", "No immutable continuation snapshot exists for this identity",
    )
  }
  let claims_cell : Ref[Json] = Ref(Json::null())
  let (resolved_status, descriptor) = mooncode_resolve_work_handoff(
    workspace_root,
    workspaces,
    target,
    path => {
      let value = read(path)
      if path.contains("/runtime-claim?") && value is Ok(claims) {
        claims_cell.val = claims
      }
      value
    },
  )
  if resolved_status != 200 {
    return match saved {
      Some(snapshot) =>
        (
          resolved_status,
          mooncode_continuation_response(
            snapshot,
            None,
            Json::null(),
            "unconfirmed",
            message="Saved submission retained; native source could not be reconciled",
          ),
        )
      None => (resolved_status, descriptor)
    }
  }
  let claims = claims_cell.val
  let events = mooncode_continuation_read_evidence(
    target,
    workspace.root_path,
    read,
  )
  if saved is None {
    match
      mooncode_continuation_read_text(
        workspace.root_path,
        mooncode_continuation_path(id, "dispatch.json"),
      ) {
      Ok(None) => ()
      _ =>
        return mooncode_continuation_error(
          409, "snapshot_conflict", "A prior dispatch may exist but its immutable request is missing; this identity cannot be recaptured",
        )
    }
    for item in mooncode_continuation_claims_items(claims) {
      let lineage = json_object_field_or_empty(
        json_object_field_or_empty(
          json_object_field_or_empty(item, "command"),
          "payload",
        ),
        "moonproj_continuation",
      )
      if json_string(lineage, "continuation_id", default="") == id {
        return mooncode_continuation_error(
          409, "snapshot_conflict", "Native work already exists for this continuation but its immutable input is missing; do not submit a replacement",
        )
      }
    }
    if events is Null {
      return mooncode_continuation_error(
        503, "runtime_unavailable", "Exact prior result evidence is unavailable; nothing was submitted",
      )
    }
    let original = match mooncode_continuation_item(target, workspace, claims) {
      Ok(Some(item)) => item
      _ =>
        return mooncode_continuation_error(
          409, "identity_mismatch", "Original native command could not be verified",
        )
    }
    let prior_id = json_string(request, "prior_result_command_id", default="")
    let prior_target = MoonCodeWorkTarget::{
      session_id: target.session_id,
      command_id: prior_id,
      book_root: target.book_root,
    }
    let prior = match
      mooncode_continuation_item(prior_target, workspace, claims) {
      Ok(Some(item)) => item
      _ =>
        return mooncode_continuation_error(
          409, "prior_result_mismatch", "The exact selected prior result is unavailable",
        )
    }
    if prior_id != target.command_id {
      let lineage = json_object_field_or_empty(
        json_object_field_or_empty(
          json_object_field_or_empty(prior, "command"),
          "payload",
        ),
        "moonproj_continuation",
      )
      if json_string(lineage, "schema", default="") !=
        "moonproj.work-continuation.v1" ||
        ["task_id", "run_id", "original_command_id"].any(key => {
          json_object_field(lineage, key) != json_object_field(source, key)
        }) {
        return mooncode_continuation_error(
          409, "prior_result_mismatch", "The prior command is not attributed to this original work",
        )
      }
      let prior_snapshot = match
        mooncode_continuation_load(
          workspace.root_path,
          json_string(lineage, "continuation_id", default=""),
          target,
        ) {
        Ok(Some(value)) => value
        _ =>
          return mooncode_continuation_error(
            409, "prior_result_mismatch", "The prior continuation snapshot is unavailable or invalid",
          )
      }
      if !mooncode_continuation_native_matches(prior_snapshot, prior) {
        return mooncode_continuation_error(
          409, "prior_result_mismatch", "Prior accepted command does not match its saved input",
        )
      }
    }
    for item in mooncode_continuation_claims_items(claims) {
      if json_string(
          json_object_field_or_empty(
            json_object_field_or_empty(item, "command"),
            "packet",
          ),
          "client_turn_id",
          default="",
        ) ==
        client {
        return mooncode_continuation_error(
          409, "idempotency_conflict", "client_turn_id already belongs to a native command; recover its original continuation",
        )
      }
    }
    let context = mooncode_work_read_context(workspace, descriptor)
    let snapshot = match
      mooncode_continuation_prepare(
        request,
        workspace,
        original,
        prior,
        context,
        events,
        @async.now().to_string(),
      ) {
      Ok(value) => value
      Err(error) =>
        return mooncode_continuation_error(409, "capture_unavailable", error)
    }
    let client_path = mooncode_continuation_base() +
      "/clients/" +
      mooncode_continuation_hash(target.session_id + ":" + client) +
      ".json"
    let client_owner : Json = {
      "continuation_id": id,
      "client_turn_id": client,
      "session_id": target.session_id,
    }
    match
      mooncode_continuation_create_once(
        workspace.root_path,
        client_path,
        client_owner.stringify(),
      ) {
      Ok(_) => ()
      Err(error) =>
        return mooncode_continuation_error(409, "idempotency_conflict", error)
    }
    match
      mooncode_continuation_create_once(
        workspace.root_path,
        mooncode_continuation_path(id, "submission.json"),
        snapshot.stringify(),
      ) {
      Ok(_) => ()
      Err(error) =>
        return (
          503,
          mooncode_continuation_response(
            snapshot,
            None,
            events,
            "not_sent",
            message=error,
          ),
        )
    }
    match
      mooncode_continuation_create_once(
        workspace.root_path,
        mooncode_continuation_path(id, "input.md"),
        json_string(snapshot, "input_text", default=""),
      ) {
      Ok(_) => ()
      Err(error) =>
        return (
          503,
          mooncode_continuation_response(
            snapshot,
            None,
            events,
            "not_sent",
            message=error,
          ),
        )
    }
    saved = Some(snapshot)
  }
  let snapshot = saved.unwrap()
  // Re-read both durable artifacts before native admission, including after a
  // partially successful capture. Never reconstruct an existing request from C0.
  match mooncode_continuation_load(workspace.root_path, id, target) {
    Ok(Some(_)) => ()
    _ =>
      return (
        409,
        mooncode_continuation_response(
          snapshot,
          None,
          events,
          "not_sent",
          message="Snapshot verification failed before native admission",
        ),
      )
  }
  let command_id = json_string(snapshot, "command_id", default="")
  for item in mooncode_continuation_claims_items(claims) {
    let packet = json_object_field_or_empty(
      json_object_field_or_empty(item, "command"),
      "packet",
    )
    if json_string(packet, "client_turn_id", default="") ==
      json_string(snapshot, "client_turn_id", default="") &&
      json_string(item, "command_id", default="") != command_id {
      return (
        409,
        mooncode_continuation_response(
          snapshot,
          None,
          events,
          "unconfirmed",
          message="The captured client-turn identity now belongs to another native command; no duplicate was submitted",
        ),
      )
    }
  }
  let command_target = MoonCodeWorkTarget::{
    session_id: target.session_id,
    command_id,
    book_root: target.book_root,
  }
  let existing = match
    mooncode_continuation_item(command_target, workspace, claims) {
    Ok(value) => value
    Err(result) => return result
  }
  if existing is Some(item) {
    if !mooncode_continuation_native_matches(snapshot, item) {
      return mooncode_continuation_error(
        409, "identity_mismatch", "Native command differs from this immutable captured submission",
      )
    }
    if operation == "submit" || mooncode_continuation_settled(item) {
      return (
        200,
        mooncode_continuation_response(snapshot, existing, events, "accepted"),
      )
    }
  }
  let unobserved_admission = match
    mooncode_continuation_unobserved_admission(workspace.root_path, snapshot) {
    Ok(value) => value
    Err(error) =>
      return (
        409,
        mooncode_continuation_response(
          snapshot,
          existing,
          events,
          "unconfirmed",
          message=error,
        ),
      )
  }
  if !ready() {
    return (
      503,
      mooncode_continuation_response(
        snapshot,
        existing,
        events,
        if existing is Some(_) {
          "accepted"
        } else {
          unobserved_admission
        },
        message="Native runtime is unavailable; exact input is saved for resume",
      ),
    )
  }
  match
    mooncode_continuation_create_once(
      workspace.root_path,
      mooncode_continuation_path(id, "dispatch.json"),
      mooncode_continuation_dispatch_marker(snapshot).stringify(),
    ) {
    Ok(_) => ()
    Err(error) =>
      return (
        503,
        mooncode_continuation_response(
          snapshot,
          existing,
          events,
          unobserved_admission,
          message=error,
        ),
      )
  }
  let response = post(
    @mooncode.moonclaw_native_turn_endpoint(target.session_id),
    json_string(snapshot, "request_body", default=""),
  )
  let acknowledged = match response {
    Ok(value) =>
      json_bool(value, "accepted", default=false) &&
      json_string(value, "session_id", default="") == target.session_id &&
      json_string(value, "command_id", default="") == command_id &&
      mooncode_work_normalized_root(json_string(value, "book_root", default="")) ==
      mooncode_work_normalized_root(workspace.root_path)
    Err(_) => false
  }
  let readback = match
    read(
      @mooncode.moonclaw_native_runtime_claim_endpoint(
        target.session_id,
        workspace.root_path,
      ),
    ) {
    Ok(value) =>
      match mooncode_continuation_item(command_target, workspace, value) {
        Ok(Some(item)) if mooncode_continuation_native_matches(snapshot, item) =>
          Some(item)
        _ => None
      }
    Err(_) => None
  }
  let admission = if acknowledged || readback is Some(_) || existing is Some(_) {
    "accepted"
  } else {
    "unconfirmed"
  }
  (
    if admission == "accepted" {
      200
    } else {
      503
    },
    mooncode_continuation_response(
      snapshot,
      match readback {
        Some(_) => readback
        None => existing
      },
      events,
      admission,
      message=if admission == "unconfirmed" {
        "Native admission is unconfirmed"
      } else {
        ""
      },
    ),
  )
}

///|
async fn handle_mooncode_work_continuation(
  workspace_root : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let request = match read_json_body(body) {
    Some(value) => value
    None => {
      send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
      return
    }
  }
  let daemon = moonclaw_model_route_daemon_candidate(workspace_root)
  let (status, payload) = mooncode_continue_work(
    workspace_root,
    discover_workspaces(workspace_root),
    request,
    path => moonclaw_get_json(daemon, path),
    (path, exact_body) => {
      mooncode_continuation_post_exact(daemon, path, exact_body)
    },
    () => mooncode_turn_runtime_ready(daemon),
  )
  conn.send_response(
    status,
    if status == 200 {
      "OK"
    } else if status == 409 {
      "Conflict"
    } else if status == 400 {
      "Bad Request"
    } else if status == 404 {
      "Not Found"
    } else {
      "Service Unavailable"
    },
    extra_headers={
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
    },
  )
  conn.write(payload.stringify())
  conn.end_response()
}

///|
async fn mooncode_continuation_post_exact(
  daemon : Json,
  path : String,
  body : String,
) -> Result[Json, String] {
  let config = match moonclaw_load_control_config(daemon) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let port = json_int(daemon, "port", default=0)
  if port <= 0 {
    return Err("MoonClaw control endpoint is unavailable")
  }
  let (response, data) = @http.post(
    "http://127.0.0.1:\{port}\{path}",
    body,
    headers=moonclaw_control_headers(config, content_type=true),
  ) catch {
    _ => return Err("MoonClaw continuation POST failed")
  }
  let text = match
    moonclaw_control_response_text(response, data, config, "continuation POST") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  Ok(
    @json.parse(text) catch {
      _ => return Err("MoonClaw returned invalid continuation acknowledgement")
    },
  )
}
