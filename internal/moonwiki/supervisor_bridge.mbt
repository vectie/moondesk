///|
let supervisor_bridge_mutex : @async.Mutex = Mutex()

///|
priv struct SupervisorBridgeDispatch {
  endpoint : String
  request_digest : String
  body : Json
}

///|
fn supervisor_bridge_transport_id() -> String {
  // This bridge talks to MoonTown's desktop owner API. Its claims must use the
  // same stable identity so a restarted bridge can reclaim and reconcile work
  // that it previously forwarded.
  "moondesk-owner-service"
}

///|
fn supervisor_bridge_state_root(workspace_root : String) -> String {
  moonsuite_product_artifact_for_workspace_root(
    workspace_root, "moondesk", "supervisor-bridge",
  )
}

///|
fn supervisor_bridge_receipts_root(workspace_root : String) -> String {
  @pathx.join(supervisor_bridge_state_root(workspace_root), "receipts")
}

///|
fn supervisor_bridge_auto_status_path(workspace_root : String) -> String {
  @pathx.join(supervisor_bridge_state_root(workspace_root), "auto-pump.json")
}

///|
async fn supervisor_bridge_read_auto_status(workspace_root : String) -> Json {
  let path = supervisor_bridge_auto_status_path(workspace_root)
  if !@fsx.exists(path) {
    return {
      "contract_id": "moondesk.supervisor-bridge-auto-pump.v1",
      "enabled": true,
      "status": "starting",
      "base_interval_ms": 2000,
      "max_backoff_ms": 30000,
      "last_receipt": Json::null(),
    }
  }
  @json.parse(@fsx.read_file(path)) catch {
    _ =>
      {
        "contract_id": "moondesk.supervisor-bridge-auto-pump.v1",
        "enabled": true,
        "status": "status_unreadable",
        "base_interval_ms": 2000,
        "max_backoff_ms": 30000,
        "last_receipt": Json::null(),
      }
  }
}

///|
async fn supervisor_bridge_write_auto_status(
  workspace_root : String,
  status : Json,
) -> Unit {
  @fsx.make_directory(
    supervisor_bridge_state_root(workspace_root),
    recursive=true,
    exists_ok=true,
  ) catch {
    _ => return
  }
  @fsx.write_to_file(
    supervisor_bridge_auto_status_path(workspace_root),
    status.stringify(indent=2) + "\n",
    create=0o600,
  ) catch {
    _ => ()
  }
}

///|
fn supervisor_bridge_digest(value : Json) -> String {
  "sha256:" +
  @crypto.bytes_to_hex_string(
    @crypto.sha256(@encoding/utf8.encode(value.stringify()).to_fixedarray()),
  )
}

///|
fn supervisor_bridge_json_int64(
  value : Json,
  key : String,
  default : Int64,
) -> Int64 {
  match json_object_field(value, key) {
    Some(String(raw)) => @string.parse_int64(raw) catch { _ => default }
    Some(Number(number, ..)) => number.to_int64()
    _ => default
  }
}

///|
fn supervisor_bridge_receipt_key(kind : String, target_id : String) -> String {
  @desk.stable_id("supervisor-bridge-" + kind, target_id)
}

///|
fn supervisor_bridge_receipt_path(
  workspace_root : String,
  kind : String,
  target_id : String,
) -> String {
  @pathx.join(
    supervisor_bridge_receipts_root(workspace_root),
    supervisor_bridge_receipt_key(kind, target_id) + ".json",
  )
}

///|
async fn supervisor_bridge_read_receipt(
  workspace_root : String,
  kind : String,
  target_id : String,
) -> Json? {
  let path = supervisor_bridge_receipt_path(workspace_root, kind, target_id)
  if !@fsx.exists(path) {
    return None
  }
  Some(@json.parse(@fsx.read_file(path))) catch {
    _ => None
  }
}

///|
async fn supervisor_bridge_write_receipt(
  workspace_root : String,
  record : Json,
) -> Result[Json, String] {
  let kind = json_string(record, "kind", default="")
  let target_id = json_string(record, "target_id", default="")
  if !["activation", "execution", "bookkeeper", "observation"].contains(kind) ||
    target_id == "" {
    return Err("invalid supervisor bridge receipt identity")
  }
  @fsx.make_directory(
    supervisor_bridge_receipts_root(workspace_root),
    recursive=true,
    exists_ok=true,
  ) catch {
    error => return Err("could not create supervisor bridge state: \{error}")
  }
  @fsx.write_to_file(
    supervisor_bridge_receipt_path(workspace_root, kind, target_id),
    record.stringify(indent=2) + "\n",
    create=0o600,
  ) catch {
    error => return Err("could not persist supervisor bridge receipt: \{error}")
  }
  Ok(record)
}

///|
async fn supervisor_bridge_receipt_records(
  workspace_root : String,
) -> Array[Json] {
  let root = supervisor_bridge_receipts_root(workspace_root)
  if !@fsx.exists(root) {
    return []
  }
  let records : Array[Json] = []
  let names = @fsx.list_directory(root) catch { _ => [] }
  for name in names {
    if !name.has_suffix(".json") {
      continue
    }
    let value = @json.parse(@fsx.read_file(@pathx.join(root, name))) catch {
      _ => continue
    }
    records.push(value)
  }
  records
}

///|
fn supervisor_bridge_materialized_grant(
  source : Json,
  kind : String,
  target_id : String,
  request_digest : String,
) -> Result[Json, String] {
  let actor_user_id = json_string(source, "owner_user_id", default="")
  let command_id = {
    let value = json_string(source, "command_id", default="")
    if value == "" {
      target_id
    } else {
      value
    }
  }
  if actor_user_id == "" ||
    target_id == "" ||
    command_id == "" ||
    !request_digest.has_prefix("sha256:") ||
    request_digest.length() != 71 {
    return Err(
      "durable Town user action lacks exact actor, command, target, or digest identity",
    )
  }
  let now_ms = @async.now()
  let decided_at = @time.unix(now_ms / 1000L).to_string() catch {
    error =>
      return Err("could not timestamp supervisor authority grant: \{error}")
  }
  let expires_at = @time.unix((now_ms + 300000L) / 1000L).to_string() catch {
    error => return Err("could not expire supervisor authority grant: \{error}")
  }
  let authority : Json = {
    "contract_id": "moonsuite.authority-decision-ref.v1",
    "decision_id": @desk.stable_id(
      "moondesk-grant",
      supervisor_bridge_digest({
        "kind": kind,
        "target_id": target_id,
        "command_id": command_id,
        "request_digest": request_digest,
      }),
    ),
    "principal": {
      "contract_id": "moonsuite.principal-ref.v1",
      "principal_id": "moonclaw-daemon",
      "kind": "service",
      "issuer": "moonclaw",
      "subject": "local-daemon",
    },
    "digest": request_digest,
    "decided_at": decided_at,
    "expires_at": expires_at,
  }
  Ok({
    "contract_id": "moondesk.supervisor-bridge-authority-grant.v1",
    "kind": kind,
    "target_id": target_id,
    "request_digest": request_digest,
    "actor_user_id": actor_user_id,
    "source_command_id": command_id,
    "source_product": "moontown",
    "source_contract": json_string(source, "schema", default=""),
    "evaluated_at": decided_at,
    "authority": authority,
  })
}

///|
fn supervisor_bridge_envelope(
  handoff : Json,
  request_digest : String,
  grant : Json,
) -> Json {
  let fields : Map[String, Json] = {
    "contract_id": "moonclaw.supervisor-command.v1",
    "command_id": json_string(handoff, "command_id", default=""),
    "request_digest": request_digest,
    "issued_at": supervisor_bridge_json_int64(handoff, "created_at_ms", 0L).to_string(),
    "evaluated_at": json_string(grant, "evaluated_at", default=""),
    "authority": json_object_field(grant, "authority").unwrap_or(Json::null()),
  }
  match json_object_field(handoff, "expected_cursor") {
    Some(value) if value != Json::null() => fields["expected_cursor"] = value
    _ => ()
  }
  Json::object(fields)
}

///|
fn supervisor_bridge_runtime_command_matches(
  command : Json,
  payload : Json,
  handoff : Json,
  request_digest : String,
) -> Bool {
  guard command is Object(command_fields) else { return false }
  let operation_fields = command_fields.copy()
  operation_fields.remove("envelope")
  let envelope = json_object_field(command, "envelope").unwrap_or(Json::null())
  let authority = json_object_field(envelope, "authority").unwrap_or(
    Json::null(),
  )
  let principal = json_object_field(authority, "principal").unwrap_or(
    Json::null(),
  )
  Json::object(operation_fields) == payload &&
  json_string(envelope, "contract_id", default="") ==
  "moonclaw.supervisor-command.v1" &&
  json_string(envelope, "command_id", default="") ==
  json_string(handoff, "command_id", default="") &&
  json_string(envelope, "request_digest", default="") == request_digest &&
  json_string(envelope, "issued_at", default="") ==
  supervisor_bridge_json_int64(handoff, "created_at_ms", -1L).to_string() &&
  json_string(envelope, "evaluated_at", default="") != "" &&
  json_object_field(envelope, "expected_cursor").unwrap_or(Json::null()) ==
  json_object_field(handoff, "expected_cursor").unwrap_or(Json::null()) &&
  json_string(authority, "contract_id", default="") ==
  "moonsuite.authority-decision-ref.v1" &&
  json_string(authority, "digest", default="") == request_digest &&
  json_string(authority, "decided_at", default="") ==
  json_string(envelope, "evaluated_at", default="") &&
  json_string(authority, "expires_at", default="") != "" &&
  json_string(principal, "contract_id", default="") ==
  "moonsuite.principal-ref.v1" &&
  json_string(principal, "principal_id", default="") == "moonclaw-daemon" &&
  json_string(principal, "kind", default="") == "service" &&
  json_string(principal, "issuer", default="") == "moonclaw" &&
  json_string(principal, "subject", default="") == "local-daemon"
}

///|
fn supervisor_bridge_grant_from_runtime_command(
  base : Json,
  command : Json,
) -> Json {
  let envelope = json_object_field(command, "envelope").unwrap_or(Json::null())
  {
    "contract_id": "moondesk.supervisor-bridge-authority-grant.v1",
    "kind": json_string(base, "kind", default=""),
    "target_id": json_string(base, "target_id", default=""),
    "request_digest": json_string(base, "request_digest", default=""),
    "actor_user_id": json_string(base, "actor_user_id", default=""),
    "source_command_id": json_string(base, "source_command_id", default=""),
    "source_product": "moontown",
    "source_contract": json_string(base, "source_contract", default=""),
    "evaluated_at": json_string(envelope, "evaluated_at", default=""),
    "authority": json_object_field(envelope, "authority").unwrap_or(
      Json::null(),
    ),
  }
}

