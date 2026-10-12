///|
fn step_host_payload() -> Json {
  {
    "workspace_id": "fixture-book",
    "run_id": "single-fixture",
    "work_item_id": "selected",
    "request_id": "action-0001",
    "action": "execute",
  }
}

///|
async fn step_host_fixture() -> (String, @desk.DeskWorkspace, Json) {
  let root = @fs.realpath(@fs.tmpdir(prefix="desk-step-"))
  let book = root + "/books/fixture-book"
  @fs.mkdir(book, recursive=true)
  let run_root = root + "/.moonsuite/products/moonflow/runs/single-fixture"
  @fs.mkdir(run_root, recursive=true)
  let projection : Json = {
    "run_id": "single-fixture",
    "book_id": "fixture-book",
    "items": [{ "work_item_id": "selected" }, { "work_item_id": "other" }],
  }
  @fs.write_file(
    run_root + "/projection.json",
    projection.stringify(),
    create_mode=CreateNew,
  )
  (
    root,
    @desk.workspace(
      id="fixture-book",
      name="Fixture",
      root_path=book,
      kind=MoonBook,
    ),
    projection,
  )
}

///|
fn step_host_result() -> Json {
  {
    "contract_id": "moonflow.single-step-result.v1",
    "run_id": "single-fixture",
    "work_item_id": "selected",
    "request_id": "action-0001",
    "status": "review",
    "message": "Digital artifact awaits explicit review",
    "qualification": {
      "evidence_class": "fixture-reference-only",
      "production_qualified": false,
      "physical_authority": false,
    },
  }
}

///|
test "single step browser request cannot supply commands config authority or paths" {
  assert_true(moonflow_single_step_payload_valid(step_host_payload()))
  for
    field in [
      "executable", "configuration_ref", "envelope", "argv", "workspace", "source_ref",
    ] {
    let payload = step_host_payload()
    if payload is Object(fields) {
      fields[field] = "host-override"
    }
    assert_false(moonflow_single_step_payload_valid(payload))
  }
  for invalid in ["../run", "--run", "run;dispatch", "", "run/path"] {
    assert_false(moonflow_single_step_identifier(invalid))
  }
}

///|
async test "single step host selects exact imported Book run item and typed operation" {
  let (root, book, _) = step_host_fixture()
  let calls : Array[String] = []
  let result = moonflow_single_step_handle_with(
    root,
    book,
    step_host_payload(),
    "2026-10-07T00:00:00Z",
    operation => {
      match operation {
        @trusted_host.ExecuteOne(run_id~, item_id~, request_id~, recorded_at~) => {
          assert_eq(run_id, "single-fixture")
          assert_eq(item_id, "selected")
          assert_eq(request_id, "action-0001")
          assert_eq(recorded_at, "2026-10-07T00:00:00Z")
          calls.push(item_id)
        }
        _ => fail("Unexpected reconciliation")
      }
      Ok(step_host_result().stringify())
    },
  )
  assert_eq(calls, ["selected"])
  assert_eq(json_string(result, "status", default=""), "review")
  assert_false(execution_sandbox_client_available())
  let wrong_book = @desk.workspace(
    id="other-book",
    name="Other",
    root_path=book.root_path,
    kind=MoonBook,
  )
  let wrong = step_host_payload()
  if wrong is Object(fields) {
    fields["workspace_id"] = "other-book"
  }
  let denied = try {
    let _ = moonflow_single_step_handle_with(
      root,
      wrong_book,
      wrong,
      "2026-10-07T00:00:00Z",
      _ => {
        calls.push("bad")
        Ok(step_host_result().stringify())
      },
    )
    false
  } catch {
    _ => true
  }
  assert_true(denied)
  assert_eq(calls, ["selected"])
}

///|
async test "single step lost malformed and overclaimed responses require reconciliation" {
  let (root, book, _) = step_host_fixture()
  for
    output in [
      Err("Response interrupted"),
      Ok("not JSON"),
      Ok("{}"),
      Ok(
        "{\"contract_id\":\"moonflow.single-step-result.v1\",\"run_id\":\"single-fixture\",\"work_item_id\":\"selected\",\"request_id\":\"action-0001\",\"status\":\"review\",\"qualification\":{\"evidence_class\":\"production\",\"production_qualified\":true,\"physical_authority\":false}} ",
      ),
    ] {
    let result = moonflow_single_step_handle_with(
      root,
      book,
      step_host_payload(),
      "2026-10-07T00:00:00Z",
      _ => output,
    )
    assert_eq(json_string(result, "status", default=""), "reconcile-required")
  }
}

///|
async test "single step run responses restore safe action identity without adapter body" {
  let (root, _, projection) = step_host_fixture()
  let run_root = root + "/.moonsuite/products/moonflow/runs/single-fixture"
  @fs.mkdir(run_root + "/single-step")
  @fs.write_file(
    run_root + "/single-step/selected.action.json",
    (
      {
        "contract_id": "moonflow.single-step-action.v1",
        "run_id": "single-fixture",
        "work_item_id": "selected",
        "request_id": "original-action",
        "status": "reconcile-required",
        "message": "Unknown",
        "adapter_request": {
          "envelope": "must-not-leak",
          "command": "must-not-leak",
        },
      } : Json).stringify(),
    create_mode=CreateNew,
  )
  let actions = moonflow_single_step_actions(run_root, projection)
  assert_eq(actions.length(), 1)
  assert_eq(
    json_string(actions[0], "request_id", default=""),
    "original-action",
  )
  assert_false(actions.to_json().stringify().contains("must-not-leak"))
  assert_false(actions.to_json().stringify().contains("adapter_request"))
}

///|
async test "single step only correlated proven no attempt blockers allow setup retry" {
  let (root, book, _) = step_host_fixture()
  let blocker : Json = {
    "contract_id": "moonflow.single-step-blocker.v1",
    "run_id": "single-fixture",
    "work_item_id": "selected",
    "request_id": "action-0001",
    "status": "blocked",
    "message": "Missing existing authority",
    "no_attempt_created": true,
  }
  let result = moonflow_single_step_handle_with(
    root,
    book,
    step_host_payload(),
    "2026-10-07T00:00:00Z",
    _ => Ok(blocker.stringify()),
  )
  assert_eq(json_string(result, "status", default=""), "blocked")
  let retry = moonflow_single_step_handle_with(
    root,
    book,
    step_host_payload(),
    "2026-10-07T00:00:00Z",
    _ => Ok(step_host_result().stringify()),
  )
  assert_eq(json_string(retry, "request_id", default=""), "action-0001")
  assert_eq(json_string(retry, "status", default=""), "review")
  if blocker is Object(fields) {
    fields["no_attempt_created"] = false
  }
  let uncertain = moonflow_single_step_handle_with(
    root,
    book,
    step_host_payload(),
    "2026-10-07T00:00:00Z",
    _ => Ok(blocker.stringify()),
  )
  assert_eq(json_string(uncertain, "status", default=""), "reconcile-required")
  let raised = moonflow_single_step_handle_with(
    root,
    book,
    step_host_payload(),
    "2026-10-07T00:00:00Z",
    _ => fail("Unexpected host failure after send"),
  )
  assert_eq(json_string(raised, "status", default=""), "reconcile-required")
}
