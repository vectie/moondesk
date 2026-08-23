///|
fn moonflow_runs_root(workspace_root : String) -> String {
  @pathx.join(
    @pathx.normalize(workspace_root),
    ".moonsuite/products/moonflow/runs",
  )
}

///|
fn moonflow_safe_run_id(run_id : String) -> Bool {
  !run_id.trim().is_empty() &&
  !run_id.contains("/") &&
  !run_id.contains("\\") &&
  !run_id.contains("..")
}

///|
fn moonflow_graph_run_id(graph : Json) -> String {
  json_string(
    graph,
    "graph_id",
    default=json_string(graph, "run_id", default=""),
  )
}

///|
async fn handle_moonflow_import_selected(
  workspace_root : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let payload = match read_json_body(body) {
    Some(value) => value
    None => {
      send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
      return
    }
  }
  let workspace_id = json_string(payload, "workspace_id", default="")
  let workspace = match find_workspace(workspace_root, workspace_id) {
    Some(value) => value
    None => {
      send_api_error(conn, method_, 404, "Not Found", "Select a MoonBook first")
      return
    }
  }
  let graph_path = moonflow_source_graph_path(workspace.root_path)
  if graph_path == "" {
    send_json(
      conn,
      method_,
      api_contract_response(
        { "book_id": workspace_id, "run_id": "" },
        ok=false,
        status="declaration_missing",
        message="This MoonBook has no executable Work graph yet",
        next_action="create_executable_document_in_wiki",
      ),
    )
    return
  }
  let source_graph = moonflow_load_executable_graph(graph_path) catch {
    error => {
      send_json(
        conn,
        method_,
        api_contract_response(
          { "book_id": workspace_id, "run_id": "" },
          ok=false,
          status="declaration_invalid",
          message="Executable Work graph rejected: \{error}",
          next_action="review_work_graph",
        ),
      )
      return
    }
  }
  let capability_evidence = moonflow_capability_evidence()
  if !json_bool(capability_evidence, "available", default=false) {
    send_json(
      conn,
      method_,
      api_contract_response(
        {
          "book_id": workspace_id,
          "run_id": "",
          "capability_evidence": capability_evidence,
        },
        ok=false,
        status="moonflow_service_missing",
        message="Flow preparation is not available in the current setup",
        next_action="review_flow_setup",
      ),
    )
    return
  }
  let moonflow_root = json_string(capability_evidence, "root", default="")
  let suite_root = workspace_context(workspace_root).suite_root
  let evaluated_at = moonflow_server_utc_timestamp()
  let catalog = moonflow_resolve_capability_catalog(
    workspace.root_path,
    evaluated_at,
  )
  guard catalog.catalog is Some(_) else {
    send_json(
      conn,
      method_,
      api_contract_response(
        {
          "book_id": workspace_id,
          "run_id": "",
          "capability_evidence": capability_evidence,
          "catalog_evidence": catalog.evidence,
        },
        ok=false,
        status="capability_catalog_unavailable",
        message="The selected MoonBook has no valid MoonFlow capability catalog",
        next_action="review_capability_catalog",
      ),
    )
    return
  }
  let compiled_graph_path = moonflow_compile_composition(
    suite_root,
    workspace.root_path,
    graph_path,
  ) catch {
    error => {
      send_api_error(
        conn,
        method_,
        409,
        "Conflict",
        "MoonFlow composition could not be compiled: \{error}",
      )
      return
    }
  }
  let graph = moonflow_load_executable_graph(compiled_graph_path) catch {
    error => {
      send_api_error(
        conn,
        method_,
        409,
        "Conflict",
        "Compiled MoonFlow graph rejected: \{error}",
      )
      return
    }
  }
  let run_id = moonflow_graph_run_id(graph)
  let source_catalog_path = json_string(
    catalog.evidence,
    "catalog_path",
    default="",
  )
  let evidence_root = moonflow_import_evidence_relative_root(
    graph,
    catalog.evidence,
    evaluated_at,
  )
  let catalog_path = moonflow_snapshot_capability_catalog(
    suite_root,
    evidence_root,
    source_catalog_path,
    json_string(catalog.evidence, "catalog_digest", default=""),
  ) catch {
    error => {
      send_json(
        conn,
        method_,
        api_contract_response(
          {
            "book_id": workspace_id,
            "run_id": run_id,
            "catalog_evidence": catalog.evidence,
          },
          ok=false,
          status="capability_catalog_changed",
          message="Capability catalog snapshot rejected: \{error}",
          next_action="retry_import",
        ),
      )
      return
    }
  }
  let validation = execution_sandbox_client_submit({
    operation: MoonFlowValidateGraph,
    input: {
      "moonflow_root": moonflow_root,
      "graph_path": compiled_graph_path,
      "catalog_path": catalog_path,
      "evaluated_at": evaluated_at,
    },
  })
  guard validation is Ok(validation_report) else {
    let receipt = moonflow_import_receipt(
      graph,
      catalog.evidence,
      evaluated_at,
      "sandbox_unavailable",
      "",
      execution_sandbox_unavailable_message(),
    )
    let receipt_ref = moonflow_persist_import_receipt(
      suite_root, evidence_root, receipt,
    )
    send_json(
      conn,
      method_,
      api_contract_response(
        {
          "book_id": workspace_id,
          "run_id": run_id,
          "catalog_evidence": catalog.evidence,
          "import_receipt_ref": receipt_ref,
        },
        ok=false,
        status="sandbox_unavailable",
        message=execution_sandbox_unavailable_message(),
        next_action="configure_execution_sandbox",
      ),
    )
    return
  }
  if !moonflow_validation_report_matches(
      validation_report,
      graph,
      catalog.evidence,
    ) {
    let detail = "Execution sandbox returned no valid graph capability report"
    let receipt = moonflow_import_receipt(
      graph,
      catalog.evidence,
      evaluated_at,
      "validation_failed",
      "",
      detail,
    )
    let receipt_ref = moonflow_persist_import_receipt(
      suite_root, evidence_root, receipt,
    )
    send_json(
      conn,
      method_,
      api_contract_response(
        {
          "book_id": workspace_id,
          "run_id": run_id,
          "catalog_evidence": catalog.evidence,
          "import_receipt_ref": receipt_ref,
        },
        ok=false,
        status="validation_failed",
        message="MoonFlow could not validate this Work graph",
        next_action="review_work_graph",
      ),
    )
    return
  }
  let validation_report_ref = moonflow_persist_validation_report(
    suite_root, evidence_root, validation_report,
  )
  if !json_bool(validation_report, "accepted", default=false) {
    let receipt = moonflow_import_receipt(
      graph,
      catalog.evidence,
      evaluated_at,
      "validation_rejected",
      validation_report_ref,
      "MoonFlow rejected at least one exact capability binding",
    )
    let receipt_ref = moonflow_persist_import_receipt(
      suite_root, evidence_root, receipt,
    )
    send_json(
      conn,
      method_,
      api_contract_response(
        {
          "book_id": workspace_id,
          "run_id": run_id,
          "catalog_evidence": catalog.evidence,
          "validation_report": validation_report,
          "validation_report_ref": validation_report_ref,
          "import_receipt_ref": receipt_ref,
        },
        ok=false,
        status="validation_rejected",
        message="The executable Work graph does not match installed capabilities",
        next_action="review_capability_bindings",
      ),
    )
    return
  }
  let imported = execution_sandbox_client_submit({
    operation: MoonFlowImportGraph,
    input: {
      "moonflow_root": moonflow_root,
      "suite_root": suite_root,
      "graph_path": compiled_graph_path,
      "catalog_path": catalog_path,
      "evaluated_at": evaluated_at,
    },
  })
  guard imported is Ok(projection) else {
    let receipt = moonflow_import_receipt(
      graph,
      catalog.evidence,
      evaluated_at,
      "sandbox_unavailable",
      validation_report_ref,
      execution_sandbox_unavailable_message(),
    )
    let receipt_ref = moonflow_persist_import_receipt(
      suite_root, evidence_root, receipt,
    )
    send_json(
      conn,
      method_,
      api_contract_response(
        {
          "book_id": workspace_id,
          "run_id": run_id,
          "catalog_evidence": catalog.evidence,
          "validation_report_ref": validation_report_ref,
          "import_receipt_ref": receipt_ref,
        },
        ok=false,
        status="sandbox_unavailable",
        message=execution_sandbox_unavailable_message(),
        next_action="configure_execution_sandbox",
      ),
    )
    return
  }
  let import_ok = json_string(projection, "run_id", default="") == run_id
  let import_detail = if import_ok {
    "MoonFlow validated and imported the exact graph and catalog"
  } else {
    "Execution sandbox returned no valid MoonFlow import projection"
  }
  let receipt = moonflow_import_receipt(
    graph,
    catalog.evidence,
    evaluated_at,
    if import_ok {
      "imported"
    } else {
      "import_failed"
    },
    validation_report_ref,
    import_detail,
  )
  let receipt_ref = moonflow_persist_import_receipt(
    suite_root, evidence_root, receipt,
  )
  send_json(
    conn,
    method_,
    api_contract_response(
      {
        "book_id": workspace_id,
        "run_id": run_id,
        "source_graph_id": moonflow_graph_run_id(source_graph),
        "source_digest": json_string(source_graph, "source_digest", default=""),
        "declaration_revision": json_string(
          source_graph,
          "declaration_revision",
          default="",
        ),
        "capability_evidence": capability_evidence,
        "catalog_evidence": catalog.evidence,
        "validation_report": validation_report,
        "validation_report_ref": validation_report_ref,
        "import_receipt_ref": receipt_ref,
        "projection": projection,
        "evaluated_at": evaluated_at,
      },
      ok=import_ok,
      status=if import_ok { "imported" } else { "import_failed" },
      message=if import_ok {
        "Executable document validated and imported into MoonFlow"
      } else {
        "MoonFlow could not import this conformant Work graph"
      },
      next_action=if import_ok { "open_run" } else { "review_work_graph" },
    ),
  )
}

