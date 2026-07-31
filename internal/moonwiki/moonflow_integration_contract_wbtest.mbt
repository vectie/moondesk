///|
fn moonflow_test_item(id : String, artifact_ref : String) -> Json {
  {
    "work_item_id": id,
    "declaration_id": id + "-declaration",
    "product_id": "product",
    "requested_authority": "workspace-mutation",
    "acceptance_criteria": ["receipt exists"],
    "operation": "product/tool@1.0.0",
    "input_contracts": ["product/request@1.0.0"],
    "output_contracts": ["product/receipt@1.0.0"],
    "required_claim": "digital-artifact",
    "input_artifacts": [artifact_ref],
    "timeout_ms": 1000,
    "depends_on": [],
  }
}

///|
fn moonflow_test_graph(items : Array[Json]) -> Json {
  {
    "contract_id": "moonsuite.work-model.v1",
    "graph_id": "test-graph-r1",
    "book_id": "test-book",
    "declaration_revision": "r1",
    "source_digest": "sha256:test-graph-r1",
    "items": items,
    "recorded_at": "2026-07-31T00:00:00Z",
  }
}

///|
async test "only the canonical Work graph can become executable" {
  let root = @fs.tmpdir(prefix="moondesk-moonflow-source-")
  let flow = @pathx.join(root, "flow")
  @fs.mkdir(flow, permission=0o755, recursive=true)
  @fsx.write_to_file(
    @pathx.join(flow, "draft-work-graph.json"),
    moonflow_test_graph([]).stringify(),
    create=0o644,
  )
  assert_eq(moonflow_source_graph_path(root), "")
  let executable = @pathx.join(flow, "work-graph.json")
  @fsx.write_to_file(
    executable,
    moonflow_test_graph([]).stringify(),
    create=0o644,
  )
  assert_eq(moonflow_source_graph_path(root), executable)
  let loaded = moonflow_load_executable_graph(executable)
  assert_eq(moonflow_graph_run_id(loaded), "test-graph-r1")
  @fsx.write_to_file(
    executable,
    ({ "contract_id": "moonfind.desired-capability-graph.v2" } : Json).stringify(),
    create=0o644,
  )
  try moonflow_load_executable_graph(executable) catch {
    _ => ()
  } noraise {
    _ => fail("desired or draft graph became executable")
  }
}

///|
async test "saved selection binds all three source identities" {
  let root = @fs.tmpdir(prefix="moondesk-moonflow-selection-")
  let flow = @pathx.join(root, "flow")
  @fs.mkdir(flow, permission=0o755, recursive=true)
  let graph = moonflow_test_graph([
    moonflow_test_item("one", "one.json"),
    moonflow_test_item("two", "two.json"),
  ])
  let record : Json = {
    "contract_id": moonflow_composition_contract(),
    "source_graph_id": "test-graph-r1",
    "source_digest": "sha256:test-graph-r1",
    "declaration_revision": "r1",
    "selected_item_ids": ["one"],
  }
  @fsx.write_to_file(
    moonflow_composition_path(root),
    record.stringify(),
    create=0o644,
  )
  assert_true(moonflow_saved_selection(root, graph) == ["one"])
  let drifted : Json = {
    "contract_id": moonflow_composition_contract(),
    "source_graph_id": "test-graph-r1",
    "source_digest": "sha256:test-graph-r1",
    "declaration_revision": "r2",
    "selected_item_ids": ["one"],
  }
  @fsx.write_to_file(
    moonflow_composition_path(root),
    drifted.stringify(),
    create=0o644,
  )
  assert_true(moonflow_saved_selection(root, graph) == ["one", "two"])
}

///|
async test "graph-relative input artifacts compile to suite-relative refs" {
  let suite = @fs.tmpdir(prefix="moondesk-moonflow-rebase-")
  let book = @pathx.join(suite, "books/test-book")
  let flow = @pathx.join(book, "flow")
  let requests = @pathx.join(flow, "requests")
  @fs.mkdir(requests, permission=0o755, recursive=true)
  let request = @pathx.join(requests, "one.json")
  @fsx.write_to_file(request, "{}\n", create=0o644)
  let graph_path = @pathx.join(flow, "work-graph.json")
  @fsx.write_to_file(
    graph_path,
    moonflow_test_graph([moonflow_test_item("one", "requests/one.json")]).stringify(
      indent=2,
    ),
    create=0o644,
  )
  let compiled = moonflow_compile_composition(suite, book, graph_path)
  assert_false(compiled == graph_path)
  let graph = moonflow_load_executable_graph(compiled)
  let artifacts = json_string_array_items(
    moonflow_graph_items(graph)[0],
    "input_artifacts",
  )
  assert_true(artifacts == ["books/test-book/flow/requests/one.json"])
  @fs.remove(request)
  try moonflow_compile_composition(suite, book, graph_path) catch {
    _ => ()
  } noraise {
    _ => fail("missing graph-relative artifact compiled")
  }
}

