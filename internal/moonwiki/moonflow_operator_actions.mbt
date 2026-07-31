///|

///|
priv struct MoonFlowOperatorEvidenceRefDefinition {
  kind : String
  reference : String
  digest : String
}

///|
priv struct MoonFlowOperatorAppEntrypointDefinition {
  kind : String
  pack_id : String
  entrypoint_id : String
  path : String
  fallback_path : String
}

///|
priv struct MoonFlowOperatorReceiverDefinition {
  handoff_token : String
  handoff_digest : String
  request_id : String
  attempt_id : String
  idempotency_key : String
  intake_path : String
  status_path : String
  receipt_path : String
  return_path : String
  status : String
  receipt_ref : String
  receipt_digest : String
  receipt_recorded_at : String
}

///|
priv struct MoonFlowOperatorActionDefinition {
  action_id : String
  action_kind : String
  label : String
  summary : String
  status : String
  enabled : Bool
  host_config : String
  handoff_template : String
  run_id : String
  work_item_id : String
  declaration_id : String
  product_id : String
  operation : String
  requested_authority : String
  authority_status : String
  claim_ceiling : String
  capability_status : String
  input_contracts : Array[String]
  output_contracts : Array[String]
  evidence_refs : Array[MoonFlowOperatorEvidenceRefDefinition]
  review_required : Bool
  review_status : String
  acceptance_criteria : Array[String]
  handoff_ref : String
  receiver : MoonFlowOperatorReceiverDefinition
  app_entrypoint : MoonFlowOperatorAppEntrypointDefinition
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
fn moonflow_action_string_array(
  fields : Map[String, Json],
  key : String,
  allow_empty : Bool,
) -> Array[String]? {
  guard fields.get(key) is Some(Array(values)) else { return None }
  let result : Array[String] = []
  for value in values {
    guard value is String(text) && !text.trim().is_empty() else { return None }
    result.push(text)
  }
  if !allow_empty && result.is_empty() {
    None
  } else {
    Some(result)
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
fn decode_moonflow_operator_action_v1(
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
    action_kind: "operator-command",
    label,
    summary,
    status,
    enabled,
    host_config,
    handoff_template,
    run_id: "",
    work_item_id: "",
    declaration_id: "",
    product_id: "",
    operation: "",
    requested_authority: "",
    authority_status: "",
    claim_ceiling: "",
    capability_status: "",
    input_contracts: [],
    output_contracts: [],
    evidence_refs: [],
    review_required: false,
    review_status: "",
    acceptance_criteria: [],
    handoff_ref: "",
    receiver: {
      handoff_token: "",
      handoff_digest: "",
      request_id: "",
      attempt_id: "",
      idempotency_key: "",
      intake_path: "",
      status_path: "",
      receipt_path: "",
      return_path: "",
      status: "",
      receipt_ref: "",
      receipt_digest: "",
      receipt_recorded_at: "",
    },
    app_entrypoint: {
      kind: "",
      pack_id: "",
      entrypoint_id: "",
      path: "",
      fallback_path: "",
    },
  })
}

///|
fn decode_moonflow_operator_evidence_refs(
  fields : Map[String, Json],
) -> Array[MoonFlowOperatorEvidenceRefDefinition]? {
  guard fields.get("evidence_refs") is Some(Array(values)) else { return None }
  let refs : Array[MoonFlowOperatorEvidenceRefDefinition] = []
  for value in values {
    guard moonflow_action_strict_object(value, ["kind", "reference", "digest"])
      is Some(item_fields) &&
      moonflow_action_required_string(item_fields, "kind") is Some(kind) &&
      moonflow_action_required_string(item_fields, "reference")
      is Some(reference) &&
      item_fields.get("digest") is Some(String(digest)) else {
      return None
    }
    if moonflow_action_relative_file(reference) is None {
      return None
    }
    refs.push({ kind, reference, digest })
  }
  Some(refs)
}

///|
fn decode_moonflow_operator_entrypoint(
  fields : Map[String, Json],
) -> MoonFlowOperatorAppEntrypointDefinition? {
  guard fields.get("app_entrypoint") is Some(value) &&
    moonflow_action_strict_object(value, [
      "kind", "pack_id", "entrypoint_id", "path", "fallback_path",
    ])
    is Some(entrypoint_fields) &&
    moonflow_action_required_string(entrypoint_fields, "kind") is Some(kind) &&
    moonflow_action_required_string(entrypoint_fields, "pack_id")
    is Some(pack_id) &&
    entrypoint_fields.get("entrypoint_id") is Some(String(entrypoint_id)) &&
    moonflow_action_required_string(entrypoint_fields, "path") is Some(path) &&
    entrypoint_fields.get("fallback_path") is Some(String(fallback_path)) else {
    return None
  }
  if kind != "pack-manifest" ||
    !moonflow_action_safe_id(pack_id) ||
    path != "/pack-apps/" + pack_id + "/" ||
    fallback_path != "" {
    return None
  }
  Some({ kind, pack_id, entrypoint_id, path, fallback_path })
}

///|
fn moonflow_receiver_token_is_safe(value : String) -> Bool {
  value.length() == 64 &&
  value
  .iter()
  .all(char => (char >= '0' && char <= '9') || (char >= 'a' && char <= 'f'))
}

///|
fn decode_moonflow_operator_receiver(
  fields : Map[String, Json],
  run_id : String,
) -> MoonFlowOperatorReceiverDefinition? {
  guard fields.get("receiver") is Some(value) &&
    moonflow_action_strict_object(value, [
      "handoff_token", "handoff_digest", "request_id", "attempt_id", "idempotency_key",
      "intake_path", "status_path", "receipt_path", "return_path", "status", "receipt_ref",
      "receipt_digest", "receipt_recorded_at",
    ])
    is Some(receiver) &&
    moonflow_action_required_string(receiver, "handoff_token") is Some(token) &&
    moonflow_action_required_string(receiver, "handoff_digest") is Some(digest) &&
    moonflow_action_required_string(receiver, "request_id") is Some(request_id) &&
    moonflow_action_required_string(receiver, "attempt_id") is Some(attempt_id) &&
    moonflow_action_required_string(receiver, "idempotency_key")
    is Some(idempotency_key) &&
    moonflow_action_required_string(receiver, "intake_path")
    is Some(intake_path) &&
    moonflow_action_required_string(receiver, "status_path")
    is Some(status_path) &&
    moonflow_action_required_string(receiver, "receipt_path")
    is Some(receipt_path) &&
    moonflow_action_required_string(receiver, "return_path")
    is Some(return_path) &&
    moonflow_action_required_string(receiver, "status") is Some(status) &&
    receiver.get("receipt_ref") is Some(String(receipt_ref)) &&
    receiver.get("receipt_digest") is Some(String(receipt_digest)) &&
    receiver.get("receipt_recorded_at") is Some(String(receipt_recorded_at)) else {
    return None
  }
  let endpoint = "/api/moonflow/runs/" + run_id + "/handoffs/" + token
  if !moonflow_receiver_token_is_safe(token) ||
    digest != "sha256:" + token ||
    request_id != "receiver-request-" + token[0:24].to_owned() ||
    attempt_id != "receiver-attempt-" + token[0:24].to_owned() ||
    idempotency_key != "receiver-" + token ||
    intake_path != endpoint ||
    status_path != endpoint + "/status" ||
    receipt_path != endpoint + "/receipt" ||
    return_path != "/?activity=flow" ||
    !["pending", "accepted", "denied", "stale"].contains(status) ||
    (
      status == "pending" &&
      (receipt_ref != "" || receipt_digest != "" || receipt_recorded_at != "")
    ) ||
    (
      ["accepted", "denied"].contains(status) &&
      (
        moonflow_action_relative_file(receipt_ref) is None ||
        !receipt_digest.has_prefix("sha256:") ||
        receipt_recorded_at.trim().is_empty()
      )
    ) {
    return None
  }
  Some({
    handoff_token: token,
    handoff_digest: digest,
    request_id,
    attempt_id,
    idempotency_key,
    intake_path,
    status_path,
    receipt_path,
    return_path,
    status,
    receipt_ref,
    receipt_digest,
    receipt_recorded_at,
  })
}

///|
fn decode_moonflow_operator_action_v2(
  value : Json,
  expected_run_id : String,
) -> MoonFlowOperatorActionDefinition? {
  guard moonflow_action_strict_object(value, [
      "action_id", "action_kind", "label", "summary", "status", "enabled", "run_id",
      "work_item_id", "declaration_id", "product_id", "operation", "requested_authority",
      "authority_status", "claim_ceiling", "capability_status", "input_contracts",
      "output_contracts", "evidence_refs", "review_required", "review_status", "acceptance_criteria",
      "handoff_ref", "receiver", "app_entrypoint",
    ])
    is Some(fields) else {
    return None
  }
  guard moonflow_action_required_string(fields, "action_id") is Some(action_id) &&
    moonflow_action_required_string(fields, "action_kind") is Some(action_kind) &&
    moonflow_action_required_string(fields, "label") is Some(label) &&
    moonflow_action_required_string(fields, "summary") is Some(summary) &&
    moonflow_action_required_string(fields, "status") is Some(status) &&
    moonflow_action_required_bool(fields, "enabled") is Some(enabled) &&
    moonflow_action_required_string(fields, "run_id") is Some(run_id) &&
    moonflow_action_required_string(fields, "work_item_id")
    is Some(work_item_id) &&
    moonflow_action_required_string(fields, "declaration_id")
    is Some(declaration_id) &&
    moonflow_action_required_string(fields, "product_id") is Some(product_id) &&
    moonflow_action_required_string(fields, "operation") is Some(operation) &&
    moonflow_action_required_string(fields, "requested_authority")
    is Some(requested_authority) &&
    moonflow_action_required_string(fields, "authority_status")
    is Some(authority_status) &&
    moonflow_action_required_string(fields, "claim_ceiling")
    is Some(claim_ceiling) &&
    moonflow_action_required_string(fields, "capability_status")
    is Some(capability_status) &&
    moonflow_action_string_array(fields, "input_contracts", true)
    is Some(input_contracts) &&
    moonflow_action_string_array(fields, "output_contracts", true)
    is Some(output_contracts) &&
    decode_moonflow_operator_evidence_refs(fields) is Some(evidence_refs) &&
    moonflow_action_required_bool(fields, "review_required")
    is Some(review_required) &&
    moonflow_action_required_string(fields, "review_status")
    is Some(review_status) &&
    moonflow_action_string_array(fields, "acceptance_criteria", false)
    is Some(acceptance_criteria) &&
    moonflow_action_required_string(fields, "handoff_ref") is Some(handoff_ref) &&
    decode_moonflow_operator_receiver(fields, run_id) is Some(receiver) &&
    decode_moonflow_operator_entrypoint(fields) is Some(app_entrypoint) else {
    return None
  }
  if !moonflow_action_safe_id(action_id) ||
    action_kind != "open-product" ||
    run_id != expected_run_id ||
    !["pending", "accepted", "denied", "stale"].contains(status) ||
    enabled != (status == "pending") ||
    !["requested", "granted-by-receipt", "denied-by-receipt"].contains(
      authority_status,
    ) ||
    !["catalog-bound", "not-declared"].contains(capability_status) ||
    !["required", "not-required", "not-declared", "accepted", "denied"].contains(
      review_status,
    ) ||
    (
      ["required", "not-required", "not-declared"].contains(review_status) &&
      (review_status == "required") != review_required
    ) ||
    receiver.status != status ||
    moonflow_action_relative_file(handoff_ref) is None ||
    !handoff_ref.has_prefix("operator-handoffs/") {
    return None
  }
  Some({
    action_id,
    action_kind,
    label,
    summary,
    status,
    enabled,
    host_config: "",
    handoff_template: "",
    run_id,
    work_item_id,
    declaration_id,
    product_id,
    operation,
    requested_authority,
    authority_status,
    claim_ceiling,
    capability_status,
    input_contracts,
    output_contracts,
    evidence_refs,
    review_required,
    review_status,
    acceptance_criteria,
    handoff_ref,
    receiver,
    app_entrypoint,
  })
}

///|
fn decode_moonflow_operator_action_catalog(
  value : Json,
  expected_run_id : String,
) -> MoonFlowOperatorActionCatalog? {
  guard value is Object(raw_fields) else { return None }
  let contract_id = match raw_fields.get("contract_id") {
    Some(String(text)) => text
    _ => return None
  }
  let allowed = if contract_id == "moonflow.operator-actions.v2" {
    [
      "contract_id", "contract_version", "run_id", "projection_sequence", "source_digest",
      "actions",
    ]
  } else {
    ["contract_id", "contract_version", "run_id", "actions"]
  }
  guard moonflow_action_strict_object(value, allowed) is Some(fields) else {
    return None
  }
  guard moonflow_action_required_string(fields, "contract_id")
    is Some(decoded_contract_id) &&
    moonflow_action_required_string(fields, "contract_version")
    is Some(contract_version) &&
    moonflow_action_required_string(fields, "run_id") is Some(run_id) &&
    fields.get("actions") is Some(Array(values)) else {
    return None
  }
  let is_v1 = decoded_contract_id == "moonflow.operator-actions.v1" &&
    contract_version == "1.0.0"
  let is_v2 = decoded_contract_id == "moonflow.operator-actions.v2" &&
    contract_version == "2.1.0"
  if (!is_v1 && !is_v2) || run_id != expected_run_id {
    return None
  }
  let actions : Array[MoonFlowOperatorActionDefinition] = []
  for value in values {
    let decoded = if is_v2 {
      decode_moonflow_operator_action_v2(value, expected_run_id)
    } else {
      decode_moonflow_operator_action_v1(value)
    }
    guard decoded is Some(action) else { return None }
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
  configured_app : Json?,
) -> Json {
  let receiver_status = action.receiver.status
  let (entrypoint_status, entrypoint_id, launch_path) = if action.action_kind ==
    "open-product" {
    match configured_app {
      Some(app) => {
        let pack_id = json_string(app, "pack_id", default="")
        let configured_entrypoint = json_string(
          app,
          "entrypoint_id",
          default="",
        )
        let launch_url = json_string(app, "launch_url", default="")
        if pack_id == action.app_entrypoint.pack_id &&
          configured_entrypoint != "" &&
          launch_url == action.app_entrypoint.path &&
          action.run_id != "" &&
          moonflow_safe_run_id(action.run_id) &&
          moonflow_receiver_token_is_safe(action.receiver.handoff_token) {
          (
            "configured",
            configured_entrypoint,
            launch_url +
            "?moonflow_run=" +
            action.run_id +
            "&moonflow_handoff=" +
            action.receiver.handoff_token,
          )
        } else {
          ("mismatch", "", "")
        }
      }
      None => ("unavailable", "", "")
    }
  } else {
    ("not-required", action.app_entrypoint.entrypoint_id, "")
  }
  let navigation_enabled = action.action_kind != "open-product" ||
    entrypoint_status == "configured"
  let enabled = action.enabled && navigation_enabled
  let status = if action.action_kind == "open-product" &&
    receiver_status == "pending" &&
    !navigation_enabled {
    "unavailable"
  } else {
    action.status
  }
  {
    "action_id": action.action_id,
    "action_kind": action.action_kind,
    "label": action.label,
    "summary": action.summary,
    "status": status,
    "enabled": enabled,
    "run_id": action.run_id,
    "work_item_id": action.work_item_id,
    "declaration_id": action.declaration_id,
    "product_id": action.product_id,
    "operation": action.operation,
    "requested_authority": action.requested_authority,
    "authority_status": action.authority_status,
    "claim_ceiling": action.claim_ceiling,
    "capability_status": action.capability_status,
    "input_contracts": action.input_contracts,
    "output_contracts": action.output_contracts,
    "evidence_refs": [
      for evidence in action.evidence_refs => {
        {
          "kind": evidence.kind,
          "reference": evidence.reference,
          "digest": evidence.digest,
        }
      }
    ],
    "review_required": action.review_required,
    "review_status": action.review_status,
    "acceptance_criteria": action.acceptance_criteria,
    "handoff_ref": action.handoff_ref,
    "receiver": if action.action_kind == "open-product" {
      {
        "handoff_token": action.receiver.handoff_token,
        "handoff_digest": action.receiver.handoff_digest,
        "request_id": action.receiver.request_id,
        "attempt_id": action.receiver.attempt_id,
        "idempotency_key": action.receiver.idempotency_key,
        "intake_path": action.receiver.intake_path,
        "status_path": action.receiver.status_path,
        "receipt_path": action.receiver.receipt_path,
        "return_path": action.receiver.return_path,
        "status": action.receiver.status,
        "receipt_ref": action.receiver.receipt_ref,
        "receipt_digest": action.receiver.receipt_digest,
        "receipt_recorded_at": action.receiver.receipt_recorded_at,
      }
    } else {
      Json::null()
    },
    "app_entrypoint": {
      "kind": action.app_entrypoint.kind,
      "pack_id": action.app_entrypoint.pack_id,
      "entrypoint_id": entrypoint_id,
      "path": action.app_entrypoint.path,
      "fallback_path": action.app_entrypoint.fallback_path,
      "status": entrypoint_status,
      "launch_path": launch_path,
    },
  }
}

///|
fn moonflow_operator_actions_response(
  run_id : String,
  status : String,
  actions : Array[Json],
) -> Json {
  {
    "contract_id": "moondesk.moonflow-operator-actions.v2",
    "contract_version": "2.0.0",
    "run_id": run_id,
    "status": status,
    "actions": Json::array(actions),
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
async fn moonflow_receiver_recovery_needed(run_root : String) -> Bool {
  let directory = @pathx.join(run_root, "operator-receipts")
  for name in read_directory_names(directory, include_hidden=false) {
    if !name.has_suffix(".json") {
      continue
    }
    let record = read_json_file_or_object(@pathx.join(directory, name))
    if json_string(record, "contract_id", default="") ==
      "moonflow.receiver-receipt-record.v1" &&
      json_string(record, "stage", default="") == "received" {
      return true
    }
  }
  false
}

///|
async fn moonflow_recover_receiver_receipts(
  workspace_root : String,
  run_root : String,
  run_id : String,
) -> Bool {
  if !moonflow_receiver_recovery_needed(run_root) {
    return true
  }
  let moonflow_root = @sys.get_env_var("MOONFLOW_ROOT").unwrap_or("")
  if moonflow_root == "" || !@fs.exists(@pathx.join(moonflow_root, "moon.mod")) {
    return false
  }
  let captured = @async.with_timeout_opt(30000, () => {
    run_process_capture(
      moonclaw_default_moon_command(),
      moonflow_cli_arguments(moonflow_root, [
        "recover-operator-receipts", workspace_root, run_id,
      ]),
    )
  })
  guard captured is Some((0, stdout, _)) else { return false }
  let response = @json.parse(stdout.trim()) catch { _ => return false }
  json_string(response, "contract_id", default="") ==
  "moonflow.receiver-recovery.v1" &&
  json_string(response, "run_id", default="") == run_id
}

///|
async fn moonflow_project_operator_actions(
  workspace_root : String,
  catalog : MoonFlowOperatorActionCatalog,
) -> (String, Array[Json]) {
  let projected : Array[Json] = []
  let mut executable = false
  for action in catalog.actions {
    let configured = if action.action_kind == "open-product" {
      configured_pack_app(workspace_root, action.app_entrypoint.pack_id)
    } else {
      None
    }
    let value = moonflow_operator_action_public_json(action, configured)
    if json_bool(value, "enabled", default=false) {
      executable = true
    }
    projected.push(value)
  }
  let status = if executable {
    "available"
  } else if projected.any(action => {
      ["accepted", "denied"].contains(json_string(action, "status", default=""))
    }) {
    "settled"
  } else {
    "unavailable"
  }
  (status, projected)
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
  if !moonflow_recover_receiver_receipts(workspace_root, run_root, run_id) {
    send_api_error(
      conn, method_, 503, "Service Unavailable", "MoonFlow receiver recovery could not be completed",
    )
    return
  }
  match moonflow_operator_action_catalog(run_root, run_id) {
    Some(catalog) => {
      let (status, actions) = moonflow_project_operator_actions(
        workspace_root, catalog,
      )
      send_json(
        conn,
        method_,
        moonflow_operator_actions_response(catalog.run_id, status, actions),
      )
    }
    None =>
      send_json(
        conn,
        method_,
        moonflow_operator_actions_response(run_id, "unavailable", []),
      )
  }
}

///|
fn moonflow_action_for_receiver_token(
  catalog : MoonFlowOperatorActionCatalog,
  token : String,
) -> MoonFlowOperatorActionDefinition? {
  let mut found : MoonFlowOperatorActionDefinition? = None
  for action in catalog.actions {
    if action.action_kind == "open-product" &&
      action.receiver.handoff_token == token {
      if found is Some(_) {
        return None
      }
      found = Some(action)
    }
  }
  found
}

///|
fn moonflow_receiver_payload_digest(payload : Json) -> String {
  "sha256:" +
  @crypto.bytes_to_hex_string(
    @crypto.sha256(@encoding/utf8.encode(payload.stringify()).to_fixedarray()),
  )
}

///|
async fn moonflow_bound_receiver_handoff(
  run_root : String,
  action : MoonFlowOperatorActionDefinition,
) -> Json? {
  guard moonflow_action_relative_file(action.handoff_ref) is Some(relative) else {
    return None
  }
  let path = @pathx.join(run_root, relative)
  if !@fs.exists(path) {
    return None
  }
  let value = @json.parse(@fs.read_file(path).text()) catch { _ => return None }
  guard moonflow_action_strict_object(value, [
      "contract_id", "contract_version", "handoff_id", "handoff_ref", "binding",
      "payload",
    ])
    is Some(fields) &&
    moonflow_action_required_string(fields, "contract_id")
    is Some("moonflow.operator-handoff.v2") &&
    moonflow_action_required_string(fields, "contract_version") is Some("2.0.0") &&
    moonflow_action_required_string(fields, "handoff_id") is Some(handoff_id) &&
    moonflow_action_required_string(fields, "handoff_ref") is Some(handoff_ref) &&
    fields.get("binding") is Some(binding_value) &&
    moonflow_action_strict_object(binding_value, [
      "handoff_token", "handoff_digest", "request_id", "attempt_id", "idempotency_key",
      "intake_path", "status_path", "receipt_path", "return_path",
    ])
    is Some(binding) &&
    fields.get("payload") is Some(payload) &&
    moonflow_action_required_string(binding, "handoff_token")
    is Some(handoff_token) &&
    moonflow_action_required_string(binding, "handoff_digest")
    is Some(handoff_digest) &&
    moonflow_action_required_string(binding, "request_id") is Some(request_id) &&
    moonflow_action_required_string(binding, "attempt_id") is Some(attempt_id) &&
    moonflow_action_required_string(binding, "idempotency_key")
    is Some(idempotency_key) &&
    moonflow_action_required_string(binding, "intake_path") is Some(intake_path) &&
    moonflow_action_required_string(binding, "status_path") is Some(status_path) &&
    moonflow_action_required_string(binding, "receipt_path")
    is Some(receipt_path) &&
    moonflow_action_required_string(binding, "return_path") is Some(return_path) &&
    payload is Object(payload_fields) &&
    payload_fields.get("run") is Some(Object(run)) &&
    payload_fields.get("authority") is Some(Object(authority)) &&
    payload_fields.get("app_entrypoint") is Some(Object(entrypoint)) &&
    moonflow_action_required_string(payload_fields, "action_kind")
    is Some("open-product") &&
    moonflow_action_required_string(run, "run_id") is Some(run_id) &&
    moonflow_action_required_string(run, "work_item_id") is Some(work_item_id) &&
    moonflow_action_required_string(run, "declaration_id")
    is Some(declaration_id) &&
    moonflow_action_required_string(run, "product_id") is Some(product_id) &&
    moonflow_action_required_string(run, "operation") is Some(operation) &&
    moonflow_action_required_string(authority, "requested_authority")
    is Some(requested_authority) &&
    moonflow_action_required_string(entrypoint, "pack_id") is Some(pack_id) else {
    return None
  }
  if handoff_id != action.action_id ||
    handoff_ref != action.handoff_ref ||
    handoff_token != action.receiver.handoff_token ||
    handoff_digest != action.receiver.handoff_digest ||
    request_id != action.receiver.request_id ||
    attempt_id != action.receiver.attempt_id ||
    idempotency_key != action.receiver.idempotency_key ||
    intake_path != action.receiver.intake_path ||
    status_path != action.receiver.status_path ||
    receipt_path != action.receiver.receipt_path ||
    return_path != action.receiver.return_path ||
    moonflow_receiver_payload_digest(payload) != action.receiver.handoff_digest ||
    run_id != action.run_id ||
    work_item_id != action.work_item_id ||
    declaration_id != action.declaration_id ||
    product_id != action.product_id ||
    operation != action.operation ||
    requested_authority != action.requested_authority ||
    pack_id != action.app_entrypoint.pack_id {
    return None
  }
  Some(value)
}

///|
fn moonflow_receiver_status_response(
  action : MoonFlowOperatorActionDefinition,
  projection : Json,
) -> Json {
  let item_status = json_array_items(projection, "items").filter_map(item => {
    if json_string(item, "work_item_id", default="") == action.work_item_id {
      Some(json_string(item, "status", default="missing"))
    } else {
      None
    }
  })
  {
    "contract_id": "moonflow.receiver-status.v1",
    "contract_version": "1.0.0",
    "run_id": action.run_id,
    "handoff_token": action.receiver.handoff_token,
    "handoff_digest": action.receiver.handoff_digest,
    "status": action.receiver.status,
    "stage": if action.receiver.status == "pending" {
      "published"
    } else {
      "applied"
    },
    "work_item_status": if item_status.is_empty() {
      "missing"
    } else {
      item_status[0]
    },
    "run_outcome": json_string(projection, "outcome", default="unknown"),
    "projection_sequence": json_int(projection, "last_sequence", default=-1),
    "receipt_ref": action.receiver.receipt_ref,
    "receipt_digest": action.receiver.receipt_digest,
    "receipt_recorded_at": action.receiver.receipt_recorded_at,
    "intake_path": action.receiver.intake_path,
    "status_path": action.receiver.status_path,
    "receipt_path": action.receiver.receipt_path,
    "return_path": action.receiver.return_path,
  }
}

///|
async fn moonflow_receiver_action(
  workspace_root : String,
  run_id : String,
  token : String,
) -> (String, MoonFlowOperatorActionDefinition?, Json) {
  if !moonflow_safe_run_id(run_id) || !moonflow_receiver_token_is_safe(token) {
    return ("invalid", None, Json::null())
  }
  let run_root = @pathx.join(moonflow_runs_root(workspace_root), run_id)
  if !@fs.exists(@pathx.join(run_root, "projection.json")) {
    return ("missing", None, Json::null())
  }
  if !moonflow_recover_receiver_receipts(workspace_root, run_root, run_id) {
    return ("recovery-failed", None, Json::null())
  }
  guard moonflow_operator_action_catalog(run_root, run_id) is Some(catalog) &&
    moonflow_action_for_receiver_token(catalog, token) is Some(action) &&
    moonflow_bound_receiver_handoff(run_root, action) is Some(handoff) else {
    return ("mismatch", None, Json::null())
  }
  ("ok", Some(action), handoff)
}

///|
async fn handle_moonflow_receiver_intake(
  workspace_root : String,
  run_id : String,
  token : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let (state, action, handoff) = moonflow_receiver_action(
    workspace_root, run_id, token,
  )
  guard state == "ok" && action is Some(bound_action) else {
    let code = if state == "missing" {
      404
    } else if state == "invalid" {
      400
    } else if state == "recovery-failed" {
      503
    } else {
      409
    }
    send_api_error(
      conn,
      method_,
      code,
      if code == 404 {
        "Not Found"
      } else {
        "Conflict"
      },
      "MoonFlow receiver handoff is unavailable",
    )
    return
  }
  guard configured_pack_app(workspace_root, bound_action.app_entrypoint.pack_id)
    is Some(_) else {
    send_api_error(
      conn, method_, 409, "Conflict", "MoonFlow receiver entrypoint is not configured",
    )
    return
  }
  send_json(conn, method_, handoff)
}

///|
async fn handle_moonflow_receiver_status(
  workspace_root : String,
  run_id : String,
  token : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let (state, action, _) = moonflow_receiver_action(
    workspace_root, run_id, token,
  )
  guard state == "ok" && action is Some(bound_action) else {
    send_api_error(
      conn,
      method_,
      if state == "missing" {
        404
      } else if state == "recovery-failed" {
        503
      } else {
        409
      },
      "Conflict",
      "MoonFlow receiver status is unavailable",
    )
    return
  }
  let run_root = @pathx.join(moonflow_runs_root(workspace_root), run_id)
  let projection = read_json_file_or_object(
    @pathx.join(run_root, "projection.json"),
  )
  send_json(
    conn,
    method_,
    moonflow_receiver_status_response(bound_action, projection),
  )
}

///|
fn moonflow_receiver_cli_status(
  value : Json,
  run_id : String,
  token : String,
) -> Json? {
  guard moonflow_action_strict_object(value, [
      "contract_id", "contract_version", "run_id", "handoff_token", "handoff_digest",
      "status", "stage", "work_item_status", "run_outcome", "projection_sequence",
      "receipt_ref", "receipt_digest", "receipt_recorded_at", "intake_path", "status_path",
      "receipt_path", "return_path",
    ])
    is Some(fields) &&
    moonflow_action_required_string(fields, "contract_id")
    is Some("moonflow.receiver-status.v1") &&
    moonflow_action_required_string(fields, "contract_version") is Some("1.0.0") &&
    moonflow_action_required_string(fields, "run_id") is Some(run_id) &&
    moonflow_action_required_string(fields, "handoff_token") is Some(token) &&
    moonflow_action_required_string(fields, "handoff_digest")
    is Some(handoff_digest) &&
    handoff_digest == "sha256:" + token &&
    moonflow_action_required_string(fields, "status") is Some(status) &&
    ["accepted", "denied"].contains(status) &&
    moonflow_action_required_string(fields, "stage") is Some("applied") &&
    moonflow_action_required_string(fields, "receipt_ref") is Some(receipt_ref) &&
    moonflow_action_relative_file(receipt_ref) is Some(_) &&
    moonflow_action_required_string(fields, "receipt_digest")
    is Some(receipt_digest) &&
    receipt_digest.has_prefix("sha256:") else {
    return None
  }
  Some(value)
}

///|
async fn handle_moonflow_receiver_receipt(
  workspace_root : String,
  run_id : String,
  token : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let (state, action, _) = moonflow_receiver_action(
    workspace_root, run_id, token,
  )
  guard state == "ok" && action is Some(bound_action) else {
    send_api_error(
      conn,
      method_,
      if state == "missing" {
        404
      } else if state == "recovery-failed" {
        503
      } else {
        409
      },
      "Conflict",
      "MoonFlow receiver handoff is unavailable",
    )
    return
  }
  guard configured_pack_app(workspace_root, bound_action.app_entrypoint.pack_id)
    is Some(_) else {
    send_api_error(
      conn, method_, 409, "Conflict", "MoonFlow receiver entrypoint is not configured",
    )
    return
  }
  guard read_json_body(body) is Some(submission) &&
    submission is Object(submission_fields) &&
    json_string(submission, "contract_id", default="") ==
    "moonflow.receiver-receipt.v1" &&
    json_string(submission, "run_id", default="") == run_id &&
    json_string(submission, "handoff_token", default="") == token &&
    json_string(submission, "handoff_digest", default="") ==
    bound_action.receiver.handoff_digest else {
    send_api_error(
      conn, method_, 400, "Bad Request", "Receiver receipt is not bound to this handoff",
    )
    return
  }
  ignore(submission_fields)
  let run_root = @pathx.join(moonflow_runs_root(workspace_root), run_id)
  let submission_relative = ".moondesk/receiver-submissions/" + token + ".json"
  let submission_path = @pathx.join(run_root, submission_relative)
  if @fs.exists(submission_path) {
    let existing = @json.parse(@fs.read_file(submission_path).text()) catch {
      _ => Json::null()
    }
    if existing != submission {
      send_api_error(
        conn, method_, 409, "Conflict", "Receiver token already has a different submission",
      )
      return
    }
  } else if !@fsx.write_confined_text(
      run_root,
      submission_relative,
      submission.stringify(indent=2) + "\n",
      create=0o600,
    ) {
    send_api_error(
      conn, method_, 500, "Internal Server Error", "Could not persist receiver submission",
    )
    return
  }
  let moonflow_root = @sys.get_env_var("MOONFLOW_ROOT").unwrap_or("")
  if moonflow_root == "" || !@fs.exists(@pathx.join(moonflow_root, "moon.mod")) {
    send_api_error(
      conn, method_, 503, "Service Unavailable", "MoonFlow host unavailable",
    )
    return
  }
  let workspace_submission_ref = ".moonsuite/products/moonflow/runs/" +
    run_id +
    "/" +
    submission_relative
  let captured = @async.with_timeout_opt(30000, () => {
    run_process_capture(
      moonclaw_default_moon_command(),
      moonflow_cli_arguments(moonflow_root, [
        "receive-operator-receipt", workspace_root, run_id, token, workspace_submission_ref,
      ]),
    )
  })
  guard captured is Some((0, stdout, _)) else {
    send_api_error(
      conn, method_, 409, "Conflict", "MoonFlow rejected the receiver receipt",
    )
    return
  }
  let response = @json.parse(stdout.trim()) catch { _ => Json::null() }
  guard moonflow_receiver_cli_status(response, run_id, token) is Some(status) else {
    send_api_error(
      conn, method_, 502, "Bad Gateway", "MoonFlow returned an invalid receiver status",
    )
    return
  }
  send_json(conn, method_, status)
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
  if action.action_kind == "open-product" {
    send_api_error(
      conn, method_, 409, "Conflict", "Navigation handoffs must be opened through their published app entrypoint",
    )
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
  let receipt_relative = ".moondesk/action-receipts/moonflow-" +
    run_id +
    "-" +
    action_id +
    ".json"
  if !@fsx.write_confined_text(
      run_root,
      receipt_relative,
      receipt.stringify(),
      create=0o600,
    ) {
    send_api_error(
      conn, method_, 500, "Internal Server Error", "Could not persist action receipt",
    )
    return
  }
  send_json(conn, method_, receipt)
}
