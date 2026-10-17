///|
async fn desk_plan_fixture() -> (String, @desk.DeskWorkspace, Json) {
  let root = @fs.realpath(@fs.tmpdir(prefix="desk-flow-plan-"))
  let book = root + "/books/fixture"
  @fs.mkdir(book + "/flow", recursive=true)
  let source = moonflow_test_graph([
    moonflow_test_item("one", "requests/one.json"),
  ])
  @fs.write_file(
    book + "/flow/work-graph.json",
    source.stringify(),
    create_mode=CreateNew,
  )
  @fs.write_file(
    book + "/flow/capability-catalog.json",
    (
      {
        "contract_id": "moonflow.capability-catalog.v1",
        "catalog_id": "fixture",
      } : Json).stringify(),
    create_mode=CreateNew,
  )
  let form : Json = {
    "contract_id": "moonflow.declared-plan-form-input.v1",
    "source_kind": "existing-graph",
    "source_graph": source,
    "edits": [
      {
        "work_item_id": "one",
        "input_artifacts": ["requests/revised.json"],
        "depends_on": [],
        "acceptance_criteria": ["Review exact artifact"],
        "timeout_ms": 60000,
      },
    ],
  }
  (
    root,
    @desk.workspace(
      id="fixture-plan",
      name="Fixture",
      root_path=book,
      kind=MoonBook,
    ),
    {
      "action": "prepare",
      "workspace_id": "fixture-plan",
      "request_id": "fixture-request123",
      "form": form,
    },
  )
}

///|
test "Desk preview explicitly lists added source operation and removed step" {
  let original = moonflow_test_item("one", "requests/one.json")
  let form : Json = {
    "source_graph": moonflow_test_graph([original]),
    "edits": [{ "work_item_id": "new" }],
    "added_templates": { "new": "one" },
  }
  let changes = moonflow_plan_changes(form)
  assert_eq(changes.length(), 2)
  assert_eq(json_string(changes[0], "field", default=""), "added_step")
  assert_eq(json_string(changes[0], "after", default=""), "one")
  assert_eq(json_string(changes[1], "field", default=""), "removed_step")
  assert_eq(json_string(changes[1], "work_item_id", default=""), "one")
}

///|
fn desk_plan_stub(calls : Array[String]) -> MoonFlowPlanningRun {
  operation => {
    match operation {
      PrepareForm(form_ref~, catalog_ref~, draft_id~, recorded_at~) => {
        calls.push("prepare")
        assert_true(form_ref.has_suffix("/form.json"))
        assert_true(catalog_ref.has_suffix("/catalog.json"))
        assert_true(draft_id.has_prefix("desk-"))
        assert_eq(recorded_at, "2026-10-07T00:00:00Z")
        Ok(
          (
            {
              "contract_id": "moonflow.declared-plan-preparation-receipt.v1",
              "prepared": {
                "preparation_id": "plan-fixture",
                "source_graph_id": "test-graph-r1",
                "graph": { "graph_id": "plan-fixture" },
              },
              "migration_preview": Json::null(),
              "dispatched": false,
            } : Json).stringify(),
        )
      }
      ApplyPrepared(preparation_id~, catalog_ref=_, evaluated_at=_) => {
        calls.push("apply")
        assert_eq(preparation_id, "plan-fixture")
        Ok(
          (
            {
              "contract_id": "moonflow.declared-plan-apply-receipt.v1",
              "preparation_id": "plan-fixture",
              "status": "applied",
              "projection": {
                "run_id": "plan-fixture",
                "items": [],
                "attempts": 0,
              },
              "migration": Json::null(),
              "dispatched": false,
              "applied_at": "2026-10-07T00:00:00Z",
            } : Json).stringify(),
        )
      }
    }
  }
}

///|
fn desk_plan_action(payload : Json, action : String) -> Json {
  {
    "action": action,
    "workspace_id": json_string(payload, "workspace_id", default=""),
    "request_id": json_string(payload, "request_id", default=""),
  }
}

