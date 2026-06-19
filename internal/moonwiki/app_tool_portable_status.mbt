///|
async fn app_tool_portable_status(
  root : String,
  book_root : String,
  book_id : String,
) -> Json {
  let book_json = read_json_file_or_object(@pathx.join(book_root, "book.json"))
  let manifest_relative = app_tool_manifest_relative_path(book_json)
  let manifest = read_json_file_or_object(
    @pathx.join(book_root, manifest_relative),
  )
  let is_app_tool = app_tool_book_is_portable_candidate(
    book_root, book_json, manifest,
  )
  let entrypoints = app_tool_entrypoints(book_json, manifest)
  let existing_entrypoints : Array[String] = []
  let html_entrypoints : Array[String] = []
  let missing_entrypoints : Array[String] = []
  for entrypoint in entrypoints {
    let absolute = @pathx.join(book_root, entrypoint)
    if @fs.exists(absolute) && !is_directory(absolute) {
      existing_entrypoints.push(entrypoint)
      if app_tool_entrypoint_is_html(entrypoint) {
        html_entrypoints.push(entrypoint)
      }
    } else {
      missing_entrypoints.push(entrypoint)
    }
  }
  let entrypoint = app_tool_preferred_html_entrypoint(html_entrypoints)
  let bundle_root = @pathx.join(
    book_root,
    app_tool_portable_bundle_relative_dir(),
  )
  let portable_manifest_path = @pathx.join(
    book_root,
    app_tool_portable_manifest_relative_path(),
  )
  let portable_manifest = read_json_file_or_object(portable_manifest_path)
  let portable_entrypoint = json_string(
    portable_manifest,
    "entrypoint",
    default=entrypoint,
  )
  let portable_entrypoint_ready = portable_entrypoint != "" &&
    app_tool_entrypoint_is_html(portable_entrypoint) &&
    @fs.exists(@pathx.join(bundle_root, portable_entrypoint)) &&
    !is_directory(@pathx.join(bundle_root, portable_entrypoint))
  let portable_ready = is_app_tool &&
    html_entrypoints.length() > 0 &&
    @fs.exists(@pathx.join(book_root, app_tool_portable_index_relative_path())) &&
    @fs.exists(portable_manifest_path) &&
    @fs.exists(
      @pathx.join(book_root, app_tool_portable_server_script_relative_path()),
    ) &&
    @fs.exists(
      @pathx.join(book_root, app_tool_portable_run_script_relative_path()),
    ) &&
    portable_entrypoint_ready
  let api_warnings = json_string_array_items(
    portable_manifest, "api_dependency_warnings",
  )
  let api_dependency_paths = json_string_array_items(
    portable_manifest, "api_dependency_paths",
  )
  let api_offline_paths = json_string_array_items(
    portable_manifest, "api_offline_paths",
  )
  let api_snapshot_routes = json_string_array_items(
    portable_manifest, "api_snapshot_routes",
  )
  let api_reference_routes = json_string_array_items(
    portable_manifest, "api_reference_routes",
  )
  let api_unsupported_routes = json_string_array_items(
    portable_manifest, "api_unsupported_routes",
  )
  let api_offline_mode = json_string(
    portable_manifest,
    "api_offline_mode",
    default=if api_dependency_paths.length() > 0 ||
      api_offline_paths.length() > 0 {
      "offline-snapshot-runtime"
    } else {
      "none"
    },
  )
  let standalone_launchable = portable_ready && api_warnings.length() == 0
  let status = if !is_app_tool {
    "not_app_tool"
  } else if existing_entrypoints.length() == 0 {
    "missing_entrypoint"
  } else if html_entrypoints.length() == 0 {
    "unsupported_entrypoint"
  } else if portable_ready && api_warnings.length() == 0 {
    "portable_ready"
  } else if portable_ready {
    "portable_with_api_warnings"
  } else {
    "export_required"
  }
  let standalone_blockers = app_tool_portable_standalone_blockers(
    status,
    api_warnings.length(),
  )
  {
    "kind": "moondesk-app-tool-portable-status",
    "ok": is_app_tool && html_entrypoints.length() > 0,
    "status": status,
    "message": app_tool_portable_status_message(status),
    "book_id": book_id,
    "book_root": book_root,
    "workspace_root": root,
    "source_manifest_path": manifest_relative,
    "template_id": app_tool_template_id(book_json, manifest),
    "app_tool": is_app_tool,
    "entrypoint": entrypoint,
    "entrypoints": json_from_string_array(entrypoints),
    "existing_entrypoints": json_from_string_array(existing_entrypoints),
    "html_entrypoints": json_from_string_array(html_entrypoints),
    "missing_entrypoints": json_from_string_array(missing_entrypoints),
    "portable_ready": portable_ready,
    "portable_bundle_path": app_tool_portable_bundle_relative_dir(),
    "portable_index_path": app_tool_portable_index_relative_path(),
    "portable_manifest_path": app_tool_portable_manifest_relative_path(),
    "server_script_path": app_tool_portable_server_script_relative_path(),
    "run_script_path": app_tool_portable_run_script_relative_path(),
    "api_snapshot_path": app_tool_portable_api_snapshot_relative_path(),
    "api_runtime_path": app_tool_portable_api_runtime_relative_path(),
    "standalone_runtime": "served-static-bundle",
    "served_url_hint": "http://127.0.0.1:8765/index.html",
    "run_hint": "cd portable/app-tool && python3 ./serve.py",
    "operatable_without_moondesk_api": standalone_launchable,
    "standalone_launchable": standalone_launchable,
    "auto_open_allowed": standalone_launchable,
    "api_offline_mode": api_offline_mode,
    "api_dependency_paths": json_from_string_array(api_dependency_paths),
    "api_offline_paths": json_from_string_array(api_offline_paths),
    "api_snapshot_routes": json_from_string_array(api_snapshot_routes),
    "api_reference_routes": json_from_string_array(api_reference_routes),
    "api_unsupported_routes": json_from_string_array(api_unsupported_routes),
    "api_dependency_warnings": json_from_string_array(api_warnings),
    "standalone_blockers": json_from_string_array(standalone_blockers),
  }
}

