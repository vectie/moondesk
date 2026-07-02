///|
async fn app_tool_portable_all_status_for_context(
  context : WorkspaceContext,
) -> Json {
  let root = context.suite_root
  let book_ids = app_tool_book_ids_for_context(context)
  let books : Array[Json] = []
  let mut portable_ready_count = 0
  let mut api_warning_count = 0
  let mut export_required_count = 0
  let mut missing_entrypoint_count = 0
  let mut unsupported_entrypoint_count = 0
  for book_id in book_ids {
    let status = app_tool_portable_status(
      root,
      app_tool_book_root_for_context(context, book_id),
      book_id,
    )
    books.push(status)
    match json_string(status, "status", default="unknown") {
      "portable_ready" => portable_ready_count += 1
      "portable_with_api_warnings" => api_warning_count += 1
      "export_required" => export_required_count += 1
      "missing_entrypoint" => missing_entrypoint_count += 1
      "unsupported_entrypoint" => unsupported_entrypoint_count += 1
      _ => ()
    }
  }
  let overall_status = app_tool_portable_all_status_label(
    book_ids.length(),
    portable_ready_count,
    api_warning_count,
    export_required_count,
    missing_entrypoint_count,
    unsupported_entrypoint_count,
  )
  let standalone_launchable = book_ids.length() > 0 &&
    export_required_count == 0 &&
    missing_entrypoint_count == 0 &&
    unsupported_entrypoint_count == 0 &&
    api_warning_count == 0
  let standalone_blockers = app_tool_portable_standalone_blockers(
    overall_status, api_warning_count,
  )
  {
    "kind": "moondesk-app-tool-portable-all-status",
    "ok": missing_entrypoint_count == 0,
    "status": overall_status,
    "message": app_tool_portable_all_status_message(overall_status),
    "workspace_root": root,
    "app_tool_book_count": book_ids.length(),
    "book_ids": json_from_string_array(book_ids),
    "portable_ready_count": portable_ready_count,
    "api_warning_count": api_warning_count,
    "export_required_count": export_required_count,
    "missing_entrypoint_count": missing_entrypoint_count,
    "unsupported_entrypoint_count": unsupported_entrypoint_count,
    "portable_bundle_path": app_tool_portable_bundle_relative_dir(),
    "standalone_runtime": "served-static-bundle",
    "operatable_without_moondesk_api": standalone_launchable,
    "standalone_launchable": standalone_launchable,
    "auto_open_allowed": standalone_launchable,
    "standalone_blockers": json_from_string_array(standalone_blockers),
    "books": Json::array(books),
  }
}

///|
async fn export_all_app_tool_portable_bundles_for_context(
  context : WorkspaceContext,
) -> Json {
  let root = context.suite_root
  let book_ids = app_tool_book_ids_for_context(context)
  let results : Array[Json] = []
  let mut exported_count = 0
  let mut failure_count = 0
  let mut api_warning_count = 0
  for book_id in book_ids {
    let book_root = app_tool_book_root_for_context(context, book_id)
    let result = export_app_tool_portable_bundle(root, book_root, book_id) catch {
      error => {
        failure_count += 1
        results.push({
          "kind": "moondesk-app-tool-portable-export",
          "ok": false,
          "status": "export_failed",
          "message": "Could not export app-tool portable bundle: \{error}",
          "book_id": book_id,
          "standalone_blockers": json_from_string_array(
            app_tool_portable_standalone_blockers("partial_failure", 0),
          ),
        })
        continue
      }
    }
    results.push(result)
    if json_bool(result, "ok", default=false) {
      exported_count += 1
      if json_string(result, "status", default="") ==
        "portable_with_api_warnings" {
        api_warning_count += 1
      }
    } else {
      failure_count += 1
    }
  }
  let status = app_tool_portable_all_export_status_label(
    book_ids.length(),
    failure_count,
    api_warning_count,
  )
  let standalone_launchable = book_ids.length() > 0 &&
    failure_count == 0 &&
    api_warning_count == 0
  let standalone_blockers = app_tool_portable_standalone_blockers(
    status, api_warning_count,
  )
  {
    "kind": "moondesk-app-tool-portable-all-export",
    "ok": failure_count == 0,
    "status": status,
    "message": app_tool_portable_all_status_message(status),
    "workspace_root": root,
    "app_tool_book_count": book_ids.length(),
    "book_ids": json_from_string_array(book_ids),
    "exported_count": exported_count,
    "failure_count": failure_count,
    "api_warning_count": api_warning_count,
    "portable_bundle_path": app_tool_portable_bundle_relative_dir(),
    "standalone_runtime": "served-static-bundle",
    "operatable_without_moondesk_api": standalone_launchable,
    "standalone_launchable": standalone_launchable,
    "auto_open_allowed": standalone_launchable,
    "standalone_blockers": json_from_string_array(standalone_blockers),
    "books": Json::array(results),
  }
}

///|
fn app_tool_portable_all_status_label(
  book_count : Int,
  portable_ready_count : Int,
  api_warning_count : Int,
  export_required_count : Int,
  missing_entrypoint_count : Int,
  unsupported_entrypoint_count : Int,
) -> String {
  if book_count == 0 {
    "no_app_tool_books"
  } else if missing_entrypoint_count > 0 {
    "missing_entrypoint"
  } else if unsupported_entrypoint_count > 0 {
    "unsupported_entrypoint"
  } else if export_required_count > 0 {
    "export_required"
  } else if api_warning_count > 0 {
    "portable_with_api_warnings"
  } else if portable_ready_count == book_count {
    "portable_ready"
  } else {
    "unknown"
  }
}

///|
fn app_tool_portable_all_export_status_label(
  book_count : Int,
  failure_count : Int,
  api_warning_count : Int,
) -> String {
  if book_count == 0 {
    "no_app_tool_books"
  } else if failure_count > 0 {
    "partial_failure"
  } else if api_warning_count > 0 {
    "portable_with_api_warnings"
  } else {
    "portable_ready"
  }
}

///|
fn app_tool_portable_all_status_message(status : String) -> String {
  match status {
    "no_app_tool_books" =>
      "No app-tool MoonBooks were discovered in this workspace."
    "missing_entrypoint" =>
      "One or more app-tool MoonBooks declare metadata but have no existing entrypoint."
    "unsupported_entrypoint" =>
      "One or more app-tool MoonBooks have existing entrypoints, but none are HTML app screens that a portable standalone shell can open."
    "export_required" =>
      "One or more app-tool MoonBooks are exportable but do not have a generated portable bundle yet."
    "portable_ready" =>
      "Every discovered app-tool MoonBook has a portable bundle with no detected Moondesk API dependency."
    "portable_with_api_warnings" =>
      "Every discovered app-tool MoonBook was exported, but at least one generated app still calls APIs outside the generic read-only snapshot and needs an external runtime adapter before launch."
    "partial_failure" => "Some app-tool MoonBooks could not be exported."
    _ => "Unknown app-tool portable workspace status."
  }
}
