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
  let request_id = json_string(payload, "request_id", default="")
    .trim()
    .to_owned()
  let source_path = json_string(payload, "source_path", default="")
    .trim()
    .to_owned()
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
  if encoded.length() > 16777216 {
    return Err("Browser evidence payload exceeds 16 MiB")
  }
  let host_receipt_id = @desk.stable_id(
    "browser-evidence",
    workspace.id + ":" + request_id + ":" + source_path,
  )
  let evidence_ref = "book/evidence/browser/\{host_receipt_id}.json"
  let absolute = @pathx.join(workspace.root_path, evidence_ref)
  if @fs.exists(absolute) {
    let stored = @json.parse(@fs.read_file(absolute).text()) catch {
      _ => return Err("Stored browser evidence receipt is unreadable")
    }
    return Ok(stored)
  }
  let screenshot_encoded = json_string(
    payload,
    "native_screenshot_png_base64",
    default="",
  )
  let screenshot_ref = if screenshot_encoded == "" {
    ""
  } else {
    "book/evidence/browser/\{host_receipt_id}.png"
  }
  let screenshot = if screenshot_encoded == "" {
    b""
  } else {
    @base64.decode(screenshot_encoded) catch {
      _ => return Err("Native screenshot is not valid base64")
    }
  }
  if screenshot.length() > 10485760 {
    return Err("Native screenshot exceeds 10 MiB")
  }
  if screenshot.length() > 0 &&
    (
      screenshot.length() < 8 ||
      screenshot[0].to_int() != 137 ||
      screenshot[1].to_int() != 80 ||
      screenshot[2].to_int() != 78 ||
      screenshot[3].to_int() != 71 ||
      screenshot[4].to_int() != 13 ||
      screenshot[5].to_int() != 10 ||
      screenshot[6].to_int() != 26 ||
      screenshot[7].to_int() != 10
    ) {
    return Err("Native screenshot is not a PNG")
  }
  let native_host_receipt = match payload {
    Object(object) => object.get("native_host_receipt").unwrap_or(Json::null())
    _ => Json::null()
  }
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
    "screenshot_ref": screenshot_ref,
    "captured_at": @async.now().to_string(),
    "snapshot": {
      "accessibility": json_string(payload, "accessibility", default=""),
      "resources": json_from_string_array(
        json_string_array_items(payload, "resources"),
      ),
      "console": json_string(payload, "console", default=""),
      "runtime": json_string(payload, "runtime", default=""),
      "native_host_receipt": native_host_receipt,
    },
  }
  @fsx.make_directory(@pathx.dirname(absolute), recursive=true, exists_ok=true) catch {
    _ => return Err("Could not create browser evidence directory")
  }
  if screenshot.length() > 0 {
    write_bytes_file(
      @pathx.join(workspace.root_path, screenshot_ref),
      screenshot,
      create=0o644,
    ) catch {
      _ => return Err("Could not persist native screenshot evidence")
    }
  }
  @fsx.write_to_file(absolute, receipt.stringify(indent=2) + "\n", create=0o644) catch {
    _ => {
      if screenshot.length() > 0 {
        @fs.remove(@pathx.join(workspace.root_path, screenshot_ref)) catch {
          _ => ()
        }
      }
      return Err("Could not persist browser evidence receipt")
    }
  }
  Ok(receipt)
}
