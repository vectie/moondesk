///|
async fn book_contract_verification(
  root : String,
  book_root : String,
  book_id : String,
  pattern_id : String,
) -> Json {
  pdf_watch_contract_verification(root, book_root, book_id, pattern_id)
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
    "book.json records MoonBook/MoonTown base-type provenance",
    pdf_watch_base_type_provenance_valid(base_type_provenance),
  )
  record_contract_check(
    checks,
    missing,
    "book records durable base-type selection from MoonDesk catalog",
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
    "MoonTown standing watch handoff targets this book",
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
        "MoonTown standing goal uses the PDF Evidence Watch pipeline prompt",
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
        checks, missing, "MoonTown standing goal uses the PDF Evidence Watch pipeline prompt",
        false,
      )
  }
  record_contract_check(
    checks, missing, "MoonTown standing goal registration receipt is durable", standing_goal_registration_ready,
  )
  record_contract_check(
    checks,
    missing,
    "MoonTown book-template request exists",
    request is Some(_),
  )
  match request {
    Some(request) =>
      record_contract_check(
        checks,
        missing,
        "MoonTown book-template request is queued or installed",
        pdf_watch_moontown_template_request_status_ready(
          json_string(request, "status", default=""),
        ),
      )
    None => ()
  }
  record_contract_check(
    checks,
    missing,
    "MoonTown template publish receipt is durable and queued or installed",
    @fs.exists(publish_receipt_path) &&
    json_bool(publish_receipt, "ok", default=false) &&
    pdf_watch_moontown_template_request_status_ready(
      json_string(publish_receipt, "status", default=""),
    ),
  )
  record_contract_check(
    checks,
    missing,
    "MoonTown publish receipt preserves the reusable research-book handoff",
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
    "MoonTown publish receipt records accepted-knowledge-only notification",
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
    "MoonTown publish receipt preserves base-type provenance",
    pdf_watch_base_type_provenance_valid(
      json_object_field_or_empty(publish_receipt, "base_type_provenance"),
    ),
  )
  record_contract_check(
    checks,
    missing,
    "MoonTown publish receipt preserves output contract handoff",
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
    "MoonTown install config uses latest flat PdfEvidenceWatchInstallSpec fields",
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
    "MoonTown install config preserves output contract handoff",
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
