///|
fn moonflow_collaboration_snapshot_path(
  workspace_path : String,
  workspace_id : String,
) -> String {
  @pathx.join(
    @pathx.join(
      @pathx.normalize(workspace_path),
      ".moonsuite/products/moonflow/collaboration",
    ),
    workspace_id + ".json",
  )
}

///|
fn moonflow_handover_catalog_valid(catalog : Json) -> Bool {
  if json_string(catalog, "contract_id", default="") !=
    "moonflow.handover-catalog.v1" {
    return false
  }
  let handovers = json_array_items(catalog, "handovers")
  if handovers.length() > 256 {
    return false
  }
  for handover in handovers {
    let handover_id = json_string(handover, "handover_id", default="")
    let state = json_string(handover, "state", default="")
    let valid = json_bool(handover, "valid", default=false)
    if !moonflow_safe_run_id(handover_id) ||
      ![
        "draft", "sealed", "offered", "accepted", "rejected", "expired", "imported",
        "resumed", "completed", "quarantined",
      ].contains(state) {
      return false
    }
    if valid &&
      (
        !is_sha256_digest(json_string(handover, "head_digest", default="")) ||
        !is_sha256_digest(json_string(handover, "envelope_digest", default=""))
      ) {
      return false
    }
    if !valid && state != "quarantined" {
      return false
    }
  }
  true
}

///|
fn moonflow_validated_handover_catalog(
  moonflow_root : String,
  workspace_path : String,
) -> Json? {
  let response = execution_sandbox_client_submit({
    operation: MoonFlowListHandovers,
    input: { "moonflow_root": moonflow_root, "workspace_path": workspace_path },
  })
  guard response is Ok(catalog) else { return None }
  if moonflow_handover_catalog_valid(catalog) {
    Some(catalog)
  } else {
    None
  }
}

///|
fn moonflow_collaboration_reply(
  workspace_id : String,
  snapshot : Json?,
  ok : Bool,
  status : String,
  message : String,
  next_action : String,
  handover_catalog? : Json = Json::null(),
) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["workspace_id"] = workspace_id.to_json()
  fields["source_contract"] = "moonflow.collaboration-snapshot.v1".to_json()
  match snapshot {
    Some(value) => fields["snapshot"] = value
    None => ()
  }
  match handover_catalog {
    Null => ()
    value => fields["handover_catalog"] = value
  }
  api_contract_response(
    Json::object(fields),
    ok~,
    status~,
    message~,
    next_action~,
  )
}

///|
async fn handle_moonflow_collaboration(
  workspace_root : String,
  workspace_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  if !moonflow_safe_run_id(workspace_id) {
    send_json(
      conn,
      method_,
      moonflow_collaboration_reply(
        workspace_id,
        None,
        false,
        "invalid_workspace",
        "The collaboration workspace identity is invalid",
        "select_workspace",
      ),
    )
    return
  }
  let workspace = match find_workspace(workspace_root, workspace_id) {
    Some(value) => value
    None => {
      send_json(
        conn,
        method_,
        moonflow_collaboration_reply(
          workspace_id,
          None,
          false,
          "workspace_unavailable",
          "Select an available MoonBook before loading collaboration",
          "select_workspace",
        ),
      )
      return
    }
  }
  let capability = moonflow_capability_evidence()
  if !json_bool(capability, "available", default=false) {
    send_json(
      conn,
      method_,
      moonflow_collaboration_reply(
        workspace_id,
        None,
        false,
        "owner_unavailable",
        "MoonFlow is not available to validate collaboration state",
        "review_flow_setup",
      ),
    )
    return
  }
  let snapshot_path = moonflow_collaboration_snapshot_path(
    workspace.root_path,
    workspace_id,
  )
  if !@fs.exists(snapshot_path) {
    send_json(
      conn,
      method_,
      moonflow_collaboration_reply(
        workspace_id,
        None,
        false,
        "not_initialized",
        "Collaboration has not been initialized for this MoonBook",
        "initialize_in_moonflow",
      ),
    )
    return
  }
  let moonflow_root = json_string(capability, "root", default="")
  let inspected = execution_sandbox_client_submit({
    operation: MoonFlowInspectCollaboration,
    input: {
      "moonflow_root": moonflow_root,
      "workspace_path": workspace.root_path,
      "workspace_id": workspace_id,
    },
  })
  guard inspected is Ok(snapshot) else {
    send_json(
      conn,
      method_,
      moonflow_collaboration_reply(
        workspace_id,
        None,
        false,
        "sandbox_unavailable",
        execution_sandbox_unavailable_message(),
        "configure_execution_sandbox",
      ),
    )
    return
  }
  if json_string(snapshot, "contract_id", default="") !=
    "moonflow.collaboration-snapshot.v1" {
    send_json(
      conn,
      method_,
      moonflow_collaboration_reply(
        workspace_id,
        None,
        false,
        "quarantined",
        "MoonFlow returned an unsupported collaboration contract",
        "upgrade_moonflow",
      ),
    )
    return
  }
  let handover_catalog = moonflow_validated_handover_catalog(
    moonflow_root,
    workspace.root_path,
  ).unwrap_or(Json::null())
  send_json(
    conn,
    method_,
    moonflow_collaboration_reply(
      workspace_id,
      Some(snapshot),
      true,
      "ready",
      "Validated MoonFlow collaboration state is ready",
      "review_collaboration",
      handover_catalog~,
    ),
  )
}
