///|
fn pack_apps_state_root(workspace_root : String) -> String {
  @pathx.join(moonsuite_state_dir(workspace_root), "pack-apps")
}

///|
fn active_packs_root(workspace_root : String) -> String {
  @pathx.join(moonsuite_state_dir(workspace_root), "packs/active")
}

///|
fn is_safe_pack_app_url(url : String) -> Bool {
  let value = url.trim().to_owned().to_lower()
  value.has_prefix("http://") || value.has_prefix("https://")
}

///|
fn pack_app_runtime_record(
  active : Json,
  manifest : Json,
  runtime : Json,
) -> Json? {
  let pack_id = json_string(active, "pack_id", default="").trim().to_owned()
  let manifest_id = json_string(manifest, "id", default="").trim().to_owned()
  let runtime_id = json_string(runtime, "pack_id", default="").trim().to_owned()
  let app_url = json_string(runtime, "app_url", default="").trim().to_owned()
  if pack_id == "" || manifest_id != pack_id || runtime_id != pack_id ||
    !is_safe_pack_app_url(app_url) {
    return None
  }
  let entrypoints = json_array_items(manifest, "app_entrypoints")
  if entrypoints.length() == 0 {
    return None
  }
  let first = entrypoints[0]
  Some(
    {
      "pack_id": pack_id,
      "version": json_string(active, "version", default=""),
      "display_name": json_string(
        manifest, "display_name", default=pack_id,
      ),
      "kind": json_string(manifest, "kind", default=""),
      "entrypoint_id": json_string(first, "id", default="app"),
      "entrypoint_path": json_string(first, "path", default="/"),
      "audience": json_string(first, "audience", default="operator"),
      "app_url": app_url,
      "runtime_contract": json_string(runtime, "contract", default=""),
      "status": "configured",
    },
  )
}

///|
async fn installed_pack_apps(workspace_root : String) -> Json {
  let apps : Array[Json] = []
  let active_root = active_packs_root(workspace_root)
  for name in read_directory_names(active_root, include_hidden=false) {
    if !name.has_suffix(".json") {
      continue
    }
    let active = read_json_file_or_object(@pathx.join(active_root, name))
    let pack_id = json_string(active, "pack_id", default="").trim().to_owned()
    let installed_root = json_string(
      active, "installed_root", default="",
    ).trim().to_owned()
    if pack_id == "" || installed_root == "" {
      continue
    }
    let manifest_path = @pathx.join(installed_root, "pack.json")
    let runtime_path = @pathx.join(pack_apps_state_root(workspace_root), pack_id + ".json")
    if !@fs.exists(manifest_path) || !@fs.exists(runtime_path) {
      continue
    }
    match pack_app_runtime_record(
      active,
      read_json_file_or_object(manifest_path),
      read_json_file_or_object(runtime_path),
    ) {
      Some(app) => apps.push(app)
      None => ()
    }
  }
  api_contract_response(
    {
      "contract": "moonsuite.pack-app-catalog.v1",
      "app_count": apps.length(),
      "apps": Json::array(apps),
      "runtime_config_root": pack_apps_state_root(workspace_root),
    },
    ok=true,
    status="ready",
    message="Installed pack applications are ready",
    next_action=if apps.length() > 0 { "open_pack_app" } else { "configure_pack_app_runtime" },
  )
}