///|
async fn moonflow_projection(path : String) -> Json? {
  if !@fs.exists(path) {
    return None
  }
  Some(@json.parse(@fs.read_file(path).text())) catch {
    _ => None
  }
}

///|
async fn moonflow_json_or(path : String, fallback : Json) -> Json {
  match moonflow_projection(path) {
    Some(value) => value
    None => fallback
  }
}

///|
async fn moonflow_enriched_projection(
  run_root : String,
  projection : Json,
) -> Json {
  let fields : Map[String, Json] = Map([])
  match projection {
    Object(existing) =>
      for key, value in existing {
        fields[key] = value
      }
    _ => return projection
  }
  fields["autonomy_binding"] = moonflow_json_or(
    @pathx.join(run_root, "autonomy-binding.json"),
    {
      "contract_id": "moonflow.autonomy-binding.v1",
      "run_id": json_string(projection, "run_id", default=""),
      "envelope": {
        "envelope_id": "",
        "mode": "not-bound",
        "expires_at": "",
        "revoked": false,
        "external_effects_allowed": false,
        "physical_effects_allowed": false,
        "budget": {
          "model_tokens": 0,
          "tool_calls": 0,
          "storage_bytes": 0,
          "attempts": 0,
          "concurrency": 0,
        },
      },
      "usage_ref": "",
      "usage": {
        "model_tokens": 0,
        "tool_calls": 0,
        "storage_bytes": 0,
        "attempts": 0,
        "concurrency": 0,
      },
      "recorded_at": "",
    },
  )
  fields["intervention_scorecard"] = moonflow_json_or(
    @pathx.join(run_root, "intervention-scorecard.json"),
    {
      "contract_id": "moonflow.intervention-scorecard.v1",
      "run_id": json_string(projection, "run_id", default=""),
      "required_intervention_count": 0,
      "hidden_orchestration_count": 0,
      "normal_path_manual_count": 0,
      "unattended_qualified": false,
      "finalization_findings": [],
      "recorded_at": "",
    },
  )
  fields["run_control"] = moonflow_json_or(
    @pathx.join(run_root, "control.json"),
    {
      "contract_id": "moonflow.run-control.v1",
      "run_id": json_string(projection, "run_id", default=""),
      "state": "running",
      "authority_ceiling": "",
      "reason": "",
      "recorded_at": "",
    },
  )
  fields["operator_surface"] = moonflow_operator_surface_projection(
    run_root,
    json_string(projection, "run_id", default=""),
  )
  Json::object(fields)
}

