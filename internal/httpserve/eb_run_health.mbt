///|
async fn eb_moonclaw_missing_input_step_health(
  home : String,
  run_id : String,
) -> Json {
  let steps_root = if home == "" || run_id == "" {
    ""
  } else {
    @pathx.join(home, "jobs/runs/" + run_id + "/steps")
  }
  let evidence_paths : Array[String] = []
  let blockers : Array[String] = []
  if steps_root != "" {
    for name in read_directory_names(steps_root, include_hidden=false) {
      if !name.has_suffix(".json") {
        continue
      }
      let path = @pathx.join(steps_root, name)
      let step = read_json_file_or_object(path)
      let output = json_object_field_or_empty(step, "output")
      let summary = json_string(step, "summary", default="").to_lower()
      let status = json_string(output, "status", default="").to_lower()
      if status == "best_effort_missing_input" ||
        summary.contains("best-effort continuation after missing input") ||
        summary.contains("continued best-effort after missing input") {
        let step_id = json_string(step, "step_id", default=name)
        let reason = "MoonClaw step used missing-input fallback: \{step_id}"
        if !blockers.contains(reason) {
          blockers.push(reason)
        }
        if !evidence_paths.contains(path) {
          evidence_paths.push(path)
        }
      }
    }
  }
  {
    "kind": "eb-moonclaw-missing-input-step-health",
    "ok": blockers.length() == 0,
    "run_id": run_id,
    "steps_root": steps_root,
    "primary_evidence_path": if evidence_paths.length() > 0 {
      evidence_paths[0]
    } else {
      steps_root
    },
    "evidence_paths": json_from_string_array(evidence_paths),
    "failed_checks": json_from_string_array(blockers),
  }
}

///|
async fn eb_moonclaw_candidate_discovery_health(
  book_root : String,
  home : String,
  run_id : String,
  run_meta : Json,
) -> Json {
  let run_workspace = json_string(run_meta, "workspace_dir", default="")
  let candidate_paths : Array[String] = []
  if book_root != "" && run_id != "" {
    candidate_paths.push(
      @pathx.join(book_root, eb_pdf_candidates_relative_path(run_id)),
    )
  }
  if run_workspace != "" {
    candidate_paths.push(
      @pathx.join(run_workspace, "outputs/official-pdf-candidates.json"),
    )
    candidate_paths.push(
      @pathx.join(run_workspace, "official-pdf-candidates.json"),
    )
  }
  if home != "" && run_id != "" {
    candidate_paths.push(
      @pathx.join(
        home,
        "jobs/runs/" + run_id + "/outputs/official-pdf-candidates.json",
      ),
    )
    candidate_paths.push(
      @pathx.join(home, "jobs/runs/" + run_id + "/official-pdf-candidates.json"),
    )
  }
  let candidate_path = eb_first_existing_path(candidate_paths)
  let candidates = if candidate_path == "" {
    Json::object({})
  } else {
    read_json_file_or_object(candidate_path)
  }
  let candidate_count = eb_pdf_candidate_count(candidates)
  let official_url_count = eb_pdf_candidate_official_url_count(candidates)
  let has_unofficial_urls = eb_pdf_candidate_has_unofficial_urls(candidates)
  let status = json_string(candidates, "status", default="")
    .trim()
    .to_owned()
    .to_lower()
  let target_scope = json_string(candidates, "target_scope", default="")
    .trim()
    .to_owned()
    .to_lower()
  let active_universe_fact_evidence_ready = target_scope != "active_universe" ||
    json_bool(candidates, "fact_based_universe_evidence", default=false)
  let active_universe_completeness_ready = target_scope != "active_universe" ||
    (
      active_universe_fact_evidence_ready &&
      json_bool(candidates, "discovery_completeness_ok", default=false)
    )
  let decision = json_string(candidates, "standing_goal_decision", default="")
    .trim()
    .to_owned()
    .to_lower()
  let failure_reason = json_string(candidates, "failure_reason", default="")
    .trim()
    .to_owned()
  let checked_domain_count = json_string_array_items(
    candidates, "checked_domains",
  ).length()
  let explicit_failure = candidate_path != "" &&
    (status == "failed" || status == "failure" || decision == "failed") &&
    failure_reason != "" &&
    checked_domain_count > 0
  let candidate_ready = candidate_path != "" &&
    candidate_count > 0 &&
    official_url_count > 0 &&
    !has_unofficial_urls &&
    active_universe_completeness_ready
  let terminal_evidence_ready = candidate_ready || explicit_failure
  let failed_checks : Array[String] = []
  push_failed_unless(
    failed_checks,
    candidate_path != "",
    "official source candidate artifact exists",
  )
  if candidate_path != "" {
    push_failed_unless(
      failed_checks, terminal_evidence_ready, "official source candidates include official-domain URLs or an explicit failed candidate record",
    )
    push_failed_unless(
      failed_checks,
      !has_unofficial_urls,
      "official source candidates do not include third-party URLs",
    )
    push_failed_unless(
      failed_checks, active_universe_fact_evidence_ready, "active-universe candidate artifact is backed by observed official-source discovery evidence",
    )
    push_failed_unless(
      failed_checks, active_universe_completeness_ready, "active-universe candidate artifact marks observed source-universe discovery complete without count thresholds",
    )
  }
  {
    "kind": "eb-moonclaw-candidate-discovery-health",
    "ok": terminal_evidence_ready,
    "candidate_ready": candidate_ready,
    "target_scope": target_scope,
    "active_universe_fact_evidence_ready": active_universe_fact_evidence_ready,
    "active_universe_completeness_ready": active_universe_completeness_ready,
    "explicit_failure": explicit_failure,
    "terminal_evidence_ready": terminal_evidence_ready,
    "run_id": run_id,
    "run_workspace": run_workspace,
    "candidate_artifact_path": candidate_path,
    "candidate_count": candidate_count,
    "official_url_count": official_url_count,
    "has_unofficial_urls": has_unofficial_urls,
    "status": status,
    "standing_goal_decision": decision,
    "failure_reason": failure_reason,
    "checked_domain_count": checked_domain_count,
    "failed_checks": json_from_string_array(failed_checks),
  }
}

