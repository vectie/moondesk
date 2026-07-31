///|
fn pack_home_test_record(status : String) -> PackAppRecord {
  {
    pack_id: "sample",
    version: "1.2.0",
    display_name: "Sample Pack",
    description: "",
    kind: "DomainPack",
    area_id: None,
    area_category: None,
    area_label: None,
    presentation_icon: None,
    presentation_surface: None,
    primary_action_label: None,
    launch_url: if status == "configured" {
      "/pack-apps/sample/"
    } else {
      ""
    },
    status,
    entrypoint_count: 1,
    workflow_count: 2,
    tool_count: 4,
    configuration_message: "status detail",
    template_count: None,
    templates: None,
  }
}

///|
fn pack_home_test_template(blocked : Bool) -> PackTemplateRecord {
  {
    contract_id: "moonsuite.template-envelope.v1",
    template_id: "sample-template",
    owner_product: "sample",
    version: "1.0.0",
    catalog_id: "sample.templates",
    catalog_version: "1.0.0",
    catalog_digest: "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
    source_ref: "templates/sample.json",
    source_digest: "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    template_class: "domain_project",
    maturity: "local-qualified",
    title: "Sample outcome",
    summary: "Create one reviewable outcome.",
    primary_user: "operator",
    primary_action: "Confirm inputs",
    completion_statement: "A named reviewer accepts or rejects the outcome.",
    icon: "S",
    migration_policy: {
      strategy: "owner-reviewed",
      compatible_from: [],
      note: "The owner reviews every version change.",
    },
    preview_ref: "/sample",
    qualification_evidence_refs: [
      {
        kind: "qualification_report",
        ref: "docs/sample.md",
        digest: "sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
      },
    ],
    requirements: {
      operations: [
        {
          operation_ref: "sample/prepare@1.0.0",
          input_schema_ref: "sample/input@1.0.0",
          output_schema_ref: "sample/output@1.0.0",
          required: true,
        },
      ],
      schemas: ["sample/input@1.0.0", "sample/output@1.0.0"],
    },
    ceilings: {
      authorities: ["workspace-mutation"],
      external_effect: false,
      cost: {
        status: "not_applicable",
        currency: "N/A",
        max_minor: Json::null(),
        note: "No provider cost",
      },
      licensing: {
        status: "cleared",
        classes: ["local"],
        note: "Local inputs only",
      },
      review: { required: true, authority: "owner", gates: ["acceptance"] },
    },
    recovery: {
      blocked,
      reason: if blocked { "Missing capability" } else { "" },
      next_action: "Open the owner",
    },
    owner_payload: Json::object({}),
  }
}

///|
test "Pack Home keeps legacy catalog records without an app area" {
  let record : PackAppRecord = @json.from_json({
    "pack_id": "legacy",
    "version": "1.0.0",
    "display_name": "Legacy Pack",
    "description": "",
    "kind": "DomainPack",
    "launch_url": "",
    "status": "workflow_only",
    "entrypoint_count": 0,
    "workflow_count": 1,
    "tool_count": 0,
    "configuration_message": "Workflow only",
  })
  assert_false(pack_has_declared_area(record))
  assert_eq(pack_area_value(record.area_label), "")
}

///|
#warnings("-alert_unstable")
test "Pack Home exposes a complete generic app area" {
  let record = {
    ..pack_home_test_record("configured"),
    area_id: Some("finance.research"),
    area_category: Some("finance"),
    area_label: Some("Finance"),
  }
  assert_true(pack_has_declared_area(record))
  assert_eq(pack_area_value(record.area_id), "finance.research")
  assert_eq(pack_area_value(record.area_category), "finance")
  assert_eq(pack_area_value(record.area_label), "Finance")
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(render_pack_area(record)),
  )
  assert_true(markup.contains(">Finance</span>"))
  assert_true(markup.contains("data-area-id=\"finance.research\""))
  assert_true(markup.contains("data-area-category=\"finance\""))
}

///|
test "Pack Home distinguishes installed state from runtime readiness" {
  assert_eq(pack_status_label("configured"), "Ready")
  assert_eq(pack_status_label("configuration_required"), "Setup required")
  assert_eq(pack_status_label("workflow_only"), "Workflow only")
  assert_true(
    pack_default_description(pack_home_test_record("configured")).contains(
      "2 workflow(s)",
    ),
  )
}

///|
test "Pack Home catalog result becomes the visible product list" {
  let catalog : PackAppCatalog = {
    app_count: 2,
    configured_count: 1,
    template_count: None,
    apps: [
      pack_home_test_record("configured"),
      { ..pack_home_test_record("workflow_only"), pack_id: "workflow" },
    ],
  }
  let (_, model) = update_workspace_results(
    code_mode_test_dispatch,
    LoadedPackApps(Ok(catalog)),
    init_model(),
  )
  assert_eq(model.pack_apps.length(), 2)
  assert_eq(model.pack_apps_status, "1 ready · 2 installed")
}

///|
#warnings("-alert_unstable")
test "template launch preserves safe default context and states the owner boundary" {
  let pack = {
    ..pack_home_test_record("configured"),
    launch_url: "/pack-apps/sample/?seed=20260727",
  }
  let template = pack_home_test_template(false)
  assert_eq(
    template_launch_url(pack, template),
    "/pack-apps/sample/?seed=20260727&template=sample-template&template_version=1.0.0&template_catalog=sample.templates&template_catalog_version=1.0.0&template_catalog_digest=sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb&template_source_digest=sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  )
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(render_template_card(pack, template)),
  )
  assert_true(markup.contains("Review in Sample Pack"))
  assert_true(markup.contains("does not create an instance or start execution"))
  assert_true(markup.contains("data-template-id=\"sample-template\""))
}

///|
#warnings("-alert_unstable")
test "collaboration surface is honest and read only before a typed adapter publishes records" {
  let model = {
    ..init_model(),
    selected_workspace_id: "sample-workspace",
    collaboration_status: "not_initialized",
    collaboration_message: "Collaboration has not been initialized for this MoonBook",
    collaboration_next_action: "initialize_in_moonflow",
  }
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_collaboration_surface(code_mode_test_dispatch, model),
    ),
  )
  assert_true(markup.contains("Collaboration is not initialized"))
  assert_true(markup.contains("Open MoonFlow"))
  assert_true(markup.contains("Read only in MoonDesk"))
  assert_true(markup.contains("data-principal-contract=\"moonsuite.principal-ref.v1\""))
  assert_true(markup.contains("data-handover-contract=\"moonsuite.handover-control.v1\""))
  assert_true(markup.contains("data-testid=\"collaboration-open-moonflow\""))
}