///|
fn supervisor_bridge_installed_book_marker_exists(book_root : String) -> Bool {
  @nativefs.path_exists(@pathx.join(book_root, "book.json")) ||
  @nativefs.path_exists(@pathx.join(book_root, "book/book.json")) ||
  @nativefs.path_exists(@pathx.join(book_root, "book/moonbook-ui-state.json"))
}

///|
fn supervisor_bridge_delegate_cwd(
  workspace_root : String,
  metadata : Json,
) -> Result[String, String] {
  let book_id = {
    let value = json_string(metadata, "book_id", default="")
    if value == "" {
      json_string(metadata, "bookId", default="")
    } else {
      value
    }
  }
  let workspace_id = {
    let value = json_string(metadata, "workspace_id", default="")
    if value == "" {
      json_string(metadata, "workspaceId", default="")
    } else {
      value
    }
  }
  if book_id == "" ||
    book_id == "." ||
    book_id == ".." ||
    book_id.contains("/") ||
    book_id.contains("\\") ||
    workspace_id == "" {
    return Err("delegate task has an invalid symbolic MoonBook binding")
  }
  let context = workspace_context(workspace_root)
  let candidate = @pathx.normalize(context.book_root(book_id))
  let active = @pathx.normalize(workspace_root)
  if !context.book_root_allowed(candidate) ||
    (active != context.suite_root && active != candidate) ||
    !supervisor_bridge_installed_book_marker_exists(candidate) {
    return Err("delegate task is not bound to an installed active MoonBook")
  }
  Ok(candidate)
}

///|
fn supervisor_bridge_delegate_intent_payload(
  handoff : Json,
  supervisor_id : String,
  workspace_root : String,
) -> Result[Json, String] {
  let schema = json_string(handoff, "schema", default="")
  let handoff_id = json_string(handoff, "handoff_id", default="")
  let instruction = json_string(handoff, "instruction", default="")
    .trim()
    .to_owned()
  if handoff_id == "" || instruction == "" || workspace_root == "" {
    return Err(
      "delegate handoff lacks its exact instruction, workspace, or stable task identity",
    )
  }
  let worker_task = json_object_field(handoff, "worker_task").unwrap_or(
    Json::null(),
  )
  let worker_bounds = json_object_field(handoff, "worker_bounds").unwrap_or(
    Json::null(),
  )
  if schema != "moontown.supervisor-execution-handoff.v2" ||
    !(worker_task is Object(_)) ||
    !(worker_bounds is Object(_)) {
    return Err(
      "delegate requires the exact Town execution handoff v2 task and scope",
    )
  }
  let task_id = json_string(worker_task, "task_id", default="")
  let conversation_id = json_string(worker_task, "conversation_id", default="")
  let title = json_string(worker_task, "title", default="")
  let model = json_string(worker_task, "model", default="")
  let metadata = json_object_field(worker_task, "metadata").unwrap_or(
    Json::null(),
  )
  let book_id = {
    let value = json_string(metadata, "book_id", default="")
    if value == "" {
      json_string(metadata, "bookId", default="")
    } else {
      value
    }
  }
  let web_search = match json_object_field(worker_task, "web_search") {
    Some(True) => true
    Some(False) => false
    _ => return Err("delegate task lacks its explicit web-search posture")
  }
  if task_id == "" ||
    conversation_id == "" ||
    title == "" ||
    model != "gpt-5.6-sol" ||
    !(metadata is Object(_)) {
    return Err("delegate task is incomplete or uses a non-allowlisted model")
  }
  let cwd = match supervisor_bridge_delegate_cwd(workspace_root, metadata) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let budget = json_object_field(worker_bounds, "budget").unwrap_or(
    Json::null(),
  )
  let max_cost_micro_usd = supervisor_bridge_json_int64(
    budget, "max_cost_micro_usd", -1L,
  )
  let max_runtime_ms = supervisor_bridge_json_int64(
    budget, "max_runtime_ms", -1L,
  )
  let max_tokens = supervisor_bridge_json_int64(budget, "max_tokens", -1L)
  let max_artifacts = json_int(budget, "max_artifacts", default=-1)
  let claim_ceiling = json_string(worker_bounds, "claim_ceiling", default="")
  let artifact_prefixes = json_object_field(worker_bounds, "artifact_prefixes").unwrap_or(
    Json::null(),
  )
  let expires_at = json_string(worker_bounds, "expires_at", default="")
  let exact_artifact_prefix = "books/" + book_id + "/artifacts"
  let artifact_prefixes_valid = match artifact_prefixes {
    Array([prefix]) => prefix == Json::string(exact_artifact_prefix)
    _ => false
  }
  if max_cost_micro_usd <= 0L ||
    max_runtime_ms <= 0L ||
    max_tokens <= 0L ||
    max_artifacts <= 0 ||
    !["evidence-only", "draft", "reviewable"].contains(claim_ceiling) ||
    !artifact_prefixes_valid ||
    expires_at == "" {
    return Err("delegate handoff has invalid durable worker bounds")
  }
  Ok({
    "supervisor_id": supervisor_id,
    "instruction": instruction,
    "task": {
      "task_id": task_id,
      "conversation_id": conversation_id,
      "title": title,
      "cwd": cwd,
      "model": model,
      "web_search": web_search,
      "metadata": metadata,
    },
    "scope": {
      "claim_ceiling": claim_ceiling,
      "budget": {
        "max_cost_micro_usd": max_cost_micro_usd.to_string(),
        "max_runtime_ms": max_runtime_ms.to_string(),
        "max_tokens": max_tokens.to_string(),
        "max_artifacts": max_artifacts,
      },
      "artifact_prefixes": artifact_prefixes,
      "expires_at": expires_at,
    },
  })
}

///|
fn supervisor_bridge_message_payload(
  handoff : Json,
  supervisor_id : String,
  parent_run_id : String,
) -> Result[Json, String] {
  let handoff_id = json_string(handoff, "handoff_id", default="")
  let command_id = json_string(handoff, "command_id", default="")
  let owner_user_id = json_string(handoff, "owner_user_id", default="")
  let content = json_string(handoff, "instruction", default="")
    .trim()
    .to_owned()
  let conversation_id = {
    let value = json_string(handoff, "conversation_id", default="")
    if value == "" {
      handoff_id
    } else {
      value
    }
  }
  let task_id = match json_string_opt(handoff, "task_id") {
    Some(value) if value != "" => Json::string(value)
    _ => Json::null()
  }
  let created_at = supervisor_bridge_json_int64(handoff, "created_at_ms", 0L)
  if handoff_id == "" ||
    command_id == "" ||
    owner_user_id == "" ||
    content == "" ||
    conversation_id == "" ||
    created_at <= 0L {
    return Err("message handoff lacks its exact durable message identity")
  }
  Ok({
    "supervisor_id": supervisor_id,
    "message": {
      "message_id": command_id,
      "conversation_id": conversation_id,
      "task_id": task_id,
      "sender_ref": owner_user_id,
      "content": content,
      "content_type": "text/plain",
      "reply_to_message_id": Json::null(),
      "created_at": created_at.to_string(),
      "metadata": {
        "source": "moontown",
        "handoff_id": handoff_id,
        "parent_run_id": parent_run_id,
        "command_kind": json_string(handoff, "command_kind", default=""),
      },
    },
  })
}

///|
fn supervisor_bridge_execution_dispatch(
  handoff : Json,
  grant? : Json,
  workspace_root? : String = "",
) -> Result[SupervisorBridgeDispatch, String] {
  let supervisor_id = json_string(handoff, "supervisor_profile_id", default="")
  let action = json_string(handoff, "action", default="")
  let schema = json_string(handoff, "schema", default="")
  if schema != "moontown.supervisor-execution-handoff.v1" &&
    schema != "moontown.supervisor-execution-handoff.v2" {
    return Err("execution handoff schema is not allowlisted")
  }
  if schema == "moontown.supervisor-execution-handoff.v2" {
    let expected_kind = match action {
      "delegate" => "bounded_worker_assignment"
      "message" => "supervisor_message"
      "steer" | "wake" => "supervisor_run_control"
      "supervisor_stop" | "supervisor_resume" => "supervisor_lifecycle_control"
      "child_stop" | "child_steer" | "child_retry" => "child_run_control"
      _ => ""
    }
    if json_string(handoff, "target_runtime", default="") != "moonclaw" ||
      expected_kind == "" ||
      json_string(handoff, "command_kind", default="") != expected_kind {
      return Err("execution handoff runtime or command kind is not exact")
    }
  }
  let parent_run_id = {
    let value = json_string(handoff, "parent_run_id", default="")
    if value == "" && schema == "moontown.supervisor-execution-handoff.v1" {
      json_string(handoff, "run_id", default="")
    } else {
      value
    }
  }
  if supervisor_id == "" || parent_run_id == "" {
    return Err("execution handoff lacks its exact supervisor or run identity")
  }
  let (endpoint, payload) : (String, Json) = match action {
    "message" =>
      (
        "message",
        match
          supervisor_bridge_message_payload(
            handoff, supervisor_id, parent_run_id,
          ) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
      )
    "steer" => {
      let target_run_id = json_string(handoff, "target_run_id", default="")
      if target_run_id == "" {
        return Err("steer handoff lacks its exact target run identity")
      }
      let message = match
        supervisor_bridge_message_payload(handoff, supervisor_id, parent_run_id) {
        Ok(value) => json_object_field(value, "message").unwrap_or(Json::null())
        Err(error) => return Err(error)
      }
      (
        "steer",
        {
          "supervisor_id": supervisor_id,
          "message": message,
          "target_run_id": target_run_id,
        },
      )
    }
    "delegate" =>
      (
        "delegate",
        match
          supervisor_bridge_delegate_intent_payload(
            handoff, supervisor_id, workspace_root,
          ) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
      )
    "wake" =>
      ("wake", { "supervisor_id": supervisor_id, "run_id": parent_run_id })
    "cancel" | "supervisor_stop" => {
      let requested = json_string(handoff, "instruction", default="")
        .trim()
        .to_owned()
      let reason = if requested == "" {
        "MoonTown requested cancellation of run " + parent_run_id
      } else {
        requested
      }
      (
        "stop",
        { "supervisor_id": supervisor_id, "reason": reason, "force": false },
      )
    }
    "retry" =>
      (
        "retry-resume",
        { "supervisor_id": supervisor_id, "action": ["Retry", parent_run_id] },
      )
    "supervisor_resume" =>
      ("retry-resume", { "supervisor_id": supervisor_id, "action": "Resume" })
    "child_stop" => {
      let worker_run_id = json_string(handoff, "target_run_id", default="")
      if worker_run_id == "" {
        return Err("child stop handoff lacks receipt-projected worker identity")
      }
      let requested = json_string(handoff, "instruction", default="")
        .trim()
        .to_owned()
      (
        "worker-stop",
        {
          "supervisor_id": supervisor_id,
          "worker_run_id": worker_run_id,
          "reason": if requested == "" {
            "MoonTown requested bounded worker cancellation"
          } else {
            requested
          },
          "force": false,
        },
      )
    }
    "child_steer" => {
      let worker_run_id = json_string(handoff, "target_run_id", default="")
      let requested = json_string(handoff, "instruction", default="")
        .trim()
        .to_owned()
      if worker_run_id == "" || requested == "" {
        return Err(
          "child steer handoff lacks receipt-projected worker identity or instruction",
        )
      }
      (
        "worker-steer",
        {
          "supervisor_id": supervisor_id,
          "worker_run_id": worker_run_id,
          "instruction": requested,
          "metadata": {
            "source": "moontown",
            "handoff_id": json_string(handoff, "handoff_id", default=""),
            "parent_run_id": parent_run_id,
            "command_kind": json_string(handoff, "command_kind", default=""),
          },
        },
      )
    }
    "child_retry" => {
      let worker_run_id = json_string(handoff, "target_run_id", default="")
      if worker_run_id == "" {
        return Err(
          "child retry handoff lacks receipt-projected worker identity",
        )
      }
      let requested = json_string(handoff, "instruction", default="")
        .trim()
        .to_owned()
      (
        "worker-retry-resume",
        {
          "supervisor_id": supervisor_id,
          "worker_run_id": worker_run_id,
          "reason": if requested == "" {
            "MoonTown requested bounded worker retry"
          } else {
            requested
          },
        },
      )
    }
    _ =>
      return Err("execution handoff action has no allowlisted MoonClaw mapping")
  }
  let request_digest = supervisor_bridge_digest(payload)
  let body = match grant {
    Some(exact_grant) => {
      let envelope = supervisor_bridge_envelope(
        handoff, request_digest, exact_grant,
      )
      match payload {
        Object(fields) => {
          let request_fields = fields.copy()
          request_fields["envelope"] = envelope
          // The wire DTO declares envelope first, but decoding is key based.
          Json::object(request_fields)
        }
        _ => Json::null()
      }
    }
    None => payload
  }
  Ok({ endpoint, request_digest, body })
}

