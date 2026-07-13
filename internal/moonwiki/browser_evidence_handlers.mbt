///|
async fn handle_browser_evidence_persistence(
  workspace_root : String,
  workspace_id : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let payload = match read_json_body(body) {
    Some(json) => json
    None => {
      send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
      return
    }
  }
  match persist_browser_evidence(workspace_root, workspace_id, payload) {
    Ok(receipt) => send_json(conn, method_, receipt)
    Err(message) => send_api_error(conn, method_, 400, "Bad Request", message)
  }
}

///|
async fn persist_browser_evidence(
  workspace_root : String,
  workspace_id : String,
  payload : Json,
) -> Result[Json, String] {
  let workspace = match find_workspace(workspace_root, workspace_id) {
    Some(workspace) => workspace
    None => return Err("Unknown workspace")
  }
  let request_id = json_string(payload, "request_id", default="").trim().to_owned()
  let source_path = json_string(payload, "source_path", default="").trim().to_owned()
  let protocol = json_string(payload, "protocol", default="")
  if protocol != "moondesk-preview-evidence-v1" {
    return Err("Unsupported browser evidence protocol")
  }
  if request_id == "" {
    return Err("Browser evidence request id is required")
  }
  if !@desk.browser_local_preview_path_allowed(source_path) {
    return Err("Browser evidence source path is outside generated site scope")
  }
  let encoded = payload.stringify()
  if encoded.length() > 262144 {
    return Err("Browser evidence payload exceeds 256 KiB")
  }
  let host_receipt_id = @desk.stable_id(
    "browser-evidence", workspace.id + ":" + request_id + ":" + source_path,
  )
  let evidence_ref = "book/evidence/browser/{host_receipt_id}.json"
  let absolute = @pathx.join(workspace.root_path, evidence_ref)
  let receipt : Json = {
    "kind": "browser-evidence-candidate",
    "protocol": "moondesk-browser-host-v1",
    "status": "persisted",
    "acceptance_status": "awaiting-bookkeeper-review",
    "host_receipt_id": host_receipt_id,
    "evidence_ref": evidence_ref,
    "workspace_id": workspace.id,
    "source_path": source_path,
    "request_id": request_id,
    "immutable": true,
    "captured_at": @async.now().to_string(),
    "snapshot": payload,
  }
  if !@fs.exists(absolute) {
    @fsx.make_directory(
      @pathx.dirname(absolute), recursive=true, exists_ok=true,
    ) catch {
      _ => return Err("Could not create browser evidence directory")
    }
    @fsx.write_to_file(
      absolute, receipt.stringify(indent=2) + "\n", create=0o644,
    ) catch {
      _ => return Err("Could not persist browser evidence receipt")
    }
  }
  Ok(receipt)
}