///|
async fn handle_moonflow_control(
  workspace_root : String,
  run_id : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  if !moonflow_safe_run_id(run_id) {
    send_api_error(conn, method_, 400, "Bad Request", "Invalid MoonFlow run id")
    return
  }
  let run_root = @pathx.join(moonflow_runs_root(workspace_root), run_id)
  let projection_path = @pathx.join(run_root, "projection.json")
  if !@fs.exists(projection_path) {
    send_api_error(conn, method_, 404, "Not Found", "MoonFlow run not found")
    return
  }
  let payload = match read_json_body(body) {
    Some(value) => value
    None => {
      send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
      return
    }
  }
  let action = json_string(payload, "action", default="")
  let detail = json_string(payload, "detail", default="")
  if !["pause", "resume", "cancel", "narrow-authority"].contains(action) {
    send_api_error(
      conn, method_, 400, "Bad Request", "Unsupported control action",
    )
    return
  }
  let capability_evidence = moonflow_capability_evidence()
  if !json_bool(capability_evidence, "available", default=false) {
    send_json(
      conn,
      method_,
      api_contract_response(
        { "run_id": run_id, "capability_evidence": capability_evidence },
        ok=false,
        status="moonflow_service_missing",
        message="MoonFlow control is not available in the current setup",
        next_action="review_flow_setup",
      ),
    )
    return
  }
  let evaluated_at = moonflow_server_utc_timestamp()
  let moonflow_root = json_string(capability_evidence, "root", default="")
  let result = execution_sandbox_client_submit({
    operation: MoonFlowControl,
    input: {
      "moonflow_root": moonflow_root,
      "suite_root": workspace_context(workspace_root).suite_root,
      "run_id": run_id,
      "action": action,
      "evaluated_at": evaluated_at,
      "detail": detail,
    },
  })
  guard result is Ok(control) else {
    send_json(
      conn,
      method_,
      api_contract_response(
        { "run_id": run_id, "evaluated_at": evaluated_at },
        ok=false,
        status="sandbox_unavailable",
        message=execution_sandbox_unavailable_message(),
        next_action="configure_execution_sandbox",
      ),
    )
    return
  }
  if !moonflow_control_receipt_matches(control, run_id) {
    send_json(
      conn,
      method_,
      api_contract_response(
        {
          "run_id": run_id,
          "evaluated_at": evaluated_at,
          "capability_evidence": capability_evidence,
          "detail": "Execution sandbox returned an invalid control receipt",
        },
        ok=false,
        status="control_rejected",
        message="MoonFlow rejected the control request",
        next_action="review_run_state",
      ),
    )
    return
  }
  send_json(conn, method_, control)
}

