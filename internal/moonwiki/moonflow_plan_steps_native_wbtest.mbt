///|
async test "declared step compiled UI request crosses production HTTP fixed Flow CLI and reloads new and revised child" {
  guard @env.get_env_var("MOONDESK_STEPS_FIXTURE") is Some(fixture) &&
    @env.get_env_var("MOONDESK_MOONFLOW_BIN") is Some(executable) else {
    println("STEPS_HTTP_NOT_CONFIGURED: actual HTTP crossing not exercised")
    return
  }
  let payload = @json.parse(@fs.read_file(fixture + "/ui-request.json").text())
  let form = json_object_field(payload, "form").unwrap()
  let source = json_object_field(form, "source_graph").unwrap()
  let workspace_id = json_string(payload, "workspace_id", default="")
  assert_eq(workspace_id, @desk.stable_id("book", "steps-book"))
  let evidence : Array[Json] = []
  for revision in [false, true] {
    let name = if revision { "revision" } else { "new" }
    let root = fixture +
      "/" +
      name +
      "-" +
      moonflow_server_utc_timestamp()
      .replace(old="-", new="")
      .replace(old=":", new="")
    let book = root + "/books/steps-book"
    @fs.mkdir(book + "/flow", recursive=true)
    @fs.mkdir(root + "/requests")
    let source_path = book + "/flow/work-graph.json"
    let catalog_path = book + "/flow/capability-catalog.json"
    @fs.write_file(
      book + "/README.md",
      "# Synthetic declared-step Book\n",
      create_mode=CreateNew,
    )
    @fs.write_file(source_path, source.stringify(), create_mode=CreateNew)
    let catalog_bytes = @fs.read_file(fixture + "/catalog.json").binary()
    @fs.write_file(catalog_path, catalog_bytes, create_mode=CreateNew)
    for filename in @fs.readdir(fixture + "/requests") {
      @fs.write_file(
        root + "/requests/" + filename,
        @fs.read_file(fixture + "/requests/" + filename).binary(),
        create_mode=CreateNew,
      )
    }
    let parent_ref = root +
      "/.moonsuite/products/moonflow/runs/" +
      moonflow_graph_run_id(source)
    if revision {
      let result = @process.collect_output(
        executable,
        [
          "import-conformant-graph",
          root,
          source_path,
          catalog_path,
          moonflow_server_utc_timestamp(),
        ],
        inherit_env=false,
        extra_env={ "HOME": "/dev/null", "PATH": "/dev/null" },
      )
      guard result.0 == 0 else {
        fail("Parent fixture import: " + result.2.text())
      }
      // Synthetic retained history is seeded before the HTTP workflow. Replay
      // through the real CLI verifies accepted checkpoints without dispatch.
      let stored = @json.parse(
        @fs.read_file(parent_ref + "/events.json").text(),
      )
      guard stored is Array(events) else { fail("parent events") }
      for id in ["root", "left"] {
        let registration = events.filter(event => {
            json_string(event, "kind", default="") == "item-registered" &&
            json_string(event, "work_item_id", default="") == id
          })[0]
        let checkpoint = @json.parse(registration.stringify())
        guard checkpoint is Object(fields) else { fail("checkpoint") }
        fields["sequence"] = ToJson::to_json(events.length())
        fields["event_id"] = ToJson::to_json("synthetic-history-" + id)
        fields["kind"] = "checkpoint-reused"
        fields["detail"] = ToJson::to_json(
          "synthetic-reviewed-checkpoint-" + id,
        )
        fields["request_id"] = ToJson::to_json("synthetic-request-" + id)
        fields["result_id"] = ToJson::to_json("synthetic-result-" + id)
        fields["attempt_id"] = ToJson::to_json("synthetic-attempt-" + id)
        fields["input_digest"] = "sha256:synthetic-prior-input"
        fields["output_digest"] = "sha256:synthetic-prior-output"
        fields["artifact_id"] = ToJson::to_json(
          "requests/review-" + id + ".json",
        )
        fields["authority_id"] = "synthetic-fixture-reviewer"
        @fs.write_file(
          root + "/requests/review-" + id + ".json",
          "{\"synthetic_fixture\":true}",
          create_mode=CreateNew,
        )
        events.push(checkpoint)
      }
      @fs.write_file(
        parent_ref + "/events.json",
        stored.stringify(indent=2),
        create_mode=CreateOrTruncate,
      )
      let replayed = @process.collect_output(
        executable,
        ["status", root, moonflow_graph_run_id(source)],
        inherit_env=false,
        extra_env={ "HOME": "/dev/null", "PATH": "/dev/null" },
      )
      guard replayed.0 == 0 else {
        fail("Synthetic checkpoint replay: " + replayed.2.text())
      }
      let projection = @json.parse(replayed.1.text())
      assert_eq(
        moonflow_graph_items(projection)
        .filter(item => json_string(item, "status", default="") == "accepted")
        .length(),
        2,
      )
      @fs.write_file(
        parent_ref + "/projection.json",
        replayed.1.binary(),
        create_mode=CreateOrTruncate,
      )
    }
    let parent_events = if revision {
      Some(@fs.read_file(parent_ref + "/events.json").binary())
    } else {
      None
    }
    let parent_projection = if revision {
      Some(@fs.read_file(parent_ref + "/projection.json").binary())
    } else {
      None
    }
    let source_bytes = @fs.read_file(source_path).binary()
    let server = Server::new("127.0.0.1", 0, reuse_addr=true)
    defer server.close()
    let ui_root = @env.get_env_var("MOONDESK_STEPS_UI_DIST").unwrap_or(root)
    @async.with_task_group(group => {
      group.spawn_bg(
        () => server.serve_desk(ui_root, root),
        no_wait=true,
        allow_failure=true,
      )
      @async.sleep(20)
      let base = "http://127.0.0.1:" + server.port().to_string()
      let (page, content) = @http.get(base + "/")
      assert_eq(page.code, 200)
      assert_true(content.text().contains("MoonDesk"))
      assert_true(
        test_http_get_json(base + "/api/workspaces", 200)
        .stringify()
        .contains(workspace_id),
      )
      let url = base + "/api/moonflow/plans"
      let prepared = test_http_post_json(url, payload, 200)
      guard json_string(prepared, "status", default="") == "prepared" else {
        fail(prepared.stringify())
      }
      assert_eq(test_http_post_json(url, payload, 200), prepared)
      let receipt = json_object_field(prepared, "receipt").unwrap()
      assert_eq(
        json_object_field(receipt, "migration_preview") != Some(Json::null()),
        revision,
      )
      let prepared_value = json_object_field(receipt, "prepared").unwrap()
      let child_id = json_string(prepared_value, "preparation_id", default="")
      let child_dir = root + "/.moonsuite/products/moonflow/runs/" + child_id
      assert_false(@fs.exists(child_dir + "/events.json"))
      let changes = json_array_items(prepared, "changes")
      assert_eq(
        changes
        .filter(change => {
          json_string(change, "field", default="") == "added_step"
        })
        .length(),
        2,
      )
      assert_eq(
        changes
        .filter(change => {
          json_string(change, "field", default="") == "removed_step"
        })
        .length(),
        1,
      )
      if revision {
        let migration = json_object_field(receipt, "migration_preview").unwrap()
        let decisions = json_array_items(migration, "decisions")
        for id in ["left-copy-1", "left-copy-2"] {
          assert_eq(
            json_string(
              decisions.filter(decision => {
                json_string(decision, "child_work_item_id", default="") == id
              })[0],
              "decision",
              default="",
            ),
            "new",
          )
        }
      }
      let applied = test_http_post_json(
        url,
        desk_plan_action(payload, "apply"),
        200,
      )
      guard json_string(applied, "status", default="") == "imported" else {
        fail(applied.stringify())
      }
      let events = @fs.read_file(child_dir + "/events.json").binary()
      let projection = @json.parse(
        @fs.read_file(child_dir + "/projection.json").text(),
      )
      let items = moonflow_graph_items(projection)
      assert_eq(items.length(), 5)
      assert_false(items.any(item => moonflow_graph_item_id(item) == "join"))
      for item in items {
        assert_eq(json_int(item, "attempt_count", default=-1), 0)
        assert_eq(json_string_array_items(item, "approvals"), [])
      }
      assert_false(@encoding/utf8.decode(events).contains("attempt-submitted"))
      assert_eq(
        test_http_post_json(url, desk_plan_action(payload, "inspect"), 200),
        applied,
      )
      assert_eq(
        test_http_post_json(url, desk_plan_action(payload, "apply"), 200),
        applied,
      )
      assert_eq(@fs.read_file(child_dir + "/events.json").binary(), events)
      for path in [source_path, catalog_path] {
        let original = @fs.read_file(path).binary()
        let changed = @json.parse(@encoding/utf8.decode(original))
        guard changed is Object(fields) else { fail("fixture object") }
        fields["changed_after_prepare"] = true
        @fs.write_file(path, changed.stringify(), create_mode=CreateOrTruncate)
        let blocked = test_http_post_json(
          url,
          desk_plan_action(payload, "apply"),
          200,
        )
        assert_eq(json_string(blocked, "status", default=""), "blocked")
        let retained = test_http_post_json(
          url,
          desk_plan_action(payload, "inspect"),
          200,
        )
        assert_false(json_bool(retained, "source_current", default=true))
        @fs.write_file(path, original, create_mode=CreateOrTruncate)
      }
      assert_eq(@fs.read_file(source_path).binary(), source_bytes)
      if parent_events is Some(bytes) {
        assert_eq(@fs.read_file(parent_ref + "/events.json").binary(), bytes)
      }
      if parent_projection is Some(bytes) {
        assert_eq(
          @fs.read_file(parent_ref + "/projection.json").binary(),
          bytes,
        )
      }
      assert_false(execution_sandbox_client_available())
      evidence.push({
        "revision": revision,
        "workspace": root,
        "request": payload,
        "prepared": prepared,
        "applied": applied,
        "projection": projection,
        "parent_exactly_preserved": true,
        "source_exactly_preserved": true,
        "attempt_count": 0,
        "source_and_catalog_stale_apply_refused": true,
        "http_boundary": true,
        "synthetic_accepted_parent_checkpoints": if revision {
          2
        } else {
          0
        },
      })
    })
  }
  @fs.write_file(
    fixture + "/http-evidence.json",
    ToJson::to_json(evidence).stringify(indent=2),
    create_mode=CreateOrTruncate,
  )
  println(
    "STEPS_HTTP_PASSED: compiled form through production HTTP to fixed native Flow prepare/import/reload; new/revision, stale pins, zero attempts, exact source/parent preservation",
  )
}
