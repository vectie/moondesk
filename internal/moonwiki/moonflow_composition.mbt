///|
fn moonflow_composition_contract() -> String {
  "moondesk.moonflow-composition.v1"
}

///|
async fn moonflow_source_graph_path(book_root : String) -> String {
  let candidates = ["flow/draft-work-graph.json", "flow/work-graph.json"]
  for candidate in candidates {
    let path = @pathx.join(book_root, candidate)
    if @fs.exists(path) {
      return path
    }
  }
  ""
}

///|
fn moonflow_composition_path(book_root : String) -> String {
  @pathx.join(book_root, "flow/composition.json")
}

///|
fn moonflow_graph_items(graph : Json) -> Array[Json] {
  match json_object_field(graph, "items") {
    Some(Array(items)) => items
    _ => []
  }
}

///|
fn moonflow_graph_item_id(item : Json) -> String {
  json_string(item, "work_item_id", default="")
}

///|
fn moonflow_graph_item_ids(graph : Json) -> Array[String] {
  moonflow_graph_items(graph).map(moonflow_graph_item_id)
}

///|
fn moonflow_composition_selection_issues(
  graph : Json,
  selected : Array[String],
) -> Array[String] {
  let issues : Array[String] = []
  let known = moonflow_graph_item_ids(graph)
  if selected.is_empty() {
    issues.push("Select at least one declared work item")
  }
  let seen : Array[String] = []
  for item_id in selected {
    if item_id.trim().is_empty() || !known.contains(item_id) {
      issues.push("Unknown work item: " + item_id)
    } else if seen.contains(item_id) {
      issues.push("Duplicate work item: " + item_id)
    } else {
      seen.push(item_id)
    }
  }
  for item in moonflow_graph_items(graph) {
    let item_id = moonflow_graph_item_id(item)
    if selected.contains(item_id) {
      for dependency in json_string_array_items(item, "depends_on") {
        if !selected.contains(dependency) {
          issues.push(
            "Work item " +
            item_id +
            " requires selected dependency " +
            dependency,
          )
        }
      }
    }
  }
  issues
}

///|
fn moonflow_composition_digest(
  graph : Json,
  selected : Array[String],
) -> String {
  let seed : Json = {
    "source_graph_id": moonflow_graph_run_id(graph),
    "source_digest": json_string(graph, "source_digest", default=""),
    "selected_item_ids": selected,
  }
  @crypto.bytes_to_hex_string(
    @crypto.sha256(@encoding/utf8.encode(seed.stringify()).to_fixedarray()),
  )
}

///|
fn moonflow_composition_response(
  workspace_id : String,
  graph : Json,
  selected : Array[String],
  status : String,
) -> Json {
  {
    "contract_id": moonflow_composition_contract(),
    "workspace_id": workspace_id,
    "source_graph_id": moonflow_graph_run_id(graph),
    "book_id": json_string(graph, "book_id", default=workspace_id),
    "declaration_revision": json_string(
      graph,
      "declaration_revision",
      default="",
    ),
    "source_digest": json_string(graph, "source_digest", default=""),
    "status": status,
    "selected_item_ids": selected,
    "items": Json::array(moonflow_graph_items(graph)),
  }
}

///|
async fn moonflow_saved_selection(
  book_root : String,
  graph : Json,
) -> Array[String] {
  let path = moonflow_composition_path(book_root)
  if !@fs.exists(path) {
    return moonflow_graph_item_ids(graph)
  }
  let saved = @json.parse(@fs.read_file(path).text()) catch {
    _ => return moonflow_graph_item_ids(graph)
  }
  if json_string(saved, "contract_id", default="") !=
    moonflow_composition_contract() ||
    json_string(saved, "source_graph_id", default="") !=
    moonflow_graph_run_id(graph) {
    return moonflow_graph_item_ids(graph)
  }
  let selected = json_string_array_items(saved, "selected_item_ids")
  if moonflow_composition_selection_issues(graph, selected).is_empty() {
    selected
  } else {
    moonflow_graph_item_ids(graph)
  }
}