///|
fn supervisor_bridge_execution_requirement(
  workspace_root : String,
  handoff : Json,
) -> Json {
  match supervisor_bridge_execution_dispatch(handoff, workspace_root~) {
    Ok(dispatch) =>
      {
        "kind": "execution",
        "target_id": json_string(handoff, "handoff_id", default=""),
        "source_request_digest": json_string(
          handoff,
          "request_digest",
          default="",
        ),
        "request_digest": dispatch.request_digest,
        "transport_request_digest": dispatch.request_digest,
        "moonclaw_endpoint": dispatch.endpoint,
        "status": json_string(handoff, "status", default=""),
        "authority_materialization": "host_from_durable_town_action",
      }
    Err(error) =>
      {
        "kind": "execution",
        "target_id": json_string(handoff, "handoff_id", default=""),
        "request_digest": "",
        "moonclaw_endpoint": "",
        "status": "blocked",
        "authority_materialization": "host_from_durable_town_action",
        "blocker": error,
      }
  }
}

///|
fn supervisor_bridge_latest_execution_handoffs(outbox : Json) -> Array[Json] {
  let latest : Map[String, Json] = Map([])
  for handoff in json_array_items(outbox, "executionHandoffs") {
    let id = json_string(handoff, "handoff_id", default="")
    if id == "" {
      continue
    }
    match latest.get(id) {
      Some(previous) if json_int(previous, "revision", default=0) >=
        json_int(handoff, "revision", default=0) => ()
      _ => latest[id] = handoff
    }
  }
  latest.values().to_array()
}

///|
fn supervisor_bridge_latest_activation_handoffs(outbox : Json) -> Array[Json] {
  let latest : Map[String, Json] = Map([])
  for handoff in json_array_items(outbox, "activationHandoffs") {
    let id = json_string(handoff, "handoff_id", default="")
    if id == "" {
      continue
    }
    match latest.get(id) {
      Some(previous) if json_int(previous, "revision", default=0) >=
        json_int(handoff, "revision", default=0) => ()
      _ => latest[id] = handoff
    }
  }
  latest.values().to_array()
}

///|
fn supervisor_bridge_latest_bookkeeper_requests(outbox : Json) -> Array[Json] {
  let latest : Map[String, Json] = Map([])
  for request in json_array_items(outbox, "requests") {
    let id = json_string(request, "request_id", default="")
    if id == "" {
      continue
    }
    match latest.get(id) {
      Some(previous) if json_int(previous, "revision", default=0) >=
        json_int(request, "revision", default=0) => ()
      _ => latest[id] = request
    }
  }
  latest.values().to_array()
}

///|
fn supervisor_bridge_active_activations(runtime : Json) -> Array[Json] {
  let active : Array[Json] = []
  for handoff in supervisor_bridge_latest_activation_handoffs(runtime) {
    if json_string(handoff, "status", default="") != "runtime_acknowledged" {
      continue
    }
    let payload = json_object_field(handoff, "payload").unwrap_or(Json::null())
    let receipt = json_object_field(handoff, "runtime_receipt").unwrap_or(
      Json::null(),
    )
    let state = json_object_field(receipt, "response").unwrap_or(Json::null())
    let supervisor_id = json_string(payload, "supervisor_id", default="")
    let parent_run_id = json_string(state, "active_run_id", default="")
    if supervisor_id != "" && parent_run_id != "" {
      active.push({
        "supervisor_id": supervisor_id,
        "parent_run_id": parent_run_id,
      })
    }
  }
  active
}

///|
fn supervisor_bridge_bookkeeper_state_claimable(state : String) -> Bool {
  [
    "pending_bookkeeper", "claimed_for_transport", "deliverable_review_required",
    "assessment_review_required", "proposal_review_required",
  ].contains(state)
}

///|
fn supervisor_bridge_bookkeeper_pending_gate(request : Json) -> String {
  match json_object_field(request, "bookkeeper_receipt") {
    Some(receipt) =>
      json_string(
        receipt,
        "state",
        default=json_string(request, "state", default=""),
      )
    None => json_string(request, "state", default="")
  }
}

///|
fn supervisor_bridge_requirements(
  workspace_root : String,
  runtime : Json,
  bookkeeper : Json,
) -> Array[Json] {
  let requirements : Array[Json] = []
  for handoff in supervisor_bridge_latest_activation_handoffs(runtime) {
    let status = json_string(handoff, "status", default="")
    if status == "pending_transport" ||
      status == "runtime_failed" ||
      (
        status == "claimed_for_transport" &&
        json_string(handoff, "claimed_by", default="") ==
        supervisor_bridge_transport_id()
      ) {
      requirements.push({
        "kind": "activation",
        "target_id": json_string(handoff, "handoff_id", default=""),
        "request_digest": json_string(handoff, "request_digest", default=""),
        "moonclaw_endpoint": "activate",
        "status": status,
        "authority_materialization": "host_from_durable_town_action",
      })
    }
  }
  for handoff in supervisor_bridge_latest_execution_handoffs(runtime) {
    let status = json_string(handoff, "status", default="")
    if status == "pending_transport" ||
      status == "runtime_failed" ||
      (
        status == "claimed_for_transport" &&
        json_string(handoff, "claimed_by", default="") ==
        supervisor_bridge_transport_id()
      ) {
      requirements.push(
        supervisor_bridge_execution_requirement(workspace_root, handoff),
      )
    }
  }
  for request in supervisor_bridge_latest_bookkeeper_requests(bookkeeper) {
    let state = json_string(request, "state", default="")
    if supervisor_bridge_bookkeeper_state_claimable(state) &&
      (
        state != "claimed_for_transport" ||
        json_string(request, "claimed_by", default="") ==
        supervisor_bridge_transport_id()
      ) {
      let submission = json_object_field(request, "product_outcome_submission").unwrap_or(
        Json::null(),
      )
      requirements.push({
        "kind": "bookkeeper",
        "target_id": json_string(request, "request_id", default=""),
        "request_digest": supervisor_bridge_digest(submission),
        "moonbook_operation": "bookkeeper.outcome.submit",
        "status": state,
        "pending_gate": supervisor_bridge_bookkeeper_pending_gate(request),
        "authority_materialization": "host_from_durable_town_action",
      })
    }
  }
  requirements
}

///|
async fn supervisor_bridge_outboxes(
  workspace_root : String,
) -> Result[(Json, Json), String] {
  let runtime = match
    moontown_owner_get_json(workspace_root, "/miniapp/outbox/runtime") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let bookkeeper = match
    moontown_owner_get_json(workspace_root, "/miniapp/outbox/bookkeeper") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if json_string(runtime, "schema", default="") !=
    "moontown.runtime-handoff-outbox.v1" ||
    json_string(bookkeeper, "schema", default="") !=
    "moontown.bookkeeper-outbox.v1" {
    return Err("MoonTown supervisor outbox contract is not exact")
  }
  Ok((runtime, bookkeeper))
}

///|
async fn supervisor_bridge_status(workspace_root : String) -> Json {
  let auto_pump = supervisor_bridge_read_auto_status(workspace_root)
  match supervisor_bridge_outboxes(workspace_root) {
    Err(error) =>
      {
        "ok": false,
        "contract_id": "moondesk.supervisor-bridge-status.v1",
        "transport_id": supervisor_bridge_transport_id(),
        "status": "moontown_unavailable",
        "message": error,
        "auto_pump": auto_pump,
        "requirements": [],
        "receipts": supervisor_bridge_receipt_records(workspace_root),
      }
    Ok((runtime, bookkeeper)) => {
      let requirements = supervisor_bridge_requirements(
        workspace_root, runtime, bookkeeper,
      )
      let active = supervisor_bridge_active_activations(runtime)
      {
        "ok": true,
        "contract_id": "moondesk.supervisor-bridge-status.v1",
        "transport_id": supervisor_bridge_transport_id(),
        "status": if !requirements.is_empty() {
          "sync_required"
        } else if !active.is_empty() {
          "observing"
        } else {
          "idle"
        },
        "message": if !requirements.is_empty() {
          "The automatic bridge will materialize short-lived authority from each exact durable Town user action; grant-and-sync remains available for recovery"
        } else if !active.is_empty() {
          "The automatic bridge is polling exact MoonClaw status and event replay into Town observations"
        } else {
          "No claimable supervisor handoffs are waiting"
        },
        "auto_pump": auto_pump,
        "requirements": requirements,
        "active_supervisors": active,
        "runtime_outbox": runtime,
        "bookkeeper_outbox": bookkeeper,
        "receipts": supervisor_bridge_receipt_records(workspace_root),
      }
    }
  }
}

