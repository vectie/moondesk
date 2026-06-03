///|
async fn refresh_generated_text_file(
  book_root : String,
  relative : String,
  content : String,
  refreshed_paths : Array[String],
  changed_paths : Array[String],
) -> Unit {
  let path = @pathx.join(book_root, relative)
  @fsx.make_directory(
    @pathx.dirname(path).to_owned(),
    recursive=true,
    exists_ok=true,
  )
  let previous = read_text_file_or_empty(path)
  if previous != content {
    @fsx.write_to_file(path, content, create=0o644)
    changed_paths.push(relative)
  }
  refreshed_paths.push(relative)
}

///|
fn eb_numeric_timestamp_key(text : String) -> String {
  let clean = text.trim().to_owned()
  if clean == "" {
    return ""
  }
  for ch in clean {
    if ch < '0' || ch > '9' {
      return ""
    }
  }
  let mut start = 0
  while start + 1 < clean.length() && clean[start] == '0' {
    start += 1
  }
  clean[start:].to_owned()
}

///|
fn eb_numeric_timestamp_gt(left : String, right : String) -> Bool {
  let left_key = eb_numeric_timestamp_key(left)
  let right_key = eb_numeric_timestamp_key(right)
  if left_key == "" || right_key == "" {
    return false
  }
  if left_key.length() != right_key.length() {
    return left_key.length() > right_key.length()
  }
  left_key > right_key
}

///|
fn eb_import_stale_after_runtime_refresh(
  book_root : String,
  import_receipt : Json,
  runtime_refresh : Json,
) -> Bool {
  ignore(book_root)
  let latest_changed_at = json_string(
    runtime_refresh,
    "latest_changed_at",
    default="",
  )
  if latest_changed_at == "" {
    return false
  }
  let import_recorded_at = json_string(
    import_receipt,
    "recorded_at",
    default="",
  )
  if import_recorded_at == "" {
    return json_string(import_receipt, "run_id", default="") != ""
  }
  eb_numeric_timestamp_gt(latest_changed_at, import_recorded_at)
}

///|
fn pdf_watch_index_markdown(
  topic : String,
  book_id : String,
  pattern_id : String,
  purpose : String,
  websites : Array[String],
) -> String {
  let lines : Array[String] = [
    "# \{book_pattern_title(pattern_id, topic)}",
    "",
    "- Book id: `\{book_id}`",
    "- Base type: `research-book`",
    "- Pattern: `\{pattern_id}`",
    "- Composition: `research-book + source adapter + extractor + analysis skill + standing watch`",
    "- Notification rule: accepted new knowledge only",
    "- Purpose: \{purpose}",
    "",
    "## Source Websites",
    "",
  ]
  for site in websites {
    lines.push("- \{site}")
  }
  lines.push("")
  lines.push("## Workflow")
  lines.push("")
  lines.push(
    "Configured PDFs land in `raw/pdfs/`, extracted text in `raw/extracted/`, analysis runs in `raw/analysis-runs/`, and reviewed findings in `wiki/findings/`.",
  )
  lines.push("")
  lines.join("\n")
}
