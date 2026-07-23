///|
fn pack_apps_state_root(workspace_root : String) -> String {
  @pathx.join(moonsuite_state_dir(workspace_root), "pack-apps")
}

///|
fn active_packs_root(workspace_root : String) -> String {
  @pathx.join(moonsuite_state_dir(workspace_root), "packs/active")
}

///|
fn is_safe_pack_id(pack_id : String) -> Bool {
  let value = pack_id.trim().to_owned()
  if value == "" || value.length() > 64 || value != value.to_lower() {
    return false
  }
  for ch in value {
    if !(ch.is_ascii_lowercase() ||
      ch.is_ascii_digit() ||
      ch == '-' ||
      ch == '_') {
      return false
    }
  }
  true
}

///|
fn is_safe_pack_app_area_id(area_id : String) -> Bool {
  let value = area_id.trim().to_owned()
  if value == "" ||
    value.length() > 96 ||
    value != value.to_lower() ||
    value.has_prefix(".") ||
    value.has_suffix(".") ||
    value.contains("..") {
    return false
  }
  for ch in value {
    if !(ch.is_ascii_lowercase() ||
      ch.is_ascii_digit() ||
      ch == '-' ||
      ch == '_' ||
      ch == '.') {
      return false
    }
  }
  true
}

///|
fn is_safe_pack_app_area_label(label : String) -> Bool {
  let value = label.trim().to_owned()
  if value == "" || value.length() > 64 {
    return false
  }
  for ch in value {
    if ch.is_control() {
      return false
    }
  }
  true
}

///|
fn pack_app_manifest_area(
  manifest : Json,
  area_override : Json?,
) -> (Bool, String, String, String) {
  let declared = match area_override {
    Some(area) => Some(area)
    None => json_object_field(manifest, "app_area")
  }
  match declared {
    None => (true, "", "", "")
    Some(Object(_) as area) => {
      let id = json_string(area, "id", default="").trim().to_owned()
      let category = json_string(area, "category", default="").trim().to_owned()
      let label = json_string(area, "label", default="").trim().to_owned()
      if is_safe_pack_app_area_id(id) &&
        is_safe_pack_id(category) &&
        is_safe_pack_app_area_label(label) {
        (true, id, category, label)
      } else {
        (false, "", "", "")
      }
    }
    Some(_) => (false, "", "", "")
  }
}

///|
fn is_safe_local_pack_service_url(url : String) -> Bool {
  let value = url.trim().to_owned().to_lower()
  let prefix = if value.has_prefix("http://127.0.0.1:") {
    "http://127.0.0.1:"
  } else if value.has_prefix("http://localhost:") {
    "http://localhost:"
  } else if value.has_prefix("http://[::1]:") {
    "http://[::1]:"
  } else {
    return false
  }
  let port_text = value[prefix.length():].to_owned()
  let port = @string.parse_int(port_text) catch { _ => return false }
  port > 0 && port < 65536
}

///|
fn is_safe_pack_route_path(path : String) -> Bool {
  let value = path.trim().to_owned()
  if !value.has_prefix("/") ||
    value.contains("//") ||
    value.contains("\\") ||
    value.contains("%") ||
    value.contains("?") ||
    value.contains("#") {
    return false
  }
  for ch in value {
    if ch.is_control() || ch.is_whitespace() {
      return false
    }
  }
  for segment in path_segments(value) {
    if segment == "." || segment == ".." {
      return false
    }
  }
  true
}

///|
fn is_matching_pack_app_url(
  app_url : String,
  service_url : String,
  entrypoint_path : String,
) -> Bool {
  is_safe_local_pack_service_url(service_url) &&
  is_safe_pack_route_path(entrypoint_path) &&
  app_url == service_url + entrypoint_path
}