///|
fn supervisor_bridge_activation_request(command : Json) -> Result[Json, String] {
  let profile = json_object_field(command, "profile").unwrap_or(Json::null())
  let request_digest = json_string(command, "request_digest", default="")
  if !(profile is Object(_)) ||
    request_digest == "" ||
    supervisor_bridge_digest(profile) != request_digest {
    return Err("Town activation claim did not return an exact MoonClaw command")
  }
  let envelope_fields : Map[String, Json] = {
    "contract_id": json_string(command, "contract_id", default=""),
    "command_id": json_string(command, "command_id", default=""),
    "request_digest": request_digest,
    "issued_at": json_object_field(command, "issued_at").unwrap_or(Json::null()),
    "evaluated_at": json_string(command, "evaluated_at", default=""),
    "authority": json_object_field(command, "authority").unwrap_or(Json::null()),
  }
  match json_object_field(command, "expected_cursor") {
    Some(value) if value != Json::null() =>
      envelope_fields["expected_cursor"] = value
    _ => ()
  }
  Ok({ "envelope": Json::object(envelope_fields), "profile": profile })
}

///|
fn supervisor_bridge_receipt_matches(
  receipt : Json,
  command_id : String,
  request_digest : String,
  supervisor_id : String,
) -> Bool {
  receipt is Object(_) &&
  json_string(receipt, "contract_id", default="") ==
  "moonclaw.supervisor-command-receipt.v1" &&
  json_string(receipt, "command_id", default="") == command_id &&
  json_string(receipt, "request_digest", default="") == request_digest &&
  json_string(receipt, "supervisor_id", default="") == supervisor_id &&
  json_string(receipt, "status", default="") != ""
}

///|
fn supervisor_bridge_execution_receipt(
  response : Json,
  endpoint : String,
) -> Json {
  if endpoint == "delegate" &&
    json_string(response, "contract_id", default="") ==
    "moonclaw.supervisor-delegate-intent-result.v1" {
    json_object_field(response, "receipt").unwrap_or(Json::null())
  } else {
    response
  }
}

///|
async fn supervisor_bridge_saved_forwarded_record(
  workspace_root : String,
  kind : String,
  target_id : String,
  request_digest : String,
) -> Json? {
  guard supervisor_bridge_read_receipt(workspace_root, kind, target_id)
    is Some(record) &&
    json_string(record, "request_digest", default="") == request_digest &&
    json_string(record, "phase", default="") == "forwarded" else {
    return None
  }
  guard json_object_field(record, "forwarded_receipt") is Some(_) else {
    return None
  }
  Some(record)
}

///|
/// Rejects the legacy delegate response shape where MoonBit's generic Option
/// encoder placed `provider_receipt` inside an array. Re-forwarding the same
/// idempotent command obtains the exact object-or-null contract and lets the
/// owner reconcile after restart.
fn supervisor_bridge_saved_execution_response_valid(record : Json) -> Bool {
  if json_string(record, "transport_endpoint", default="") != "delegate" {
    return true
  }
  guard json_object_field(record, "forwarded_response") is Some(response) &&
    json_string(response, "contract_id", default="") ==
    "moonclaw.supervisor-delegate-intent-result.v1" else {
    return false
  }
  match json_object_field(response, "provider_receipt") {
    Some(Null) | Some(Object(_)) => true
    _ => false
  }
}

///|
async fn supervisor_bridge_saved_execution_transport(
  workspace_root : String,
  handoff : Json,
  payload : Json,
  request_digest : String,
) -> Json? {
  let target_id = json_string(handoff, "handoff_id", default="")
  guard supervisor_bridge_read_receipt(workspace_root, "execution", target_id)
    is Some(record) &&
    json_string(record, "request_digest", default="") == request_digest &&
    json_object_field(record, "transport_request") is Some(command) &&
    supervisor_bridge_runtime_command_matches(
      command, payload, handoff, request_digest,
    ) else {
    return None
  }
  let phase = json_string(record, "phase", default="")
  if (
      phase == "forwarded" &&
      supervisor_bridge_saved_execution_response_valid(record)
    ) ||
    (
      phase == "claimed" &&
      json_string(handoff, "status", default="") == "claimed_for_transport" &&
      json_string(handoff, "claimed_by", default="") ==
      supervisor_bridge_transport_id()
    ) {
    Some(record)
  } else {
    None
  }
}

///|
async fn supervisor_bridge_saved_bookkeeper_round(
  workspace_root : String,
  target_id : String,
  request_digest : String,
  source_receipt_digest : String,
) -> Json? {
  guard supervisor_bridge_read_receipt(workspace_root, "bookkeeper", target_id)
    is Some(record) &&
    json_string(record, "request_digest", default="") == request_digest &&
    json_string(record, "source_receipt_digest", default="") ==
    source_receipt_digest &&
    json_string(record, "phase", default="") == "forwarded" &&
    json_object_field(record, "forwarded_receipt") is Some(_) else {
    return None
  }
  Some(record)
}

///|
async fn supervisor_bridge_reconciled_bookkeeper_receipt(
  workspace_root : String,
  target_id : String,
  request_digest : String,
  source_receipt_digest : String,
) -> Json? {
  guard supervisor_bridge_read_receipt(workspace_root, "bookkeeper", target_id)
    is Some(record) &&
    json_string(record, "request_digest", default="") == request_digest &&
    json_string(record, "phase", default="") == "reconciled" &&
    json_object_field(record, "forwarded_receipt") is Some(receipt) &&
    supervisor_bridge_digest(receipt) == source_receipt_digest else {
    return None
  }
  Some(receipt)
}

///|
async fn supervisor_bridge_bookkeeper_receipt_history(
  workspace_root : String,
  target_id : String,
  source_receipt_digest : String,
) -> Array[Json] {
  guard supervisor_bridge_read_receipt(workspace_root, "bookkeeper", target_id)
    is Some(record) else {
    return []
  }
  let history = json_array_items(record, "receipt_history")
  let previous_round = json_string(record, "source_receipt_digest", default="")
  if previous_round == "" || previous_round == source_receipt_digest {
    return history
  }
  guard json_object_field(record, "forwarded_receipt") is Some(receipt) else {
    return history
  }
  history.push({
    "source_receipt_digest": previous_round,
    "forwarded_receipt": receipt,
    "owner_receipt": json_object_field(record, "owner_receipt").unwrap_or(
      Json::null(),
    ),
    "phase": json_string(record, "phase", default=""),
  })
  history
}

///|
async fn supervisor_bridge_release_runtime(
  workspace_root : String,
  kind : String,
  target_id : String,
  expected_cursor : Int,
) -> Unit {
  ignore(
    moontown_owner_post_json(
      workspace_root,
      "/miniapp/outbox/runtime/release",
      {
        "kind": kind,
        "handoffId": target_id,
        "expectedCursor": expected_cursor,
      },
    ),
  )
}

///|
async fn supervisor_bridge_pump_activation(
  workspace_root : String,
  handoff : Json,
  expected_cursor : Int,
  daemon : Json,
) -> Json {
  let target_id = json_string(handoff, "handoff_id", default="")
  let request_digest = json_string(handoff, "request_digest", default="")
  let grant = match
    supervisor_bridge_materialized_grant(
      handoff, "activation", target_id, request_digest,
    ) {
    Ok(value) => value
    Err(error) =>
      return {
        "kind": "activation",
        "target_id": target_id,
        "status": "blocked",
        "request_digest": request_digest,
        "error": error,
      }
  }
  let claim = match
    moontown_owner_post_json(workspace_root, "/miniapp/outbox/runtime/claim", {
      "kind": "activation",
      "handoffId": target_id,
      "expectedCursor": expected_cursor,
      "evaluatedAt": json_string(grant, "evaluated_at", default=""),
      "authority": json_object_field(grant, "authority").unwrap_or(Json::null()),
    }) {
    Ok(value) => value
    Err(error) =>
      return {
        "kind": "activation",
        "target_id": target_id,
        "status": "claim_failed",
        "error": error,
      }
  }
  let claim_cursor = json_int(claim, "cursor", default=-1)
  let command = json_object_field(claim, "moonclawCommand").unwrap_or(
    Json::null(),
  )
  let request = match supervisor_bridge_activation_request(command) {
    Ok(value) => value
    Err(error) => {
      supervisor_bridge_release_runtime(
        workspace_root, "activation", target_id, claim_cursor,
      )
      return {
        "kind": "activation",
        "target_id": target_id,
        "status": "released",
        "error": error,
      }
    }
  }
  let saved_record = supervisor_bridge_saved_forwarded_record(
    workspace_root, "activation", target_id, request_digest,
  )
  let saved_receipt = match saved_record {
    Some(record) => json_object_field(record, "forwarded_receipt")
    None => None
  }
  let saved_response = match saved_record {
    Some(record) =>
      match json_object_field(record, "forwarded_response") {
        Some(response) => Some(response)
        None => saved_receipt
      }
    None => None
  }
  let evidence_grant = match saved_record {
    Some(record) =>
      json_object_field(record, "authority_grant").unwrap_or(grant)
    None => grant
  }
  let evidence_request = match saved_record {
    Some(record) =>
      json_object_field(record, "transport_request").unwrap_or(request)
    None => request
  }
  if saved_record is None {
    ignore(
      supervisor_bridge_write_receipt(workspace_root, {
        "contract_id": "moondesk.supervisor-bridge-receipt.v1",
        "kind": "activation",
        "target_id": target_id,
        "request_digest": request_digest,
        "phase": "claimed",
        "authority_grant": grant,
        "transport_request": request,
        "updated_at": @async.now().to_string(),
      }),
    )
  }
  let forwarded = match saved_response {
    Some(value) => Ok(value)
    None => moonclaw_post_json(daemon, "/v1/supervisors/activate", request)
  }
  let receipt = match forwarded {
    Ok(value) if supervisor_bridge_receipt_matches(
        value,
        json_string(command, "command_id", default=""),
        request_digest,
        json_string(
          json_object_field(request, "profile").unwrap_or(Json::null()),
          "supervisor_id",
          default="",
        ),
      ) => value
    Ok(_) => {
      supervisor_bridge_release_runtime(
        workspace_root, "activation", target_id, claim_cursor,
      )
      return {
        "kind": "activation",
        "target_id": target_id,
        "status": "released",
        "error": "MoonClaw returned a mismatched activation receipt",
      }
    }
    Err(error) => {
      supervisor_bridge_release_runtime(
        workspace_root, "activation", target_id, claim_cursor,
      )
      return {
        "kind": "activation",
        "target_id": target_id,
        "status": "released",
        "error": error,
      }
    }
  }
  ignore(
    supervisor_bridge_write_receipt(workspace_root, {
      "contract_id": "moondesk.supervisor-bridge-receipt.v1",
      "kind": "activation",
      "target_id": target_id,
      "request_digest": request_digest,
      "phase": "forwarded",
      "authority_grant": evidence_grant,
      "latest_claim_authority_grant": grant,
      "transport_request": evidence_request,
      "forwarded_receipt": receipt,
      "updated_at": @async.now().to_string(),
    }),
  )
  match
    moontown_owner_post_json(
      workspace_root,
      "/miniapp/outbox/runtime/reconcile",
      {
        "kind": "activation",
        "handoffId": target_id,
        "expectedCursor": claim_cursor,
        "receipt": receipt,
      },
    ) {
    Err(error) =>
      {
        "kind": "activation",
        "target_id": target_id,
        "status": "reconcile_pending",
        "error": error,
      }
    Ok(reconciled) => {
      ignore(
        supervisor_bridge_write_receipt(workspace_root, {
          "contract_id": "moondesk.supervisor-bridge-receipt.v1",
          "kind": "activation",
          "target_id": target_id,
          "request_digest": request_digest,
          "phase": "reconciled",
          "authority_grant": evidence_grant,
          "latest_claim_authority_grant": grant,
          "transport_request": evidence_request,
          "forwarded_receipt": receipt,
          "owner_receipt": reconciled,
          "updated_at": @async.now().to_string(),
        }),
      )
      {
        "kind": "activation",
        "target_id": target_id,
        "status": "reconciled",
        "receipt": reconciled,
      }
    }
  }
}

