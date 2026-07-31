///|
fn flow_test_item(status : String) -> MoonFlowItemProjection {
  {
    work_item_id: "research",
    declaration_id: "decl-research",
    product_id: "moonwiki",
    requested_authority: "knowledge-write",
    acceptance_criteria: ["sources are reviewed"],
    input_contracts: ["moonbook/research-request@1.0.0"],
    output_contracts: ["moonbook/research-evidence@1.0.0"],
    required_claim: "research-evidence",
    input_artifacts: ["requests/research.json"],
    timeout_ms: 30000,
    depends_on: [],
    status,
    attempt_count: 1,
    request_id: "request-1",
    result_id: "result-1",
    active_attempt_id: "attempt-1",
    idempotency_key: "retry-1",
    external_job_id: "job-1",
    attempt_status: "completed",
    operation: "research",
    input_digest: "input-digest",
    output_digest: "output-digest",
    error_kind: "",
    compensable: false,
    blocker: "",
    acceptance_review_id: "review-1",
    acceptance_review_artifact: "evidence/review.json",
    acceptance_reviewer_id: "reviewer-1",
    artifacts: ["evidence/research.json"],
    approvals: ["reviewer-1"],
    adapter_id: Some("moonbook-adapter"),
    claim_ceiling: Some("accepted-knowledge"),
    review_required: Some(true),
    health_checked_at: Some("2026-07-31T00:00:00Z"),
    health_valid_until: Some("2026-08-01T00:00:00Z"),
    health_evidence_ref: Some("evidence/health.json"),
    health_evidence_digest: Some(
      "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
    ),
  }
}

///|
test "Flow exposes durable execution identities" {
  let item = flow_test_item("review")
  assert_eq(item.request_id, "request-1")
  assert_eq(item.result_id, "result-1")
  assert_eq(item.active_attempt_id, "attempt-1")
  assert_eq(item.idempotency_key, "retry-1")
  assert_eq(item.external_job_id, "job-1")
}

///|
test "Flow explains governed readiness and acceptance" {
  assert_eq(
    moonflow_item_explanation(flow_test_item("ready")),
    "Dependencies are accepted; the declared product may execute now",
  )
  assert_eq(
    moonflow_item_explanation(flow_test_item("accepted")),
    "Accepted by explicit review with bound output evidence",
  )
}

///|
test "Flow exposes failure reasons instead of a status-only dead end" {
  let blocked = { ..flow_test_item("blocked"), blocker: "source missing" }
  assert_eq(moonflow_item_explanation(blocked), "source missing")
  let failed = {
    ..flow_test_item("failed"),
    acceptance_review_id: "",
    blocker: "",
    error_kind: "tool-timeout",
  }
  assert_eq(
    moonflow_item_explanation(failed),
    "Execution reported tool-timeout",
  )
}

///|
test "Flow describes migrated checkpoints without a zero-attempt implication" {
  let item = {
    ..flow_test_item("accepted"),
    attempt_count: 0,
    attempt_status: "checkpoint-reused",
  }
  assert_eq(moonflow_item_execution_label(item), "checkpoint reused")
}

///|
test "Flow first-run action requires a selected MoonBook" {
  let (_, missing) = update_workspace_surface_actions(
    code_mode_test_dispatch,
    PrepareMoonFlow,
    init_model(),
  )
  assert_eq(missing.moonflow_status, "Select a MoonBook first")
  let (_, selected) = update_workspace_surface_actions(
    code_mode_test_dispatch,
    PrepareMoonFlow,
    { ..init_model(), selected_workspace_id: "book-demo" },
  )
  assert_true(selected.moonflow_status.contains("up to 30 seconds"))
}

