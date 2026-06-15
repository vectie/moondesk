///|
async fn book_contract_verification(
  root : String,
  book_root : String,
  book_id : String,
  pattern_id : String,
) -> Json {
  if pattern_id == "exchangeable-bond-evidence-watch" {
    eb_contract_verification(root, book_root, book_id)
  } else {
    pdf_watch_contract_verification(root, book_root, book_id, pattern_id)
  }
}

///|
async fn pdf_watch_contract_verification(
  root : String,
  book_root : String,
  book_id : String,
  pattern_id : String,
) -> Json {
  let checks : Array[String] = []
  let missing : Array[String] = []
  let book_json = read_json_file_or_object(@pathx.join(book_root, "book.json"))
  let watch = json_object_field_or_empty(book_json, "watch")
  let analysis = json_object_field_or_empty(book_json, "analysis")
  let base_type_provenance = json_object_field_or_empty(
    book_json, "base_type_provenance",
  )
  let operator_config_path = @pathx.join(
    book_root,
    pdf_watch_operator_config_relative_path(),
  )
  let operator_config = read_json_file_or_object(operator_config_path)
  let base_type_selection_path = @pathx.join(
    book_root,
    pdf_watch_base_type_selection_relative_path(),
  )
  let base_type_selection = read_json_file_or_object(base_type_selection_path)
  let operator_watch = json_object_field_or_empty(operator_config, "watch")
  let operator_analysis = json_object_field_or_empty(
    operator_config, "analysis",
  )
  let request_id = @desk.stable_id("book-template-request", book_id)
  let request = json_record_by_id(
    json_array_items(
      read_json_file_or_object(town_book_template_request_path(root)),
      "requests",
    ),
    request_id,
  )
  let config_path = @pathx.join(
    town_book_template_config_root(root),
    book_id + ".json",
  )
  let publish_receipt_path = @pathx.join(
    book_root,
    pdf_watch_moontown_publish_receipt_relative_path(),
  )
  let publish_receipt = read_json_file_or_object(publish_receipt_path)
  let standing_goal_receipt_path = @pathx.join(
    book_root,
    pdf_watch_moontown_standing_goal_receipt_relative_path(),
  )
  let standing_goal_receipt = read_json_file_or_object(
    standing_goal_receipt_path,
  )
  let install_config = read_json_file_or_object(config_path)
  let standing_goals = read_json_array_file(town_standing_goals_path(root))
  let global_standing_goal_ready = json_record_with_target_book_exists(
    standing_goals, book_id,
  )
  let standing_goal_registration_ready = moontown_standing_goal_registration_ready(
    standing_goal_receipt_path, standing_goal_receipt, book_id,
  )
  let catalog = read_json_array_file(town_moonbooks_path(root))
  record_contract_check(
    checks,
    missing,
    "book.json declares research-book base type",
    json_string(book_json, "type", default="") == "research-book" &&
    json_string(book_json, "book_type", default="") == "research-book",
  )
  record_contract_check(
    checks,
    missing,
    "book.json records MoonBook/Moontown base-type provenance",
    pdf_watch_base_type_provenance_valid(base_type_provenance),
  )
  record_contract_check(
    checks,
    missing,
    "book records durable base-type selection from Moondesk catalog",
    @fs.exists(base_type_selection_path) &&
    pdf_watch_base_type_selection_valid_for_book(book_json, base_type_selection) &&
    json_bool(base_type_selection, "verified", default=false),
  )
  record_contract_check(
    checks,
    missing,
    "book.json records the requested PDF Evidence Watch book layout",
    json_string(
      json_object_field_or_empty(book_json, "layout"),
      "raw_inbox",
      default="",
    ) ==
    "raw/inbox/" &&
    json_string(
      json_object_field_or_empty(book_json, "layout"),
      "raw_pdfs",
      default="",
    ) ==
    "raw/pdfs/" &&
    json_string(
      json_object_field_or_empty(book_json, "layout"),
      "raw_extracted",
      default="",
    ) ==
    "raw/extracted/" &&
    json_string(
      json_object_field_or_empty(book_json, "layout"),
      "raw_analysis_runs",
      default="",
    ) ==
    "raw/analysis-runs/" &&
    json_string(
      json_object_field_or_empty(book_json, "layout"),
      "site_generated",
      default="",
    ) ==
    "site/generated/",
  )
  record_contract_check(
    checks,
    missing,
    "book.json keeps reusable pdf-evidence-watch specialization",
    json_string(book_json, "pattern", default="") == pattern_id &&
    json_string(book_json, "template_id", default="") == "pdf-evidence-watch",
  )
  record_contract_check(
    checks,
    missing,
    "watch config has source websites and PDF dedupe policy",
    json_string_array_items(watch, "websites").length() > 0 &&
    json_string_array_items(watch, "file_types").contains("pdf") &&
    json_string_array_items(watch, "dedupe_by").contains("sha256"),
  )
  record_contract_check(
    checks,
    missing,
    "analysis config points at wiki/methods/my-analysis-method.md",
    json_string(analysis, "method_page", default="") ==
    "wiki/methods/my-analysis-method.md",
  )
  record_contract_check(
    checks,
    missing,
    "book-owned operator config preserves the reusable nested watch/analysis shape",
    @fs.exists(operator_config_path) &&
    json_string(operator_config, "type", default="") == "research-book" &&
    json_string(operator_config, "id", default="") == book_id &&
    json_string_array_items(operator_watch, "websites").length() > 0 &&
    json_string_array_items(operator_watch, "file_types").contains("pdf") &&
    json_string_array_items(operator_watch, "dedupe_by").contains("sha256") &&
    json_string(operator_analysis, "method_page", default="") ==
    "wiki/methods/my-analysis-method.md",
  )
  for path in pdf_watch_required_paths(pattern_id) {
    record_contract_check(
      checks,
      missing,
      "required path `\{path}` exists",
      @fs.exists(@pathx.join(book_root, path)),
    )
  }
  record_contract_check(
    checks,
    missing,
    "MoonBook catalog contains this research book",
    json_record_with_id_exists(catalog, book_id),
  )
  record_contract_check(
    checks,
    missing,
    "Moontown standing watch handoff targets this book",
    global_standing_goal_ready || standing_goal_registration_ready,
  )
  let global_goal = json_record_by_id(
    standing_goals,
    pdf_watch_goal_id(book_id),
  )
  match global_goal {
    Some(goal) =>
      record_contract_check(
        checks,
        missing,
        "Moontown standing goal uses the PDF Evidence Watch pipeline prompt",
        json_string(goal, "target_book_id", default="") == book_id &&
        json_string(goal, "prompt", default="").contains(
          "Watch configured websites for new relevant PDFs",
        ) &&
        json_string(goal, "prompt", default="").contains("download and extract") &&
        json_string(goal, "prompt", default="").contains(
          "compare against the existing MoonBook baseline",
        ) &&
        json_string(goal, "prompt", default="").contains(
          "notify the operator only after accepted new knowledge",
        ),
      )
    None =>
      record_contract_check(
        checks, missing, "Moontown standing goal uses the PDF Evidence Watch pipeline prompt",
        false,
      )
  }
  record_contract_check(
    checks, missing, "Moontown standing goal registration receipt is durable", standing_goal_registration_ready,
  )
  record_contract_check(
    checks,
    missing,
    "Moontown book-template request exists",
    request is Some(_),
  )
  match request {
    Some(request) =>
      record_contract_check(
        checks,
        missing,
        "Moontown book-template request is queued or installed",
        pdf_watch_moontown_template_request_status_ready(
          json_string(request, "status", default=""),
        ),
      )
    None => ()
  }
  record_contract_check(
    checks,
    missing,
    "Moontown template publish receipt is durable and queued or installed",
    @fs.exists(publish_receipt_path) &&
    json_bool(publish_receipt, "ok", default=false) &&
    pdf_watch_moontown_template_request_status_ready(
      json_string(publish_receipt, "status", default=""),
    ),
  )
  record_contract_check(
    checks,
    missing,
    "Moontown publish receipt preserves the reusable research-book handoff",
    json_string(publish_receipt, "book_ownership_contract", default="") ==
    "research-book + source adapter + extractor + analysis skill + standing watch" &&
    json_string(publish_receipt, "target_book_id", default="") == book_id &&
    json_string(publish_receipt, "standing_goal_id", default="") ==
    pdf_watch_goal_id(book_id) &&
    json_string(publish_receipt, "template_request_lifecycle", default="") ==
    "already-installed-by-moondesk",
  )
  record_contract_check(
    checks,
    missing,
    "Moontown publish receipt records accepted-knowledge-only notification",
    json_string(
      json_object_field_or_empty(publish_receipt, "standing_goal_contract"),
      "notify_rule",
      default="",
    ) ==
    "accepted-new-knowledge-only",
  )
  record_contract_check(
    checks,
    missing,
    "Moontown publish receipt preserves base-type provenance",
    pdf_watch_base_type_provenance_valid(
      json_object_field_or_empty(publish_receipt, "base_type_provenance"),
    ),
  )
  record_contract_check(
    checks,
    missing,
    "Moontown publish receipt preserves output contract handoff",
    json_string(
      json_object_field_or_empty(publish_receipt, "output_contract"),
      "output_contract",
      default="",
    ) ==
    json_string(
      pdf_watch_output_contract_handoff(pattern_id),
      "output_contract",
      default="",
    ),
  )
  record_contract_check(
    checks,
    missing,
    "Moontown install config uses latest flat PdfEvidenceWatchInstallSpec fields",
    json_string(install_config, "book_id", default="") == book_id &&
    json_string(install_config, "title", default="") != "" &&
    json_string_array_items(install_config, "websites").length() > 0 &&
    json_string(install_config, "analysis_method", default="") != "" &&
    json_int(install_config, "cadence_ticks", default=0) > 0 &&
    json_string(install_config, "workspace_root", default="") ==
    pdf_watch_moontown_install_workspace_root(book_id, book_root),
  )
  record_contract_check(
    checks,
    missing,
    "Moontown install config preserves output contract handoff",
    json_string(
      json_object_field_or_empty(install_config, "output_contract"),
      "output_contract",
      default="",
    ) ==
    json_string(
      pdf_watch_output_contract_handoff(pattern_id),
      "output_contract",
      default="",
    ),
  )
  {
    "book_id": book_id,
    "pattern_id": pattern_id,
    "verified": missing.length() == 0,
    "checks": json_from_string_array(checks),
    "missing": json_from_string_array(missing),
    "moontown_request_id": request_id,
    "moontown_request_status": match request {
      Some(request) => json_string(request, "status", default="")
      None => ""
    },
    "moontown_config_path": config_path,
    "operator_config_path": pdf_watch_operator_config_relative_path(),
    "base_type_selection_path": pdf_watch_base_type_selection_relative_path(),
    "base_type_selection": base_type_selection,
    "moontown_global_standing_goal_ready": global_standing_goal_ready,
    "moontown_standing_goal_registration_ready": standing_goal_registration_ready,
    "moontown_standing_goal_registration_path": pdf_watch_moontown_standing_goal_receipt_relative_path(),
    "moontown_publish_receipt_path": pdf_watch_moontown_publish_receipt_relative_path(),
  }
}