///|
fn sort_moonflow_projections(projections : Array[Json]) -> Unit {
  projections.sort_by(fn(left, right) {
    let right_revision = json_string(right, "declaration_revision", default="")
    let left_revision = json_string(left, "declaration_revision", default="")
    let by_length = right_revision.length().compare(left_revision.length())
    if by_length != 0 {
      return by_length
    }
    let by_revision = right_revision.compare(left_revision)
    if by_revision != 0 {
      return by_revision
    }
    json_string(right, "run_id", default="").compare(
      json_string(left, "run_id", default=""),
    )
  })
}

///|
async fn handle_moonflow_runs(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let root = moonflow_runs_root(workspace_root)
  let projections : Array[Json] = []
  for run_id in read_directory_names(root, include_hidden=false) {
    if !moonflow_safe_run_id(run_id) {
      continue
    }
    match
      moonflow_projection(
        @pathx.join(@pathx.join(root, run_id), "projection.json"),
      ) {
      Some(projection) =>
        projections.push(
          moonflow_enriched_projection(@pathx.join(root, run_id), projection),
        )
      None => ()
    }
  }
  sort_moonflow_projections(projections)
  send_json(conn, method_, Json::array(projections))
}

///|
async fn handle_moonflow_run(
  workspace_root : String,
  run_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  if !moonflow_safe_run_id(run_id) {
    send_api_error(conn, method_, 400, "Bad Request", "Invalid MoonFlow run id")
    return
  }
  let path = @pathx.join(
    @pathx.join(moonflow_runs_root(workspace_root), run_id),
    "projection.json",
  )
  match moonflow_projection(path) {
    Some(projection) =>
      send_json(
        conn,
        method_,
        moonflow_enriched_projection(
          @pathx.join(moonflow_runs_root(workspace_root), run_id),
          projection,
        ),
      )
    None =>
      send_api_error(conn, method_, 404, "Not Found", "MoonFlow run not found")
  }
}
