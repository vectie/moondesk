///|
async fn write_moontown_standing_goal_registration(
  root~ : String,
  book_root~ : String,
  book_id~ : String,
  pattern_id~ : String,
  goal~ : Json,
) -> Json {
  let goal_id = json_string(goal, "id", default=pdf_watch_goal_id(book_id))
  let target_book_id = json_string(goal, "target_book_id", default=book_id)
  let receipt : Json = {
    "ok": true,
    "status": "registered",
    "kind": "moontown-standing-goal-registration",
    "registered_by": "Moondesk",
    "owner": "Moontown",
    "goal_id": goal_id,
    "target_book_id": target_book_id,
    "pattern_id": pattern_id,
    "enabled": json_bool(goal, "enabled", default=false),
    "cadence_ticks": json_int(goal, "cadence_ticks", default=0),
    "next_due_tick": json_int(goal, "next_due_tick", default=0),
    "source_policy": json_string(goal, "source_policy", default=""),
    "standing_goal_path": town_standing_goals_path(root),
    "watcher_ledger_path": ".moonsuite/products/moontown/watchers/" +
    goal_id +
    ".jsonl",
    "book_result_path_template": ".moonsuite/products/moontown/book-results/<run_id>.json",
    "daemon_job": "standing-goal-dispatch",
    "output_contract": pdf_watch_output_contract_handoff(pattern_id),
    "decision_field": "standing_goal_decision",
    "expected_decisions": json_from_string_array([
      "update", "no_change", "needs_review", "failed", "deferred",
    ]),
    "expected_outputs": json_from_string_array(
      book_pattern_output_files(pattern_id),
    ),
  }
  @fsx.write_to_file(
    @pathx.join(
      book_root,
      pdf_watch_moontown_standing_goal_receipt_relative_path(),
    ),
    receipt.stringify(indent=2) + "\n",
    create=0o644,
  )
  receipt
}