///|
fn eb_pdf_candidate_count(candidates : Json) -> Int {
  let mut count = 0
  for key in eb_pdf_candidate_url_fields() {
    count += json_string_array_items(candidates, key).length()
  }
  for key in eb_pdf_candidate_record_fields() {
    for item in json_array_items(candidates, key) {
      match item {
        Json::String(value) => if value.trim().to_owned() != "" { count += 1 }
        Json::Object(_) => count += 1
        _ => ()
      }
    }
  }
  count
}

///|
fn eb_pdf_candidate_official_url_count(candidates : Json) -> Int {
  let mut count = 0
  for key in eb_pdf_candidate_url_fields() {
    for url in json_string_array_items(candidates, key) {
      if eb_is_http_url(url) && eb_url_allowed_official_domain(url) {
        count += 1
      }
    }
  }
  for key in eb_pdf_candidate_record_fields() {
    for record in json_array_items(candidates, key) {
      let url = eb_source_record_url(record)
      if eb_is_http_url(url) && eb_url_allowed_official_domain(url) {
        count += 1
      }
    }
  }
  count
}

///|
fn eb_pdf_candidate_has_unofficial_urls(candidates : Json) -> Bool {
  for key in eb_pdf_candidate_url_fields() {
    for url in json_string_array_items(candidates, key) {
      if eb_is_http_url(url) && !eb_url_allowed_official_domain(url) {
        return true
      }
    }
  }
  for key in eb_pdf_candidate_record_fields() {
    for record in json_array_items(candidates, key) {
      let url = eb_source_record_url(record)
      if eb_is_http_url(url) && !eb_url_allowed_official_domain(url) {
        return true
      }
    }
  }
  false
}

///|
fn eb_pdf_candidate_url_fields() -> Array[String] {
  [
    "checked_official_urls", "official_urls", "official_pdf_urls", "candidate_urls",
    "pdf_urls", "source_urls",
  ]
}

///|
fn eb_pdf_candidate_record_fields() -> Array[String] {
  [
    "candidates", "pdf_candidates", "official_pdf_candidates", "sources", "checked_sources",
    "source_records",
  ]
}

///|
async fn eb_moonclaw_web_tool_contract_health(
  book_root : String,
  run_id : String,
  run_meta : Json,
  packet_path : String,
) -> Json {
  let packet_text = read_text_file_or_empty(packet_path).to_lower()
  let packet_requires_web_tools = packet_text.contains("runtime_mode") &&
    packet_text.contains("executor") &&
    packet_text.contains("tool_access") &&
    packet_text.contains("full") &&
    packet_text.contains("allow_execution_tools") &&
    packet_text.contains("required_runtime_tools") &&
    packet_text.contains("web_search") &&
    packet_text.contains("web_fetch")
  let evidence_paths : Array[String] = []
  let blockers : Array[String] = []
  if packet_path == "" || !@fs.exists(packet_path) {
    blockers.push("MoonClaw proposal packet exists")
  } else if !packet_requires_web_tools {
    blockers.push(
      "MoonClaw proposal packet requests executor/full runtime with web_search and web_fetch",
    )
    evidence_paths.push(packet_path)
  }
  if run_id != "" {
    let run_roots : Array[String] = [
      @pathx.join(book_root, "moonclaw-jobs/" + run_id),
    ]
    let workspace_dir = trimmed_payload_text(
      json_string(run_meta, "workspace_dir", default=""),
      default="",
    )
    if workspace_dir != "" &&
      !run_roots.contains(@pathx.normalize(workspace_dir)) {
      run_roots.push(workspace_dir)
    }
    for root in run_roots {
      if @fs.exists(root) {
        eb_collect_web_tool_blockers_from_run_root(
          root, evidence_paths, blockers,
        )
      }
    }
  }
  {
    "kind": "eb-moonclaw-web-tool-contract",
    "ok": blockers.length() == 0,
    "packet_path": packet_path,
    "packet_requires_web_tools": packet_requires_web_tools,
    "run_id": run_id,
    "primary_evidence_path": if evidence_paths.length() > 0 {
      evidence_paths[0]
    } else {
      packet_path
    },
    "evidence_paths": json_from_string_array(evidence_paths),
    "failed_checks": json_from_string_array(blockers),
  }
}

///|
async fn eb_collect_web_tool_blockers_from_run_root(
  root : String,
  evidence_paths : Array[String],
  blockers : Array[String],
) -> Unit {
  for name in read_directory_names(root, include_hidden=true) {
    let path = @pathx.join(root, name)
    if !is_directory(path) &&
      (name.has_suffix(".json") || name.has_suffix(".md")) {
      eb_record_web_tool_blocker(path, evidence_paths, blockers)
    }
  }
  let outputs_root = @pathx.join(root, "outputs")
  for name in read_directory_names(outputs_root, include_hidden=false) {
    let path = @pathx.join(outputs_root, name)
    if !is_directory(path) &&
      (name.has_suffix(".json") || name.has_suffix(".md")) {
      eb_record_web_tool_blocker(path, evidence_paths, blockers)
    }
  }
  eb_record_web_tool_blocker(
    @pathx.join(root, ".moonclaw/run.json"),
    evidence_paths,
    blockers,
  )
}