///|
async fn supervisor_bridge_pump_execution(
  workspace_root : String,
  handoff : Json,
  expected_cursor : Int,
  daemon : Json,
) -> Json {
  let target_id = json_string(handoff, "handoff_id", default="")
  let preview = match
    supervisor_bridge_execution_dispatch(handoff, workspace_root~) {
    Ok(value) => value
    Err(error) =>
      return {
        "kind": "execution",
        "target_id": target_id,
        "status": "blocked",
        "error": error,
      }
  }
  let grant = match
    supervisor_bridge_materialized_grant(
      handoff,
      "execution",
      target_id,
      preview.request_digest,
    ) {
    Ok(value) => value
    Err(error) =>
      return {
        "kind": "execution",
        "target_id": target_id,
        "status": "blocked",
        "request_digest": preview.request_digest,
        "moonclaw_endpoint": preview.endpoint,
        "error": error,
      }
  }
  let fresh_dispatch = match
    supervisor_bridge_execution_dispatch(handoff, grant~, workspace_root~) {
    Ok(value) if value.request_digest == preview.request_digest => value
    _ =>
      return {
        "kind": "execution",
        "target_id": target_id,
        "status": "blocked",
        "error": "Execution mapping changed while binding authority",
      }
  }
  let saved_record = supervisor_bridge_saved_execution_transport(
    workspace_root,
    handoff,
    preview.body,
    preview.request_digest,
  )
  let bound_request = match saved_record {
    Some(record) =>
      json_object_field(record, "transport_request").unwrap_or(Json::null())
    None =>
      match json_object_field(handoff, "runtime_command") {
        Some(command) =>
          if json_string(handoff, "status", default="") !=
            "claimed_for_transport" {
            fresh_dispatch.body
          } else if supervisor_bridge_runtime_command_matches(
              command,
              preview.body,
              handoff,
              preview.request_digest,
            ) {
            command
          } else {
            return {
              "kind": "execution",
              "target_id": target_id,
              "status": "blocked",
              "error": "Persisted Town runtime command is not the exact bound transport request",
            }
          }
        _ => fresh_dispatch.body
      }
  }
  let evidence_grant = match saved_record {
    Some(record) =>
      json_object_field(record, "authority_grant").unwrap_or_else(() => {
        supervisor_bridge_grant_from_runtime_command(grant, bound_request)
      })
    None if bound_request != fresh_dispatch.body =>
      supervisor_bridge_grant_from_runtime_command(grant, bound_request)
    None => grant
  }
  let claim = match
    moontown_owner_post_json(workspace_root, "/miniapp/outbox/runtime/claim", {
      "kind": "execution",
      "handoffId": target_id,
      "expectedCursor": expected_cursor,
      "sourceRequestDigest": json_string(handoff, "request_digest", default=""),
      "transportRequestDigest": preview.request_digest,
      "transportEndpoint": preview.endpoint,
      "transportRequest": preview.body,
      "runtimeCommand": bound_request,
    }) {
    Ok(value) => value
    Err(error) =>
      return {
        "kind": "execution",
        "target_id": target_id,
        "status": "claim_failed",
        "error": error,
      }
  }
  let claim_cursor = json_int(claim, "cursor", default=-1)
  let claimed = json_object_field(claim, "executionHandoff").unwrap_or_else(() => {
    json_object_field(claim, "moonclawDelegation").unwrap_or(Json::null())
  })
  if json_string(claimed, "handoff_id", default="") != target_id ||
    json_string(claimed, "request_digest", default="") !=
    json_string(handoff, "request_digest", default="") ||
    json_string(claimed, "transport_request_digest", default="") !=
    preview.request_digest ||
    json_string(claimed, "transport_endpoint", default="") != preview.endpoint ||
    json_object_field(claimed, "transport_request").unwrap_or(Json::null()) !=
    preview.body ||
    json_object_field(claimed, "runtime_command").unwrap_or(Json::null()) !=
    bound_request {
    supervisor_bridge_release_runtime(
      workspace_root, "execution", target_id, claim_cursor,
    )
    return {
      "kind": "execution",
      "target_id": target_id,
      "status": "released",
      "error": "Town did not durably bind the exact execution transport digest and endpoint",
    }
  }
  let claimed_preview = match
    supervisor_bridge_execution_dispatch(claimed, workspace_root~) {
    Ok(value) if value.request_digest == preview.request_digest &&
      value.endpoint == preview.endpoint &&
      value.body == preview.body => value
    _ => {
      supervisor_bridge_release_runtime(
        workspace_root, "execution", target_id, claim_cursor,
      )
      return {
        "kind": "execution",
        "target_id": target_id,
        "status": "released",
        "error": "Execution mapping changed while claiming",
      }
    }
  }
  if !supervisor_bridge_runtime_command_matches(
      bound_request,
      claimed_preview.body,
      claimed,
      claimed_preview.request_digest,
    ) {
    supervisor_bridge_release_runtime(
      workspace_root, "execution", target_id, claim_cursor,
    )
    return {
      "kind": "execution",
      "target_id": target_id,
      "status": "released",
      "error": "Town returned a runtime command with a mismatched envelope",
    }
  }
  let dispatch : SupervisorBridgeDispatch = {
    endpoint: claimed_preview.endpoint,
    request_digest: claimed_preview.request_digest,
    body: bound_request,
  }
  let command_id = json_string(claimed, "command_id", default="")
  let saved_receipt = match saved_record {
    Some(record) if json_string(record, "phase", default="") == "forwarded" =>
      json_object_field(record, "forwarded_receipt")
    None => None
    _ => None
  }
  let saved_response = match saved_record {
    Some(record) if json_string(record, "phase", default="") == "forwarded" =>
      match json_object_field(record, "forwarded_response") {
        Some(response) => Some(response)
        None => saved_receipt
      }
    None => None
    _ => None
  }
  let evidence_request = match saved_record {
    Some(record) =>
      json_object_field(record, "transport_request").unwrap_or(dispatch.body)
    None => dispatch.body
  }
  if saved_record is None {
    ignore(
      supervisor_bridge_write_receipt(workspace_root, {
        "contract_id": "moondesk.supervisor-bridge-receipt.v1",
        "kind": "execution",
        "target_id": target_id,
        "source_request_digest": json_string(
          claimed,
          "request_digest",
          default="",
        ),
        "request_digest": dispatch.request_digest,
        "transport_request_digest": dispatch.request_digest,
        "transport_endpoint": dispatch.endpoint,
        "operation_payload": preview.body,
        "phase": "claimed",
        "authority_grant": evidence_grant,
        "moonclaw_endpoint": dispatch.endpoint,
        "transport_request": evidence_request,
        "updated_at": @async.now().to_string(),
      }),
    )
  }
  if !supervisor_bridge_runtime_command_matches(
      evidence_request,
      claimed_preview.body,
      claimed,
      claimed_preview.request_digest,
    ) {
    supervisor_bridge_release_runtime(
      workspace_root, "execution", target_id, claim_cursor,
    )
    return {
      "kind": "execution",
      "target_id": target_id,
      "status": "released",
      "error": "Persisted execution request failed envelope/digest validation",
    }
  }
  let forwarded = match saved_response {
    Some(value) => Ok(value)
    None =>
      moonclaw_post_json(
        daemon,
        "/v1/supervisors/" +
        json_string(claimed, "supervisor_profile_id", default="") +
        "/commands/" +
        dispatch.endpoint,
        evidence_request,
      )
  }
  let (response, receipt) = match forwarded {
    Ok(value) => {
      let receipt = supervisor_bridge_execution_receipt(
        value,
        dispatch.endpoint,
      )
      if supervisor_bridge_receipt_matches(
          receipt,
          command_id,
          dispatch.request_digest,
          json_string(claimed, "supervisor_profile_id", default=""),
        ) {
        (value, receipt)
      } else {
        supervisor_bridge_release_runtime(
          workspace_root, "execution", target_id, claim_cursor,
        )
        return {
          "kind": "execution",
          "target_id": target_id,
          "status": "released",
          "error": "MoonClaw returned a mismatched execution receipt",
        }
      }
    }
    Err(error) => {
      supervisor_bridge_release_runtime(
        workspace_root, "execution", target_id, claim_cursor,
      )
      return {
        "kind": "execution",
        "target_id": target_id,
        "status": "released",
        "error": error,
      }
    }
  }
  ignore(
    supervisor_bridge_write_receipt(workspace_root, {
      "contract_id": "moondesk.supervisor-bridge-receipt.v1",
      "kind": "execution",
      "target_id": target_id,
      "source_request_digest": json_string(
        claimed,
        "request_digest",
        default="",
      ),
      "request_digest": dispatch.request_digest,
      "transport_request_digest": dispatch.request_digest,
      "transport_endpoint": dispatch.endpoint,
      "operation_payload": preview.body,
      "phase": "forwarded",
      "authority_grant": evidence_grant,
      "latest_claim_authority_grant": evidence_grant,
      "moonclaw_endpoint": dispatch.endpoint,
      "transport_request": evidence_request,
      "forwarded_response": response,
      "forwarded_receipt": receipt,
      "updated_at": @async.now().to_string(),
    }),
  )
  let town_receipt = if dispatch.endpoint == "delegate" {
    response
  } else {
    receipt
  }
  match
    moontown_owner_post_json(
      workspace_root,
      "/miniapp/outbox/runtime/reconcile",
      {
        "kind": "execution",
        "handoffId": target_id,
        "expectedCursor": claim_cursor,
        "receipt": town_receipt,
      },
    ) {
    Err(error) =>
      {
        "kind": "execution",
        "target_id": target_id,
        "status": "reconcile_pending",
        "error": error,
      }
    Ok(reconciled) => {
      ignore(
        supervisor_bridge_write_receipt(workspace_root, {
          "contract_id": "moondesk.supervisor-bridge-receipt.v1",
          "kind": "execution",
          "target_id": target_id,
          "source_request_digest": json_string(
            claimed,
            "request_digest",
            default="",
          ),
          "request_digest": dispatch.request_digest,
          "transport_request_digest": dispatch.request_digest,
          "transport_endpoint": dispatch.endpoint,
          "operation_payload": preview.body,
          "phase": "reconciled",
          "authority_grant": evidence_grant,
          "latest_claim_authority_grant": evidence_grant,
          "moonclaw_endpoint": dispatch.endpoint,
          "transport_request": evidence_request,
          "forwarded_response": response,
          "forwarded_receipt": receipt,
          "owner_receipt": reconciled,
          "updated_at": @async.now().to_string(),
        }),
      )
      {
        "kind": "execution",
        "target_id": target_id,
        "status": "reconciled",
        "receipt": reconciled,
      }
    }
  }
}

