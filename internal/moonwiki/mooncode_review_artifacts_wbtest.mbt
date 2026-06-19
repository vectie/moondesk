///|
async test "mooncode action plan writes durable moonbook manifest" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-mooncode-action-plan-wbtest-" +
    @desk.stable_id("mooncode-action-plan-test", @async.now().to_string()),
  )
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  let session : Json = {
    "id": "code-demo",
    "workspace_id": "book-demo",
    "workspace_name": "Demo Book",
    "workspace_root": root,
  }
  let payload : Json = { "context_path": "tools/demo/main.mbt" }
  let message = @mooncode.command_message("run_tests", payload)
  let packet = @mooncode.projected_command_packet(
    session, payload, "run_tests", message, "2026-06-14T00:00:00Z", "tools/demo/main.mbt",
  )
  let runtime_command = @mooncode.runtime_command_record(
    session, payload, message, packet,
  )
  append_mooncode_command_log(root, "code-demo", packet)
  append_mooncode_runtime_command_log(root, "code-demo", runtime_command)
  append_mooncode_runtime_dispatch_log(root, "code-demo", {
    "protocol": "mooncode.v1",
    "kind": "mooncode.runtime-dispatch",
    "command_id": json_string(packet, "command_id", default=""),
    "session_id": "code-demo",
    "status": "native-dispatched",
  })
  let manifest = write_mooncode_action_plan_manifest(root, session)
  assert_eq(json_string(manifest, "kind", default=""), "mooncode-action-plan")
  assert_eq(json_int(manifest, "action_count", default=0), 1)
  assert_eq(
    json_string(manifest, "next_required_action", default=""),
    "await_runtime_proof",
  )
  let relative = json_string(manifest, "manifest_path", default="")
  assert_eq(relative, "wiki/reviews/mooncode/code-demo/action-plan.json")
  assert_true(@fs.exists(@pathx.join(root, relative)))
  let actions = json_array_items(manifest, "actions")
  assert_eq(json_string(actions[0], "runtime_state", default=""), "delivered")
}

///|
async test "mooncode package artifacts preserve raw ids while paths stay safe" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-mooncode-package-id-wbtest-" +
    @desk.stable_id("mooncode-package-id-test", @async.now().to_string()),
  )
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  let session : Json = {
    "id": "agent/unsafe",
    "workspace_id": "book-demo",
    "workspace_name": "Demo Book",
    "workspace_root": root,
  }
  let command_packet : Json = {
    "protocol": "mooncode.v1",
    "command_id": "cmd/unsafe",
    "session_id": "agent/unsafe",
    "workspace_root": root,
  }
  match
    write_mooncode_review_receipt_if_needed(
      session, "package", command_packet, "tools/demo/main.mbt", "Package unsafe id command",
      "2026-06-16T00:00:00Z",
    ) {
    Some(with_package) => {
      let receipt = json_object_field_or_empty(
        with_package, "mooncode_last_review_receipt",
      )
      assert_eq(json_string(receipt, "session_id", default=""), "agent/unsafe")
      assert_eq(json_string(receipt, "command_id", default=""), "cmd/unsafe")
      assert_eq(
        json_string(receipt, "receipt_path", default=""),
        "wiki/reviews/mooncode/session/package-command.json",
      )
      assert_true(
        @fs.exists(
          @pathx.join(root, json_string(receipt, "receipt_path", default="")),
        ),
      )
      let package_manifest = json_object_field_or_empty(
        with_package, "mooncode_last_package_manifest",
      )
      assert_eq(
        json_string(package_manifest, "session_id", default=""),
        "agent/unsafe",
      )
      assert_eq(
        json_string(package_manifest, "command_id", default=""),
        "cmd/unsafe",
      )
      assert_eq(
        json_string(package_manifest, "manifest_path", default=""),
        "portable/app-tool/mooncode/session/package-command.json",
      )
      let index = json_object_field_or_empty(
        with_package, "mooncode_last_package_index_manifest",
      )
      assert_eq(json_string(index, "session_id", default=""), "agent/unsafe")
      assert_eq(
        json_string(index, "package_root", default=""),
        "portable/app-tool/mooncode/session",
      )
      assert_true(
        @fs.exists(
          @pathx.join(root, "portable/app-tool/mooncode/session/index.json"),
        ),
      )
    }
    None => fail("package action should write review/package artifacts")
  }
}

