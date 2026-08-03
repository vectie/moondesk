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
fn moonflow_collaboration_inspect_arguments(
  moonflow_root : String,
  workspace_path : String,
  workspace_id : String,
) -> Array[String] {
  moonflow_cli_arguments(moonflow_root, [
    "collaboration", "inspect", workspace_path, workspace_id,
  ])
}

///|
fn moonflow_handover_list_arguments(
  moonflow_root : String,
  workspace_path : String,
) -> Array[String] {
  moonflow_cli_arguments(moonflow_root, ["handover", "list", workspace_path])
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
async fn moonflow_validated_handover_catalog(
  moon : String,
  moonflow_root : String,
  workspace_path : String,
) -> Json? {
  let captured = @async.with_timeout_opt(30000, () => {
    run_process_capture(
      moon,
      moonflow_handover_list_arguments(moonflow_root, workspace_path),
    )
  })
  guard captured is Some((0, stdout, _)) else { return None }
  let catalog = @json.parse(stdout) catch { _ => return None }
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
  let moon = moonclaw_default_moon_command()
  let captured = @async.with_timeout_opt(30000, () => {
    run_process_capture(
      moon,
      moonflow_collaboration_inspect_arguments(
        moonflow_root,
        workspace.root_path,
        workspace_id,
      ),
    )
  })
  guard captured is Some((code, stdout, stderr)) else {
    send_json(
      conn,
      method_,
      moonflow_collaboration_reply(
        workspace_id,
        None,
        false,
        "owner_timeout",
        "MoonFlow did not validate collaboration within 30 seconds",
        "retry_or_inspect_moonflow",
      ),
    )
    return
  }
  if code != 0 {
    let rejection_detail = if stderr.trim().is_empty() {
      ""
    } else {
      ": " + trim_for_record(stderr)
    }
    send_json(
      conn,
      method_,
      moonflow_collaboration_reply(
        workspace_id,
        None,
        false,
        "quarantined",
        "MoonFlow rejected the collaboration snapshot" + rejection_detail,
        "inspect_or_recover_in_moonflow",
      ),
    )
    return
  }
  let snapshot = @json.parse(stdout) catch {
    _ => {
      send_json(
        conn,
        method_,
        moonflow_collaboration_reply(
          workspace_id,
          None,
          false,
          "quarantined",
          "MoonFlow returned an unreadable collaboration projection",
          "inspect_or_recover_in_moonflow",
        ),
      )
      return
    }
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
    moon,
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