///|
async fn supervisor_bridge_moonbook_installed_root(
  workspace_root : String,
) -> Result[String, String] {
  guard configured_pack_app(workspace_root, "moonbook") is Some(_) else {
    return Err("MoonBook configured-pack owner service is unavailable")
  }
  let active_path = @pathx.join(
    active_packs_root(workspace_root),
    "moonbook.json",
  )
  let active = read_json_file_or_object(active_path)
  let root = json_string(active, "installed_root", default="")
  if root == "" ||
    !@fs.exists(@pathx.join(root, "cmd/moonflow_adapter/moon.pkg")) {
    return Err("MoonBook's installed pack lacks its outcome adapter")
  }
  Ok(root)
}

///|
fn supervisor_bridge_bookkeeper_receipt_matches(
  receipt : Json,
  submission : Json,
) -> Bool {
  let expected = json_object_field(submission, "submission").unwrap_or(
    Json::null(),
  )
  let actual = json_object_field(receipt, "submission").unwrap_or(Json::null())
  receipt is Object(_) &&
  json_string(receipt, "contract_version", default="") ==
  "moonbook.bookkeeper.product_outcome_submission_receipt.v1" &&
  json_string(actual, "record_id", default="") ==
  json_string(expected, "record_id", default="") &&
  json_string(actual, "record_version", default="") ==
  json_string(expected, "record_version", default="") &&
  json_string(actual, "record_digest", default="") ==
  json_string(expected, "record_digest", default="") &&
  [
    "deliverable_review_required", "assessment_review_required", "proposal_review_required",
    "closed_no_capability_change", "reviewed_proposal_handed_off", "deliverable_rejected",
    "assessment_rejected", "proposal_rejected",
  ].contains(json_string(receipt, "state", default="")) &&
  !json_bool(receipt, "activation_authorized", default=true) &&
  !json_bool(receipt, "external_side_effects_applied", default=true)
}

///|
async fn supervisor_bridge_submit_bookkeeper(
  workspace_root : String,
  target_id : String,
  submission : Json,
) -> Result[Json, String] {
  let installed_root = match
    supervisor_bridge_moonbook_installed_root(workspace_root) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let suite_root = moonsuite_root(workspace_root)
  let relative = ".moonsuite/products/moondesk/supervisor-bridge/submissions/" +
    supervisor_bridge_receipt_key("bookkeeper", target_id) +
    ".json"
  let absolute = @pathx.join(suite_root, relative)
  @fsx.make_directory(@pathx.dirname(absolute), recursive=true, exists_ok=true) catch {
    error => return Err("could not prepare MoonBook adapter input: \{error}")
  }
  if @fsx.exists(absolute) {
    let existing = @json.parse(@fsx.read_file(absolute)) catch {
      _ => return Err("persisted MoonBook adapter input is invalid")
    }
    if existing != submission {
      return Err("MoonBook adapter input identity has conflicting content")
    }
  } else {
    @fsx.write_to_file(
      absolute,
      submission.stringify(indent=2) + "\n",
      create=0o600,
    ) catch {
      error => return Err("could not persist MoonBook adapter input: \{error}")
    }
  }
  let moon = moonclaw_default_moon_command()
  let captured = @async.with_timeout_opt(30000, () => {
    run_process_capture(moon, [
      "-C", installed_root, "run", "cmd/moonflow_adapter", "--", "submit-product-outcome",
      "--workspace", suite_root, "--submission", relative,
    ])
  })
  guard captured is Some((code, stdout, stderr)) else {
    return Err("MoonBook outcome adapter timed out")
  }
  if code != 0 {
    let detail = if stderr.trim() == "" {
      stdout.trim().to_owned()
    } else {
      stderr.trim().to_owned()
    }
    return Err("MoonBook outcome adapter failed: " + detail)
  }
  let receipt = @json.parse(stdout.trim()) catch {
    _ => return Err("MoonBook outcome adapter returned invalid JSON")
  }
  if !supervisor_bridge_bookkeeper_receipt_matches(receipt, submission) {
    return Err("MoonBook outcome adapter returned a mismatched receipt")
  }
  Ok(receipt)
}

///|
async fn supervisor_bridge_pump_bookkeeper(
  workspace_root : String,
  request : Json,
  expected_cursor : Int,
) -> Json {
  let target_id = json_string(request, "request_id", default="")
  let preview_submission = json_object_field(
    request, "product_outcome_submission",
  ).unwrap_or(Json::null())
  let request_digest = supervisor_bridge_digest(preview_submission)
  let source_receipt = json_object_field(request, "bookkeeper_receipt").unwrap_or(
    Json::null(),
  )
  let source_receipt_digest = supervisor_bridge_digest(source_receipt)
  let pending_gate = supervisor_bridge_bookkeeper_pending_gate(request)
  let grant = match
    supervisor_bridge_materialized_grant(
      request, "bookkeeper", target_id, request_digest,
    ) {
    Ok(value) => value
    Err(error) =>
      return {
        "kind": "bookkeeper",
        "target_id": target_id,
        "status": "blocked",
        "request_digest": request_digest,
        "error": error,
      }
  }
  let preflight_receipt = match
    supervisor_bridge_reconciled_bookkeeper_receipt(
      workspace_root, target_id, request_digest, source_receipt_digest,
    ) {
    Some(_) =>
      match
        supervisor_bridge_submit_bookkeeper(
          workspace_root, target_id, preview_submission,
        ) {
        Ok(receipt) if supervisor_bridge_digest(receipt) ==
          source_receipt_digest =>
          return {
            "kind": "bookkeeper",
            "target_id": target_id,
            "status": "already_reconciled",
            "pending_gate": pending_gate,
            "receipt": receipt,
          }
        Ok(receipt) => Some(receipt)
        Err(error) =>
          return {
            "kind": "bookkeeper",
            "target_id": target_id,
            "status": "moonbook_unavailable",
            "pending_gate": pending_gate,
            "error": error,
          }
      }
    None => None
  }
  let claim = match
    moontown_owner_post_json(
      workspace_root,
      "/miniapp/outbox/bookkeeper/claim",
      { "requestId": target_id, "expectedCursor": expected_cursor },
    ) {
    Ok(value) => value
    Err(error) =>
      return {
        "kind": "bookkeeper",
        "target_id": target_id,
        "status": "claim_failed",
        "error": error,
      }
  }
  let claim_cursor = json_int(claim, "cursor", default=-1)
  let submission = json_object_field(claim, "submission").unwrap_or(
    Json::null(),
  )
  if supervisor_bridge_digest(submission) != request_digest ||
    json_string(claim, "operation", default="") != "bookkeeper.outcome.submit" {
    ignore(
      moontown_owner_post_json(
        workspace_root,
        "/miniapp/outbox/bookkeeper/release",
        { "requestId": target_id, "expectedCursor": claim_cursor },
      ),
    )
    return {
      "kind": "bookkeeper",
      "target_id": target_id,
      "status": "released",
      "error": "Town returned a mismatched Bookkeeper submission",
    }
  }
  let saved_record = supervisor_bridge_saved_bookkeeper_round(
    workspace_root, target_id, request_digest, source_receipt_digest,
  )
  let receipt_history = supervisor_bridge_bookkeeper_receipt_history(
    workspace_root, target_id, source_receipt_digest,
  )
  let saved_receipt = match saved_record {
    Some(record) => json_object_field(record, "forwarded_receipt")
    None => None
  }
  let evidence_grant = match saved_record {
    Some(record) =>
      json_object_field(record, "authority_grant").unwrap_or(grant)
    None => grant
  }
  let evidence_request = match saved_record {
    Some(record) =>
      json_object_field(record, "transport_request").unwrap_or(submission)
    None => submission
  }
  if saved_record is None {
    ignore(
      supervisor_bridge_write_receipt(workspace_root, {
        "contract_id": "moondesk.supervisor-bridge-receipt.v1",
        "kind": "bookkeeper",
        "target_id": target_id,
        "request_digest": request_digest,
        "source_receipt_digest": source_receipt_digest,
        "pending_gate": pending_gate,
        "phase": "claimed",
        "operation": "bookkeeper.outcome.submit",
        "authority_grant": grant,
        "transport_request": submission,
        "receipt_history": receipt_history,
        "updated_at": @async.now().to_string(),
      }),
    )
  }
  let forwarded = match saved_receipt {
    Some(value) => Ok(value)
    None =>
      match preflight_receipt {
        Some(value) => Ok(value)
        None =>
          supervisor_bridge_submit_bookkeeper(
            workspace_root, target_id, submission,
          )
      }
  }
  let receipt = match forwarded {
    Ok(value) => value
    Err(error) => {
      ignore(
        moontown_owner_post_json(
          workspace_root,
          "/miniapp/outbox/bookkeeper/release",
          { "requestId": target_id, "expectedCursor": claim_cursor },
        ),
      )
      return {
        "kind": "bookkeeper",
        "target_id": target_id,
        "status": "released",
        "error": error,
      }
    }
  }
  ignore(
    supervisor_bridge_write_receipt(workspace_root, {
      "contract_id": "moondesk.supervisor-bridge-receipt.v1",
      "kind": "bookkeeper",
      "target_id": target_id,
      "request_digest": request_digest,
      "source_receipt_digest": source_receipt_digest,
      "pending_gate": pending_gate,
      "phase": "forwarded",
      "operation": "bookkeeper.outcome.submit",
      "authority_grant": evidence_grant,
      "latest_claim_authority_grant": grant,
      "transport_request": evidence_request,
      "forwarded_receipt": receipt,
      "receipt_history": receipt_history,
      "updated_at": @async.now().to_string(),
    }),
  )
  match
    moontown_owner_post_json(
      workspace_root,
      "/miniapp/outbox/bookkeeper/reconcile",
      {
        "requestId": target_id,
        "expectedCursor": claim_cursor,
        "receipt": receipt,
      },
    ) {
    Err(error) =>
      {
        "kind": "bookkeeper",
        "target_id": target_id,
        "status": "reconcile_pending",
        "error": error,
      }
    Ok(reconciled) => {
      ignore(
        supervisor_bridge_write_receipt(workspace_root, {
          "contract_id": "moondesk.supervisor-bridge-receipt.v1",
          "kind": "bookkeeper",
          "target_id": target_id,
          "request_digest": request_digest,
          "source_receipt_digest": source_receipt_digest,
          "pending_gate": pending_gate,
          "phase": "reconciled",
          "operation": "bookkeeper.outcome.submit",
          "authority_grant": evidence_grant,
          "latest_claim_authority_grant": grant,
          "transport_request": evidence_request,
          "forwarded_receipt": receipt,
          "owner_receipt": reconciled,
          "receipt_history": receipt_history,
          "updated_at": @async.now().to_string(),
        }),
      )
      {
        "kind": "bookkeeper",
        "target_id": target_id,
        "status": "reconciled",
        "receipt": reconciled,
      }
    }
  }
}