///|
test "mooncode native response appends runtime events" {
  let event = @mooncode.event_record(
    id="native-event",
    lane="runtime",
    kind="runtime_update",
    title="Runtime update",
    status="running",
    created_at="1",
    detail="native",
  )
  let turn_event = @mooncode.event_record(
    id="runtime-turn-event",
    lane="tool",
    kind="tool_result",
    title="Tool result",
    status="done",
    created_at="2",
    detail="turn",
  )
  let package_event = @mooncode.event_record(
    id="runtime-package-event",
    lane="artifact",
    kind="runtime.package_verified",
    title="Package verified",
    status="verified",
    created_at="3",
    detail="package",
  )
  let session = @mooncode.append_projected_native_response_events(
    Json::object({}),
    {
      "events": [event],
      "execution": { "events": [turn_event] },
      "turn_receipt": { "events": [turn_event] },
      "package_events": [package_event],
      "turns": [{ "package_events": [package_event] }],
    },
    loop_fallback_created_at="2026-06-17T00:00:00Z",
  )
  let events = json_array_items(session, "mooncode_command_events")
  assert_eq(events.length(), 3)
  assert_eq(json_string(events[0], "id", default=""), "native-event")
  assert_eq(json_string(events[1], "id", default=""), "runtime-turn-event")
  assert_eq(json_string(events[2], "id", default=""), "runtime-package-event")
}

///|
test "mooncode native runtime loop response records loop status event" {
  let session = @mooncode.append_projected_native_response_events(
    Json::object({}),
    {
      "kind": "mooncode-runtime-loop",
      "protocol": "mooncode.v1",
      "session_id": "code-demo",
      "book_root": "/tmp/demo-book",
      "consumer_id": "moondesk-native-runtime-loop",
      "ran_turn_count": 0,
      "failed_turn_count": 0,
      "stopped_by": "idle",
      "message": "MoonClaw native runtime loop found no claimable MoonCode commands.",
    },
    loop_fallback_created_at="2026-06-17T00:00:00Z",
  )
  let events = json_array_items(session, "mooncode_command_events")
  assert_eq(events.length(), 1)
  assert_eq(json_string(events[0], "lane", default=""), "runtime")
  assert_eq(json_string(events[0], "kind", default=""), "runtime_loop")
  assert_eq(json_string(events[0], "status", default=""), "done")
  assert_eq(json_string(events[0], "command", default=""), "runtime-loop")
  assert_eq(json_string(events[0], "path", default=""), "/tmp/demo-book")
  assert_true(
    json_string(events[0], "detail", default="").contains("no claimable"),
  )
}

///|
test "mooncode command events keep typed command packet" {
  let base : Json = {
    "id": "code-demo",
    "workspace_id": "book-demo",
    "workspace_name": "Demo Book",
    "workspace_root": "/tmp/demo-book",
    "mooncode_runtime_session_id": "runtime-demo",
  }
  let payload : Json = { "context_path": "apps/demo/app.mbt" }
  let message = @mooncode.command_message("package", payload)
  let packet = @mooncode.projected_command_packet(
    base, payload, "package", message, "2026-06-14T00:00:00Z", "apps/demo/app.mbt",
  )
  let session = @mooncode.append_projected_command_event(
    base,
    action="package",
    status="queued",
    detail=message,
    created_at="2026-06-14T00:00:00Z",
    path="apps/demo/app.mbt",
    command_packet=packet,
  )
  let events = project_mooncode_events(session, [], [])
  assert_eq(events.length(), 1)
  let event_packet = json_object_field_or_empty(events[0], "command_packet")
  assert_eq(json_string(event_packet, "action", default=""), "package")
  assert_eq(json_string(event_packet, "approval", default=""), "operator")
  assert_true(
    json_string_array_items(event_packet, "tool_hints").contains(
      "package_app_tool",
    ),
  )
  let summary = @mooncode.session_summary(session, events)
  assert_eq(json_int(summary, "command_packet_count", default=0), 1)
  assert_true(
    json_string(summary, "last_command_packet", default="") == "" ||
    summary.stringify().contains("typed_command_packets"),
  )
}