///|
async fn write_moontown_book_template_publish(
  root~ : String,
  book_root~ : String,
  book_id~ : String,
  topic~ : String,
  pattern_id~ : String,
  purpose~ : String,
  cadence~ : Int,
  websites~ : Array[String],
  method_body~ : String,
  skill_pack~ : Array[String],
  goal~ : Json,
) -> Json {
  let config_root = town_book_template_config_root(root)
  @fsx.make_directory(config_root, recursive=true, exists_ok=true)
  let config_name = book_id + ".json"
  let config_path = @pathx.join(config_root, config_name)
  let config_rel = "book-template-configs/" + config_name
  @fsx.write_to_file(
    config_path,
    pdf_watch_moontown_install_config(
      book_id~,
      topic~,
      pattern_id~,
      purpose~,
      book_root~,
      cadence~,
      websites~,
      method_body~,
      skill_pack~,
    ).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  let request = pdf_watch_moontown_template_request(
    book_id~,
    topic~,
    pattern_id~,
    config_rel~,
    goal~,
  )
  let request_status = json_string(request, "status", default="")
  let goal_id = json_string(goal, "id", default=pdf_watch_goal_id(book_id))
  let request_path = town_book_template_request_path(root)
  let existing = read_json_file_or_object(request_path)
  let requests = upsert_record_by_id(
    json_array_items(existing, "requests"),
    request,
  )
  let ledger : Json = { "requests": Json::array(requests) }
  @fsx.write_to_file(
    request_path,
    ledger.stringify(indent=2) + "\n",
    create=0o644,
  )
  if request_status != "pending" {
    let event = pdf_watch_moontown_template_event(
      request~,
      config_rel~,
      status=request_status,
    )
    append_json_line(town_book_template_event_path(root), event)
  }
  let receipt : Json = {
    "ok": true,
    "status": request_status,
    "template_id": "pdf-evidence-watch",
    "publish_mode": pdf_watch_moontown_publish_mode(pattern_id),
    "processor": "moondesk-pattern-builder",
    "reason": pdf_watch_moontown_publish_reason(pattern_id),
    "book_ownership_contract": "research-book + source adapter + extractor + analysis skill + standing watch",
    "base_type_provenance": pdf_watch_base_type_provenance_json(),
    "template_request_lifecycle": "already-installed-by-moondesk",
    "moontown_processor_contract": "installed requests are reconciled into lifecycle events; pending requests are reserved for Moontown template-installer ownership",
    "standing_goal_id": goal_id,
    "target_book_id": book_id,
    "operator_config_path": pdf_watch_operator_config_relative_path(),
    "operator_config_shape": "nested watch/analysis config; editable without touching Moontown JSON",
    "base_type_selection_path": pdf_watch_base_type_selection_relative_path(),
    "output_contract": pdf_watch_output_contract_handoff(pattern_id),
    "config_path": config_path,
    "config_relative_path": config_rel,
    "request_path": request_path,
    "event_path": town_book_template_event_path(root),
    "daemon_job": "standing-goal-dispatch",
    "standing_goal_contract": {
      "id": goal_id,
      "title": json_string(goal, "title", default=""),
      "target_book_id": book_id,
      "cadence_ticks": json_int(goal, "cadence_ticks", default=0),
      "source_policy": json_string(goal, "source_policy", default="web-first"),
      "notify_rule": "accepted-new-knowledge-only",
    },
    "handoff": {
      "moondesk": "create/configure/edit the research-book workspace",
      "moontown": "schedule the standing watch and surface live status/notifications",
      "moonbook": "own durable PDFs, extracted text, wiki, evidence matrix, review queue, and generated site",
      "moonclaw": "execute bounded browse/fetch/download/extract/analyze/package runs",
      "bookkeeper": "accept or reject candidate knowledge before notification",
    },
    "request": request,
  }
  @fsx.write_to_file(
    @pathx.join(book_root, pdf_watch_moontown_publish_receipt_relative_path()),
    receipt.stringify(indent=2) + "\n",
    create=0o644,
  )
  receipt
}

///|
fn pdf_watch_moontown_install_config(
  book_id~ : String,
  topic~ : String,
  pattern_id~ : String,
  purpose~ : String,
  book_root~ : String,
  cadence~ : Int,
  websites~ : Array[String],
  method_body~ : String,
  skill_pack~ : Array[String],
) -> Json {
  ignore(skill_pack)
  {
    "book_id": book_id,
    "title": book_pattern_title(pattern_id, topic),
    "purpose": purpose,
    "pattern_id": pattern_id,
    "output_contract": pdf_watch_output_contract_handoff(pattern_id),
    "websites": json_from_string_array(websites),
    "analysis_method": method_body,
    "analysis_method_path": "",
    "cadence_ticks": cadence,
    "workspace_root": pdf_watch_moontown_install_workspace_root(
      book_id, book_root,
    ),
  }
}

///|
fn pdf_watch_output_contract_handoff(pattern_id : String) -> Json {
  {
    "kind": "moondesk-output-contract-handoff",
    "pattern_id": pattern_id,
    "output_contract": "moontown.pdf_evidence_watch.result.v1",
    "result_schema_path": "schemas/analysis-result.schema.md",
    "source_schema_path": "schemas/pdf-source.schema.md",
    "accepted_output_paths": json_from_string_array([
      "wiki/findings/", "wiki/evidence-matrix.md", "site/generated/",
    ]),
    "publish_rule": "Bookkeeper must accept source-backed new knowledge before Moondesk/MoonBook update durable findings or notify.",
    "validation_gate": "GET /api/books/verify checks the reusable research-book + source adapter + extractor + analysis skill + standing watch handoff.",
  }
}

///|
fn pdf_watch_moontown_install_workspace_root(
  book_id : String,
  book_root : String,
) -> String {
  if book_root.has_suffix("/books/" + book_id) {
    "../../books/" + book_id
  } else {
    book_root
  }
}

///|
fn pdf_watch_moontown_template_request(
  book_id~ : String,
  topic~ : String,
  pattern_id~ : String,
  config_rel~ : String,
  goal~ : Json,
) -> Json {
  let request_id = @desk.stable_id("book-template-request", book_id)
  let goal_id = json_string(goal, "id", default="")
  let status = pdf_watch_moontown_template_request_status(pattern_id)
  {
    "id": request_id,
    "template_id": "pdf-evidence-watch",
    "config_path": config_rel,
    "status": status,
    "pattern_id": pattern_id,
    "output_contract": pdf_watch_output_contract_handoff(pattern_id),
    "summary": pdf_watch_moontown_template_request_summary(
      book_id, topic, pattern_id, goal_id, status,
    ),
    "last_processed_tick": 0,
  }
}

///|
fn pdf_watch_moontown_template_request_status(pattern_id : String) -> String {
  ignore(pattern_id)
  "installed"
}

///|
fn pdf_watch_moontown_publish_mode(pattern_id : String) -> String {
  ignore(pattern_id)
  "moondesk-research-book-direct-create-plus-installed-moontown-template-request"
}

///|
fn pdf_watch_moontown_publish_reason(pattern_id : String) -> String {
  ignore(pattern_id)
  "Moondesk created the reusable research-book pattern workspace, wrote the flat PdfEvidenceWatchInstallSpec for Moontown visibility, and registered the standing watch directly. Moontown's current generic `pdf-evidence-watch` installer should not re-run over this book because it still rewrites `book.json` into the narrower template-installer schema instead of preserving the research-book base type."
}

///|
fn pdf_watch_moontown_template_request_summary(
  book_id : String,
  topic : String,
  pattern_id : String,
  goal_id : String,
  status : String,
) -> String {
  ignore(status)
  "Moondesk installed `\{book_id}` from pattern `\{pattern_id}` for \{topic}; standing goal `\{goal_id}` targets this book. Moontown should schedule the standing goal and should not re-run the generic `pdf-evidence-watch` installer over this already-built research-book workspace."
}

///|
fn pdf_watch_moontown_template_event(
  request~ : Json,
  config_rel~ : String,
  status~ : String,
) -> Json {
  let request_id = json_string(request, "id", default="")
  let summary = json_string(request, "summary", default="")
  {
    "id": request_id + "-moondesk",
    "request_id": request_id,
    "template_id": "pdf-evidence-watch",
    "status": status,
    "config_path": config_rel,
    "summary": summary,
    "tick": 0,
    "generated_at_ms": 0,
  }
}

///|
async fn append_json_line(path : String, record : Json) -> Unit {
  let existing = if @fs.exists(path) {
    @fs.read_file(path).text() catch {
      _ => ""
    }
  } else {
    ""
  }
  let line = record.stringify()
  let content = if existing.trim().is_empty() {
    line + "\n"
  } else {
    existing.trim_end().to_owned() + "\n" + line + "\n"
  }
  @fsx.write_to_file(path, content, create=0o644)
}

///|
async fn pdf_watch_readiness(
  root : String,
  book_root : String,
  book_id : String,
  pattern_id : String,
  goal : Json,
) -> Json {
  let required = pdf_watch_required_paths(pattern_id)
  let missing : Array[String] = []
  for path in required {
    if !@fs.exists(@pathx.join(book_root, path)) {
      missing.push(path)
    }
  }
  let goals = read_json_array_file(town_standing_goals_path(root))
  let catalog = read_json_array_file(town_moonbooks_path(root))
  let goal_id = json_string(goal, "id", default="")
  let template_request_id = @desk.stable_id("book-template-request", book_id)
  let template_request = json_record_by_id(
    json_array_items(
      read_json_file_or_object(town_book_template_request_path(root)),
      "requests",
    ),
    template_request_id,
  )
  let standing_goal_receipt_path = @pathx.join(
    book_root,
    pdf_watch_moontown_standing_goal_receipt_relative_path(),
  )
  let standing_goal_receipt = read_json_file_or_object(
    standing_goal_receipt_path,
  )
  {
    "ready": missing.length() == 0 &&
    json_record_with_id_exists(goals, goal_id) &&
    json_record_with_id_exists(catalog, book_id) &&
    json_bool(standing_goal_receipt, "ok", default=false) &&
    json_string(standing_goal_receipt, "status", default="") == "registered",
    "missing_paths": json_from_string_array(missing),
    "required_count": required.length(),
    "missing_count": missing.length(),
    "has_standing_goal": json_record_with_id_exists(goals, goal_id),
    "has_catalog_entry": json_record_with_id_exists(catalog, book_id),
    "has_moontown_template_request": json_record_with_id_exists(
      json_array_items(
        read_json_file_or_object(town_book_template_request_path(root)),
        "requests",
      ),
      template_request_id,
    ),
    "moontown_template_request_status": match template_request {
      Some(request) => json_string(request, "status", default="")
      None => ""
    },
    "has_moontown_template_config": @fs.exists(
      @pathx.join(town_book_template_config_root(root), book_id + ".json"),
    ),
    "has_moontown_standing_goal_registration": @fs.exists(
      standing_goal_receipt_path,
    ),
    "moontown_standing_goal_registration_status": json_string(
      standing_goal_receipt,
      "status",
      default="",
    ),
    "output_template_path": "",
    "output_template_ready": true,
    "contract_verification": book_contract_verification(
      root, book_root, book_id, pattern_id,
    ),
  }
}
