///|
priv struct MoonFlowOperatorActionDefinition {
  action_id : String
  label : String
  summary : String
  status : String
  enabled : Bool
  host_config : String
  handoff_template : String
}

///|
priv struct MoonFlowOperatorActionCatalog {
  run_id : String
  actions : Array[MoonFlowOperatorActionDefinition]
}

///|
fn moonflow_action_safe_id(value : String) -> Bool {
  !value.is_empty() &&
  value.length() <= 96 &&
  value
  .iter()
  .all(char => {
    (char >= 'a' && char <= 'z') ||
    (char >= 'A' && char <= 'Z') ||
    (char >= '0' && char <= '9') ||
    char == '-' ||
    char == '_'
  })
}

///|
fn moonflow_action_strict_object(
  value : Json,
  allowed : Array[String],
) -> Map[String, Json]? {
  guard value is Object(fields) else { return None }
  for key, _ in fields {
    if !allowed.contains(key) {
      return None
    }
  }
  Some(fields)
}

///|
fn moonflow_action_required_string(
  fields : Map[String, Json],
  key : String,
) -> String? {
  match fields.get(key) {
    Some(String(value)) if !value.trim().is_empty() => Some(value)
    _ => None
  }
}

///|
fn moonflow_action_required_bool(
  fields : Map[String, Json],
  key : String,
) -> Bool? {
  match fields.get(key) {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => None
  }
}

///|
fn moonflow_action_relative_file(value : String) -> String? {
  if value.has_prefix("/") ||
    value.contains("\\") ||
    value.contains("..") ||
    value.iter().any(char => char.is_control()) {
    return None
  }
  match clean_relative_path(value) {
    Some(relative) if relative == value && !relative.has_suffix("/") =>
      Some(relative)
    _ => None
  }
}

///|
fn decode_moonflow_operator_action(
  value : Json,
) -> MoonFlowOperatorActionDefinition? {
  guard moonflow_action_strict_object(value, [
      "action_id", "label", "summary", "status", "enabled", "host_config", "handoff_template",
    ])
    is Some(fields) else {
    return None
  }
  guard moonflow_action_required_string(fields, "action_id") is Some(action_id) &&
    moonflow_action_required_string(fields, "label") is Some(label) &&
    moonflow_action_required_string(fields, "summary") is Some(summary) &&
    moonflow_action_required_string(fields, "status") is Some(status) &&
    moonflow_action_required_bool(fields, "enabled") is Some(enabled) &&
    moonflow_action_required_string(fields, "host_config") is Some(host_config) &&
    moonflow_action_required_string(fields, "handoff_template")
    is Some(handoff_template) else {
    return None
  }
  if !moonflow_action_safe_id(action_id) ||
    !["available", "stale", "rejected", "unavailable"].contains(status) ||
    (enabled && status != "available") ||
    moonflow_action_relative_file(host_config) is None ||
    moonflow_action_relative_file(handoff_template) is None {
    return None
  }
  Some({
    action_id,
    label,
    summary,
    status,
    enabled,
    host_config,
    handoff_template,
  })
}

///|
fn decode_moonflow_operator_action_catalog(
  value : Json,
  expected_run_id : String,
) -> MoonFlowOperatorActionCatalog? {
  guard moonflow_action_strict_object(value, [
      "contract_id", "contract_version", "run_id", "actions",
    ])
    is Some(fields) else {
    return None
  }
  guard moonflow_action_required_string(fields, "contract_id")
    is Some(contract_id) &&
    moonflow_action_required_string(fields, "contract_version")
    is Some(contract_version) &&
    moonflow_action_required_string(fields, "run_id") is Some(run_id) &&
    fields.get("actions") is Some(Array(values)) else {
    return None
  }
  if contract_id != "moonflow.operator-actions.v1" ||
    contract_version != "1.0.0" ||
    run_id != expected_run_id {
    return None
  }
  let actions : Array[MoonFlowOperatorActionDefinition] = []
  for value in values {
    guard decode_moonflow_operator_action(value) is Some(action) else {
      return None
    }
    if actions.any(existing => existing.action_id == action.action_id) {
      return None
    }
    actions.push(action)
  }
  Some({ run_id, actions })
}

