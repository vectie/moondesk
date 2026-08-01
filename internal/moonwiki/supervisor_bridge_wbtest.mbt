///|
fn supervisor_bridge_execution_fixture(action : String) -> Json {
  {
    "schema": "moontown.supervisor-execution-handoff.v1",
    "handoff_id": "execution-command-1",
    "command_id": "command-1",
    "request_digest": "sha256:" + "1".repeat(64),
    "owner_user_id": "user-1",
    "supervisor_profile_id": "supervisor-1",
    "run_id": "run-1",
    "action": action,
    "instruction": "bounded instruction",
    "expected_cursor": 4,
    "created_at_ms": 1000,
  }
}

///|
fn supervisor_bridge_delegate_fixture() -> Json {
  {
    "schema": "moontown.supervisor-execution-handoff.v2",
    "handoff_id": "execution-command-1",
    "command_id": "command-1",
    "request_digest": "sha256:" + "1".repeat(64),
    "owner_user_id": "user-1",
    "supervisor_profile_id": "supervisor-1",
    "parent_run_id": "run-1",
    "action": "delegate",
    "instruction": "bounded instruction",
    "target_runtime": "moonclaw",
    "command_kind": "bounded_worker_assignment",
    "worker_task": {
      "task_id": "command-1",
      "conversation_id": "execution-command-1",
      "title": "Bounded worker",
      "cwd": "workspace://workspace-a/books/book-a",
      "model": "gpt-5.6-sol",
      "web_search": false,
      "metadata": { "workspace_id": "workspace-a", "book_id": "book-a" },
    },
    "worker_bounds": {
      "claim_ceiling": "reviewable",
      "budget": {
        "max_cost_micro_usd": "2000000",
        "max_runtime_ms": "600000",
        "max_tokens": "20000",
        "max_artifacts": 8,
      },
      "artifact_prefixes": ["books/book-a/artifacts"],
      "expires_at": "2026-08-01T01:00:00Z",
    },
    "worker_bounds_source": "user_supplied",
    "created_at_ms": "1785542400000",
  }
}

///|
test "saved delegate response requires object-or-null provider receipt" {
  let valid : Json = {
    "transport_endpoint": "delegate",
    "forwarded_response": {
      "contract_id": "moonclaw.supervisor-delegate-intent-result.v1",
      "provider_receipt": Json::null(),
    },
  }
  assert_true(supervisor_bridge_saved_execution_response_valid(valid))
  let legacy : Json = {
    "transport_endpoint": "delegate",
    "forwarded_response": {
      "contract_id": "moonclaw.supervisor-delegate-intent-result.v1",
      "provider_receipt": [{ "status": "accepted" }],
    },
  }
  assert_false(supervisor_bridge_saved_execution_response_valid(legacy))
}

///|
fn supervisor_bridge_child_retry_fixture() -> Json {
  {
    "schema": "moontown.supervisor-execution-handoff.v2",
    "handoff_id": "execution-command-retry",
    "command_id": "command-retry",
    "request_digest": "sha256:" + "2".repeat(64),
    "owner_user_id": "user-1",
    "supervisor_profile_id": "supervisor-1",
    "parent_run_id": "run-1",
    "target_run_id": "worker-run-1",
    "action": "child_retry",
    "instruction": "retry after review",
    "target_runtime": "moonclaw",
    "command_kind": "child_run_control",
    "worker_bounds_source": "not_applicable",
    "created_at_ms": "1785542400000",
  }
}

///|
async test "supervisor bridge maps only exact MoonClaw command DTOs" {
  let wake = supervisor_bridge_execution_dispatch(
    supervisor_bridge_execution_fixture("wake"),
  )
  guard wake is Ok(wake) else { fail("wake should map") }
  assert_eq(wake.endpoint, "wake")
  assert_eq(
    wake.request_digest,
    supervisor_bridge_digest({
      "supervisor_id": "supervisor-1",
      "run_id": "run-1",
    }),
  )
  let stop = supervisor_bridge_execution_dispatch(
    supervisor_bridge_execution_fixture("cancel"),
  )
  guard stop is Ok(stop) else { fail("cancel should map") }
  assert_eq(stop.endpoint, "stop")
  let retry = supervisor_bridge_execution_dispatch(
    supervisor_bridge_execution_fixture("retry"),
  )
  guard retry is Ok(retry) else { fail("retry should map") }
  assert_eq(retry.endpoint, "retry-resume")
  assert_eq(json_object_field(retry.body, "action").unwrap_or(Json::null()), [
    "Retry", "run-1",
  ])
  let child_retry = supervisor_bridge_execution_dispatch(
    supervisor_bridge_child_retry_fixture(),
  )
  guard child_retry is Ok(child_retry) else { fail("child retry should map") }
  assert_eq(child_retry.endpoint, "worker-retry-resume")
  let root = @pathx.join(
    "/tmp",
    "moondesk-supervisor-bridge-" + @async.now().to_string(),
  )
  let book_root = workspace_context(root).book_root("book-a")
  @fsx.make_directory(book_root, recursive=true, exists_ok=true)
  @fsx.write_to_file(@pathx.join(book_root, "book.json"), "{}\n")
  let delegate = supervisor_bridge_execution_dispatch(
    supervisor_bridge_delegate_fixture(),
    workspace_root=root,
  )
  guard delegate is Ok(delegate) else { fail("delegate should map") }
  assert_eq(delegate.endpoint, "delegate")
  assert_eq(delegate.body, {
    "supervisor_id": "supervisor-1",
    "instruction": "bounded instruction",
    "task": {
      "task_id": "command-1",
      "conversation_id": "execution-command-1",
      "title": "Bounded worker",
      "cwd": book_root,
      "model": "gpt-5.6-sol",
      "web_search": false,
      "metadata": { "workspace_id": "workspace-a", "book_id": "book-a" },
    },
    "scope": {
      "claim_ceiling": "reviewable",
      "budget": {
        "max_cost_micro_usd": "2000000",
        "max_runtime_ms": "600000",
        "max_tokens": "20000",
        "max_artifacts": 8,
      },
      "artifact_prefixes": ["books/book-a/artifacts"],
      "expires_at": "2026-08-01T01:00:00Z",
    },
  })
}