///|
fn pdf_watch_moontown_template_request_status_ready(status : String) -> Bool {
  status == "pending" || status == "retry" || status == "installed"
}

///|
async fn moontown_standing_goal_registration_ready(
  receipt_path : String,
  receipt : Json,
  book_id : String,
) -> Bool {
  @fs.exists(receipt_path) &&
  json_bool(receipt, "ok", default=false) &&
  json_string(receipt, "status", default="") == "registered" &&
  json_string(receipt, "target_book_id", default="") == book_id &&
  json_string(receipt, "daemon_job", default="") == "standing-goal-dispatch"
}

///|
fn pdf_watch_base_type_provenance_valid(provenance : Json) -> Bool {
  json_string(provenance, "base_type", default="") == "research-book" &&
  json_string(provenance, "moonbook_owner", default="") == "MoonBook" &&
  json_string(provenance, "moontown_template_id", default="") ==
  "pdf-evidence-watch" &&
  json_string(provenance, "creation_palette_source", default="").contains(
    "templates/books/templates.json",
  ) &&
  json_string(provenance, "moondesk_pattern_contract", default="") ==
  "research-book + source adapter + extractor + analysis skill + standing watch" &&
  json_string_array_items(provenance, "moonbook_layout_refs").contains(
    "../moonbook/docs/CLI_AND_LAYOUT.md",
  ) &&
  json_string_array_items(provenance, "template_registry_refs").contains(
    "../moontown/templates/books/templates.json",
  )
}