///|
fn moonflow_operator_action_public_json(
  action : MoonFlowOperatorActionDefinition,
) -> Json {
  {
    "action_id": action.action_id,
    "label": action.label,
    "summary": action.summary,
    "status": action.status,
    "enabled": action.enabled,
  }
}

///|
fn moonflow_operator_actions_response(
  run_id : String,
  status : String,
  actions : Array[MoonFlowOperatorActionDefinition],
) -> Json {
  {
    "contract_id": "moondesk.moonflow-operator-actions.v1",
    "contract_version": "1.0.0",
    "run_id": run_id,
    "status": status,
    "actions": [
      for action in actions => moonflow_operator_action_public_json(action)
    ],
  }
}

///|
async fn moonflow_operator_action_catalog(
  run_root : String,
  run_id : String,
) -> MoonFlowOperatorActionCatalog? {
  let path = @pathx.join(run_root, "operator-actions.json")
  if !@fs.exists(path) {
    return None
  }
  let json = @json.parse(@fs.read_file(path).text()) catch { _ => return None }
  decode_moonflow_operator_action_catalog(json, run_id)
}

///|
async fn handle_moonflow_operator_actions(
  workspace_root : String,
  run_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  if !moonflow_safe_run_id(run_id) {
    send_api_error(conn, method_, 400, "Bad Request", "Invalid MoonFlow run id")
    return
  }
  let run_root = @pathx.join(moonflow_runs_root(workspace_root), run_id)
  if !@fs.exists(@pathx.join(run_root, "projection.json")) {
    send_api_error(conn, method_, 404, "Not Found", "MoonFlow run not found")
    return
  }
  match moonflow_operator_action_catalog(run_root, run_id) {
    Some(catalog) =>
      send_json(
        conn,
        method_,
        moonflow_operator_actions_response(
          catalog.run_id,
          "available",
          catalog.actions,
        ),
      )
    None =>
      send_json(
        conn,
        method_,
        moonflow_operator_actions_response(run_id, "unavailable", []),
      )
  }
}

///|
fn moonflow_sanitized_record_ref(value : Json) -> Json {
  guard moonflow_action_strict_object(value, ["kind", "id", "version", "digest"])
    is Some(fields) else {
    return Json::null()
  }
  guard moonflow_action_required_string(fields, "kind") is Some(kind) &&
    moonflow_action_required_string(fields, "id") is Some(id) &&
    moonflow_action_required_string(fields, "version") is Some(version) &&
    moonflow_action_required_string(fields, "digest") is Some(digest) else {
    return Json::null()
  }
  { "kind": kind, "id": id, "version": version, "digest": digest }
}

///|
fn moonflow_sanitized_receipt(
  run_id : String,
  action_id : String,
  value : Json,
) -> Json? {
  guard moonflow_action_strict_object(value, [
      "contract_id", "contract_version", "operation", "status", "effect_executed",
      "record_persisted", "record_ref", "unsupported_fields", "source_digest",
    ])
    is Some(fields) else {
    return None
  }
  guard moonflow_action_required_string(fields, "contract_id")
    is Some(contract_id) &&
    moonflow_action_required_string(fields, "contract_version")
    is Some(contract_version) &&
    moonflow_action_required_string(fields, "operation") is Some(operation) &&
    moonflow_action_required_string(fields, "status") is Some(status) &&
    moonflow_action_required_bool(fields, "effect_executed")
    is Some(effect_executed) &&
    moonflow_action_required_bool(fields, "record_persisted")
    is Some(record_persisted) &&
    fields.get("record_ref") is Some(record_ref) &&
    fields.get("unsupported_fields") is Some(Array(unsupported_values)) &&
    moonflow_action_required_string(fields, "source_digest")
    is Some(source_digest) else {
    return None
  }
  if contract_id != "moonflow.pack-host-receipt.v1" ||
    contract_version != "1.0.0" ||
    effect_executed {
    return None
  }
  let unsupported : Array[String] = []
  for item in unsupported_values {
    guard item is String(text) else { return None }
    unsupported.push(text)
  }
  Some({
    "contract_id": "moondesk.moonflow-action-receipt.v1",
    "contract_version": "1.0.0",
    "run_id": run_id,
    "action_id": action_id,
    "operation": operation,
    "status": status,
    "effect_executed": false,
    "record_persisted": record_persisted,
    "record_ref": match record_ref {
      Null => Json::null()
      _ => moonflow_sanitized_record_ref(record_ref)
    },
    "unsupported_fields": unsupported,
    "source_digest": source_digest,
  })
}

