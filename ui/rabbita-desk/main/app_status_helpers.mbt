///|
fn app_tool_portable_status_summary(result : Json) -> String {
  let status = json_field_string(result, "status", default="unknown")
  let book_id = json_field_string(result, "book_id", default="")
  let index_path = json_field_string(
    result,
    "index_path",
    default=json_field_string(
      result,
      "portable_index_path",
      default="portable/app-tool/index.html",
    ),
  )
  let manifest_path = json_field_string(
    result,
    "manifest_path",
    default=json_field_string(
      result,
      "portable_manifest_path",
      default="portable/app-tool/portable-manifest.json",
    ),
  )
  let copied = json_field_string_array_items(result, "copied_paths").length()
  let missing = json_field_string_array_items(result, "missing_paths").length()
  let api_free = json_field_bool_label(
    result, "operatable_without_moondesk_api",
  )
  let runtime = json_field_string(
    result,
    "standalone_runtime",
    default="unknown-runtime",
  )
  let run_hint = json_field_string(result, "run_hint", default="")
  let unsupported = json_field_string_array_summary(
    result, "api_unsupported_routes",
  )
  let blockers = json_field_string_array_summary(result, "standalone_blockers")
  "Portable app-tool export \{status}; book \{empty_label(book_id)}; index \{index_path}; manifest \{manifest_path}; runtime \{runtime}; copied \{copied}; missing \{missing}; launchable \{api_free}; blockers \{blockers}; unsupported APIs \{unsupported}; \{run_hint}"
}

///|
fn app_tool_portable_all_status_summary(result : Json) -> String {
  let status = json_field_string(result, "status", default="unknown")
  let book_count = json_field_int(result, "app_tool_book_count", default=0)
  let exported = json_field_int(result, "exported_count", default=0)
  let failures = json_field_int(result, "failure_count", default=0)
  let warnings = json_field_int(result, "api_warning_count", default=0)
  let ready = json_field_int(result, "portable_ready_count", default=0)
  let required = json_field_int(result, "export_required_count", default=0)
  let api_free = json_field_bool_label(
    result, "operatable_without_moondesk_api",
  )
  let blockers = json_field_string_array_summary(result, "standalone_blockers")
  "Portable app-tool batch \{status}; books \{book_count}; exported \{exported}; ready \{ready}; export required \{required}; failures \{failures}; API warnings \{warnings}; launchable \{api_free}; blockers \{blockers}"
}

///|
fn request_title(record : RequestRecord) -> String {
  json_field_string(record.request, "title", default="Moondesk request")
}

///|
fn trimmed_or(value : String, fallback : String) -> String {
  let value = value.trim().to_owned()
  if value == "" {
    fallback
  } else {
    value
  }
}

///|
fn text_lines(value : String) -> Array[String] {
  let lines : Array[String] = []
  for raw in value.split("\n") {
    let line = raw.trim().to_owned()
    if line != "" {
      lines.push(line)
    }
  }
  lines
}

///|
fn int_text(value : String, fallback : Int) -> Int {
  @string.parse_int(value.trim().to_owned()) catch {
    _ => fallback
  }
}

///|
fn clamp_int(value : Int, min : Int, max : Int) -> Int {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}

///|
fn daemon_lifecycle_label(result : DaemonLifecycleResult) -> String {
  let pid = if result.pid > 0 { " pid \{result.pid}" } else { "" }
  "\{result.status}\{pid}: \{result.message}"
}

///|
fn launch_agent_label(result : LaunchAgentResult) -> String {
  let state = if result.installed {
    if result.loaded {
      "loaded"
    } else {
      "installed"
    }
  } else {
    "not installed"
  }
  "LaunchAgent \{state}: \{result.message}"
}