///|
async test "Desk plan host repeated prepare explicit apply and reload retain exact source with no execution" {
  let (root, workspace, payload) = desk_plan_fixture()
  let original = @fs.read_file(workspace.root_path + "/flow/work-graph.json").binary()
  let calls : Array[String] = []
  let first = moonflow_plan_handle_with(
    root,
    workspace,
    payload,
    "2026-10-07T00:00:00Z",
    desk_plan_stub(calls),
  )
  let repeated = moonflow_plan_handle_with(
    root,
    workspace,
    payload,
    "2026-10-07T00:00:01Z",
    desk_plan_stub(calls),
  )
  assert_eq(first, repeated)
  assert_eq(calls, ["prepare"])
  assert_false(@fs.exists(root + "/.moonsuite/products/moonflow/runs"))
  let form = moonflow_plan_read(
    root,
    moonflow_plan_relative("fixture-request123") + "/form.json",
  )
  assert_eq(
    json_string(form, "source_ref", default=""),
    "books/fixture/flow/work-graph.json",
  )
  assert_eq(moonflow_plan_changes(form).length(), 3)
  let applied = moonflow_plan_handle_with(
    root,
    workspace,
    desk_plan_action(payload, "apply"),
    "2026-10-07T00:00:02Z",
    desk_plan_stub(calls),
  )
  assert_true(
    json_object_field(applied, "applied")
    is Some({ "contract_id": "moonflow.declared-plan-apply-receipt.v1", .. }),
  )
  let reapplied = moonflow_plan_handle_with(
    root,
    workspace,
    desk_plan_action(payload, "apply"),
    "2026-10-07T00:00:03Z",
    desk_plan_stub(calls),
  )
  assert_eq(applied, reapplied)
  assert_eq(calls, ["prepare", "apply", "apply"])
  let loaded = moonflow_plan_handle_with(
    root,
    workspace,
    desk_plan_action(payload, "inspect"),
    "2026-10-07T00:00:04Z",
    desk_plan_stub(calls),
  )
  assert_eq(loaded, applied)
  assert_eq(
    @fs.read_file(workspace.root_path + "/flow/work-graph.json").binary(),
    original,
  )
  assert_false(execution_sandbox_client_available())
}

///|
async test "Desk plan host source and catalog changes refuse apply while preserving prepared packet" {
  for changed in ["work-graph.json", "capability-catalog.json", "formatting"] {
    let (root, workspace, payload) = desk_plan_fixture()
    let calls : Array[String] = []
    ignore(
      moonflow_plan_handle_with(
        root,
        workspace,
        payload,
        "2026-10-07T00:00:00Z",
        desk_plan_stub(calls),
      ),
    )
    let path = workspace.root_path +
      "/flow/" +
      (if changed == "formatting" { "work-graph.json" } else { changed })
    let value = @json.parse(@fs.read_file(path).text())
    guard value is Object(fields) else { fail("fixture") }
    if changed != "formatting" {
      fields["changed"] = true
    }
    @fs.write_file(
      path,
      value.stringify(indent=2),
      create_mode=CreateOrTruncate,
    )
    try
      moonflow_plan_handle_with(
        root,
        workspace,
        desk_plan_action(payload, "apply"),
        "2026-10-07T00:00:01Z",
        desk_plan_stub(calls),
      )
    catch {
      error =>
        assert_true(error.to_string().contains("changed after preparation"))
    } noraise {
      _ => fail("stale plan applied")
    }
    let retained = moonflow_plan_handle_with(
      root,
      workspace,
      desk_plan_action(payload, "inspect"),
      "2026-10-07T00:00:02Z",
      desk_plan_stub(calls),
    )
    assert_false(json_bool(retained, "source_current", default=true))
    assert_eq(calls, ["prepare"])
  }
}

///|
async test "Desk plan host rejects Book switch stale form conflicting request and missing receipt" {
  let (root, workspace, payload) = desk_plan_fixture()
  let calls : Array[String] = []
  let switched = @desk.workspace(
    id="another",
    name="Another",
    root_path=workspace.root_path,
    kind=MoonBook,
  )
  try
    moonflow_plan_handle_with(
      root,
      switched,
      payload,
      "2026-10-07T00:00:00Z",
      desk_plan_stub(calls),
    )
  catch {
    _ => ()
  } noraise {
    _ => fail("Book switch accepted")
  }
  try
    moonflow_plan_handle_with(
      root,
      workspace,
      desk_plan_action(payload, "apply"),
      "2026-10-07T00:00:00Z",
      desk_plan_stub(calls),
    )
  catch {
    _ => ()
  } noraise {
    _ => fail("unprepared plan applied")
  }
  ignore(
    moonflow_plan_handle_with(
      root,
      workspace,
      payload,
      "2026-10-07T00:00:00Z",
      desk_plan_stub(calls),
    ),
  )
  let wrong = @json.parse(payload.stringify())
  guard wrong is { "form": Object(form_fields), .. } else { fail("fixture") }
  form_fields["source_graph"] = moonflow_test_graph([])
  try
    moonflow_plan_handle_with(
      root,
      workspace,
      wrong,
      "2026-10-07T00:00:01Z",
      desk_plan_stub(calls),
    )
  catch {
    _ => ()
  } noraise {
    _ => fail("stale source accepted")
  }
  assert_eq(calls, ["prepare"])
}