///|
fn pdf_watch_base_type_selection_valid_for_book(
  book_json : Json,
  selection : Json,
) -> Bool {
  let pattern_id = pdf_watch_pattern_id_from_book_json(book_json)
  let provenance = json_object_field_or_empty(selection, "base_type_provenance")
  json_string(selection, "kind", default="") == "moondesk-base-type-selection" &&
  json_string(selection, "book_id", default="") ==
  json_string(book_json, "id", default="") &&
  json_string(selection, "base_type", default="") == "research-book" &&
  json_string(selection, "pattern_id", default="") == pattern_id &&
  json_string(selection, "selected_from", default="").contains(
    "/api/books/base-types",
  ) &&
  json_string(selection, "base_type_owner", default="") == "MoonBook" &&
  json_string(selection, "handoff_target", default="") == "Moontown" &&
  json_bool(selection, "selected_from_catalog", default=false) &&
  json_bool(selection, "supported_pattern", default=false) &&
  json_string(selection, "build_contract", default="") ==
  "research-book + source adapter + extractor + analysis skill + standing watch" &&
  pdf_watch_base_type_provenance_valid(provenance) &&
  json_string_array_items(selection, "required_roots").contains("book.json") &&
  json_string_array_items(selection, "required_roots").contains("wiki/") &&
  json_string_array_items(selection, "template_registry_refs").contains(
    "../moontown/templates/books/templates.json",
  ) &&
  json_string_array_items(selection, "moonbook_layout_refs").contains(
    "../moonbook/docs/CLI_AND_LAYOUT.md",
  )
}