///|
async fn moonflow_compile_composition(
  suite_root : String,
  book_root : String,
  graph_path : String,
) -> String {
  let graph = @json.parse(@fs.read_file(graph_path).text())
  let selection_path = moonflow_composition_path(book_root)
  if !@fs.exists(selection_path) {
    return graph_path
  }
  let selected = moonflow_saved_selection(book_root, graph)
  let issues = moonflow_composition_selection_issues(graph, selected)
  guard issues.is_empty() else {
    fail("Invalid MoonFlow composition: " + issues.join("; "))
  }
  if selected.length() == moonflow_graph_items(graph).length() {
    return graph_path
  }
  let digest = moonflow_composition_digest(graph, selected)
  let suffix = digest[0:12].to_owned()
  let fields : Map[String, Json] = {}
  match graph {
    Object(values) =>
      for key, value in values {
        fields[key] = value
      }
    _ => fail("MoonFlow Work graph must be an object")
  }
  fields["graph_id"] = (moonflow_graph_run_id(graph) + "-selection-" + suffix).to_json()
  fields["declaration_revision"] = (json_string(
    graph,
    "declaration_revision",
    default="r0",
  ) +
  "-selection-" +
  suffix).to_json()
  fields["source_digest"] = ("sha256:" + digest).to_json()
  fields["items"] = Json::array(
    moonflow_graph_items(graph).filter(item => {
      selected.contains(moonflow_graph_item_id(item))
    }),
  )
  let directory = @pathx.join(
    suite_root, ".moonsuite/products/moondesk/compositions",
  )
  if !@fs.exists(directory) {
    @fs.mkdir(directory, permission=0o755, recursive=true)
  }
  let compiled_path = @pathx.join(directory, suffix + ".json")
  @fsx.write_to_file(
    compiled_path,
    Json::object(fields).stringify(indent=2) + "\n",
    create=0o644,
  )
  compiled_path
}

///|
async fn handle_moonflow_composition(
  workspace_root : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let payload = match read_json_body(body) {
    Some(value) => value
    None => {
      send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
      return
    }
  }
  let workspace_id = json_string(payload, "workspace_id", default="")
  let workspace = match find_workspace(workspace_root, workspace_id) {
    Some(value) => value
    None => {
      send_api_error(conn, method_, 404, "Not Found", "Select a MoonBook first")
      return
    }
  }
  let graph_path = moonflow_source_graph_path(workspace.root_path)
  if graph_path == "" {
    send_api_error(
      conn, method_, 404, "Not Found", "This MoonBook has no executable Work graph",
    )
    return
  }
  let graph = @json.parse(@fs.read_file(graph_path).text()) catch {
    _ => {
      send_api_error(conn, method_, 409, "Conflict", "Invalid Work graph JSON")
      return
    }
  }
  let action = json_string(payload, "action", default="load")
  if action == "load" {
    let selected = moonflow_saved_selection(workspace.root_path, graph)
    send_json(
      conn,
      method_,
      moonflow_composition_response(workspace_id, graph, selected, "loaded"),
    )
    return
  }
  if action != "save" {
    send_api_error(
      conn, method_, 400, "Bad Request", "Unsupported composition action",
    )
    return
  }
  let selected = json_string_array_items(payload, "selected_item_ids")
  let issues = moonflow_composition_selection_issues(graph, selected)
  if !issues.is_empty() {
    send_api_error(conn, method_, 409, "Conflict", issues.join("; "))
    return
  }
  let path = moonflow_composition_path(workspace.root_path)
  let flow_root = @pathx.join(workspace.root_path, "flow")
  if !@fs.exists(flow_root) {
    @fs.mkdir(flow_root, permission=0o755, recursive=true)
  }
  let record : Json = {
    "contract_id": moonflow_composition_contract(),
    "workspace_id": workspace_id,
    "source_graph_id": moonflow_graph_run_id(graph),
    "source_digest": json_string(graph, "source_digest", default=""),
    "selected_item_ids": selected,
    "recorded_at": json_string(payload, "recorded_at", default=""),
  }
  @fsx.write_to_file(path, record.stringify(indent=2) + "\n", create=0o644)
  send_json(
    conn,
    method_,
    moonflow_composition_response(workspace_id, graph, selected, "saved"),
  )
}