///|
fn pack_app_runtime_record_resolved(
  active : Json,
  manifest : Json,
  runtime : Json,
  area_override : Json?,
) -> Json? {
  let pack_id = json_string(active, "pack_id", default="").trim().to_owned()
  let manifest_id = json_string(manifest, "id", default="").trim().to_owned()
  let runtime_id = json_string(runtime, "pack_id", default="").trim().to_owned()
  let app_url = json_string(runtime, "app_url", default="").trim().to_owned()
  let service_url = json_string(runtime, "service_url", default="")
    .trim()
    .to_owned()
  let runtime_contract = json_string(runtime, "contract", default="")
    .trim()
    .to_owned()
  let entrypoints = json_array_items(manifest, "app_entrypoints")
  let (area_valid, area_id, area_category, area_label) = pack_app_manifest_area(
    manifest, area_override,
  )
  if !is_safe_pack_id(pack_id) ||
    manifest_id != pack_id ||
    runtime_id != pack_id ||
    runtime_contract != "moonsuite.pack-app-runtime.v1" ||
    !area_valid ||
    entrypoints.length() == 0 {
    return None
  }
  let first = entrypoints[0]
  let entrypoint_path = json_string(first, "path", default="").trim().to_owned()
  if !is_matching_pack_app_url(app_url, service_url, entrypoint_path) {
    return None
  }
  Some({
    "pack_id": pack_id,
    "version": json_string(active, "version", default=""),
    "display_name": json_string(manifest, "display_name", default=pack_id),
    "kind": json_string(manifest, "kind", default=""),
    "entrypoint_id": json_string(first, "id", default="app"),
    "entrypoint_path": entrypoint_path,
    "audience": json_string(first, "audience", default="operator"),
    "area_id": area_id,
    "area_category": area_category,
    "area_label": area_label,
    "app_url": app_url,
    "service_url": service_url,
    "launch_url": "/pack-apps/" + pack_id + "/",
    "runtime_contract": runtime_contract,
    "status": "configured",
  })
}

///|
fn pack_app_runtime_record(
  active : Json,
  manifest : Json,
  runtime : Json,
) -> Json? {
  pack_app_runtime_record_resolved(active, manifest, runtime, None)
}

///|
fn pack_app_catalog_record_resolved(
  active : Json,
  manifest : Json,
  runtime : Json?,
  area_override : Json?,
) -> Json? {
  let pack_id = json_string(active, "pack_id", default="").trim().to_owned()
  let manifest_id = json_string(manifest, "id", default="").trim().to_owned()
  let (area_valid, area_id, area_category, area_label) = pack_app_manifest_area(
    manifest, area_override,
  )
  if !is_safe_pack_id(pack_id) || manifest_id != pack_id || !area_valid {
    return None
  }
  let entrypoints = json_array_items(manifest, "app_entrypoints")
  let configured = match runtime {
    Some(runtime) =>
      match area_override {
        Some(area) =>
          pack_app_runtime_record_resolved(
            active,
            manifest,
            runtime,
            Some(area),
          )
        None => pack_app_runtime_record(active, manifest, runtime)
      }
    None => None
  }
  match configured {
    Some(app) =>
      Some({
        "pack_id": json_string(app, "pack_id", default=pack_id),
        "version": json_string(app, "version", default=""),
        "display_name": json_string(app, "display_name", default=pack_id),
        "description": json_string(manifest, "description", default=""),
        "kind": json_string(app, "kind", default="DomainPack"),
        "entrypoint_id": json_string(app, "entrypoint_id", default="app"),
        "entrypoint_path": json_string(app, "entrypoint_path", default="/"),
        "audience": json_string(app, "audience", default="operator"),
        "area_id": json_string(app, "area_id", default=""),
        "area_category": json_string(app, "area_category", default=""),
        "area_label": json_string(app, "area_label", default=""),
        "app_url": json_string(app, "app_url", default=""),
        "service_url": json_string(app, "service_url", default=""),
        "launch_url": json_string(app, "launch_url", default=""),
        "runtime_contract": json_string(app, "runtime_contract", default=""),
        "status": "configured",
        "entrypoint_count": entrypoints.length(),
        "workflow_count": json_array_items(manifest, "workflows").length(),
        "tool_count": json_array_items(manifest, "tools").length(),
        "configuration_message": "Ready to open",
      })
    None => {
      let has_runtime = runtime is Some(_)
      let status = if entrypoints.is_empty() {
        "workflow_only"
      } else if has_runtime {
        "configuration_invalid"
      } else {
        "configuration_required"
      }
      let message = if status == "workflow_only" {
        "This pack contributes workflows and contracts without a standalone app."
      } else if status == "configuration_invalid" {
        "The local app runtime configuration is invalid or unsafe."
      } else {
        "Install or start the pack app service to open its domain workspace."
      }
      let first = if entrypoints.is_empty() {
        Json::object({})
      } else {
        entrypoints[0]
      }
      Some({
        "pack_id": pack_id,
        "version": json_string(
          active,
          "version",
          default=json_string(manifest, "version", default=""),
        ),
        "display_name": json_string(manifest, "display_name", default=pack_id),
        "description": json_string(manifest, "description", default=""),
        "kind": json_string(manifest, "kind", default="DomainPack"),
        "entrypoint_id": json_string(first, "id", default=""),
        "entrypoint_path": json_string(first, "path", default=""),
        "audience": json_string(first, "audience", default="operator"),
        "area_id": area_id,
        "area_category": area_category,
        "area_label": area_label,
        "app_url": "",
        "service_url": "",
        "launch_url": "",
        "runtime_contract": "",
        "status": status,
        "entrypoint_count": entrypoints.length(),
        "workflow_count": json_array_items(manifest, "workflows").length(),
        "tool_count": json_array_items(manifest, "tools").length(),
        "configuration_message": message,
      })
    }
  }
}