///|
fn record_contract_check(
  checks : Array[String],
  missing : Array[String],
  label : String,
  ok : Bool,
) -> Unit {
  if ok {
    checks.push(label)
  } else {
    missing.push(label)
  }
}

///|
fn json_record_with_id_exists(records : Array[Json], id : String) -> Bool {
  for record in records {
    if json_string(record, "id", default="") == id {
      return true
    }
  }
  false
}

///|
fn json_record_by_id(records : Array[Json], id : String) -> Json? {
  for record in records {
    if json_string(record, "id", default="") == id {
      return Some(record)
    }
  }
  None
}

///|
fn json_record_with_target_book_exists(
  records : Array[Json],
  book_id : String,
) -> Bool {
  for record in records {
    if json_string(record, "target_book_id", default="") == book_id {
      return true
    }
  }
  false
}

///|
fn pdf_watch_required_paths(pattern_id : String) -> Array[String] {
  let paths = [
    "book.json",
    pdf_watch_operator_config_relative_path(),
    "raw/bootstrap/PDF_WATCH_CONTRACT.md",
    pdf_watch_base_type_selection_relative_path(),
    "raw/inbox",
    "raw/inbox/.keep",
    "raw/pdfs/.keep",
    "raw/html/.keep",
    "raw/extracted/.keep",
    "raw/analysis-runs/.keep",
    "wiki/index.md",
    "wiki/methods/my-analysis-method.md",
    "wiki/methods/analysis-method.md",
    "wiki/sources/README.md",
    "wiki/evidence-matrix.md",
    "wiki/findings/README.md",
    "wiki/reviews/pdf-watch-review.md",
    "wiki/history/standing-watch.md",
    "skills/pdf-watch/SKILL.md",
    "skills/pdf-analysis/SKILL.md",
    "schemas/pdf-source.schema.md",
    "schemas/analysis-result.schema.md",
    "book/Home.html",
    "book/site/generated/index.html",
  ]
  if pattern_id == "exchangeable-bond-evidence-watch" {
    paths.push("skills/eb-credit-compliance/SKILL.md")
    paths.push("skills/tool-watch/SKILL.md")
    paths.push("skills/tool-build/SKILL.md")
    paths.push("schemas/eb-tracking-output.schema.md")
    paths.push("raw/inbox/eb-tracking-request.json")
    paths.push("raw/inbox/eb-standing-watch-dispatch.json")
    paths.push("moonclaw.jobs.json")
    paths.push(eb_moonclaw_proposal_packet_relative_path())
    paths.push("raw/bootstrap/EB_WATCH_CONTRACT.md")
    paths.push(eb_operator_prompt_relative_path())
    paths.push("raw/bootstrap/eb_extract_pdf_text.py")
    paths.push("raw/bootstrap/eb_package_workbook.py")
    paths.push(eb_prompt_contract_receipt_relative_path())
    paths.push(eb_expected_output_contract_relative_path())
    paths.push("raw/analysis-runs/eb-contract-verification.json")
    paths.push("raw/analysis-runs/eb-output-validation.json")
    paths.push("book/outputs/README.md")
    paths.push("wiki/tools/tool-spec.md")
    paths.push("tool-manifest.json")
    paths.push("app/index.html")
    paths.push("book/site/generated/tool.html")
    paths.push(eb_output_template_relative_path())
  }
  paths
}