///|
async fn eb_record_web_tool_blocker(
  path : String,
  evidence_paths : Array[String],
  blockers : Array[String],
) -> Unit {
  if !@fs.exists(path) {
    return
  }
  let reason = eb_web_tool_blocker_reason(
    read_text_file_or_empty(path).to_lower(),
  )
  if reason != "" {
    if !blockers.contains(reason) {
      blockers.push(reason)
    }
    if !evidence_paths.contains(path) {
      evidence_paths.push(path)
    }
  }
}

///|
fn eb_web_tool_blocker_reason(lower : String) -> String {
  if lower.contains("no working web search") ||
    lower.contains("no callable web") ||
    lower.contains("web_search was not enabled") ||
    lower.contains("web_fetch was not enabled") ||
    lower.contains("web search is unavailable") ||
    lower.contains("web fetch is unavailable") ||
    lower.contains("no working web-search") ||
    lower.contains("no working web-fetch") {
    "MoonClaw run output reports web_search or web_fetch unavailable"
  } else if lower.contains("planneronly") &&
    lower.contains("tool_access") &&
    lower.contains("limited") {
    "MoonClaw role runtime was planner-only/limited"
  } else if (
      lower.contains("\"allow_execution_tools\":false") ||
      lower.contains("\"allow_execution_tools\": false")
    ) &&
    lower.contains("web_search") {
    "MoonClaw role runtime disabled execution tools"
  } else {
    ""
  }
}

///|
async fn eb_standing_goal_for_book(root : String, book_id : String) -> Json {
  for goal in read_json_array_file(town_standing_goals_path(root)) {
    if json_string(goal, "target_book_id", default="") == book_id {
      return goal
    }
  }
  Json::object({})
}

///|
async fn eb_latest_watcher_record_for_goal(
  root : String,
  goal_id : String,
  book_id : String,
) -> Json {
  if goal_id == "" {
    return Json::object({})
  }
  let path = @pathx.join(
    @pathx.join(root, ".moontown/watchers"),
    goal_id + ".jsonl",
  )
  if !@fs.exists(path) {
    return Json::object({})
  }
  let text = @fs.read_file(path).text() catch { _ => return Json::object({}) }
  let mut latest : Json = Json::object({})
  for line in text.split("\n") {
    let line = line.trim().to_owned()
    if line == "" {
      continue
    }
    let parsed = @json.parse(line) catch { _ => continue }
    if json_string(parsed, "book_id", default="") == book_id {
      latest = parsed
    }
  }
  latest
}

///|
async fn eb_source_screen_files(book_root : String) -> Array[String] {
  let root = @pathx.join(book_root, "raw/analysis-runs")
  let files : Array[String] = []
  for name in read_directory_names(root, include_hidden=false) {
    if name.has_suffix("-official-source-screen.json") &&
      eb_source_screen_valid(@pathx.join(root, name)) {
      files.push("raw/analysis-runs/" + name)
    }
  }
  files
}

///|
async fn eb_pdf_candidate_files(book_root : String) -> Array[String] {
  let root = @pathx.join(book_root, "raw/analysis-runs")
  let files : Array[String] = []
  for name in read_directory_names(root, include_hidden=false) {
    if name.has_suffix("-official-pdf-candidates.json") &&
      eb_pdf_candidate_file_valid(@pathx.join(root, name)) {
      files.push("raw/analysis-runs/" + name)
    }
  }
  files
}

///|
async fn eb_pdf_candidate_file_valid(path : String) -> Bool {
  let candidates = read_json_file_or_object(path)
  let target_scope = json_string(candidates, "target_scope", default="")
    .trim()
    .to_owned()
    .to_lower()
  let active_universe_fact_evidence_ready = target_scope != "active_universe" ||
    json_bool(candidates, "fact_based_universe_evidence", default=false)
  let active_universe_completeness_ready = target_scope != "active_universe" ||
    (
      active_universe_fact_evidence_ready &&
      json_bool(candidates, "discovery_completeness_ok", default=false)
    )
  eb_pdf_candidate_count(candidates) > 0 &&
  eb_pdf_candidate_official_url_count(candidates) > 0 &&
  !eb_pdf_candidate_has_unofficial_urls(candidates) &&
  active_universe_completeness_ready
}

///|
async fn eb_source_screen_valid(path : String) -> Bool {
  let screen = read_json_file_or_object(path)
  json_string(screen, "kind", default="") == "eb-official-source-screen" &&
  json_string(screen, "status", default="") == "official_source_screened" &&
  json_int(screen, "official_domain_count", default=0) >=
  eb_official_domains().length()
}

///|
async fn eb_production_source_screen_valid(path : String) -> Bool {
  let screen = read_json_file_or_object(path)
  eb_source_screen_valid(path) &&
  eb_source_screen_live_fetch_performed(screen) &&
  eb_source_screen_checked_count(screen) > 0 &&
  eb_source_screen_official_url_count(screen) > 0 &&
  !eb_source_screen_has_unofficial_urls(screen) &&
  eb_source_screen_downloaded_source_count(screen) > 0 &&
  eb_source_screen_extracted_source_count(screen) > 0 &&
  eb_source_screen_has_durable_pdf_evidence(screen)
}

///|
async fn eb_production_source_screen_valid_for_book(
  book_root : String,
  path : String,
) -> Bool {
  let screen = read_json_file_or_object(path)
  eb_production_source_screen_valid(path) &&
  eb_source_screen_has_durable_pdf_evidence_files(book_root, screen)
}

///|
fn eb_source_screen_live_fetch_performed(screen : Json) -> Bool {
  json_bool(screen, "live_fetch_performed", default=false) ||
  json_bool(screen, "live_pdf_fetch_performed", default=false)
}