///|
fn pack_app_catalog_record(
  active : Json,
  manifest : Json,
  runtime : Json?,
) -> Json? {
  pack_app_catalog_record_resolved(active, manifest, runtime, None)
}

///|
fn is_safe_installed_pack_artifact_path(path : String) -> Bool {
  let value = path.trim().to_owned()
  if value == "" ||
    value != path ||
    value.contains("\\") ||
    value.contains("%") ||
    @pathx.is_absolute(value) {
    return false
  }
  for ch in value {
    if ch.is_control() {
      return false
    }
  }
  match clean_relative_path(value) {
    Some(normalized) => normalized == value
    None => false
  }
}

///|
async fn resolve_installed_pack_app_area(
  installed_root : String,
  manifest : Json,
) -> (Bool, Json?) {
  if json_object_field(manifest, "app_area") is Some(_) {
    return (true, None)
  }
  let mut artifact : Json? = None
  for evaluation in json_array_items(manifest, "evaluations") {
    if json_string(evaluation, "id", default="") == "moondesk-app-area" {
      if artifact is Some(_) {
        return (false, None)
      }
      artifact = Some(evaluation)
    }
  }
  guard artifact is Some(artifact) else { return (true, None) }
  if json_string(artifact, "version", default="") != "1.0.0" {
    return (false, None)
  }
  let relative = json_string(artifact, "path", default="")
  if !is_safe_installed_pack_artifact_path(relative) {
    return (false, None)
  }
  let root = @fs.realpath(installed_root) catch { _ => return (false, None) }
  let candidate = @pathx.join(root, relative)
  if !@fs.exists(candidate) {
    return (false, None)
  }
  let resolved = @fs.realpath(candidate) catch { _ => return (false, None) }
  if !resolved.has_prefix(root + "/") {
    return (false, None)
  }
  let payload = @json.parse(@fs.read_file(resolved).text()) catch {
    _ => return (false, None)
  }
  if json_string(payload, "contract", default="") !=
    "moonsuite.pack-app-area.v1" {
    return (false, None)
  }
  match json_object_field(payload, "app_area") {
    Some(Object(_) as area) => (true, Some(area))
    _ => (false, None)
  }
}

///|
async fn configured_pack_app(
  workspace_root : String,
  pack_id : String,
) -> Json? {
  if !is_safe_pack_id(pack_id) {
    return None
  }
  let active_path = @pathx.join(
    active_packs_root(workspace_root),
    pack_id + ".json",
  )
  let runtime_path = @pathx.join(
    pack_apps_state_root(workspace_root),
    pack_id + ".json",
  )
  if !@fs.exists(active_path) || !@fs.exists(runtime_path) {
    return None
  }
  let active = read_json_file_or_object(active_path)
  let installed_root = json_string(active, "installed_root", default="")
    .trim()
    .to_owned()
  if installed_root == "" {
    return None
  }
  let manifest_path = @pathx.join(installed_root, "pack.json")
  if !@fs.exists(manifest_path) {
    return None
  }
  let manifest = read_json_file_or_object(manifest_path)
  let (area_contract_valid, area_override) = resolve_installed_pack_app_area(
    installed_root, manifest,
  )
  if !area_contract_valid {
    return None
  }
  let runtime = read_json_file_or_object(runtime_path)
  match area_override {
    Some(area) =>
      pack_app_runtime_record_resolved(active, manifest, runtime, Some(area))
    None => pack_app_runtime_record(active, manifest, runtime)
  }
}