///|
async test "supervisor bridge accepts every trusted installed-book marker" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-supervisor-markers-" + @async.now().to_string(),
  )
  for marker in ["book.json", "book/book.json", "book/moonbook-ui-state.json"] {
    let book_id = match marker {
      "book.json" => "root-manifest"
      "book/book.json" => "nested-manifest"
      _ => "ui-state"
    }
    let book_root = workspace_context(root).book_root(book_id)
    let marker_path = @pathx.join(book_root, marker)
    @fsx.make_directory(
      @pathx.dirname(marker_path),
      recursive=true,
      exists_ok=true,
    )
    @fsx.write_to_file(marker_path, "{}\n")
    assert_true(supervisor_bridge_installed_book_marker_exists(book_root))
    assert_eq(
      supervisor_bridge_delegate_cwd(root, {
        "workspace_id": "workspace-a",
        "book_id": book_id,
      }),
      Ok(book_root),
    )
  }
  let missing_root = workspace_context(root).book_root("missing-marker")
  @fsx.make_directory(missing_root, recursive=true, exists_ok=true)
  assert_false(supervisor_bridge_installed_book_marker_exists(missing_root))
  assert_true(
    supervisor_bridge_delegate_cwd(root, {
      "workspace_id": "workspace-a",
      "book_id": "missing-marker",
    })
    is Err(_),
  )
}

///|
test "supervisor bridge host grant is exact and receiver bound" {
  let source = supervisor_bridge_execution_fixture("wake")
  let digest = "sha256:" + "a".repeat(64)
  let grant = supervisor_bridge_materialized_grant(
    source, "execution", "execution-command-1", digest,
  )
  guard grant is Ok(grant) else { fail("durable user action should grant") }
  assert_eq(json_string(grant, "actor_user_id", default=""), "user-1")
  assert_eq(json_string(grant, "request_digest", default=""), digest)
  let authority = json_object_field(grant, "authority").unwrap()
  assert_eq(json_string(authority, "digest", default=""), digest)
  let principal = json_object_field(authority, "principal").unwrap()
  assert_eq(
    json_string(principal, "principal_id", default=""),
    "moonclaw-daemon",
  )
  assert_eq(json_string(principal, "kind", default=""), "service")
  let operation = supervisor_bridge_execution_dispatch(source)
  guard operation is Ok(operation) else { fail("wake operation should map") }
  let exact_grant = supervisor_bridge_materialized_grant(
    source,
    "execution",
    "execution-command-1",
    operation.request_digest,
  )
  guard exact_grant is Ok(exact_grant) else { fail("operation should grant") }
  let command = supervisor_bridge_execution_dispatch(source, grant=exact_grant)
  guard command is Ok(command) else { fail("wake command should bind") }
  assert_true(
    supervisor_bridge_runtime_command_matches(
      command.body,
      operation.body,
      source,
      operation.request_digest,
    ),
  )
}

///|
test "supervisor bridge reconciles terminal Bookkeeper rejections once" {
  let submission : Json = {
    "submission": {
      "record_id": "outcome-1",
      "record_version": "1",
      "record_digest": "sha256:" + "c".repeat(64),
    },
  }
  for
    state in [
      "deliverable_rejected", "assessment_rejected", "proposal_rejected",
    ] {
    let receipt : Json = {
      "contract_version": "moonbook.bookkeeper.product_outcome_submission_receipt.v1",
      "submission": {
        "record_id": "outcome-1",
        "record_version": "1",
        "record_digest": "sha256:" + "c".repeat(64),
      },
      "state": state,
      "activation_authorized": false,
      "external_side_effects_applied": false,
    }
    assert_true(
      supervisor_bridge_bookkeeper_receipt_matches(receipt, submission),
    )
    assert_false(supervisor_bridge_bookkeeper_state_claimable(state))
  }
}
