///|
fn source_semantics_bounded_output(text : String, limit : Int) -> String {
  if text.length() <= limit {
    text
  } else {
    text[:limit].to_owned() + "\n… output truncated"
  }
}

///|
fn source_semantics_normalize_output(
  output : String,
  workspace_root : String,
) -> String {
  source_semantics_bounded_output(output, 160000).replace_all(
    old=workspace_root + "/",
    new="",
  )
}

///|
fn source_semantics_diagnostics(
  output : String,
  workspace_root : String,
) -> Array[Json] {
  let diagnostics : Array[Json] = []
  for line in output.split("\n") {
    let parsed = @json.parse(line) catch { _ => continue }
    guard parsed is Object(fields) else { continue }
    guard fields.get("$message_type") is Some(String("diagnostic")) else {
      continue
    }
    let next = fields.copy()
    if fields.get("path") is Some(String(path)) {
      let relative = match path.strip_prefix(workspace_root + "/") {
        Some(value) => value.to_owned()
        None => path
      }
      next["relative_path"] = relative.to_json()
    }
    diagnostics.push(Json::object(next))
  }
  diagnostics
}

///|
async fn source_semantics_module_root(
  workspace_root : String,
  absolute_path : String,
) -> String? {
  for current = @pathx.dirname(absolute_path).to_owned(), depth = 0; depth < 64; {
    if @fs.exists(@pathx.join(current, "moon.mod")) {
      return Some(current)
    }
    if current == workspace_root {
      return None
    }
    let parent = @pathx.dirname(current).to_owned()
    if parent == current || !canonical_path_is_within(workspace_root, parent) {
      return None
    }
    continue parent, depth + 1
  }
  None
}

///|
fn source_semantics_module_path(
  module_root : String,
  absolute_path : String,
) -> String? {
  absolute_path.strip_prefix(module_root + "/").map(value => value.to_owned())
}

///|
fn source_semantics_module_prefix(
  workspace_root : String,
  module_root : String,
) -> String? {
  if module_root == workspace_root {
    Some("")
  } else {
    module_root
    .strip_prefix(workspace_root + "/")
    .map(value => value.to_owned() + "/")
  }
}

///|
fn source_semantics_ide_args(
  action : String,
  symbol : String,
  module_path : String,
  line : Int,
  column : Int,
) -> Result[Array[String], String] {
  if symbol.trim() == "" {
    return Err("Select a symbol before semantic navigation")
  }
  let verb = match action {
    "definition" => "peek-def"
    "references" => "find-references"
    _ => return Err("Unsupported source semantic action")
  }
  Ok([
    "ide",
    verb,
    symbol,
    "--loc",
    module_path +
    ":" +
    line.max(1).to_string() +
    ":" +
    column.max(1).to_string(),
  ])
}

///|
async fn source_semantics_result(
  workspace : @desk.DeskWorkspace,
  payload : Json,
) -> Result[Json, String] {
  let action = json_string(payload, "action", default="")
  let requested_path = decode_query_value(
    json_string(payload, "path", default=""),
  )
  let clean_path = match clean_relative_path(requested_path) {
    Some(path) if path.has_suffix(".mbt") => path
    _ => return Err("Compiler semantics require a confined MoonBit source path")
  }
  let absolute_path = match
    @fsx.resolve_confined_existing(workspace.root_path, clean_path) {
    Some(path) => path
    None => return Err("MoonBit source path does not exist in this workspace")
  }
  let canonical_workspace_root = @fs.realpath(workspace.root_path) catch {
    _ => return Err("Workspace root is unavailable")
  }
  let module_root = match
    source_semantics_module_root(canonical_workspace_root, absolute_path) {
    Some(root) => root
    None => return Err("No moon.mod was found for this source file")
  }
  let module_path = match
    source_semantics_module_path(module_root, absolute_path) {
    Some(path) => path
    None => return Err("Source path is outside its MoonBit module")
  }
  let module_prefix = match
    source_semantics_module_prefix(canonical_workspace_root, module_root) {
    Some(prefix) => prefix
    None => return Err("MoonBit module is outside this workspace")
  }
  if action == "diagnostics" {
    let (code, stdout, stderr) = run_process_capture_in(
      "moon",
      ["check", "--output-json", "--diagnostic-limit", "200"],
      cwd=module_root,
    )
    if code == -1 {
      return Err("MoonBit compiler is unavailable")
    }
    let combined = stdout + "\n" + stderr
    let diagnostics = source_semantics_diagnostics(
      combined, canonical_workspace_root,
    )
    return Ok({
      "ok": code == 0,
      "action": action,
      "path": clean_path,
      "module_prefix": module_prefix,
      "exit_code": code,
      "diagnostics": diagnostics,
      "diagnostic_count": diagnostics.length(),
    })
  }
  let symbol = json_string(payload, "symbol", default="")
  let line = json_int(payload, "line", default=1)
  let column = json_int(payload, "column", default=1)
  let args = match
    source_semantics_ide_args(action, symbol, module_path, line, column) {
    Ok(args) => args
    Err(problem) => return Err(problem)
  }
  let (code, stdout, stderr) = run_process_capture_in(
    "moon",
    args,
    cwd=module_root,
  )
  if code == -1 {
    return Err("MoonBit IDE service is unavailable")
  }
  let combined = if stdout == "" { stderr } else { stdout + stderr }
  Ok({
    "ok": code == 0,
    "action": action,
    "path": clean_path,
    "module_prefix": module_prefix,
    "symbol": symbol,
    "exit_code": code,
    "output": source_semantics_normalize_output(
      combined, canonical_workspace_root,
    ),
  })
}

///|
async fn handle_workspace_source_semantics(
  workspace_root : String,
  workspace_id : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let workspace = match find_workspace(workspace_root, workspace_id) {
    Some(workspace) => workspace
    None => {
      send_api_error(conn, method_, 404, "Not Found", "Unknown workspace")
      return
    }
  }
  let payload = match read_json_body(body) {
    Some(json) => json
    None => {
      send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
      return
    }
  }
  match source_semantics_result(workspace, payload) {
    Ok(result) => send_json(conn, method_, result)
    Err(problem) =>
      send_api_error(conn, method_, 422, "Unprocessable Content", problem)
  }
}