///|
fn pdf_watch_contract_markdown(pattern_id : String, topic : String) -> String {
  [
    "# PDF Watch Contract",
    "",
    "- Topic: \{topic}",
    "- Pattern: `\{pattern_id}`",
    "- Base type: `research-book`",
    "- Source adapter: configured websites",
    "- Extractor: PDF full text and tables",
    "- Analysis skill: book-local method and skills",
    "- Standing watch: Moontown recurring goal",
    "",
    "The watcher may add raw evidence and review candidates, but accepted knowledge requires Bookkeeper review.",
  ].join("\n")
}

///|
fn pdf_watch_sources_readme(topic : String) -> String {
  [
    "# Sources",
    "",
    "One source card per relevant \{topic} PDF. Include canonical URL, title, publisher, retrieval time, sha256, local PDF path, extracted text path, and screening decision.",
  ].join("\n")
}

///|
fn pdf_watch_evidence_matrix_markdown(
  pattern_id : String,
  topic : String,
) -> String {
  let extra = if pattern_id == "exchangeable-bond-evidence-watch" {
    "For EB runs, each accepted workbook row must trace back to official-domain URLs, downloaded PDF hashes, extracted text paths, cross-verification status, lifecycle stage coverage, and Bookkeeper decision."
  } else {
    "For generic PDF-watch runs, each accepted finding must trace back to source URL, downloaded PDF hash, extracted text path, method output, baseline delta, and Bookkeeper decision."
  }
  [
    "# Evidence Matrix",
    "",
    "- Topic: \{topic}",
    "- Status: initialized",
    "",
    "This page is the durable MoonBook evidence matrix. MoonClaw may append candidate rows, but Bookkeeper decides which rows become accepted knowledge.",
    "",
    extra,
    "",
    "| Source | Local PDF | Extracted text | Claim or row | Baseline delta | Review decision | Output path |",
    "| --- | --- | --- | --- | --- | --- | --- |",
    "| pending | pending | pending | pending | pending | pending | pending |",
    "",
  ].join("\n")
}

///|
fn pdf_watch_findings_readme(pattern_id : String, topic : String) -> String {
  let extra = if pattern_id == "exchangeable-bond-evidence-watch" {
    "For EB tracking, accepted findings should also maintain the XLSX output contract in `book/outputs/`."
  } else {
    "Accepted findings should update wiki pages only when source-backed knowledge changes."
  }
  [
    "# Findings",
    "",
    "Accepted \{topic} findings live here after Bookkeeper review.",
    "",
    extra,
  ].join("\n")
}

///|
fn pdf_watch_review_markdown(topic : String) -> String {
  [
    "# PDF Watch Review Queue",
    "",
    "Use this page to decide whether candidate \{topic} source evidence becomes accepted book knowledge.",
    "",
    "- Accept only source-backed deltas.",
    "- Reject duplicates and low-quality sources.",
    "- Record why conclusions changed.",
  ].join("\n")
}

///|
fn pdf_watch_history_markdown(topic : String, book_id : String) -> String {
  [
    "# Standing Watch History",
    "",
    "- Book: `\{book_id}`",
    "- Topic: \{topic}",
    "- Current state: initialized",
    "",
    "Each watcher run must append checked websites, PDFs discovered, PDFs downloaded, accepted findings, rejected findings, wiki pages changed, output files changed, and notification status.",
  ].join("\n")
}

///|
fn pdf_watch_site_html(
  topic : String,
  book_id : String,
  pattern_id : String,
  purpose : String,
  websites : Array[String],
) -> String {
  let site_list = if websites.length() == 0 {
    "<li>No websites configured.</li>"
  } else {
    websites.map(fn(site) { "<li>\{site}</li>" }).join("")
  }
  "<!doctype html><html><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"><title>\{book_pattern_title(pattern_id, topic)}</title><style>body{margin:0;font-family:system-ui,-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#f6f7f3;color:#172018}main{max-width:960px;margin:0 auto;padding:48px 24px}section{border:1px solid #cdd6c5;background:white;border-radius:8px;padding:24px}code{background:#edf1e8;padding:2px 6px;border-radius:4px}li{margin:6px 0}</style></head><body><main><section><p><code>\{book_id}</code> · <code>\{pattern_id}</code></p><h1>\{book_pattern_title(pattern_id, topic)}</h1><p>\{purpose}</p><h2>Watch Sites</h2><ul>\{site_list}</ul><h2>Workflow</h2><ol><li>Discover changed PDFs from configured websites.</li><li>Download PDFs and extract text/tables with provenance.</li><li>Analyze with the book-local method and skills.</li><li>Promote accepted findings into the wiki and notify only on new knowledge.</li></ol></section></main></body></html>\n"
}