///|
fn eb_source_screen_checked_count(screen : Json) -> Int {
  let declared = json_int(screen, "checked_sources_count", default=0)
  if declared > 0 {
    declared
  } else {
    eb_source_screen_official_url_count(screen)
  }
}

///|
fn eb_source_screen_declared_count(screen : Json, keys : Array[String]) -> Int {
  for key in keys {
    let declared = json_int(screen, key, default=0)
    if declared > 0 {
      return declared
    }
  }
  0
}

///|
fn eb_source_screen_downloaded_pdf_count(screen : Json) -> Int {
  let declared = eb_source_screen_declared_count(screen, [
    "downloaded_pdf_count", "downloaded_pdfs_count", "pdf_download_count",
  ])
  if declared > 0 {
    return declared
  }
  eb_source_screen_array_item_count(screen, [
    "downloaded_pdfs", "downloaded_pdf_paths", "pdf_downloads",
  ]) +
  eb_source_screen_record_count(screen, fn(record) {
    eb_source_record_downloaded(record)
  })
}

///|
fn eb_source_screen_downloaded_source_count(screen : Json) -> Int {
  let declared = eb_source_screen_declared_count(screen, [
    "downloaded_source_count", "downloaded_sources_count", "source_download_count",
  ])
  if declared > 0 {
    return declared
  }
  let pdf_count = eb_source_screen_downloaded_pdf_count(screen)
  if pdf_count > 0 {
    return pdf_count
  }
  eb_source_screen_record_count(screen, fn(record) {
    eb_source_record_downloaded(record)
  })
}

///|
fn eb_source_screen_extracted_pdf_count(screen : Json) -> Int {
  let declared = eb_source_screen_declared_count(screen, [
    "extracted_pdf_count", "extracted_pdfs_count", "pdf_extract_count",
  ])
  if declared > 0 {
    return declared
  }
  eb_source_screen_array_item_count(screen, [
    "extracted_pdfs", "extracted_documents", "extracted_texts", "extracted_pdf_paths",
  ]) +
  eb_source_screen_record_count(screen, fn(record) {
    eb_source_record_extracted(record)
  })
}

///|
fn eb_source_screen_extracted_source_count(screen : Json) -> Int {
  let declared = eb_source_screen_declared_count(screen, [
    "extracted_source_count", "extracted_sources_count", "source_extract_count",
  ])
  if declared > 0 {
    return declared
  }
  let pdf_count = eb_source_screen_extracted_pdf_count(screen)
  if pdf_count > 0 {
    return pdf_count
  }
  eb_source_screen_record_count(screen, fn(record) {
    eb_source_record_extracted(record)
  })
}

///|
fn eb_source_screen_array_item_count(
  screen : Json,
  keys : Array[String],
) -> Int {
  let mut count = 0
  for key in keys {
    for item in json_array_items(screen, key) {
      match item {
        Json::String(value) => if value.trim().to_owned() != "" { count += 1 }
        Json::Object(_) => count += 1
        _ => ()
      }
    }
  }
  count
}

///|
fn eb_source_screen_record_count(
  screen : Json,
  predicate : (Json) -> Bool,
) -> Int {
  let mut count = 0
  for key in eb_source_screen_record_fields() {
    for record in json_array_items(screen, key) {
      if predicate(record) {
        count += 1
      }
    }
  }
  count
}

///|
fn eb_source_screen_official_url_count(screen : Json) -> Int {
  let mut count = 0
  for key in eb_source_screen_url_fields() {
    for url in json_string_array_items(screen, key) {
      if eb_is_http_url(url) && eb_url_allowed_official_domain(url) {
        count += 1
      }
    }
  }
  for key in eb_source_screen_record_fields() {
    for record in json_array_items(screen, key) {
      let url = eb_source_record_url(record)
      if eb_is_http_url(url) && eb_url_allowed_official_domain(url) {
        count += 1
      }
    }
  }
  count
}

///|
fn eb_source_screen_has_unofficial_urls(screen : Json) -> Bool {
  for key in eb_source_screen_url_fields() {
    for url in json_string_array_items(screen, key) {
      if eb_is_http_url(url) && !eb_url_allowed_official_domain(url) {
        return true
      }
    }
  }
  for key in eb_source_screen_record_fields() {
    for record in json_array_items(screen, key) {
      let url = eb_source_record_url(record)
      if eb_is_http_url(url) && !eb_url_allowed_official_domain(url) {
        return true
      }
    }
  }
  false
}

///|
fn eb_source_screen_url_fields() -> Array[String] {
  [
    "checked_official_urls", "accepted_official_urls", "official_source_urls", "source_urls",
    "pdf_urls",
  ]
}

///|
fn eb_source_screen_record_fields() -> Array[String] {
  [
    "sources", "checked_sources", "accepted_sources", "official_sources", "pdf_sources",
    "source_records",
  ]
}

///|
fn eb_source_screen_has_durable_pdf_evidence(screen : Json) -> Bool {
  for key in eb_source_screen_record_fields() {
    for record in json_array_items(screen, key) {
      if eb_source_record_durable_pdf_evidence(record) {
        return true
      }
    }
  }
  false
}

///|
async fn eb_source_screen_has_durable_pdf_evidence_files(
  book_root : String,
  screen : Json,
) -> Bool {
  for key in eb_source_screen_record_fields() {
    for record in json_array_items(screen, key) {
      if eb_source_record_durable_pdf_evidence_files(book_root, record) {
        return true
      }
    }
  }
  false
}