///|
async fn handle_moonflow_operator_action(
  workspace_root : String,
  run_id : String,
  action_id : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  if !moonflow_safe_run_id(run_id) || !moonflow_action_safe_id(action_id) {
    send_api_error(conn, method_, 400, "Bad Request", "Invalid MoonFlow action")
    return
  }
  guard read_json_body(body) is Some(Object(body_fields)) &&
    body_fields.is_empty() else {
    send_api_error(
      conn, method_, 400, "Bad Request", "MoonFlow actions accept no client-supplied authority or paths",
    )
    return
  }
  let run_root = @pathx.join(moonflow_runs_root(workspace_root), run_id)
  guard moonflow_operator_action_catalog(run_root, run_id) is Some(catalog) else {
    send_api_error(
      conn, method_, 409, "Conflict", "Operator actions unavailable",
    )
    return
  }
  let mut selected : MoonFlowOperatorActionDefinition? = None
  for candidate in catalog.actions {
    if candidate.action_id == action_id {
      selected = Some(candidate)
    }
  }
  guard selected is Some(action) else {
    send_api_error(conn, method_, 404, "Not Found", "MoonFlow action not found")
    return
  }
  if !action.enabled || action.status != "available" {
    send_json(conn, method_, {
      "contract_id": "moondesk.moonflow-action-receipt.v1",
      "contract_version": "1.0.0",
      "run_id": run_id,
      "action_id": action_id,
      "operation": "operator-command",
      "status": action.status,
      "effect_executed": false,
      "record_persisted": false,
      "record_ref": Json::null(),
      "unsupported_fields": [],
      "source_digest": "",
    })
    return
  }
  guard moonflow_action_relative_file(action.host_config)
    is Some(config_relative) &&
    moonflow_action_relative_file(action.handoff_template)
    is Some(handoff_relative) else {
    send_api_error(conn, method_, 409, "Conflict", "Invalid action definition")
    return
  }
  let config_path = @pathx.join(run_root, config_relative)
  let handoff_path = @pathx.join(run_root, handoff_relative)
  if !@fs.exists(config_path) || !@fs.exists(handoff_path) {
    send_api_error(conn, method_, 409, "Conflict", "Action inputs unavailable")
    return
  }
  let moonflow_root = @sys.get_env_var("MOONFLOW_ROOT").unwrap_or("")
  if moonflow_root == "" || !@fs.exists(@pathx.join(moonflow_root, "moon.mod")) {
    send_api_error(
      conn, method_, 503, "Service Unavailable", "MoonFlow host unavailable",
    )
    return
  }
  let moon = moonclaw_default_moon_command()
  let captured = @async.with_timeout_opt(30000, () => {
    run_process_capture(moon, [
      "-C", moonflow_root, "run", "cmd/main", "--", "commit-pack-handoff", config_path,
      handoff_path,
    ])
  })
  guard captured is Some((code, stdout, _)) else {
    send_api_error(
      conn, method_, 504, "Gateway Timeout", "MoonFlow action timed out",
    )
    return
  }
  if code != 0 {
    send_api_error(
      conn, method_, 409, "Conflict", "MoonFlow rejected the action",
    )
    return
  }
  let receipt_json = @json.parse(stdout.trim()) catch {
    _ => {
      send_api_error(
        conn, method_, 502, "Bad Gateway", "Invalid MoonFlow receipt",
      )
      return
    }
  }
  guard moonflow_sanitized_receipt(run_id, action_id, receipt_json)
    is Some(receipt) else {
    send_api_error(
      conn, method_, 502, "Bad Gateway", "Invalid MoonFlow receipt",
    )
    return
  }
  send_json(conn, method_, receipt)
}