///|
async test "mooncode review actions write moonbook receipts" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-mooncode-review-receipt-wbtest-" +
    @desk.stable_id("mooncode-review-test", @async.now().to_string()),
  )
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  let session : Json = {
    "id": "code-demo",
    "workspace_id": "book-demo",
    "workspace_name": "Demo Book",
    "workspace_root": root,
    "mooncode_runtime_session_id": "runtime-demo",
    "mooncode_dispatch_mode": "moonclaw-mooncode-runtime",
  }
  let payload : Json = { "context_path": "tools/demo/main.mbt" }
  @fsx.make_directory(
    @pathx.join(root, "tools/demo"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    @pathx.join(root, "tools/demo/main.mbt"),
    "fn main { println(\"mooncode\") }\n",
  )
  let message = @mooncode.command_message("accept", payload)
  let packet = @mooncode.projected_command_packet(
    session, payload, "accept", message, "2026-06-14T00:00:00Z", "tools/demo/main.mbt",
  )
  let receipt = write_mooncode_review_receipt(
    session, "accept", packet, "tools/demo/main.mbt", message, "2026-06-14T00:00:00Z",
  )
  assert_eq(json_string(receipt, "kind", default=""), "mooncode-review-receipt")
  assert_eq(json_string(receipt, "protocol", default=""), "mooncode.v1")
  assert_eq(json_string(receipt, "action", default=""), "accept")
  assert_eq(
    json_string(receipt, "context_path", default=""),
    "tools/demo/main.mbt",
  )
  let relative = json_string(receipt, "receipt_path", default="")
  assert_true(relative.has_prefix("wiki/reviews/mooncode/code-demo/accept-"))
  let absolute = @pathx.join(root, relative)
  assert_true(@fs.exists(absolute))
  let saved = @json.parse(@fs.read_file(absolute).text()) catch {
    _ => Json::object({})
  }
  assert_eq(json_string(saved, "action", default=""), "accept")
  assert_eq(
    json_string(
      json_object_field_or_empty(saved, "command_packet"),
      "protocol",
      default="",
    ),
    "mooncode.v1",
  )

  let recorded = write_mooncode_review_receipt_if_needed(
    session,
    "package",
    @mooncode.projected_command_packet(
      session,
      payload,
      "package",
      @mooncode.command_message("package", payload),
      "2026-06-14T00:01:00Z",
      "tools/demo/main.mbt",
    ),
    "tools/demo/main.mbt",
    "Package it.",
    "2026-06-14T00:01:00Z",
  )
  match recorded {
    Some(next) => {
      let events = json_array_items(next, "mooncode_command_events")
      assert_eq(events.length(), 3)
      assert_eq(json_string(events[0], "kind", default=""), "receipt.package")
      assert_eq(json_string(events[0], "command", default=""), "")
      assert_eq(json_string(events[1], "kind", default=""), "package.manifest")
      assert_eq(json_string(events[1], "lane", default=""), "artifact")
      assert_eq(json_string(events[2], "kind", default=""), "package.index")
      assert_eq(json_string(events[2], "lane", default=""), "artifact")
      let manifest = json_object_field_or_empty(
        next, "mooncode_last_package_manifest",
      )
      assert_eq(
        json_string(manifest, "kind", default=""),
        "mooncode-package-manifest",
      )
      assert_eq(json_string(manifest, "package_kind", default=""), "tool")
      let manifest_relative = json_string(manifest, "manifest_path", default="")
      assert_true(
        manifest_relative.has_prefix(
          "portable/app-tool/mooncode/code-demo/package-",
        ),
      )
      assert_true(@fs.exists(@pathx.join(root, manifest_relative)))
      let saved_manifest = @json.parse(
        @fs.read_file(@pathx.join(root, manifest_relative)).text(),
      ) catch {
        _ => Json::object({})
      }
      assert_eq(
        json_string(saved_manifest, "review_receipt_path", default=""),
        json_string(
          json_object_field_or_empty(next, "mooncode_last_review_receipt"),
          "receipt_path",
          default="",
        ),
      )
      assert_eq(
        json_string(saved_manifest, "source_inventory_status", default=""),
        "source-bound",
      )
      assert_eq(json_int(saved_manifest, "source_present_count", default=0), 1)
      assert_eq(
        json_string(saved_manifest, "source_promotion_status", default=""),
        "promoted",
      )
      assert_eq(json_int(saved_manifest, "promoted_source_count", default=0), 1)
      let inventory = json_array_items(saved_manifest, "source_inventory")
      assert_eq(inventory.length(), 1)
      assert_eq(
        json_string(inventory[0], "path", default=""),
        "tools/demo/main.mbt",
      )
      assert_eq(json_string(inventory[0], "kind", default=""), "file")
      assert_true(json_bool(inventory[0], "package_ready", default=false))
      assert_eq(
        json_int(inventory[0], "size_bytes", default=0),
        "fn main { println(\"mooncode\") }\n".length(),
      )
      assert_true(json_string(inventory[0], "sha256", default="").length() > 20)
      assert_true(json_bool(inventory[0], "promoted", default=false))
      let promoted_path = json_string(inventory[0], "promoted_path", default="")
      assert_true(
        promoted_path.has_prefix(
          "portable/app-tool/mooncode/code-demo/sources/",
        ),
      )
      assert_true(promoted_path.has_suffix("/tools/demo/main.mbt"))
      assert_true(@fs.exists(@pathx.join(root, promoted_path)))
      assert_eq(
        @fs.read_file(@pathx.join(root, promoted_path)).text(),
        "fn main { println(\"mooncode\") }\n",
      )
      let index_manifest = json_object_field_or_empty(
        next, "mooncode_last_package_index_manifest",
      )
      assert_eq(
        json_string(index_manifest, "kind", default=""),
        "mooncode-package-index",
      )
      assert_eq(
        json_string(index_manifest, "status", default=""),
        "source-bound",
      )
      assert_eq(
        json_string(index_manifest, "manifest_path", default=""),
        "portable/app-tool/mooncode/code-demo/index.json",
      )
      assert_true(
        @fs.exists(
          @pathx.join(
            root,
            json_string(index_manifest, "manifest_path", default=""),
          ),
        ),
      )
      assert_eq(json_int(index_manifest, "package_count", default=0), 1)
      assert_eq(
        json_int(index_manifest, "source_bound_package_count", default=0),
        1,
      )
      assert_eq(
        json_int(index_manifest, "executable_ready_count", default=0),
        1,
      )
      assert_true(
        json_string_array_items(index_manifest, "entry_points") ==
        ["tools/demo/main.mbt"],
      )
      let candidates = mooncode_package_candidates_projection(next, "code-demo")
      assert_eq(
        json_string(candidates, "kind", default=""),
        "mooncode-package-candidates",
      )
      assert_eq(json_int(candidates, "package_count", default=0), 1)
      assert_eq(
        json_int(candidates, "source_bound_package_count", default=0),
        1,
      )
      assert_eq(
        json_int(candidates, "missing_source_package_count", default=1),
        0,
      )
      assert_eq(
        json_string(candidates, "package_index_status", default=""),
        "source-bound",
      )
      assert_eq(
        json_string(candidates, "package_index_path", default=""),
        "portable/app-tool/mooncode/code-demo/index.json",
      )
      assert_eq(
        json_int(candidates, "package_index_executable_ready_count", default=0),
        1,
      )
      assert_eq(json_array_items(candidates, "packages").length(), 1)
      assert_eq(
        json_int(
          @mooncode.session_summary(next, events),
          "moonbook_review_receipt_count",
          default=0,
        ),
        1,
      )
      assert_eq(
        json_int(
          @mooncode.session_summary(next, events),
          "moonbook_package_manifest_count",
          default=0,
        ),
        1,
      )
      assert_eq(
        json_int(
          @mooncode.session_summary(next, events),
          "moonbook_package_index_manifest_count",
          default=0,
        ),
        1,
      )
      let with_change_set = write_mooncode_change_set_if_possible(next)
      let change_set = json_object_field_or_empty(
        with_change_set, "mooncode_last_change_set_manifest",
      )
      assert_eq(
        json_string(change_set, "kind", default=""),
        "mooncode-change-set",
      )
      assert_eq(json_int(change_set, "artifact_count", default=0), 2)
      assert_eq(json_int(change_set, "review_count", default=0), 1)
      let change_set_relative = json_string(
        change_set,
        "manifest_path",
        default="",
      )
      assert_eq(
        change_set_relative, "wiki/reviews/mooncode/code-demo/change-set.json",
      )
      assert_true(@fs.exists(@pathx.join(root, change_set_relative)))
      match mooncode_read_change_set_manifest(with_change_set) {
        Some(read_back) =>
          assert_eq(
            json_string(read_back, "manifest_path", default=""),
            change_set_relative,
          )
        None => fail("change-set manifest should be readable from session")
      }
      let saved_change_set = @json.parse(
        @fs.read_file(@pathx.join(root, change_set_relative)).text(),
      ) catch {
        _ => Json::object({})
      }
      assert_eq(
        json_string(saved_change_set, "protocol", default=""),
        "mooncode.v1",
      )
      assert_eq(
        json_int(
          @mooncode.session_summary(
            with_change_set,
            json_array_items(with_change_set, "mooncode_command_events"),
          ),
          "moonbook_change_set_manifest_count",
          default=0,
        ),
        1,
      )
      let with_patch_set = write_mooncode_patch_set_if_possible(with_change_set)
      let patch_set = json_object_field_or_empty(
        with_patch_set, "mooncode_last_patch_set_manifest",
      )
      assert_eq(
        json_string(patch_set, "kind", default=""),
        "mooncode-patch-set",
      )
      let patch_set_relative = json_string(
        patch_set,
        "manifest_path",
        default="",
      )
      assert_eq(
        patch_set_relative, "wiki/reviews/mooncode/code-demo/patch-set.json",
      )
      assert_true(@fs.exists(@pathx.join(root, patch_set_relative)))
      match mooncode_read_patch_set_manifest(with_patch_set) {
        Some(read_back) =>
          assert_eq(
            json_string(read_back, "manifest_path", default=""),
            patch_set_relative,
          )
        None => fail("patch-set manifest should be readable from session")
      }
      assert_eq(json_string(patch_set, "status", default=""), "empty")
      assert_eq(json_int(patch_set, "patch_count", default=-1), 0)
      assert_eq(
        json_int(
          @mooncode.session_summary(
            with_patch_set,
            json_array_items(with_patch_set, "mooncode_command_events"),
          ),
          "moonbook_patch_set_manifest_count",
          default=0,
        ),
        1,
      )
      let with_tool_approvals = write_mooncode_tool_approvals_if_possible(
        @mooncode.append_projected_command_event(
          with_patch_set,
          action="approve_tool",
          status="queued",
          detail="Approve shell",
          created_at="2026-06-14T00:02:00Z",
          path="moon test",
          command_packet=@mooncode.projected_command_packet(
            with_patch_set,
            { "context_path": "moon test" },
            "approve_tool",
            "Approve shell",
            "2026-06-14T00:02:00Z",
            "moon test",
          ),
        ),
      )
      let tool_approvals = json_object_field_or_empty(
        with_tool_approvals, "mooncode_last_tool_approvals_manifest",
      )
      assert_eq(
        json_string(tool_approvals, "kind", default=""),
        "mooncode-tool-approvals",
      )
      let tool_approvals_relative = json_string(
        tool_approvals,
        "manifest_path",
        default="",
      )
      assert_eq(
        tool_approvals_relative, "wiki/reviews/mooncode/code-demo/tool-approvals.json",
      )
      assert_true(@fs.exists(@pathx.join(root, tool_approvals_relative)))
      match mooncode_read_tool_approvals_manifest(with_tool_approvals) {
        Some(read_back) =>
          assert_eq(
            json_string(read_back, "manifest_path", default=""),
            tool_approvals_relative,
          )
        None => fail("tool-approval manifest should be readable from session")
      }
      let with_test_event = @mooncode.append_projected_command_event(
        with_tool_approvals,
        action="run_tests",
        status="passed",
        detail="moon test passed",
        created_at="2026-06-14T00:03:00Z",
        path="tools/demo/main.mbt",
        command_packet=@mooncode.projected_command_packet(
          with_tool_approvals,
          { "context_path": "tools/demo/main.mbt" },
          "run_tests",
          "moon test",
          "2026-06-14T00:03:00Z",
          "tools/demo/main.mbt",
        ),
      )
      let with_test_runs = write_mooncode_test_runs_if_possible(with_test_event)
      let test_runs = json_object_field_or_empty(
        with_test_runs, "mooncode_last_test_runs_manifest",
      )
      assert_eq(
        json_string(test_runs, "kind", default=""),
        "mooncode-test-runs",
      )
      let test_runs_relative = json_string(
        test_runs,
        "manifest_path",
        default="",
      )
      assert_eq(
        test_runs_relative, "wiki/reviews/mooncode/code-demo/test-runs.json",
      )
      assert_true(@fs.exists(@pathx.join(root, test_runs_relative)))
      assert_eq(json_int(test_runs, "run_count", default=0), 1)
      assert_eq(json_int(test_runs, "passed_run_count", default=0), 1)
      assert_eq(json_int(test_runs, "failed_run_count", default=-1), 0)
      match mooncode_read_test_runs_manifest(with_test_runs) {
        Some(read_back) =>
          assert_eq(
            json_string(read_back, "manifest_path", default=""),
            test_runs_relative,
          )
        None => fail("test-run manifest should be readable from session")
      }
      let with_eval_report = write_mooncode_eval_report_if_possible(
        with_test_runs,
      )
      let eval_report = json_object_field_or_empty(
        with_eval_report, "mooncode_last_eval_report_manifest",
      )
      assert_eq(
        json_string(eval_report, "kind", default=""),
        "mooncode-eval-report",
      )
      let eval_report_relative = json_string(
        eval_report,
        "manifest_path",
        default="",
      )
      assert_eq(
        eval_report_relative, "wiki/reviews/mooncode/code-demo/eval-report.json",
      )
      assert_true(@fs.exists(@pathx.join(root, eval_report_relative)))
      assert_eq(json_int(eval_report, "check_count", default=0), 28)
      assert_eq(json_int(eval_report, "missing_check_count", default=0), 10)
      match mooncode_read_eval_report_manifest(with_eval_report) {
        Some(read_back) =>
          assert_eq(
            json_string(read_back, "manifest_path", default=""),
            eval_report_relative,
          )
        None => fail("eval-report manifest should be readable from session")
      }
      let package_payload : Json = { "context_path": "tools/demo/main.mbt" }
      let package_packet = @mooncode.projected_command_packet(
        with_eval_report, package_payload, "package", "Package it.", "2026-06-14T00:04:00Z",
        "tools/demo/main.mbt",
      )
      append_mooncode_command_log(root, "code-demo", package_packet)
      append_mooncode_runtime_command_log(
        root,
        "code-demo",
        @mooncode.runtime_command_record(
          with_eval_report, package_payload, "Package it.", package_packet,
        ),
      )
      append_mooncode_runtime_dispatch_log(root, "code-demo", {
        "protocol": "mooncode.v1",
        "kind": "mooncode.runtime-dispatch",
        "dispatch_id": "outdated-claim-package",
        "command_id": json_string(package_packet, "command_id", default=""),
        "session_id": "code-demo",
        "status": "runtime-claimed",
        "dispatch_mode": "mooncode-runtime-claim",
        "created_at": "2026-06-14T00:04:30Z",
        "mooncode_command_valid": true,
      })
      let with_session_snapshot = write_mooncode_session_snapshot_if_possible(
        root, with_eval_report,
      )
      let session_snapshot = json_object_field_or_empty(
        with_session_snapshot, "mooncode_session_snapshot",
      )
      assert_eq(
        json_string(session_snapshot, "kind", default=""),
        "mooncode-session-snapshot",
      )
      assert_true(
        @fs.exists(json_string(session_snapshot, "snapshot_path", default="")),
      )
      let snapshot_resume_endpoints = json_object_field_or_empty(
        session_snapshot, "resume_endpoints",
      )
      assert_eq(
        json_string(snapshot_resume_endpoints, "readiness", default=""),
        "/api/mooncode/sessions/code-demo/readiness",
      )
      assert_eq(
        json_int(session_snapshot, "runtime_command_count", default=0),
        1,
      )
      let snapshot_dispatches = json_array_items(
        session_snapshot, "runtime_dispatches",
      )
      assert_eq(snapshot_dispatches.length(), 1)
      assert_true(
        json_object_field(snapshot_dispatches[0], "runtime_command") is Some(_),
      )
      assert_true(json_object_field(snapshot_dispatches[0], "owner") is Some(_))
      let with_runtime_handoff = write_mooncode_runtime_handoff_if_possible(
        root, with_session_snapshot,
      )
      let runtime_handoff = json_object_field_or_empty(
        with_runtime_handoff, "mooncode_last_runtime_handoff_manifest",
      )
      assert_eq(
        json_string(runtime_handoff, "kind", default=""),
        "mooncode-runtime-handoff",
      )
      assert_eq(
        json_string(runtime_handoff, "status", default=""),
        "replay-resumable",
      )
      let handoff_relative = json_string(
        runtime_handoff,
        "manifest_path",
        default="",
      )
      assert_eq(
        handoff_relative, "wiki/reviews/mooncode/code-demo/runtime-handoff.json",
      )
      assert_true(@fs.exists(@pathx.join(root, handoff_relative)))
      assert_eq(json_int(runtime_handoff, "command_count", default=0), 1)
      assert_eq(
        json_int(runtime_handoff, "runtime_command_count", default=0),
        1,
      )
      let handoff_dispatches = json_array_items(
        runtime_handoff, "runtime_dispatches",
      )
      assert_eq(handoff_dispatches.length(), 1)
      assert_true(
        json_object_field(handoff_dispatches[0], "runtime_command") is Some(_),
      )
      let runtime_consumer = json_object_field_or_empty(
        runtime_handoff, "runtime_consumer",
      )
      assert_eq(
        json_string(runtime_consumer, "kind", default=""),
        "mooncode-runtime-consumer-handoff",
      )
      assert_eq(
        json_string(runtime_consumer, "status", default=""),
        "lease-held",
      )
      assert_false(json_bool(runtime_consumer, "ready_to_claim", default=true))
      assert_true(@mooncode.runtime_handoff_manifest_current(runtime_handoff))
      let outdated_runtime_handoff : Json = {
        "kind": "mooncode-runtime-handoff",
        "resume_contract": {
          "runtime_command_feed_endpoint": "/api/mooncode/sessions/code-demo/runtime-commands",
          "runtime_command_log_path": "runtime-commands.jsonl",
          "runtime_claim_endpoint": "/api/mooncode/sessions/code-demo/runtime-claim",
          "runtime_dispatch_endpoint": "/api/mooncode/sessions/code-demo/runtime-dispatch",
          "runtime_dispatch_log_path": "runtime-dispatches.jsonl",
          "runtime_event_ingest_endpoint": "/api/mooncode/sessions/code-demo/runtime-events",
          "runtime_replay_endpoint": "/api/mooncode/sessions/code-demo/runtime-replay",
          "action_plan_endpoint": "/api/mooncode/sessions/code-demo/action-plan",
        },
      }
      assert_false(
        @mooncode.runtime_handoff_manifest_current(outdated_runtime_handoff),
      )
      let runtime_claim = json_object_field_or_empty(
        runtime_handoff, "runtime_claim",
      )
      assert_eq(json_int(runtime_claim, "claimed_command_count", default=0), 1)
      let resume_contract = json_object_field_or_empty(
        runtime_handoff, "resume_contract",
      )
      assert_true(
        json_string(resume_contract, "stream_endpoint", default="").contains(
          "since=<sequence>",
        ),
      )
      assert_eq(
        json_string(resume_contract, "session_snapshot_path", default=""),
        json_string(session_snapshot, "snapshot_path", default=""),
      )
      assert_eq(
        json_string(resume_contract, "session_store_endpoint", default=""),
        "/api/mooncode/sessions/code-demo/session-store",
      )
      assert_true(
        json_string(resume_contract, "runtime_command_log_path", default="").contains(
          "runtime-commands.jsonl",
        ),
      )
      assert_eq(
        json_string(
          resume_contract,
          "runtime_command_feed_endpoint",
          default="",
        ),
        "/api/mooncode/sessions/code-demo/runtime-commands",
      )
      assert_eq(
        json_string(resume_contract, "readiness_endpoint", default=""),
        "/api/mooncode/sessions/code-demo/readiness",
      )
      let engine = json_object_field_or_empty(runtime_handoff, "engine")
      assert_false(json_bool(engine, "native_runtime_ready", default=true))
      match mooncode_read_runtime_handoff_manifest(with_runtime_handoff) {
        Some(read_back) =>
          assert_eq(
            json_string(read_back, "manifest_path", default=""),
            handoff_relative,
          )
        None => fail("runtime-handoff manifest should be readable from session")
      }
      assert_eq(
        json_int(
          @mooncode.session_summary(
            with_runtime_handoff,
            json_array_items(with_runtime_handoff, "mooncode_command_events"),
          ),
          "mooncode_runtime_handoff_manifest_count",
          default=0,
        ),
        1,
      )
      assert_eq(
        json_int(
          @mooncode.session_summary(
            with_runtime_handoff,
            json_array_items(with_runtime_handoff, "mooncode_command_events"),
          ),
          "moonbook_eval_report_manifest_count",
          default=0,
        ),
        1,
      )
    }
    None => fail("package action should write a MoonBook review receipt")
  }
}