///|
test "catalog discovery and import commands remain generic and exact" {
  assert_true(
    moonflow_capability_catalog_candidate("/suite/books/book", "") ==
    ("/suite/books/book/flow/capability-catalog.json", "book"),
  )
  assert_true(
    moonflow_capability_catalog_candidate(
      "/suite/books/book", "/host/catalog.json",
    ) ==
    ("/host/catalog.json", "environment"),
  )
  assert_true(
    moonflow_validate_graph_cli_arguments(
      "/moonflow", "/compiled/graph.json", "/book/flow/capability-catalog.json",
      "2026-07-31T00:00:00Z",
    ) ==
    [
      "-C", "/moonflow", "run", "cmd/main", "--", "validate-work-graph-capabilities",
      "/compiled/graph.json", "/book/flow/capability-catalog.json", "2026-07-31T00:00:00Z",
    ],
  )
  assert_true(
    moonflow_import_graph_cli_arguments(
      "/moonflow", "/suite", "/compiled/graph.json", "/book/flow/capability-catalog.json",
      "2026-07-31T00:00:00Z",
    ) ==
    [
      "-C", "/moonflow", "run", "cmd/main", "--", "import-conformant-graph", "/suite",
      "/compiled/graph.json", "/book/flow/capability-catalog.json", "2026-07-31T00:00:00Z",
    ],
  )
}

///|
test "composition projects exact catalog evidence without dropping graph fields" {
  let graph = moonflow_test_graph([
    moonflow_test_item("one", "requests/one.json"),
  ])
  let catalog : Json = {
    "contract_id": "moonflow.capability-catalog.v1",
    "catalog_id": "catalog-r1",
    "operations": [
      {
        "operation_ref": "product/tool@1.0.0",
        "adapter_id": "product-adapter-r1",
        "claim_ceiling": "digital-artifact",
        "review_required": true,
        "health_checked_at": "2026-07-30T23:00:00Z",
        "health_valid_until": "2026-08-01T00:00:00Z",
        "health_evidence_ref": "health/product.json",
        "health_evidence_digest": "sha256:health",
      },
    ],
  }
  let evidence : Json = {
    "catalog_id": "catalog-r1",
    "catalog_status": "loaded",
    "evaluated_at": "2026-07-31T00:00:00Z",
  }
  let resolution : MoonFlowCapabilityCatalogResolution = {
    catalog: Some(catalog),
    evidence,
  }
  let response = moonflow_composition_response(
    "test-book",
    graph,
    ["one"],
    "loaded",
    resolution,
  )
  assert_eq(json_string(response, "catalog_id", default=""), "catalog-r1")
  let item = match json_object_field(response, "items") {
    Some(Array([value])) => value
    _ => fail("expected one enriched item")
  }
  assert_eq(json_string(item, "declaration_id", default=""), "one-declaration")
  assert_true(
    json_string_array_items(item, "input_contracts") ==
    ["product/request@1.0.0"],
  )
  assert_eq(json_string(item, "adapter_id", default=""), "product-adapter-r1")
  assert_eq(
    json_string(item, "health_evidence_ref", default=""),
    "health/product.json",
  )
}

///|
async test "catalog snapshot pins the exact bytes used by both CLI phases" {
  let suite = @fs.tmpdir(prefix="moondesk-moonflow-catalog-snapshot-")
  let source = @pathx.join(suite, "source-catalog.json")
  let content = "{\"contract_id\":\"moonflow.capability-catalog.v1\"}\n"
  @fsx.write_to_file(source, content, create=0o600)
  let digest = "sha256:" +
    @crypto.bytes_to_hex_string(
      @crypto.sha256(@encoding/utf8.encode(content).to_fixedarray()),
    )
  let relative = ".moonsuite/products/moondesk/moonflow-imports/test"
  let snapshot = moonflow_snapshot_capability_catalog(
    suite, relative, source, digest,
  )
  assert_eq(@fs.read_file(snapshot).text(), content)
  try
    moonflow_snapshot_capability_catalog(
      suite, relative, source, "sha256:stale",
    )
  catch {
    _ => ()
  } noraise {
    _ => fail("changed catalog was accepted")
  }
}