///|
fn app_tool_portable_standalone_blockers(
  status : String,
  api_warning_count : Int,
) -> Array[String] {
  let blockers : Array[String] = []
  match status {
    "not_app_tool" => blockers.push("not_app_tool")
    "missing_entrypoint" => blockers.push("missing_html_entrypoint")
    "unsupported_entrypoint" => blockers.push("unsupported_non_html_entrypoint")
    "export_required" => blockers.push("portable_export_required")
    "portable_with_api_warnings" =>
      blockers.push("unsupported_moondesk_api_dependencies")
    "partial_failure" => blockers.push("portable_export_failed")
    "no_app_tool_books" => blockers.push("no_app_tool_books")
    _ => ()
  }
  if api_warning_count > 0 &&
    !blockers.contains("unsupported_moondesk_api_dependencies") {
    blockers.push("unsupported_moondesk_api_dependencies")
  }
  blockers
}

///|
fn app_tool_portable_status_message(status : String) -> String {
  match status {
    "not_app_tool" =>
      "Book does not declare the app-tool-book template or manifest."
    "missing_entrypoint" =>
      "Book declares app-tool metadata but none of its entrypoints exist."
    "unsupported_entrypoint" =>
      "Book declares app-tool metadata and has existing entrypoints, but none are HTML files suitable for the portable iframe shell."
    "portable_ready" =>
      "Portable app-tool bundle is ready and has no detected Moondesk API dependency."
    "portable_with_api_warnings" =>
      "Portable app-tool bundle was generated, but it still calls APIs outside the generic read-only snapshot. Treat it as an external app pack that needs its own runtime adapter before launch."
    "export_required" =>
      "Book can be exported, but portable/app-tool has not been generated yet."
    _ => "Unknown app-tool portable status."
  }
}