///|
fn eb_source_record_durable_pdf_evidence(record : Json) -> Bool {
  let url = eb_source_record_url(record)
  eb_is_http_url(url) &&
  eb_url_allowed_official_domain(url) &&
  eb_source_record_downloaded(record) &&
  eb_source_record_extracted(record) &&
  (
    json_string(record, "sha256", default="").trim().to_owned() != "" ||
    json_string(record, "source_sha256", default="").trim().to_owned() != "" ||
    json_string(record, "pdf_sha256", default="").trim().to_owned() != "" ||
    json_string(record, "source_path", default="").trim().to_owned() != "" ||
    json_string(record, "html_path", default="").trim().to_owned() != "" ||
    json_string(record, "local_source_path", default="").trim().to_owned() != "" ||
    json_string(record, "local_pdf_path", default="").trim().to_owned() != "" ||
    json_string(record, "pdf_path", default="").trim().to_owned() != ""
  ) &&
  (
    json_string(record, "extracted_text_sha256", default="").trim().to_owned() !=
    "" ||
    json_string(record, "text_sha256", default="").trim().to_owned() != "" ||
    json_string(record, "extracted_text_path", default="").trim().to_owned() !=
    "" ||
    json_string(record, "text_path", default="").trim().to_owned() != ""
  )
}

///|
async fn eb_source_record_durable_pdf_evidence_files(
  book_root : String,
  record : Json,
) -> Bool {
  eb_source_record_durable_pdf_evidence(record) &&
  (
    eb_record_book_artifact_exists(
      book_root,
      record,
      ["local_pdf_path", "pdf_path"],
      "raw/pdfs/",
    ) ||
    eb_record_book_artifact_exists(
      book_root,
      record,
      ["local_source_path", "source_path", "html_path"],
      "raw/html/",
    )
  ) &&
  eb_record_book_artifact_exists(
    book_root,
    record,
    ["extracted_text_path", "text_path"],
    "raw/extracted/",
  )
}

///|
async fn eb_record_book_artifact_exists(
  book_root : String,
  record : Json,
  keys : Array[String],
  required_prefix : String,
) -> Bool {
  for key in keys {
    let relative = eb_book_relative_path(
      book_root,
      json_string(record, key, default=""),
    )
    if relative.has_prefix(required_prefix) &&
      @fs.exists(@pathx.join(book_root, relative)) {
      return true
    }
  }
  false
}

///|
async fn copy_eb_source_screen_durable_artifacts(
  book_root : String,
  run_workspace : String,
  source_screen_path : String,
) -> Int {
  if run_workspace == "" ||
    source_screen_path == "" ||
    !@fs.exists(source_screen_path) {
    return 0
  }
  let screen = read_json_file_or_object(source_screen_path)
  let mut copied = 0
  for key in eb_source_screen_record_fields() {
    for record in json_array_items(screen, key) {
      if copy_eb_record_book_artifact(
          book_root,
          run_workspace,
          record,
          ["local_pdf_path", "pdf_path"],
          "raw/pdfs/",
        ) {
        copied += 1
      }
      if copy_eb_record_book_artifact(
          book_root,
          run_workspace,
          record,
          ["extracted_text_path", "text_path"],
          "raw/extracted/",
        ) {
        copied += 1
      }
    }
  }
  copied
}

///|
async fn copy_eb_record_book_artifact(
  book_root : String,
  run_workspace : String,
  record : Json,
  keys : Array[String],
  required_prefix : String,
) -> Bool {
  for key in keys {
    let relative = eb_book_relative_path(
      book_root,
      json_string(record, key, default=""),
    )
    if relative == "" || !relative.has_prefix(required_prefix) {
      continue
    }
    let target = @pathx.join(book_root, relative)
    if @fs.exists(target) {
      return false
    }
    let source = @pathx.join(run_workspace, relative)
    if !@fs.exists(source) {
      continue
    }
    let bytes = @fs.read_file(source).binary() catch { _ => continue }
    @fsx.make_directory(
      @pathx.dirname(target).to_owned(),
      recursive=true,
      exists_ok=true,
    )
    write_bytes_file(target, bytes)
    return true
  }
  false
}

///|
fn eb_source_record_url(record : Json) -> String {
  for key in ["url", "pdf_url", "source_url", "original_url", "href"] {
    let value = json_string(record, key, default="").trim().to_owned()
    if value != "" {
      return value
    }
  }
  ""
}

///|
fn eb_source_record_downloaded(record : Json) -> Bool {
  json_bool(record, "downloaded", default=false) ||
  json_bool(record, "pdf_downloaded", default=false) ||
  eb_source_record_status_is_success(record, "download_status") ||
  eb_source_record_status_is_success(record, "fetch_status") ||
  json_string(record, "local_pdf_path", default="").trim().to_owned() != "" ||
  json_string(record, "pdf_path", default="").trim().to_owned() != ""
}

///|
fn eb_source_record_extracted(record : Json) -> Bool {
  json_bool(record, "extracted", default=false) ||
  json_bool(record, "text_extracted", default=false) ||
  eb_source_record_status_is_success(record, "extract_status") ||
  json_string(record, "extracted_text_path", default="").trim().to_owned() != "" ||
  json_string(record, "text_path", default="").trim().to_owned() != ""
}

///|
fn eb_source_record_status_is_success(record : Json, key : String) -> Bool {
  let value = json_string(record, key, default="").trim().to_owned().to_lower()
  value == "ok" ||
  value == "success" ||
  value == "succeeded" ||
  value == "completed" ||
  value == "downloaded" ||
  value == "extracted" ||
  value == "fetched"
}

///|
fn eb_is_http_url(url : String) -> Bool {
  let lower = url.trim().to_owned().to_lower()
  lower.has_prefix("https://") || lower.has_prefix("http://")
}

