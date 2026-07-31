///|

///|
fn moonflow_server_utc_timestamp() -> String raise {
  @time.unix(@async.now() / 1000L).to_string()
}

///|
fn moonflow_cli_arguments(
  moonflow_root : String,
  command : Array[String],
) -> Array[String] {
  let arguments = ["-C", moonflow_root, "run", "cmd/main", "--"]
  for value in command {
    arguments.push(value)
  }
  arguments
}

///|
fn moonflow_validate_graph_cli_arguments(
  moonflow_root : String,
  graph_path : String,
  catalog_path : String,
  evaluated_at : String,
) -> Array[String] {
  moonflow_cli_arguments(moonflow_root, [
    "validate-work-graph-capabilities", graph_path, catalog_path, evaluated_at,
  ])
}

///|
fn moonflow_import_graph_cli_arguments(
  moonflow_root : String,
  suite_root : String,
  graph_path : String,
  catalog_path : String,
  evaluated_at : String,
) -> Array[String] {
  moonflow_cli_arguments(moonflow_root, [
    "import-conformant-graph", suite_root, graph_path, catalog_path, evaluated_at,
  ])
}

///|
fn moonflow_control_cli_arguments(
  moonflow_root : String,
  suite_root : String,
  run_id : String,
  action : String,
  evaluated_at : String,
  detail : String,
) -> Array[String] {
  let command = ["control", suite_root, run_id, action, evaluated_at]
  if detail != "" {
    command.push(detail)
  }
  moonflow_cli_arguments(moonflow_root, command)
}

///|
fn moonflow_import_evidence_relative_root(
  graph : Json,
  catalog_evidence : Json,
  evaluated_at : String,
) -> String {
  let seed : Json = {
    "graph_id": moonflow_graph_run_id(graph),
    "source_digest": json_string(graph, "source_digest", default=""),
    "declaration_revision": json_string(
      graph,
      "declaration_revision",
      default="",
    ),
    "catalog_id": json_string(catalog_evidence, "catalog_id", default=""),
    "catalog_digest": json_string(
      catalog_evidence,
      "catalog_digest",
      default="",
    ),
    "evaluated_at": evaluated_at,
  }
  let digest = @crypto.bytes_to_hex_string(
    @crypto.sha256(@encoding/utf8.encode(seed.stringify()).to_fixedarray()),
  )
  ".moonsuite/products/moondesk/moonflow-imports/" + digest[0:16].to_owned()
}

///|
async fn moonflow_snapshot_capability_catalog(
  suite_root : String,
  relative_root : String,
  source_path : String,
  expected_digest : String,
) -> String {
  let bytes = @fs.read_file(source_path).binary()
  let actual_digest = "sha256:" +
    @crypto.bytes_to_hex_string(@crypto.sha256(bytes))
  guard actual_digest == expected_digest else {
    fail("MoonFlow capability catalog changed during preparation")
  }
  let directory = @pathx.join(suite_root, relative_root)
  if !@fs.exists(directory) {
    @fs.mkdir(directory, permission=0o755, recursive=true)
  }
  let path = @pathx.join(directory, "capability-catalog.json")
  @fs.write_file(path, bytes, create_mode=CreateOrTruncate, permission=0o600)
  path
}

///|
async fn moonflow_persist_validation_report(
  suite_root : String,
  relative_root : String,
  report : Json,
) -> String {
  let directory = @pathx.join(suite_root, relative_root)
  if !@fs.exists(directory) {
    @fs.mkdir(directory, permission=0o755, recursive=true)
  }
  let relative = relative_root + "/validation-report.json"
  @fsx.write_to_file(
    @pathx.join(suite_root, relative),
    report.stringify(indent=2) + "\n",
    create=0o644,
  )
  relative
}

///|
fn moonflow_import_receipt(
  graph : Json,
  catalog_evidence : Json,
  evaluated_at : String,
  status : String,
  validation_report_ref : String,
  detail : String,
) -> Json {
  {
    "contract_id": "moondesk.moonflow-import-receipt.v1",
    "graph_id": moonflow_graph_run_id(graph),
    "source_digest": json_string(graph, "source_digest", default=""),
    "declaration_revision": json_string(
      graph,
      "declaration_revision",
      default="",
    ),
    "catalog_id": json_string(catalog_evidence, "catalog_id", default=""),
    "catalog_digest": json_string(
      catalog_evidence,
      "catalog_digest",
      default="",
    ),
    "evaluated_at": evaluated_at,
    "status": status,
    "validation_report_ref": validation_report_ref,
    "detail": detail,
  }
}

///|
async fn moonflow_persist_import_receipt(
  suite_root : String,
  relative_root : String,
  receipt : Json,
) -> String {
  let directory = @pathx.join(suite_root, relative_root)
  if !@fs.exists(directory) {
    @fs.mkdir(directory, permission=0o755, recursive=true)
  }
  let relative = relative_root + "/import-receipt.json"
  @fsx.write_to_file(
    @pathx.join(suite_root, relative),
    receipt.stringify(indent=2) + "\n",
    create=0o644,
  )
  relative
}

///|
fn moonflow_validation_report_matches(
  report : Json,
  graph : Json,
  catalog_evidence : Json,
) -> Bool {
  json_string(report, "contract_id", default="") ==
  "moonflow.graph-capability-report.v1" &&
  json_string(report, "graph_id", default="") == moonflow_graph_run_id(graph) &&
  json_string(report, "catalog_id", default="") ==
  json_string(catalog_evidence, "catalog_id", default="")
}

///|
fn moonflow_control_receipt_matches(control : Json, run_id : String) -> Bool {
  json_string(control, "contract_id", default="") == "moonflow.run-control.v1" &&
  json_string(control, "run_id", default="") == run_id
}