///|
fn supervisor_bridge_observation_matches(
  status : Json,
  replay : Json,
  supervisor_id : String,
  after_cursor : Int,
) -> Int? {
  let state = json_object_field(status, "state").unwrap_or(Json::null())
  let runtime_cursor = json_int(state, "cursor", default=-1)
  if json_string(status, "contract_id", default="") !=
    "moonclaw.supervisor-status.v1" ||
    json_string(state, "contract_id", default="") !=
    "moonclaw.supervisor-state.v1" ||
    json_string(state, "supervisor_id", default="") != supervisor_id ||
    runtime_cursor < 0 ||
    json_string(replay, "contract_id", default="") !=
    "moonclaw.supervisor-replay.v1" ||
    json_string(replay, "supervisor_id", default="") != supervisor_id ||
    json_int(replay, "after_cursor", default=-1) != after_cursor ||
    json_int(replay, "next_cursor", default=-1) != runtime_cursor ||
    json_bool(replay, "has_more", default=true) {
    None
  } else {
    Some(runtime_cursor)
  }
}

///|
async fn supervisor_bridge_complete_replay(
  daemon : Json,
  supervisor_id : String,
  after_cursor : Int,
  target_cursor : Int,
) -> Result[Json, String] {
  let events : Array[Json] = []
  let mut page_after = after_cursor
  while true {
    let page = match
      moonclaw_get_json(
        daemon,
        "/v1/supervisors/" +
        supervisor_id +
        "/events?after_cursor=" +
        page_after.to_string() +
        "&limit=1000",
      ) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let page_next = json_int(page, "next_cursor", default=-1)
    if json_string(page, "contract_id", default="") !=
      "moonclaw.supervisor-replay.v1" ||
      json_string(page, "supervisor_id", default="") != supervisor_id ||
      json_int(page, "after_cursor", default=-1) != page_after ||
      page_next < page_after ||
      page_next > target_cursor {
      return Err("MoonClaw returned a discontinuous supervisor replay page")
    }
    for event in json_array_items(page, "events") {
      events.push(event)
    }
    if page_next == target_cursor {
      if json_bool(page, "has_more", default=true) {
        return Err("MoonClaw replay advanced beyond the observed status cursor")
      }
      return Ok({
        "contract_id": "moonclaw.supervisor-replay.v1",
        "supervisor_id": supervisor_id,
        "after_cursor": after_cursor,
        "next_cursor": target_cursor,
        "has_more": false,
        "events": events,
      })
    }
    if !json_bool(page, "has_more", default=false) || page_next == page_after {
      return Err("MoonClaw replay did not reach the observed status cursor")
    }
    page_after = page_next
  }
  Err("MoonClaw replay ended unexpectedly")
}

///|
async fn supervisor_bridge_reconcile_observation(
  workspace_root : String,
  supervisor_id : String,
  observation : Json,
  expected_cursor : Int,
) -> Json {
  let runtime_cursor = json_int(observation, "runtime_cursor", default=-1)
  let observation_digest = json_string(
    observation,
    "observation_digest",
    default="",
  )
  let reconciled = match
    moontown_owner_post_json(
      workspace_root,
      "/miniapp/runtime/observations/reconcile",
      {
        "supervisorId": supervisor_id,
        "expectedCursor": expected_cursor,
        "observation": observation,
      },
    ) {
    Ok(value) => value
    Err(error) =>
      return {
        "kind": "observation",
        "target_id": supervisor_id,
        "status": "reconcile_pending",
        "runtime_cursor": runtime_cursor,
        "town_cursor": expected_cursor,
        "error": error,
      }
  }
  if !json_bool(reconciled, "ok", default=false) ||
    json_string(reconciled, "supervisorId", default="") != supervisor_id ||
    json_int(reconciled, "runtimeCursor", default=-1) != runtime_cursor ||
    json_string(reconciled, "observationDigest", default="") !=
    observation_digest ||
    json_string(reconciled, "status", default="") != "reconciled" {
    return {
      "kind": "observation",
      "target_id": supervisor_id,
      "status": "reconcile_pending",
      "runtime_cursor": runtime_cursor,
      "town_cursor": expected_cursor,
      "error": "Town returned a mismatched runtime observation receipt",
    }
  }
  ignore(
    supervisor_bridge_write_receipt(workspace_root, {
      "contract_id": "moondesk.supervisor-bridge-receipt.v1",
      "kind": "observation",
      "target_id": supervisor_id,
      "request_digest": observation_digest,
      "runtime_cursor": runtime_cursor,
      "phase": "reconciled",
      "transport_request": observation,
      "owner_receipt": reconciled,
      "updated_at": @async.now().to_string(),
    }),
  )
  {
    "kind": "observation",
    "target_id": supervisor_id,
    "status": "reconciled",
    "runtime_cursor": runtime_cursor,
    "town_cursor": json_int(reconciled, "cursor", default=expected_cursor),
    "receipt": reconciled,
  }
}

///|
async fn supervisor_bridge_pump_observation(
  workspace_root : String,
  active : Json,
  expected_cursor : Int,
  daemon : Json,
) -> Json {
  let supervisor_id = json_string(active, "supervisor_id", default="")
  let previous = supervisor_bridge_read_receipt(
    workspace_root, "observation", supervisor_id,
  )
  match previous {
    Some(record) if json_string(record, "phase", default="") == "observed" => {
      let saved = json_object_field(record, "transport_request").unwrap_or(
        Json::null(),
      )
      return supervisor_bridge_reconcile_observation(
        workspace_root, supervisor_id, saved, expected_cursor,
      )
    }
    _ => ()
  }
  let after_cursor = match previous {
    Some(record) if json_string(record, "phase", default="") == "reconciled" =>
      json_int(record, "runtime_cursor", default=0)
    _ => 0
  }
  let has_reconciled_observation = match previous {
    Some(record) => json_string(record, "phase", default="") == "reconciled"
    None => false
  }
  let status = match
    moonclaw_get_json(daemon, "/v1/supervisors/" + supervisor_id + "/status") {
    Ok(value) => value
    Err(error) =>
      return {
        "kind": "observation",
        "target_id": supervisor_id,
        "status": "runtime_unavailable",
        "town_cursor": expected_cursor,
        "error": error,
      }
  }
  let state = json_object_field(status, "state").unwrap_or(Json::null())
  let current_cursor = json_int(state, "cursor", default=-1)
  if has_reconciled_observation && current_cursor == after_cursor {
    return {
      "kind": "observation",
      "target_id": supervisor_id,
      "status": "already_observed",
      "runtime_cursor": current_cursor,
      "town_cursor": expected_cursor,
    }
  }
  if current_cursor < after_cursor {
    return {
      "kind": "observation",
      "target_id": supervisor_id,
      "status": "blocked",
      "town_cursor": expected_cursor,
      "error": "MoonClaw supervisor cursor regressed",
    }
  }
  let replay = match
    supervisor_bridge_complete_replay(
      daemon, supervisor_id, after_cursor, current_cursor,
    ) {
    Ok(value) => value
    Err(error) =>
      return {
        "kind": "observation",
        "target_id": supervisor_id,
        "status": "runtime_unavailable",
        "town_cursor": expected_cursor,
        "error": error,
      }
  }
  guard supervisor_bridge_observation_matches(
      status, replay, supervisor_id, after_cursor,
    )
    is Some(runtime_cursor) else {
    return {
      "kind": "observation",
      "target_id": supervisor_id,
      "status": "blocked",
      "town_cursor": expected_cursor,
      "error": "MoonClaw returned a non-exact or incomplete runtime observation",
    }
  }
  let canonical : Json = {
    "supervisor_id": supervisor_id,
    "runtime_cursor": runtime_cursor,
    "status_projection": status,
    "event_replay": replay,
  }
  let observation_digest = supervisor_bridge_digest(canonical)
  let observation : Json = {
    "contract_id": "moonsuite.supervisor-runtime-observation.v1",
    "supervisor_id": supervisor_id,
    "runtime_cursor": runtime_cursor,
    "observation_digest": observation_digest,
    "status_projection": status,
    "event_replay": replay,
  }
  ignore(
    supervisor_bridge_write_receipt(workspace_root, {
      "contract_id": "moondesk.supervisor-bridge-receipt.v1",
      "kind": "observation",
      "target_id": supervisor_id,
      "request_digest": observation_digest,
      "runtime_cursor": runtime_cursor,
      "phase": "observed",
      "transport_request": observation,
      "updated_at": @async.now().to_string(),
    }),
  )
  supervisor_bridge_reconcile_observation(
    workspace_root, supervisor_id, observation, expected_cursor,
  )
}