///|
fn eb_url_allowed_official_domain(url : String) -> Bool {
  let host = eb_url_host(url)
  if host == "" {
    return false
  }
  for domain in eb_official_domains() {
    let domain = domain.to_lower()
    if host == domain || host.has_suffix("." + domain) {
      return true
    }
  }
  false
}

///|
fn eb_url_host(url : String) -> String {
  let lower = url.trim().to_owned().to_lower()
  let rest = if lower.has_prefix("https://") {
    lower[8:].to_owned()
  } else if lower.has_prefix("http://") {
    lower[7:].to_owned()
  } else {
    lower
  }
  let path_parts = rest.split("/").to_array()
  let before_path = if path_parts.length() == 0 {
    rest
  } else {
    path_parts[0].to_owned()
  }
  let query_parts = before_path.split("?").to_array()
  let before_query = if query_parts.length() == 0 {
    before_path
  } else {
    query_parts[0].to_owned()
  }
  let port_parts = before_query.split(":").to_array()
  if port_parts.length() == 0 {
    before_query.trim().to_owned()
  } else {
    port_parts[0].trim().to_owned()
  }
}

///|
fn is_accepted_eb_output_name(name : String) -> Bool {
  name.has_prefix("EB追踪_") &&
  name.has_suffix(".xlsx") &&
  !name.contains("[") &&
  !name.contains("]") &&
  !name.contains("债券代码") &&
  !name.contains("债券简称") &&
  !name.contains("YYYYMMDD")
}