///|
async fn handle_pack_app_proxy(
  workspace_root : String,
  method_ : @http.RequestMethod,
  request_path : String,
  body : &@io.Reader,
  conn : @http.ServerConnection,
) -> Unit {
  guard method_ is Get || method_ is Head || method_ is Post else {
    send_status(conn, 405, "Method Not Allowed", "Method Not Allowed\n")
    return
  }
  let request_route = strip_query(request_path)
  if !is_safe_pack_route_path(request_route) {
    send_status(conn, 400, "Bad Request", "Invalid pack application path\n")
    return
  }
  let segments = path_segments(request_route)
  guard segments is ["pack-apps", pack_id, .. rest] else {
    send_status(conn, 404, "Not Found", "Pack application not found\n")
    return
  }
  if !is_safe_pack_id(pack_id) {
    send_status(conn, 400, "Bad Request", "Invalid pack application path\n")
    return
  }
  guard configured_pack_app(workspace_root, pack_id) is Some(app) else {
    send_status(conn, 404, "Not Found", "Pack application not configured\n")
    return
  }
  let service_url = json_string(app, "service_url", default="")
  let target_path = if rest.length() == 0 {
    json_string(app, "entrypoint_path", default="/")
  } else {
    "/" + rest.join("/")
  }
  let target = service_url + target_path
  let upstream = if method_ is Post {
    let payload = body.read_all().text()
    let json_payload = @json.parse(payload) catch {
      _ => {
        send_status(
          conn, 400, "Bad Request", "Pack application POST requires JSON\n",
        )
        return
      }
    }
    @http.post(target, json_payload, headers={
      "Content-Type": "application/json",
      "Accept": "application/json",
    }) catch {
      _ => {
        send_status(conn, 502, "Bad Gateway", "Pack application unavailable\n")
        return
      }
    }
  } else {
    @http.get(target) catch {
      _ => {
        send_status(conn, 502, "Bad Gateway", "Pack application unavailable\n")
        return
      }
    }
  }
  let (response, data) = upstream
  let response_type = if rest.length() == 0 {
    "text/html; charset=utf-8"
  } else if rest[0] == "api" || rest[0].has_prefix("health") {
    "application/json; charset=utf-8"
  } else {
    content_type(target_path)
  }
  conn.send_response(response.code, "Upstream", extra_headers={
    "content-type": response_type,
    "cache-control": "no-store",
    "x-content-type-options": "nosniff",
  })
  if method_ is Head {
    conn.end_response()
    return
  }
  conn.write(data.binary())
  conn.end_response()
}

///|
async fn installed_pack_apps(workspace_root : String) -> Json {
  let apps : Array[Json] = []
  let mut configured_count = 0
  let active_root = active_packs_root(workspace_root)
  for name in read_directory_names(active_root, include_hidden=false) {
    if !name.has_suffix(".json") {
      continue
    }
    let active = read_json_file_or_object(@pathx.join(active_root, name))
    let pack_id = json_string(active, "pack_id", default="").trim().to_owned()
    let installed_root = json_string(active, "installed_root", default="")
      .trim()
      .to_owned()
    if !is_safe_pack_id(pack_id) ||
      name != pack_id + ".json" ||
      installed_root == "" {
      continue
    }
    let manifest_path = @pathx.join(installed_root, "pack.json")
    let runtime_path = @pathx.join(
      pack_apps_state_root(workspace_root),
      pack_id + ".json",
    )
    if !@fs.exists(manifest_path) {
      continue
    }
    let manifest = read_json_file_or_object(manifest_path)
    let (area_contract_valid, area_override) = resolve_installed_pack_app_area(
      installed_root, manifest,
    )
    if !area_contract_valid {
      continue
    }
    let runtime = if @fs.exists(runtime_path) {
      Some(read_json_file_or_object(runtime_path))
    } else {
      None
    }
    let projected = match area_override {
      Some(area) =>
        pack_app_catalog_record_resolved(active, manifest, runtime, Some(area))
      None => pack_app_catalog_record(active, manifest, runtime)
    }
    match projected {
      Some(app) => {
        if json_string(app, "status", default="") == "configured" {
          configured_count = configured_count + 1
        }
        apps.push(app)
      }
      None => ()
    }
  }
  api_contract_response(
    {
      "contract": "moonsuite.pack-app-catalog.v1",
      "app_count": apps.length(),
      "configured_count": configured_count,
      "apps": Json::array(apps),
      "runtime_config_root": pack_apps_state_root(workspace_root),
    },
    ok=true,
    status="ready",
    message="Installed pack applications are ready",
    next_action=if apps.length() > 0 {
      "open_pack_app"
    } else {
      "configure_pack_app_runtime"
    },
  )
}