///|
async fn supervisor_bridge_grant_and_sync(workspace_root : String) -> Json {
  supervisor_bridge_mutex.acquire()
  defer supervisor_bridge_mutex.release()
  let results : Array[Json] = []
  let first = match supervisor_bridge_outboxes(workspace_root) {
    Ok(value) => value
    Err(error) =>
      return {
        "ok": false,
        "contract_id": "moondesk.supervisor-bridge-sync.v1",
        "status": "moontown_unavailable",
        "message": error,
        "results": [],
      }
  }
  let (runtime, bookkeeper) = first
  let requirements = supervisor_bridge_requirements(
    workspace_root, runtime, bookkeeper,
  )
  let active = supervisor_bridge_active_activations(runtime)
  if requirements.is_empty() && active.is_empty() {
    return {
      "ok": true,
      "contract_id": "moondesk.supervisor-bridge-sync.v1",
      "status": "sync_complete",
      "transport_id": supervisor_bridge_transport_id(),
      "result_count": 0,
      "failure_count": 0,
      "results": [],
    }
  }
  let needs_moonclaw = !active.is_empty() ||
    requirements.any(fn(requirement) {
      json_string(requirement, "kind", default="") != "bookkeeper"
    })
  let daemon = if needs_moonclaw {
    ensure_moonclaw_daemon_running(workspace_root, action="start")
  } else {
    { "running": true }
  }
  if needs_moonclaw && !json_bool(daemon, "running", default=false) {
    return {
      "ok": false,
      "contract_id": "moondesk.supervisor-bridge-sync.v1",
      "status": "moonclaw_unavailable",
      "message": json_string(
        daemon,
        "message",
        default="MoonClaw supervisor runtime is unavailable",
      ),
      "results": [],
    }
  }
  let mut cursor = json_int(runtime, "cursor", default=-1)
  for handoff in supervisor_bridge_latest_activation_handoffs(runtime) {
    let status = json_string(handoff, "status", default="")
    if status == "pending_transport" ||
      status == "runtime_failed" ||
      (
        status == "claimed_for_transport" &&
        json_string(handoff, "claimed_by", default="") ==
        supervisor_bridge_transport_id()
      ) {
      let result = supervisor_bridge_pump_activation(
        workspace_root, handoff, cursor, daemon,
      )
      results.push(result)
      match supervisor_bridge_outboxes(workspace_root) {
        Ok((next_runtime, _)) =>
          cursor = json_int(next_runtime, "cursor", default=cursor)
        Err(_) => ()
      }
    }
  }
  for handoff in supervisor_bridge_latest_execution_handoffs(runtime) {
    let status = json_string(handoff, "status", default="")
    if status == "pending_transport" ||
      status == "runtime_failed" ||
      (
        status == "claimed_for_transport" &&
        json_string(handoff, "claimed_by", default="") ==
        supervisor_bridge_transport_id()
      ) {
      let result = supervisor_bridge_pump_execution(
        workspace_root, handoff, cursor, daemon,
      )
      results.push(result)
      match supervisor_bridge_outboxes(workspace_root) {
        Ok((next_runtime, _)) =>
          cursor = json_int(next_runtime, "cursor", default=cursor)
        Err(_) => ()
      }
    }
  }
  cursor = json_int(bookkeeper, "cursor", default=cursor).max(cursor)
  for request in supervisor_bridge_latest_bookkeeper_requests(bookkeeper) {
    let state = json_string(request, "state", default="")
    if supervisor_bridge_bookkeeper_state_claimable(state) &&
      (
        state != "claimed_for_transport" ||
        json_string(request, "claimed_by", default="") ==
        supervisor_bridge_transport_id()
      ) {
      let result = supervisor_bridge_pump_bookkeeper(
        workspace_root, request, cursor,
      )
      results.push(result)
      match supervisor_bridge_outboxes(workspace_root) {
        Ok((next_runtime, _)) =>
          cursor = json_int(next_runtime, "cursor", default=cursor)
        Err(_) => ()
      }
    }
  }
  match supervisor_bridge_outboxes(workspace_root) {
    Ok((observation_runtime, _)) => {
      cursor = json_int(observation_runtime, "cursor", default=cursor)
      for
        activation in supervisor_bridge_active_activations(observation_runtime) {
        let result = supervisor_bridge_pump_observation(
          workspace_root, activation, cursor, daemon,
        )
        cursor = json_int(result, "town_cursor", default=cursor)
        results.push(result)
      }
    }
    Err(error) =>
      results.push({
        "kind": "observation",
        "target_id": "runtime-outbox",
        "status": "reconcile_pending",
        "town_cursor": cursor,
        "error": error,
      })
  }
  let failures = results
    .filter(item => {
      json_string(item, "status", default="") != "reconciled" &&
      json_string(item, "status", default="") != "already_reconciled" &&
      json_string(item, "status", default="") != "already_observed"
    })
    .length()
  {
    "ok": failures == 0,
    "contract_id": "moondesk.supervisor-bridge-sync.v1",
    "status": if failures == 0 {
      "sync_complete"
    } else {
      "sync_incomplete"
    },
    "transport_id": supervisor_bridge_transport_id(),
    "result_count": results.length(),
    "failure_count": failures,
    "results": results,
  }
}

///|
fn supervisor_bridge_last_result_receipt(
  result : Json,
  previous : Json,
) -> Json {
  let mut last = previous
  for item in json_array_items(result, "results") {
    match json_object_field(item, "receipt") {
      Some(receipt) => last = receipt
      None => ()
    }
  }
  last
}

///|
async fn supervisor_bridge_auto_pump(active_root : Ref[String]) -> Unit {
  let mut delay_ms = 2000
  while true {
    let workspace_root = active_root.val
    let previous = supervisor_bridge_read_auto_status(workspace_root)
    let previous_receipt = json_object_field(previous, "last_receipt").unwrap_or(
      Json::null(),
    )
    let checked_at_ms = @async.now().to_string()
    match supervisor_bridge_outboxes(workspace_root) {
      Err(error) => {
        delay_ms = (delay_ms * 2).min(30000)
        supervisor_bridge_write_auto_status(workspace_root, {
          "contract_id": "moondesk.supervisor-bridge-auto-pump.v1",
          "enabled": true,
          "status": "moontown_unavailable",
          "workspace_root": workspace_root,
          "base_interval_ms": 2000,
          "next_interval_ms": delay_ms,
          "max_backoff_ms": 30000,
          "last_checked_at_ms": checked_at_ms,
          "message": error,
          "last_receipt": previous_receipt,
        })
      }
      Ok((runtime, bookkeeper)) => {
        let requirements = supervisor_bridge_requirements(
          workspace_root, runtime, bookkeeper,
        )
        let active = supervisor_bridge_active_activations(runtime)
        if requirements.is_empty() && active.is_empty() {
          delay_ms = 2000
          supervisor_bridge_write_auto_status(workspace_root, {
            "contract_id": "moondesk.supervisor-bridge-auto-pump.v1",
            "enabled": true,
            "status": "idle",
            "workspace_root": workspace_root,
            "base_interval_ms": 2000,
            "next_interval_ms": delay_ms,
            "max_backoff_ms": 30000,
            "last_checked_at_ms": checked_at_ms,
            "pending_count": 0,
            "active_supervisor_count": 0,
            "last_receipt": previous_receipt,
          })
        } else {
          let result = supervisor_bridge_grant_and_sync(workspace_root)
          if json_bool(result, "ok", default=false) {
            delay_ms = 2000
          } else {
            delay_ms = (delay_ms * 2).min(30000)
          }
          supervisor_bridge_write_auto_status(workspace_root, {
            "contract_id": "moondesk.supervisor-bridge-auto-pump.v1",
            "enabled": true,
            "status": if json_bool(result, "ok", default=false) {
              "sync_complete"
            } else {
              "sync_incomplete"
            },
            "workspace_root": workspace_root,
            "base_interval_ms": 2000,
            "next_interval_ms": delay_ms,
            "max_backoff_ms": 30000,
            "last_checked_at_ms": checked_at_ms,
            "pending_count": requirements.length(),
            "active_supervisor_count": active.length(),
            "last_result": result,
            "last_receipt": supervisor_bridge_last_result_receipt(
              result, previous_receipt,
            ),
          })
        }
      }
    }
    @async.sleep(delay_ms)
  }
}

///|
async fn handle_supervisor_bridge_status(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  send_json(conn, method_, supervisor_bridge_status(workspace_root))
}

///|
async fn handle_supervisor_bridge_sync(
  workspace_root : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  guard read_json_body(body) is Some(Object(_)) else {
    send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
    return
  }
  let result = supervisor_bridge_grant_and_sync(workspace_root)
  send_json(conn, method_, result)
}

///|
async fn handle_supervisor_bridge_receipt(
  workspace_root : String,
  kind : String,
  target_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  if !["activation", "execution", "bookkeeper", "observation"].contains(kind) ||
    !moonclaw_supervisor_id_allowed(target_id) {
    send_api_error(
      conn, method_, 400, "Bad Request", "Invalid bridge receipt identity",
    )
    return
  }
  match supervisor_bridge_read_receipt(workspace_root, kind, target_id) {
    Some(receipt) => send_json(conn, method_, receipt)
    None =>
      send_api_error(
        conn, method_, 404, "Not Found", "Bridge receipt not found",
      )
  }
}
