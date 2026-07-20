///|
fn pack_home_test_record(status : String) -> PackAppRecord {
  {
    pack_id: "sample",
    version: "1.2.0",
    display_name: "Sample Pack",
    description: "",
    kind: "DomainPack",
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
  }
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
