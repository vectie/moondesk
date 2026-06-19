///|
async fn export_app_tool_portable_bundle(
  root : String,
  book_root : String,
  book_id : String,
) -> Json {
  let book_json = read_json_file_or_object(@pathx.join(book_root, "book.json"))
  let manifest_relative = app_tool_manifest_relative_path(book_json)
  let manifest = read_json_file_or_object(
    @pathx.join(book_root, manifest_relative),
  )
  if !app_tool_book_is_portable_candidate(book_root, book_json, manifest) {
    return {
      "kind": "moondesk-app-tool-portable-export",
      "ok": false,
      "status": "not_app_tool",
      "message": app_tool_portable_status_message("not_app_tool"),
      "book_id": book_id,
      "standalone_blockers": json_from_string_array(
        app_tool_portable_standalone_blockers("not_app_tool", 0),
      ),
    }
  }
  let entrypoints = app_tool_entrypoints(book_json, manifest)
  let existing_entrypoints : Array[String] = []
  let html_entrypoints : Array[String] = []
  for entrypoint in entrypoints {
    let absolute = @pathx.join(book_root, entrypoint)
    if @fs.exists(absolute) && !is_directory(absolute) {
      existing_entrypoints.push(entrypoint)
      if app_tool_entrypoint_is_html(entrypoint) {
        html_entrypoints.push(entrypoint)
      }
    }
  }
  if existing_entrypoints.length() == 0 {
    return {
      "kind": "moondesk-app-tool-portable-export",
      "ok": false,
      "status": "missing_entrypoint",
      "message": app_tool_portable_status_message("missing_entrypoint"),
      "book_id": book_id,
      "entrypoints": json_from_string_array(entrypoints),
      "standalone_blockers": json_from_string_array(
        app_tool_portable_standalone_blockers("missing_entrypoint", 0),
      ),
    }
  }
  if html_entrypoints.length() == 0 {
    return {
      "kind": "moondesk-app-tool-portable-export",
      "ok": false,
      "status": "unsupported_entrypoint",
      "message": app_tool_portable_status_message("unsupported_entrypoint"),
      "book_id": book_id,
      "entrypoints": json_from_string_array(entrypoints),
      "existing_entrypoints": json_from_string_array(existing_entrypoints),
      "standalone_blockers": json_from_string_array(
        app_tool_portable_standalone_blockers("unsupported_entrypoint", 0),
      ),
    }
  }
  let bundle_root = @pathx.join(
    book_root,
    app_tool_portable_bundle_relative_dir(),
  )
  @fsx.make_directory(bundle_root, recursive=true, exists_ok=true)
  let source_paths = app_tool_expand_portable_source_paths(
    book_root,
    app_tool_portable_source_paths(book_json, manifest),
  )
  let copied_paths : Array[String] = []
  let missing_paths : Array[String] = []
  let skipped_paths : Array[String] = []
  for relative in source_paths {
    app_tool_copy_book_path(
      book_root, bundle_root, relative, copied_paths, missing_paths, skipped_paths,
    )
  }
  app_tool_rewrite_portable_local_asset_roots(bundle_root, copied_paths)
  let api_dependency_paths = app_tool_portable_api_dependency_paths(
    bundle_root, copied_paths,
  )
  let api_reference_routes = app_tool_portable_api_reference_routes(
    bundle_root, copied_paths,
  )
  let api_offline_paths : Array[String] = []
  let api_dependency_warnings : Array[String] = []
  let api_snapshot_routes = app_tool_portable_api_snapshot_routes()
  let api_unsupported_routes = app_tool_portable_api_unsupported_routes(
    api_reference_routes, api_snapshot_routes,
  )
  let api_snapshot = app_tool_portable_api_snapshot(root, book_id)
  app_tool_write_offline_api_snapshot(
    bundle_root, copied_paths, api_dependency_paths, api_snapshot, api_offline_paths,
    api_dependency_warnings, api_unsupported_routes,
  )
  let standalone_launchable = api_dependency_warnings.length() == 0
  let status = if standalone_launchable {
    "portable_ready"
  } else {
    "portable_with_api_warnings"
  }
  let standalone_blockers = app_tool_portable_standalone_blockers(
    status,
    api_dependency_warnings.length(),
  )
  let entrypoint = app_tool_preferred_html_entrypoint(html_entrypoints)
  let title = app_tool_title(book_json, manifest, book_id)
  let index_html = app_tool_portable_index_html(
    book_id, title, entrypoint, existing_entrypoints, api_dependency_warnings, api_offline_paths,
  )
  @fsx.write_to_file(
    @pathx.join(bundle_root, "index.html"),
    index_html,
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(bundle_root, "README.md"),
    app_tool_portable_readme(
      book_id, entrypoint, api_dependency_warnings, api_offline_paths,
    ),
    create=0o644,
  )
  app_tool_write_static_host_launcher(bundle_root)
  let export_record : Json = {
    "kind": "moondesk-app-tool-portable-bundle",
    "portable_version": "1",
    "ok": true,
    "status": status,
    "book_id": book_id,
    "title": title,
    "template_id": app_tool_template_id(book_json, manifest),
    "source_manifest_path": manifest_relative,
    "bundle_path": app_tool_portable_bundle_relative_dir(),
    "index_path": app_tool_portable_index_relative_path(),
    "manifest_path": app_tool_portable_manifest_relative_path(),
    "server_script_path": app_tool_portable_server_script_relative_path(),
    "run_script_path": app_tool_portable_run_script_relative_path(),
    "api_snapshot_path": app_tool_portable_api_snapshot_relative_path(),
    "api_runtime_path": app_tool_portable_api_runtime_relative_path(),
    "entrypoint": entrypoint,
    "entrypoints": json_from_string_array(existing_entrypoints),
    "html_entrypoints": json_from_string_array(html_entrypoints),
    "copied_paths": json_from_string_array(copied_paths),
    "missing_paths": json_from_string_array(missing_paths),
    "skipped_paths": json_from_string_array(skipped_paths),
    "api_offline_mode": app_tool_offline_api_mode(
      api_dependency_paths, api_offline_paths, api_dependency_warnings,
    ),
    "api_dependency_paths": json_from_string_array(api_dependency_paths),
    "api_offline_paths": json_from_string_array(api_offline_paths),
    "api_snapshot_routes": json_from_string_array(api_snapshot_routes),
    "api_reference_routes": json_from_string_array(api_reference_routes),
    "api_unsupported_routes": json_from_string_array(api_unsupported_routes),
    "api_dependency_warnings": json_from_string_array(api_dependency_warnings),
    "standalone_runtime": "served-static-bundle",
    "served_url_hint": "http://127.0.0.1:8765/index.html",
    "run_hint": "cd portable/app-tool && python3 ./serve.py",
    "operatable_without_moondesk_api": standalone_launchable,
    "standalone_launchable": standalone_launchable,
    "auto_open_allowed": standalone_launchable,
    "standalone_blockers": json_from_string_array(standalone_blockers),
    "open_hint": "Run portable/app-tool/run-local.command or serve portable/app-tool/ from a static HTTP host so generated JavaScript modules and relative assets share one origin.",
  }
  @fsx.write_to_file(
    @pathx.join(bundle_root, "portable-manifest.json"),
    export_record.stringify(indent=2) + "\n",
    create=0o644,
  )
  @fsx.make_directory(
    @pathx.join(book_root, "raw/analysis-runs"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "raw/analysis-runs/app-tool-portable-export.json"),
    export_record.stringify(indent=2) + "\n",
    create=0o644,
  )
  export_record
}