///|
async fn eb_contract_verification(
  root : String,
  book_root : String,
  book_id : String,
) -> Json {
  let failed : Array[String] = []
  let book_json = read_json_file_or_object(@pathx.join(book_root, "book.json"))
  let request_path = @pathx.join(
    book_root, "raw/inbox/eb-tracking-request.json",
  )
  let dispatch_path = @pathx.join(
    book_root, "raw/inbox/eb-standing-watch-dispatch.json",
  )
  let moonclaw_profile_path = @pathx.join(book_root, "moonclaw.jobs.json")
  let moonclaw_packet_path = @pathx.join(
    book_root,
    eb_moonclaw_proposal_packet_relative_path(),
  )
  let watch_contract_path = @pathx.join(
    book_root, "raw/bootstrap/EB_WATCH_CONTRACT.md",
  )
  let operator_prompt_path = @pathx.join(
    book_root,
    eb_operator_prompt_relative_path(),
  )
  let prompt_contract_path = @pathx.join(
    book_root,
    eb_prompt_contract_receipt_relative_path(),
  )
  let prompt_contract = eb_prompt_contract_verification(book_root, book_id)
  let prompt_contract_receipt = read_json_file_or_object(prompt_contract_path)
  let expected_output_contract_path = @pathx.join(
    book_root,
    eb_expected_output_contract_relative_path(),
  )
  let expected_output_contract = read_json_file_or_object(
    expected_output_contract_path,
  )
  let base_type_selection_path = @pathx.join(
    book_root,
    pdf_watch_base_type_selection_relative_path(),
  )
  let base_type_selection = read_json_file_or_object(base_type_selection_path)
  let schema_path = @pathx.join(
    book_root, "schemas/eb-tracking-output.schema.md",
  )
  let method_path = @pathx.join(book_root, "wiki/methods/analysis-method.md")
  let evidence_matrix_path = @pathx.join(book_root, "wiki/evidence-matrix.md")
  let skill_path = @pathx.join(
    book_root, "skills/eb-credit-compliance/SKILL.md",
  )
  let output_path = @pathx.join(book_root, eb_output_template_relative_path())
  let output_validation_path = @pathx.join(
    book_root,
    eb_output_validation_relative_path(),
  )
  let output_validation = eb_output_validation(book_root, book_id)
  let handoff_path = if root == "" {
    ""
  } else {
    @pathx.join(town_moondesk_requests_root(root), book_id + ".json")
  }
  let template_config_path = if root == "" {
    ""
  } else {
    @pathx.join(town_book_template_config_root(root), book_id + ".json")
  }
  let template_publish_receipt_path = @pathx.join(
    book_root,
    pdf_watch_moontown_publish_receipt_relative_path(),
  )
  let template_publish_receipt = read_json_file_or_object(
    template_publish_receipt_path,
  )
  let template_publish_output_contract = json_object_field_or_empty(
    template_publish_receipt, "output_contract",
  )
  let standing_goal_receipt_path = @pathx.join(
    book_root,
    pdf_watch_moontown_standing_goal_receipt_relative_path(),
  )
  let standing_goal_receipt = read_json_file_or_object(
    standing_goal_receipt_path,
  )
  let standing_goal_output_contract = json_object_field_or_empty(
    standing_goal_receipt, "output_contract",
  )
  let global_standing_goal_ready = if root == "" {
    false
  } else {
    json_record_with_target_book_exists(
      read_json_array_file(town_standing_goals_path(root)),
      book_id,
    )
  }
  let standing_goal_registration_ready = moontown_standing_goal_registration_ready(
    standing_goal_receipt_path, standing_goal_receipt, book_id,
  )
  let template_request_id = @desk.stable_id("book-template-request", book_id)
  push_failed_unless(
    failed,
    @fs.exists(request_path),
    "execution request exists",
  )
  push_failed_unless(
    failed,
    @fs.exists(dispatch_path),
    "standing watch dispatch packet exists",
  )
  push_failed_unless(
    failed,
    @fs.exists(watch_contract_path),
    "EB standing watch contract exists",
  )
  push_failed_unless(
    failed,
    @fs.exists(base_type_selection_path) &&
    json_bool(base_type_selection, "verified", default=false) &&
    pdf_watch_base_type_selection_valid_for_book(book_json, base_type_selection),
    "research-book base type selection receipt exists and is verified",
  )
  push_failed_unless(
    failed,
    @fs.exists(operator_prompt_path),
    "EB operator prompt artifact exists",
  )
  push_failed_unless(
    failed,
    @fs.exists(prompt_contract_path),
    "EB operator prompt contract receipt exists",
  )
  push_failed_unless(
    failed,
    json_bool(prompt_contract, "verified", default=false),
    "EB operator prompt contract content is complete",
  )
  push_failed_unless(
    failed,
    json_bool(prompt_contract_receipt, "verified", default=false) &&
    json_string(prompt_contract_receipt, "prompt_path", default="") ==
    eb_operator_prompt_relative_path(),
    "EB operator prompt contract receipt is verified and points at prompt artifact",
  )
  push_failed_unless(
    failed,
    @fs.exists(expected_output_contract_path) &&
    eb_expected_output_contract_valid(expected_output_contract),
    "EB expected output contract receipt exists and is verified",
  )
  push_failed_unless(
    failed,
    @fs.exists(moonclaw_profile_path),
    "MoonClaw EB profile exists",
  )
  push_failed_unless(
    failed,
    @fs.exists(@pathx.join(book_root, "raw/bootstrap/eb_extract_pdf_text.py")) &&
    @fs.exists(@pathx.join(book_root, "raw/bootstrap/eb_package_workbook.py")),
    "EB deterministic extraction and packaging helpers exist",
  )
  push_failed_unless(
    failed,
    @fs.exists(moonclaw_packet_path),
    "MoonClaw EB proposal packet exists",
  )
  push_failed_unless(failed, @fs.exists(schema_path), "output schema exists")
  push_failed_unless(failed, @fs.exists(method_path), "analysis method exists")
  push_failed_unless(
    failed,
    @fs.exists(evidence_matrix_path) &&
    file_contains(evidence_matrix_path, "Evidence Matrix") &&
    file_contains(evidence_matrix_path, "Bookkeeper"),
    "MoonBook evidence matrix exists",
  )
  push_failed_unless(failed, @fs.exists(skill_path), "EB skill exists")
  push_failed_unless(
    failed,
    @fs.exists(output_validation_path),
    "output validation record exists",
  )
  push_failed_unless(
    failed,
    eb_xlsx_package_valid(output_path),
    "XLSX template is valid package payload",
  )
  push_failed_unless(
    failed,
    eb_xlsx_internal_contract_valid(output_path),
    "XLSX template has required sheets, headers, and formatting contract",
  )
  push_failed_unless(
    failed,
    eb_output_manifest_valid(
      book_root,
      eb_output_template_relative_path(),
      accepted_required=false,
    ),
    "XLSX template manifest preserves output contract",
  )
  for header in eb_announcement_sheet_headers() {
    push_failed_unless(
      failed,
      file_contains(schema_path, header),
      "schema has announcement header: \{header}",
    )
  }
  for header in eb_indicator_sheet_headers() {
    push_failed_unless(
      failed,
      file_contains(schema_path, header),
      "schema has indicator header: \{header}",
    )
  }
  for
    proof in [
      ".manifest.json", ".validation.json", "xlsx_sha256", "workbook_data_proof",
      "appendix_notes", "quality_proof", "lifecycle_stage_proof", "official-source-screen.json",
    ] {
    push_failed_unless(
      failed,
      file_contains(schema_path, proof),
      "schema has output proof rule: \{proof}",
    )
  }
  for
    stage in [
      "发行与上市", "存续期定期报告", "存续期临时公告", "换股期管理",
      "赎回与回售", "兑付与退出",
    ] {
    push_failed_unless(
      failed,
      file_contains(request_path, stage),
      "execution request has lifecycle stage: \{stage}",
    )
  }
  for domain in eb_official_domains() {
    push_failed_unless(
      failed,
      file_contains(request_path, domain),
      "execution request has official domain: \{domain}",
    )
    push_failed_unless(
      failed,
      file_contains(dispatch_path, domain),
      "standing watch dispatch has official domain: \{domain}",
    )
  }
  for
    marker in [
      "standing_goal_decision", "delta_score", "new_source_count", "checked_sources_count",
      "accepted_facts_count", "book_changed",
    ] {
    push_failed_unless(
      failed,
      file_contains(dispatch_path, marker) &&
      file_contains(watch_contract_path, marker),
      "standing watch marker includes: \{marker}",
    )
  }
  push_failed_unless(
    failed,
    file_contains(dispatch_path, "MoonClaw") &&
    file_contains(dispatch_path, "Bookkeeper"),
    "standing watch dispatch preserves executor/reviewer split",
  )
  push_failed_unless(
    failed,
    file_contains(request_path, "target_bonds") &&
    file_contains(request_path, "target_bond_count") &&
    file_contains(dispatch_path, "target_bonds") &&
    file_contains(moonclaw_packet_path, "target_bonds"),
    "EB target bond list is durable across request, dispatch, and MoonClaw packet",
  )
  push_failed_unless(
    failed,
    file_contains(moonclaw_profile_path, "eb_pdf_evidence_watch") &&
    file_contains(moonclaw_profile_path, "package_result") &&
    file_contains(moonclaw_profile_path, "eb_package_workbook.py"),
    "MoonClaw profile has EB watch execution steps",
  )
  push_failed_unless(
    failed,
    file_contains(moonclaw_profile_path, "\"timeout_ms\": 300000") &&
    file_contains(moonclaw_profile_path, "\"max_total_tokens\": 48000") &&
    file_contains(moonclaw_profile_path, "\"retry_max_attempts\": 1") &&
    file_contains(moonclaw_packet_path, "\"timeout_ms\": 300000") &&
    file_contains(moonclaw_packet_path, "\"max_total_tokens\": 48000") &&
    file_contains(moonclaw_packet_path, "\"retry_max_attempts\": 1"),
    "MoonClaw EB execution steps are bounded by timeout and token ceiling",
  )
  push_failed_unless(
    failed,
    file_contains(moonclaw_packet_path, "eb_pdf_evidence_watch") &&
    file_contains(moonclaw_packet_path, "raw/inbox/eb-tracking-request.json") &&
    file_contains(
      moonclaw_packet_path, "moondesk.exchangeable_bond_tracking.xlsx.v1",
    ),
    "MoonClaw proposal packet targets EB execution contract",
  )
  for
    proof in [
      "workbook_data_proof", "appendix_notes", "quality_proof", "lifecycle_stage_proof",
    ] {
    push_failed_unless(
      failed,
      file_contains(request_path, proof) &&
      file_contains(dispatch_path, proof) &&
      file_contains(moonclaw_packet_path, proof),
      "handoff requires workbook validation proof: \{proof}",
    )
  }
  push_failed_unless(
    failed,
    file_contains(method_path, "公告追踪主表") &&
    file_contains(method_path, "关键指标监控表"),
    "analysis method names both required sheets",
  )
  push_failed_unless(
    failed,
    file_contains(operator_prompt_path, "角色设定") &&
    file_contains(
      operator_prompt_path, "EB追踪_[债券代码]_[债券简称]_[YYYYMMDD].xlsx",
    ) &&
    file_contains(operator_prompt_path, "Excel (.xlsx)"),
    "operator prompt preserves canonical Chinese EB workflow and output contract",
  )
  push_failed_unless(
    failed,
    file_contains(skill_path, "Bookkeeper") &&
    file_contains(skill_path, "公告追踪主表"),
    "EB skill preserves review and normalization rules",
  )
  if root != "" {
    push_failed_unless(
      failed,
      @fs.exists(handoff_path),
      "Moondesk handoff exists",
    )
    push_failed_unless(
      failed,
      @fs.exists(template_config_path),
      "Moontown template install config exists",
    )
    push_failed_unless(
      failed,
      json_record_with_id_exists(
        json_array_items(
          read_json_file_or_object(town_book_template_request_path(root)),
          "requests",
        ),
        template_request_id,
      ),
      "Moontown template request receipt exists",
    )
    push_failed_unless(
      failed,
      @fs.exists(template_publish_receipt_path) &&
      json_bool(template_publish_receipt, "ok", default=false) &&
      json_string(template_publish_receipt, "status", default="") == "installed",
      "Moontown template publish receipt is installed and durable",
    )
    push_failed_unless(
      failed,
      json_string(
        template_publish_output_contract,
        "output_contract",
        default="",
      ) ==
      "moondesk.exchangeable_bond_tracking.xlsx.v1" &&
      json_string(
        template_publish_output_contract,
        "expected_output_contract_path",
        default="",
      ) ==
      eb_expected_output_contract_relative_path(),
      "Moontown template publish receipt preserves EB output contract handoff",
    )
    push_failed_unless(
      failed,
      global_standing_goal_ready || standing_goal_registration_ready,
      "Moontown standing watch handoff targets book",
    )
    push_failed_unless(
      failed, standing_goal_registration_ready, "Moontown standing goal registration receipt is durable",
    )
    push_failed_unless(
      failed,
      json_string(standing_goal_output_contract, "output_contract", default="") ==
      "moondesk.exchangeable_bond_tracking.xlsx.v1" &&
      json_string(
        standing_goal_output_contract,
        "expected_output_contract_path",
        default="",
      ) ==
      eb_expected_output_contract_relative_path(),
      "Moontown standing goal registration receipt preserves EB output contract handoff",
    )
    push_failed_unless(
      failed,
      json_record_with_id_exists(
        read_json_array_file(town_moonbooks_path(root)),
        book_id,
      ),
      "MoonBook catalog entry exists",
    )
  }
  {
    "book_id": book_id,
    "pattern_id": "exchangeable-bond-evidence-watch",
    "verified": failed.length() == 0,
    "failed_checks": json_from_string_array(failed),
    "required_sheet_count": 2,
    "announcement_header_count": eb_announcement_sheet_headers().length(),
    "indicator_header_count": eb_indicator_sheet_headers().length(),
    "official_domain_count": eb_official_domains().length(),
    "lifecycle_stage_count": 6,
    "output_template_path": eb_output_template_relative_path(),
    "output_validation_path": eb_output_validation_relative_path(),
    "expected_output_contract_path": eb_expected_output_contract_relative_path(),
    "expected_output_contract": expected_output_contract,
    "operator_prompt_path": eb_operator_prompt_relative_path(),
    "operator_prompt_contract_path": eb_prompt_contract_receipt_relative_path(),
    "operator_prompt_contract": prompt_contract,
    "base_type_selection_path": pdf_watch_base_type_selection_relative_path(),
    "base_type_selection": base_type_selection,
    "moontown_template_publish_receipt_path": pdf_watch_moontown_publish_receipt_relative_path(),
    "output_validation": output_validation,
    "moontown_template_config_path": template_config_path,
    "moontown_template_request_id": template_request_id,
    "moontown_global_standing_goal_ready": global_standing_goal_ready,
    "moontown_standing_goal_registration_ready": standing_goal_registration_ready,
    "moontown_standing_goal_registration_path": pdf_watch_moontown_standing_goal_receipt_relative_path(),
  }
}