///|
#warnings("-alert_unstable")
test "Flow composition exposes exact catalog-bound contract metadata" {
  let composition : MoonFlowComposition = @json.from_json({
    "contract_id": "composition-v1",
    "workspace_id": "book-demo",
    "source_graph_id": "graph-1",
    "book_id": "demo",
    "declaration_revision": "1",
    "source_digest": "digest",
    "status": "draft",
    "selected_item_ids": ["research"],
    "items": [
      {
        "work_item_id": "research",
        "declaration_id": "decl-research",
        "product_id": "moonwiki",
        "requested_authority": "knowledge-write",
        "acceptance_criteria": ["sources are reviewed"],
        "depends_on": [],
        "operation": "research",
        "input_contracts": ["moonbook/research-request@1.0.0"],
        "output_contracts": ["moonbook/research-evidence@1.0.0"],
        "required_claim": "research-evidence",
        "input_artifacts": ["requests/research.json"],
        "timeout_ms": 30000,
        "adapter_id": "moonbook-adapter",
        "claim_ceiling": "accepted-knowledge",
        "review_required": true,
        "health_checked_at": "2026-07-31T00:00:00Z",
        "health_valid_until": "2026-08-01T00:00:00Z",
        "health_evidence_ref": "evidence/health.json",
        "health_evidence_digest": "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
      },
    ],
    "catalog_id": "catalog-2026-07-31",
    "catalog_status": "conformant",
    "evaluated_at": "2026-07-31T12:00:00Z",
    "validation_status": "accepted",
    "validation_issues": [],
  })
  assert_true(composition.selected_item_ids == ["research"])
  assert_eq(composition.items[0].work_item_id, "research")
  assert_eq(composition.items[0].operation, "research")
  assert_eq(composition.items[0].declaration_id, "decl-research")
  assert_eq(composition.items[0].input_contracts, [
    "moonbook/research-request@1.0.0",
  ])
  assert_eq(composition.items[0].claim_ceiling, Some("accepted-knowledge"))
  assert_eq(composition.items[0].review_required, Some(true))
  assert_eq(composition.catalog_id, Some("catalog-2026-07-31"))
  assert_eq(composition.validation_status, Some("accepted"))
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_moonflow_composition_canvas(dispatch, {
        ..init_model(),
        moonflow_composition: Some(composition),
      }),
    ),
  )
  assert_true(markup.contains("decl-research"))
  assert_true(markup.contains("moonbook/research-request@1.0.0"))
  assert_true(markup.contains("moonbook/research-evidence@1.0.0"))
  assert_true(markup.contains("Claim ceiling · accepted-knowledge"))
  assert_true(markup.contains("Named review required"))
  assert_true(markup.contains("Catalog validated"))
  assert_true(markup.contains("validation accepted"))
  assert_true(markup.contains(">Fit</button>"))
  let continuation = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_moonflow_composition_continuation(Some(composition)),
    ),
  )
  assert_true(continuation.contains("Graph-derived continuation"))
  assert_true(continuation.contains("moonwiki"))
  assert_true(continuation.contains("research"))
  assert_false(continuation.contains("MoonRobo"))
  assert_false(continuation.contains("MoonMoon"))
}

///|
test "Flow import status keeps the durable run or next action visible" {
  let decoded : MoonFlowImportResult = @json.from_json({
    "book_id": "book-demo",
    "run_id": "run-demo-r1",
    "ok": true,
    "status": "imported",
    "message": "Executable document imported into MoonFlow",
    "api_contract": "moonsuite.phase6.v1",
    "next_action": "open_run",
  })
  assert_eq(decoded.run_id, "run-demo-r1")
  assert_eq(
    moonflow_import_status({
      ok: true,
      status: "imported",
      message: "Executable document imported into MoonFlow",
      next_action: "open_run",
      book_id: "book-demo",
      run_id: "run-demo-r1",
      capability_evidence: None,
    }),
    "Executable document imported into MoonFlow · run run-demo-r1",
  )
  assert_eq(
    moonflow_import_status({
      ok: false,
      status: "declaration_missing",
      message: "This MoonBook has no executable Work graph yet",
      next_action: "create_executable_document_in_wiki",
      book_id: "book-demo",
      run_id: "",
      capability_evidence: None,
    }),
    "This MoonBook has no executable Work graph yet · next: create executable document in wiki",
  )
}

///|
test "Flow adapter readiness requires catalog evidence, not product inventory" {
  let item = {
    work_item_id: "research",
    declaration_id: "decl-research",
    product_id: "moonbook",
    requested_authority: "workspace-mutation",
    acceptance_criteria: ["evidence retained"],
    depends_on: [],
    operation: "moonbook/wiki.requirements.prepare@0.1.0",
    input_contracts: ["moonbook/wiki-requirements-prepare@1.0.0"],
    output_contracts: ["moonbook/wiki-requirements-packet@1.0.0"],
    required_claim: "accepted-knowledge",
    input_artifacts: ["requests/research.json"],
    timeout_ms: 30000,
    adapter_id: None,
    claim_ceiling: None,
    review_required: None,
    health_checked_at: None,
    health_valid_until: None,
    health_evidence_ref: None,
    health_evidence_digest: None,
  }
  let composition = {
    selected_item_ids: ["research"],
    items: [item],
    catalog_id: None,
    catalog_status: None,
    evaluated_at: None,
    validation_status: None,
    validation_issues: None,
  }
  assert_eq(
    moonflow_composition_item_catalog_status(composition, item),
    "Catalog evidence unavailable",
  )
}

///|
test "Flow scopes suite-wide runs to the selected MoonBook root" {
  assert_true(
    moonflow_book_root_matches(
      "/Users/kq/moonsuite/books/unified-lunar-robot", "unified-lunar-robot",
    ),
  )
  assert_false(
    moonflow_book_root_matches(
      "/Users/kq/moonsuite/books/unified-lunar-robot", "lunar-robot-autonomy-v3",
    ),
  )
  assert_true(moonflow_book_root_matches("books\\demo", "demo"))
}
