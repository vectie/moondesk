///|
fn source_semantics_bounded_output(text : String, limit : Int) -> String {
  if text.length() <= limit {
    text
  } else {
    text[:limit].to_owned() + "\n… output truncated"
  }
}

///|
#warnings("-unused_value")
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
#warnings("-unused_value")
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
      let relative = if path.has_prefix("/") {
        match path.strip_prefix(workspace_root + "/") {
          Some(value) => value.to_owned()
          // A sandbox scratch path is not a canonical MoonBook path and must
          // not cross the desktop API boundary.
          None => continue
        }
      } else {
        match clean_relative_path(path) {
          Some(value) => value
          None => continue
        }
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
priv enum SourceSemanticsSandboxAction {
  Diagnostics
  Definition(symbol~ : String, line~ : Int, column~ : Int)
  References(symbol~ : String, line~ : Int, column~ : Int)
}

///|
priv struct SourceSemanticsSandboxRequest {
  workspace_root : String
  module_root : String
  module_path : String
  action : SourceSemanticsSandboxAction
}

///|
priv enum SourceSemanticsResultError {
  InvalidRequest(String)
  SandboxUnavailable
}

///|
fn source_semantics_sandbox_request(
  action : String,
  symbol : String,
  workspace_root : String,
  module_root : String,
  module_path : String,
  line : Int,
  column : Int,
) -> Result[SourceSemanticsSandboxRequest, String] {
  let sandbox_action = match action {
    "diagnostics" => SourceSemanticsSandboxAction::Diagnostics
    "definition" => {
      match
        source_semantics_ide_args(action, symbol, module_path, line, column) {
        Ok(_) => ()
        Err(problem) => return Err(problem)
      }
      Definition(symbol~, line~, column~)
    }
    "references" => {
      match
        source_semantics_ide_args(action, symbol, module_path, line, column) {
        Ok(_) => ()
        Err(problem) => return Err(problem)
      }
      References(symbol~, line~, column~)
    }
    _ => return Err("Unsupported source semantic action")
  }
  Ok({ workspace_root, module_root, module_path, action: sandbox_action })
}

///|
async fn execute_source_semantics_sandbox(
  request : SourceSemanticsSandboxRequest,
) -> Result[Json, SourceSemanticsResultError] {
  ignore(request.module_path)
  match request.action {
    Diagnostics =>
      return match
        source_semantics_sandbox_diagnostics(
          request.workspace_root,
          request.module_root,
        ) {
        Ok(result) => Ok(result)
        Err(Unavailable | InvalidReceipt | Truncated) => Err(SandboxUnavailable)
      }
    Definition(symbol~, line~, column~) | References(symbol~, line~, column~) => {
      ignore(symbol)
      ignore(line)
      ignore(column)
    }
  }
  // Semantic navigation remains closed until it receives its own typed,
  // receipt-bound capability. It must never fall back to a host process.
  Err(SandboxUnavailable)
}

///|
fn source_semantics_sandbox_error_message(
  error : SourceSemanticsResultError,
) -> String {
  match error {
    InvalidRequest(message) => message
    SandboxUnavailable =>
      "Source semantics sandbox is unavailable; host execution was refused"
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
) -> Result[Json, SourceSemanticsResultError] {
  let action = json_string(payload, "action", default="")
  let requested_path = decode_query_value(
    json_string(payload, "path", default=""),
  )
  let clean_path = match clean_relative_path(requested_path) {
    Some(path) if path.has_suffix(".mbt") => path
    _ =>
      return Err(
        InvalidRequest(
          "Compiler semantics require a confined MoonBit source path",
        ),
      )
  }
  let absolute_path = match
    @fsx.resolve_confined_existing(workspace.root_path, clean_path) {
    Some(path) => path
    None =>
      return Err(
        InvalidRequest("MoonBit source path does not exist in this workspace"),
      )
  }
  let canonical_workspace_root = @fs.realpath(workspace.root_path) catch {
    _ => return Err(InvalidRequest("Workspace root is unavailable"))
  }
  let module_root = match
    source_semantics_module_root(canonical_workspace_root, absolute_path) {
    Some(root) => root
    None =>
      return Err(InvalidRequest("No moon.mod was found for this source file"))
  }
  let module_path = match
    source_semantics_module_path(module_root, absolute_path) {
    Some(path) => path
    None =>
      return Err(InvalidRequest("Source path is outside its MoonBit module"))
  }
  let module_prefix = match
    source_semantics_module_prefix(canonical_workspace_root, module_root) {
    Some(prefix) => prefix
    None =>
      return Err(InvalidRequest("MoonBit module is outside this workspace"))
  }
  let symbol = json_string(payload, "symbol", default="")
  let line = json_int(payload, "line", default=1)
  let column = json_int(payload, "column", default=1)
  let request = match
    source_semantics_sandbox_request(
      action, symbol, canonical_workspace_root, module_root, module_path, line, column,
    ) {
    Ok(request) => request
    Err(problem) => return Err(InvalidRequest(problem))
  }
  ignore(module_prefix)
  ignore(clean_path)
  match execute_source_semantics_sandbox(request) {
    Ok(result) => {
      guard request.action is Diagnostics else { return Ok(result) }
      let output = json_string(result, "output", default="")
      let exit_code = json_int(result, "exit_code", default=-1)
      let diagnostics = source_semantics_diagnostics(
        output, canonical_workspace_root,
      )
      Ok({
        "ok": exit_code == 0,
        "action": action,
        "path": clean_path,
        "module_prefix": module_prefix,
        "exit_code": exit_code,
        "diagnostics": diagnostics,
        "diagnostic_count": diagnostics.length(),
        "execution_sandbox": "moonfort",
      })
    }
    Err(error) => Err(error)
  }
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
    Err(InvalidRequest(problem)) =>
      send_api_error(conn, method_, 422, "Unprocessable Content", problem)
    Err(SandboxUnavailable) =>
      send_api_error(
        conn,
        method_,
        503,
        "Service Unavailable",
        source_semantics_sandbox_error_message(SandboxUnavailable),
      )
  }
}
