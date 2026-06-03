///|
fn eb_default_goal_id_for_book(book_id : String) -> String {
  pdf_watch_goal_id(book_id)
}

///|
async fn eb_output_validation(book_root : String, book_id : String) -> Json {
  let outputs_root = @pathx.join(book_root, "book/outputs")
  let template_name = "EB追踪_[债券代码]_[债券简称]_[YYYYMMDD].xlsx"
  let template_path = @pathx.join(book_root, eb_output_template_relative_path())
  let expected_output_contract_path = @pathx.join(
    book_root,
    eb_expected_output_contract_relative_path(),
  )
  let expected_output_contract = read_json_file_or_object(
    expected_output_contract_path,
  )
  let expected_output_contract_ready = @fs.exists(expected_output_contract_path) &&
    eb_expected_output_contract_valid(expected_output_contract)
  let names = read_directory_names(outputs_root, include_hidden=false)
  let xlsx_files : Array[String] = []
  let accepted_files : Array[String] = []
  let valid_accepted_files : Array[String] = []
  let output_manifest_files : Array[String] = []
  for name in names {
    if name.has_suffix(".xlsx.manifest.json") {
      output_manifest_files.push(name)
    }
    if name.has_suffix(".xlsx") {
      xlsx_files.push(name)
      if is_accepted_eb_output_name(name) {
        accepted_files.push(name)
        if eb_accepted_output_valid(book_root, "book/outputs/" + name) {
          valid_accepted_files.push(name)
        }
      }
    }
  }
  let template_manifest_ready = eb_output_manifest_valid(
    book_root,
    eb_output_template_relative_path(),
    accepted_required=false,
  )
  let template_workbook_validation_ready = eb_output_workbook_validation_valid(
    book_root,
    eb_output_template_relative_path(),
  )
  let template_appendix_notes_ready = eb_output_appendix_notes_valid(
    book_root,
    eb_output_template_relative_path(),
  )
  let template_internal_workbook_contract_ready = eb_xlsx_internal_contract_valid(
    template_path,
  )
  let template_ready = eb_xlsx_package_valid(template_path) &&
    template_manifest_ready &&
    template_workbook_validation_ready &&
    expected_output_contract_ready
  let required_package_parts = eb_xlsx_required_package_parts()
  let template_missing_package_parts = eb_xlsx_package_missing_parts(
    template_path,
  )
  let source_screen_files = eb_source_screen_files(book_root)
  let source_evidence_ready = source_screen_files.length() > 0
  let pdf_candidate_files = eb_pdf_candidate_files(book_root)
  let pdf_candidate_evidence_ready = pdf_candidate_files.length() > 0
  let accepted_output_count = valid_accepted_files.length()
  let final_output_ready = accepted_output_count > 0 &&
    source_evidence_ready &&
    pdf_candidate_evidence_ready &&
    expected_output_contract_ready
  let status = if final_output_ready {
    "accepted_output_ready"
  } else if accepted_output_count > 0 {
    if !source_evidence_ready {
      "accepted_output_waiting_for_source_screen"
    } else {
      "accepted_output_waiting_for_pdf_candidates"
    }
  } else if template_ready {
    "template_ready_waiting_for_accepted_output"
  } else {
    "missing_or_invalid_template"
  }
  {
    "book_id": book_id,
    "kind": "eb-output-validation",
    "status": status,
    "template_path": eb_output_template_relative_path(),
    "expected_output_contract_path": eb_expected_output_contract_relative_path(),
    "expected_output_contract_ready": expected_output_contract_ready,
    "expected_output_contract": expected_output_contract,
    "template_ready": template_ready,
    "template_manifest_ready": template_manifest_ready,
    "template_workbook_validation_ready": template_workbook_validation_ready,
    "template_appendix_notes_ready": template_appendix_notes_ready,
    "template_internal_workbook_contract_ready": template_internal_workbook_contract_ready,
    "template_package_ready": eb_xlsx_package_valid(template_path),
    "template_missing_package_parts": json_from_string_array(
      template_missing_package_parts,
    ),
    "template_name_has_placeholders": template_name.contains("["),
    "xlsx_file_count": xlsx_files.length(),
    "xlsx_files": json_from_string_array(xlsx_files),
    "output_manifest_count": output_manifest_files.length(),
    "output_manifest_files": json_from_string_array(output_manifest_files),
    "accepted_output_count": accepted_files.length(),
    "accepted_output_files": json_from_string_array(accepted_files),
    "valid_accepted_output_count": accepted_output_count,
    "valid_accepted_output_files": json_from_string_array(valid_accepted_files),
    "source_evidence_ready": source_evidence_ready,
    "source_screen_files": json_from_string_array(source_screen_files),
    "pdf_candidate_evidence_ready": pdf_candidate_evidence_ready,
    "pdf_candidate_files": json_from_string_array(pdf_candidate_files),
    "final_output_ready": final_output_ready,
    "required_filename_pattern": "EB追踪_[债券代码]_[债券简称]_[YYYYMMDD].xlsx",
    "expected_output_contract_gate": "The book must preserve raw/analysis-runs/eb-expected-output-contract.json so output validation can prove the exact XLSX filename, sheet/header, sidecar, lifecycle, official-source, multi-bond, and Bookkeeper acceptance contract.",
    "required_package_parts": json_from_string_array(required_package_parts),
    "required_sheets": json_from_string_array([
      "公告追踪主表", "关键指标监控表",
    ]),
    "acceptance_gate": "A non-placeholder EB追踪_<债券代码>_<债券简称>_<YYYYMMDD>.xlsx must be written after Bookkeeper accepts source-backed knowledge.",
    "workbook_validation_gate": "An accepted workbook requires a sibling .xlsx.validation.json proof with xlsx_sha256 bound to the workbook bytes, exact EB sheet headers, positive source-backed data-row proof for both sheets, actual XLSX rows beyond the header in both sheets, OOXML hyperlink relationships for official original-link cells, and workbook XML preserving frozen headers, filters, column widths, and bold header styling.",
    "appendix_notes_gate": "The validation proof must also show workbook notes with search keywords, retrieval date, and official information source list.",
    "quality_proof_gate": "The validation proof must show official-link-only rows, clickable source URLs, summaries within 200 characters, key data emphasis, cross-verification, timing checks, data consistency reconciliation, missing-disclosure marking, and workbook formatting; production workbook XML must also contain the clickable official hyperlink relationships.",
    "lifecycle_proof_gate": "The validation proof must show every EB lifecycle stage was reviewed and expected-but-missing disclosures were marked with reasons.",
    "pdf_candidate_gate": "An accepted workbook also requires durable official PDF candidate discovery under raw/analysis-runs/*-official-pdf-candidates.json before source-screen and workbook output can be final.",
    "source_gate": "An accepted workbook also requires a durable official-source screen under raw/analysis-runs/*-official-source-screen.json.",
  }
}

///|
fn eb_first_valid_accepted_output_relative(output_validation : Json) -> String {
  let files = json_string_array_items(
    output_validation, "valid_accepted_output_files",
  )
  if files.length() == 0 {
    ""
  } else {
    "book/outputs/" + files[0]
  }
}

///|
async fn eb_valid_accepted_output_relative_for_run(
  book_root : String,
  run_id : String,
  output_validation : Json,
) -> String {
  if run_id == "" {
    return ""
  }
  let files = json_string_array_items(
    output_validation, "valid_accepted_output_files",
  )
  for name in files {
    let relative = "book/outputs/" + name
    if eb_output_manifest_run_id(book_root, relative) == run_id &&
      eb_accepted_output_valid(book_root, relative) {
      return relative
    }
  }
  ""
}

///|
async fn eb_output_manifest_run_id(
  book_root : String,
  output_relative : String,
) -> String {
  let manifest_path = @pathx.join(
    book_root,
    eb_output_manifest_relative_path(output_relative),
  )
  if !@fs.exists(manifest_path) {
    return ""
  }
  json_string(read_json_file_or_object(manifest_path), "run_id", default="")
  .trim()
  .to_owned()
}

///|
async fn eb_accepted_output_valid(
  book_root : String,
  output_relative : String,
) -> Bool {
  let output_path = @pathx.join(book_root, output_relative)
  eb_xlsx_package_valid(output_path) &&
  is_accepted_eb_output_name(eb_output_name_from_relative(output_relative)) &&
  eb_output_manifest_valid(book_root, output_relative, accepted_required=true) &&
  eb_output_workbook_validation_valid(book_root, output_relative) &&
  eb_output_appendix_notes_valid(book_root, output_relative) &&
  eb_output_quality_proof_valid(book_root, output_relative) &&
  eb_output_lifecycle_proof_valid(book_root, output_relative)
}

///|
fn eb_output_name_from_relative(output_relative : String) -> String {
  let parts = path_segments(output_relative)
  if parts.length() == 0 {
    output_relative
  } else {
    parts[parts.length() - 1]
  }
}

///|
async fn eb_output_manifest_valid(
  book_root : String,
  output_relative : String,
  accepted_required~ : Bool,
) -> Bool {
  let manifest_path = @pathx.join(
    book_root,
    eb_output_manifest_relative_path(output_relative),
  )
  if !@fs.exists(manifest_path) {
    return false
  }
  let manifest = read_json_file_or_object(manifest_path)
  let xlsx_sha256 = json_string(manifest, "xlsx_sha256", default="")
    .trim()
    .to_owned()
  let pdf_candidates_relative = json_string(
      manifest,
      "pdf_candidates_path",
      default="",
    )
    .trim()
    .to_owned()
  json_string(manifest, "kind", default="") == "eb-tracking-output-manifest" &&
  json_string(manifest, "output_contract", default="") ==
  "moondesk.exchangeable_bond_tracking.xlsx.v1" &&
  json_string(manifest, "xlsx_path", default="") == output_relative &&
  xlsx_sha256 != "" &&
  xlsx_sha256 == eb_file_sha256(@pathx.join(book_root, output_relative)) &&
  json_bool(manifest, "official_source_required", default=false) &&
  json_bool(manifest, "accepted_by_bookkeeper", default=!accepted_required) ==
  accepted_required &&
  (
    !accepted_required ||
    eb_manifest_pdf_candidates_path_valid(pdf_candidates_relative)
  ) &&
  eb_manifest_sheet_headers_valid(manifest)
}

///|
fn eb_manifest_pdf_candidates_path_valid(
  pdf_candidates_relative : String,
) -> Bool {
  match clean_relative_path(pdf_candidates_relative) {
    Some(path) =>
      path.has_prefix("raw/analysis-runs/") &&
      path.has_suffix("-official-pdf-candidates.json")
    None => false
  }
}

///|
async fn eb_file_sha256(path : String) -> String {
  let bytes = @fs.read_file(path).binary() catch { _ => return "" }
  @crypto.bytes_to_hex_string(@crypto.sha256(bytes.to_fixedarray()))
}

///|
fn eb_manifest_sheet_headers_valid(manifest : Json) -> Bool {
  let sheets = json_array_items(manifest, "sheets")
  eb_manifest_sheet_has_headers(
    sheets,
    "公告追踪主表",
    eb_announcement_sheet_headers(),
  ) &&
  eb_manifest_sheet_has_headers(
    sheets,
    "关键指标监控表",
    eb_indicator_sheet_headers(),
  )
}

///|
fn eb_manifest_sheet_has_headers(
  sheets : Array[Json],
  name : String,
  headers : Array[String],
) -> Bool {
  for sheet in sheets {
    if json_string(sheet, "name", default="") == name {
      return json_string_array_exact(sheet, "headers", headers)
    }
  }
  false
}

///|
async fn eb_output_workbook_validation_valid(
  book_root : String,
  output_relative : String,
) -> Bool {
  let validation_path = @pathx.join(
    book_root,
    eb_output_workbook_validation_relative_path(output_relative),
  )
  if !@fs.exists(validation_path) {
    return false
  }
  let validation = read_json_file_or_object(validation_path)
  let xlsx_sha256 = json_string(validation, "xlsx_sha256", default="")
    .trim()
    .to_owned()
  let sample_run = json_bool(validation, "sample_run", default=true)
  let workbook_path = @pathx.join(book_root, output_relative)
  json_string(validation, "kind", default="") ==
  "eb-tracking-workbook-validation" &&
  json_string(validation, "output_contract", default="") ==
  "moondesk.exchangeable_bond_tracking.xlsx.v1" &&
  json_string(validation, "xlsx_path", default="") == output_relative &&
  json_bool(validation, "workbook_package_valid", default=false) &&
  json_bool(validation, "headers_valid", default=false) &&
  xlsx_sha256 != "" &&
  xlsx_sha256 == eb_file_sha256(workbook_path) &&
  eb_manifest_sheet_headers_valid(validation) &&
  eb_workbook_data_proof_valid(validation) &&
  (sample_run || eb_xlsx_data_rows_valid(workbook_path)) &&
  (sample_run || eb_xlsx_indicator_core_metrics_valid(workbook_path)) &&
  (sample_run || eb_xlsx_official_hyperlinks_valid(workbook_path)) &&
  eb_xlsx_internal_contract_valid(workbook_path)
}

///|
async fn eb_output_workbook_validation_sample_run(
  book_root : String,
  output_relative : String,
) -> Bool {
  let validation_path = @pathx.join(
    book_root,
    eb_output_workbook_validation_relative_path(output_relative),
  )
  if !@fs.exists(validation_path) {
    return true
  }
  let validation = read_json_file_or_object(validation_path)
  json_bool(validation, "sample_run", default=true)
}

///|
async fn eb_output_workbook_data_proof_valid(
  book_root : String,
  output_relative : String,
) -> Bool {
  let validation_path = @pathx.join(
    book_root,
    eb_output_workbook_validation_relative_path(output_relative),
  )
  if !@fs.exists(validation_path) {
    return false
  }
  eb_workbook_data_proof_valid(read_json_file_or_object(validation_path))
}

///|
async fn eb_output_workbook_hyperlinks_valid(
  book_root : String,
  output_relative : String,
) -> Bool {
  let validation_path = @pathx.join(
    book_root,
    eb_output_workbook_validation_relative_path(output_relative),
  )
  if !@fs.exists(validation_path) {
    return false
  }
  let validation = read_json_file_or_object(validation_path)
  if json_bool(validation, "sample_run", default=true) {
    return true
  }
  eb_xlsx_official_hyperlinks_valid(@pathx.join(book_root, output_relative))
}

///|
fn eb_workbook_data_proof_valid(validation : Json) -> Bool {
  if json_bool(validation, "sample_run", default=true) {
    return true
  }
  let proof = json_object_field_or_empty(validation, "workbook_data_proof")
  eb_data_proof_bool(validation, proof, [
    "workbook_contains_data_rows", "data_rows_present", "sheets_have_data_rows",
  ]) &&
  eb_data_proof_bool(validation, proof, [
    "all_rows_source_backed", "rows_source_backed", "source_backed_rows_present",
  ]) &&
  eb_data_proof_int(validation, proof, [
    "announcement_data_row_count", "sheet1_data_row_count", "announcement_rows",
    "main_table_row_count",
  ]) >
  0 &&
  eb_data_proof_int(validation, proof, [
    "indicator_data_row_count", "sheet2_data_row_count", "indicator_rows", "monitor_table_row_count",
  ]) >
  0 &&
  eb_data_proof_int(validation, proof, [
    "source_backed_row_count", "official_source_row_count", "rows_with_official_source_url",
    "rows_with_original_url",
  ]) >
  0 &&
  eb_data_proof_bool(validation, proof, [
    "indicator_core_metrics_populated", "sheet2_core_metrics_populated", "core_metrics_populated",
  ]) &&
  eb_data_proof_int(validation, proof, [
    "indicator_core_metric_rows", "sheet2_core_metric_rows", "core_metric_rows",
  ]) >
  0 &&
  eb_data_proof_int(validation, proof, [
    "indicator_metric_min_non_placeholder_cells", "sheet2_min_non_placeholder_metric_cells",
    "min_non_placeholder_metric_cells",
  ]) >=
  4
}

///|
fn eb_data_proof_bool(
  validation : Json,
  proof : Json,
  keys : Array[String],
) -> Bool {
  for key in keys {
    if json_bool(proof, key, default=false) {
      return true
    }
  }
  for key in keys {
    if json_bool(validation, key, default=false) {
      return true
    }
  }
  false
}

///|
fn eb_data_proof_int(
  validation : Json,
  proof : Json,
  keys : Array[String],
) -> Int {
  for key in keys {
    let value = json_int(proof, key, default=0)
    if value > 0 {
      return value
    }
  }
  for key in keys {
    let value = json_int(validation, key, default=0)
    if value > 0 {
      return value
    }
  }
  0
}

///|
async fn eb_output_appendix_notes_valid(
  book_root : String,
  output_relative : String,
) -> Bool {
  let validation_path = @pathx.join(
    book_root,
    eb_output_workbook_validation_relative_path(output_relative),
  )
  if !@fs.exists(validation_path) {
    return false
  }
  eb_appendix_notes_valid(
    read_json_file_or_object(validation_path),
    output_relative,
  )
}

///|
async fn eb_output_quality_proof_valid(
  book_root : String,
  output_relative : String,
) -> Bool {
  let validation_path = @pathx.join(
    book_root,
    eb_output_workbook_validation_relative_path(output_relative),
  )
  if !@fs.exists(validation_path) {
    return false
  }
  eb_quality_proof_valid(read_json_file_or_object(validation_path))
}

///|
async fn eb_output_lifecycle_proof_valid(
  book_root : String,
  output_relative : String,
) -> Bool {
  let validation_path = @pathx.join(
    book_root,
    eb_output_workbook_validation_relative_path(output_relative),
  )
  if !@fs.exists(validation_path) {
    return false
  }
  eb_lifecycle_proof_valid(read_json_file_or_object(validation_path))
}

///|
fn eb_quality_proof_valid(validation : Json) -> Bool {
  let proof = json_object_field_or_empty(validation, "quality_proof")
  let official_domains = eb_quality_string_array(validation, proof, [
    "official_link_domains", "official_domains", "allowed_domains",
  ])
  eb_quality_bool(validation, proof, [
    "official_links_only", "official_domain_urls_only", "official_urls_only",
  ]) &&
  eb_quality_bool(validation, proof, [
    "clickable_official_links", "clickable_source_urls", "clickable_original_links",
    "official_source_hyperlinks", "source_url_hyperlinks",
  ]) &&
  eb_quality_bool(validation, proof, [
    "cross_verification_performed", "cross_verified", "issuer_underlying_cross_checked",
  ]) &&
  eb_quality_bool(validation, proof, [
    "timing_checks_performed", "timing_validated", "disclosure_timing_checked",
  ]) &&
  eb_quality_bool(validation, proof, [
    "data_consistency_reconciled", "sheet_data_reconciled", "cumulative_exchange_reconciled",
  ]) &&
  eb_quality_bool(validation, proof, [
    "summaries_within_200_chars", "summary_length_checked", "core_summaries_within_200_chars",
    "summaries_within_limit",
  ]) &&
  eb_quality_bool(validation, proof, [
    "key_data_emphasized", "key_data_bold_or_colored", "key_data_highlighted", "critical_data_emphasized",
  ]) &&
  eb_quality_bool(validation, proof, [
    "missing_disclosures_marked", "missing_expected_disclosures_marked", "missing_nodes_marked",
  ]) &&
  eb_quality_bool(validation, proof, [
    "workbook_formatting_applied", "excel_formatting_applied", "formatting_applied",
  ]) &&
  eb_string_array_has_official_source(official_domains)
}

///|
fn eb_lifecycle_proof_valid(validation : Json) -> Bool {
  let proof = json_object_field_or_empty(validation, "lifecycle_stage_proof")
  let stages = json_array_items(proof, "stages")
  eb_quality_bool(validation, proof, [
    "all_six_stages_reviewed", "all_stages_reviewed", "six_lifecycle_stages_reviewed",
  ]) &&
  eb_quality_bool(validation, proof, [
    "missing_expected_disclosures_marked", "missing_disclosures_marked", "missing_nodes_marked",
  ]) &&
  eb_lifecycle_stage_array_covers_all(stages)
}

///|
fn eb_lifecycle_stage_array_covers_all(stages : Array[Json]) -> Bool {
  for stage in eb_lifecycle_stage_names() {
    if !eb_lifecycle_stage_array_contains_ready_stage(stages, stage) {
      return false
    }
  }
  true
}

///|
fn eb_lifecycle_stage_array_contains_ready_stage(
  stages : Array[Json],
  stage : String,
) -> Bool {
  for item in stages {
    if json_string(item, "stage", default="") == stage &&
      eb_lifecycle_stage_status_ready(json_string(item, "status", default="")) {
      return true
    }
  }
  false
}

///|
fn eb_lifecycle_stage_status_ready(status : String) -> Bool {
  status == "covered_or_marked_missing" ||
  status == "covered" ||
  status == "reviewed" ||
  status == "missing_marked" ||
  status == "reviewed_with_missing_markers"
}

///|
fn eb_quality_bool(
  validation : Json,
  proof : Json,
  keys : Array[String],
) -> Bool {
  for key in keys {
    if json_bool(proof, key, default=false) {
      return true
    }
  }
  for key in keys {
    if json_bool(validation, key, default=false) {
      return true
    }
  }
  false
}

///|
fn eb_quality_string_array(
  validation : Json,
  proof : Json,
  keys : Array[String],
) -> Array[String] {
  for key in keys {
    let values = json_string_array_items(proof, key)
    if values.length() > 0 {
      return values
    }
  }
  for key in keys {
    let values = json_string_array_items(validation, key)
    if values.length() > 0 {
      return values
    }
  }
  []
}

///|
fn eb_appendix_notes_valid(validation : Json, output_relative : String) -> Bool {
  let notes = json_object_field_or_empty(validation, "appendix_notes")
  let keywords = eb_appendix_string_array(validation, notes, [
    "search_keywords", "keywords", "retrieval_keywords",
  ])
  let sources = eb_appendix_string_array(validation, notes, [
    "information_sources", "source_list", "sources", "official_sources",
  ])
  let retrieval_date = eb_appendix_first_string(validation, notes, [
    "retrieval_date", "search_date", "检索日期",
  ])
  let parts = eb_output_name_parts(
    eb_output_name_from_relative(output_relative),
  )
  let bond_code = json_string(parts, "bond_code", default="")
  let bond_short_name = json_string(parts, "bond_short_name", default="")
  keywords.length() > 0 &&
  eb_retrieval_date_valid(retrieval_date) &&
  eb_string_array_has_official_source(sources) &&
  (bond_code == "" || eb_string_array_contains_token(keywords, bond_code)) &&
  (
    bond_short_name == "" ||
    eb_target_text_is_placeholder(bond_short_name) ||
    eb_string_array_contains_token(keywords, bond_short_name)
  )
}

///|
fn eb_appendix_string_array(
  validation : Json,
  notes : Json,
  keys : Array[String],
) -> Array[String] {
  for key in keys {
    let values = json_string_array_items(notes, key)
    if values.length() > 0 {
      return values
    }
  }
  for key in keys {
    let values = json_string_array_items(validation, key)
    if values.length() > 0 {
      return values
    }
  }
  []
}

///|
fn eb_appendix_first_string(
  validation : Json,
  notes : Json,
  keys : Array[String],
) -> String {
  let nested = json_first_string(notes, keys, default="")
  if nested.trim().to_owned() != "" {
    nested
  } else {
    json_first_string(validation, keys, default="")
  }
}

///|
fn eb_retrieval_date_valid(text : String) -> Bool {
  let clean = text.trim().to_owned()
  eb_yyyymmdd_string_valid(clean) ||
  (
    clean.length() == 10 &&
    clean[4] == '-' &&
    clean[7] == '-' &&
    eb_yyyymmdd_string_valid(clean.replace_all(old="-", new=""))
  )
}

///|
fn eb_string_array_has_official_source(values : Array[String]) -> Bool {
  for value in values {
    let clean = value.trim().to_owned()
    if eb_is_http_url(clean) {
      if eb_url_allowed_official_domain(clean) {
        return true
      }
    } else if eb_official_domains().contains(clean.to_lower()) {
      return true
    }
  }
  false
}

///|
fn eb_string_array_contains_token(
  values : Array[String],
  token : String,
) -> Bool {
  let token = token.trim().to_owned()
  if token == "" {
    return false
  }
  for value in values {
    if value.contains(token) {
      return true
    }
  }
  false
}

///|
async fn eb_output_target_match(
  book_root : String,
  output_relative : String,
) -> Json {
  let failed : Array[String] = []
  let name = eb_output_name_from_relative(output_relative)
  let parsed = eb_output_name_parts(name)
  let output_code = json_string(parsed, "bond_code", default="")
  let output_short_name = json_string(parsed, "bond_short_name", default="")
  let output_as_of = json_string(parsed, "as_of", default="")
  let manifest = read_json_file_or_object(
    @pathx.join(book_root, eb_output_manifest_relative_path(output_relative)),
  )
  let manifest_code = json_string(manifest, "bond_code", default="")
  let manifest_short_name = json_string(manifest, "bond_short_name", default="")
  let target_scope = eb_target_scope_from_book(book_root)
  let multi_scope = target_scope == "active_universe" ||
    target_scope == "portfolio"
  push_failed_unless(
    failed,
    json_bool(parsed, "ok", default=false),
    "output filename follows EB追踪_<债券代码>_<债券简称>_<YYYYMMDD>.xlsx",
  )
  if multi_scope {
    push_failed_unless(
      failed,
      output_code == "ACTIVEEB" || output_code == "PORTFOLIO",
      "portfolio/universe output filename uses ACTIVEEB or PORTFOLIO code",
    )
  } else {
    push_failed_unless(
      failed,
      eb_target_code_is_production(output_code),
      "output filename uses a real non-sample 132XXX EB code",
    )
  }
  push_failed_unless(
    failed,
    !eb_target_text_is_placeholder(output_short_name),
    "output filename uses a non-placeholder EB short name",
  )
  push_failed_unless(
    failed,
    manifest_code == output_code && manifest_short_name == output_short_name,
    "output manifest bond code/name match the workbook filename",
  )
  let targets = eb_production_targets_from_book(book_root)
  let matching_targets : Array[Json] = []
  for target in targets {
    if eb_target_matches_output(target, output_code, output_short_name) {
      matching_targets.push(target)
    }
  }
  if !multi_scope {
    push_failed_unless(
      failed,
      matching_targets.length() > 0,
      "accepted workbook code/name match at least one configured production EB target",
    )
  }
  {
    "kind": "eb-output-target-match",
    "ok": failed.length() == 0,
    "output_path": output_relative,
    "filename": name,
    "bond_code": output_code,
    "bond_short_name": output_short_name,
    "as_of": output_as_of,
    "target_scope": target_scope,
    "manifest_bond_code": manifest_code,
    "manifest_bond_short_name": manifest_short_name,
    "target_count": targets.length(),
    "matching_target_count": matching_targets.length(),
    "matching_targets": Json::array(matching_targets),
    "failed_checks": json_from_string_array(failed),
  }
}

///|
fn eb_output_name_parts(name : String) -> Json {
  if !name.has_prefix("EB追踪_") || !name.has_suffix(".xlsx") {
    return { "ok": false, "bond_code": "", "bond_short_name": "", "as_of": "" }
  }
  let pieces = name.split("_").to_array()
  if pieces.length() < 4 || pieces[0].to_owned() != "EB追踪" {
    return { "ok": false, "bond_code": "", "bond_short_name": "", "as_of": "" }
  }
  let code = pieces[1].to_owned()
  let as_of_with_suffix = pieces[pieces.length() - 1].to_owned()
  let as_of = if as_of_with_suffix.has_suffix(".xlsx") {
    as_of_with_suffix[:as_of_with_suffix.length() - ".xlsx".length()].to_owned()
  } else {
    as_of_with_suffix
  }
  let name_parts : Array[String] = []
  for index = 2; index < pieces.length() - 1; index = index + 1 {
    name_parts.push(pieces[index].to_owned())
  }
  let short_name = name_parts.join("_")
  {
    "ok": code != "" && short_name != "" && eb_yyyymmdd_string_valid(as_of),
    "bond_code": code,
    "bond_short_name": short_name,
    "as_of": as_of,
  }
}

///|
fn eb_yyyymmdd_string_valid(text : String) -> Bool {
  let clean = text.trim().to_owned()
  if clean.length() != 8 {
    return false
  }
  for ch in clean {
    if ch < '0' || ch > '9' {
      return false
    }
  }
  true
}

///|
fn eb_target_matches_output(
  target : Json,
  output_code : String,
  output_short_name : String,
) -> Bool {
  let target_code = json_string(target, "bond_code", default="")
    .trim()
    .to_owned()
  let target_name = json_string(
      target,
      "bond_full_name_or_short_name",
      default="",
    )
    .trim()
    .to_owned()
  target_code == output_code &&
  eb_target_production_failed_checks(target).length() == 0 &&
  eb_target_name_matches_output(target_name, output_short_name)
}

///|
fn eb_target_name_matches_output(
  target_name : String,
  output_short_name : String,
) -> Bool {
  let target_name = target_name.trim().to_owned()
  let output_short_name = output_short_name.trim().to_owned()
  target_name != "" &&
  output_short_name != "" &&
  !eb_target_text_is_placeholder(target_name) &&
  !eb_target_text_is_placeholder(output_short_name) &&
  (
    target_name == output_short_name ||
    target_name.contains(output_short_name) ||
    output_short_name.contains(target_name)
  )
}

///|
fn json_string_array_exact(
  json : Json,
  key : String,
  expected : Array[String],
) -> Bool {
  let actual = json_string_array_items(json, key)
  if actual.length() != expected.length() {
    return false
  }
  for index = 0; index < expected.length(); index = index + 1 {
    if actual[index] != expected[index] {
      return false
    }
  }
  true
}

///|
async fn eb_durable_run_health(
  root : String,
  book_root : String,
  book_id : String,
) -> Json {
  let failed : Array[String] = []
  let contract = book_contract_verification(
    root, book_root, book_id, "exchangeable-bond-evidence-watch",
  )
  let target_readiness = eb_production_target_readiness(book_root)
  let targets_production_ready = json_bool(
    target_readiness,
    "ok",
    default=false,
  )
  let production_proof_receipt_relative = eb_production_proof_receipt_relative_path()
  let production_proof_receipt_path = @pathx.join(
    book_root, production_proof_receipt_relative,
  )
  let production_proof_receipt = read_json_file_or_object(
    production_proof_receipt_path,
  )
  let production_proof_receipt_ready = @fs.exists(production_proof_receipt_path) &&
    json_string(production_proof_receipt, "kind", default="") ==
    "eb-production-proof"
  let production_proof_status = json_string(
    production_proof_receipt,
    "status",
    default=if production_proof_receipt_ready { "unknown" } else { "not_run" },
  )
  let production_proof_level = json_string(
    production_proof_receipt,
    "proof_level",
    default="",
  )
  let output_validation = json_object_field_or_empty(
    contract, "output_validation",
  )
  let expected_output_contract = json_object_field_or_empty(
    contract, "expected_output_contract",
  )
  let base_type_selection = json_object_field_or_empty(
    contract, "base_type_selection",
  )
  let base_type_selection_ready = json_bool(
      base_type_selection,
      "verified",
      default=false,
    ) &&
    json_string(base_type_selection, "base_type", default="") == "research-book" &&
    json_string(base_type_selection, "handoff_target", default="") == "Moontown"
  let moontown_template_publish_receipt_path = json_string(
    contract,
    "moontown_template_publish_receipt_path",
    default=pdf_watch_moontown_publish_receipt_relative_path(),
  )
  let moontown_template_publish_receipt = if moontown_template_publish_receipt_path ==
    "" {
    Json::object({})
  } else {
    read_json_file_or_object(
      @pathx.join(book_root, moontown_template_publish_receipt_path),
    )
  }
  let moontown_template_publish_receipt_ready = json_bool(
      moontown_template_publish_receipt,
      "ok",
      default=false,
    ) &&
    json_string(moontown_template_publish_receipt, "target_book_id", default="") ==
    book_id &&
    json_string(
      json_object_field_or_empty(
        moontown_template_publish_receipt, "output_contract",
      ),
      "output_contract",
      default="",
    ) ==
    "moondesk.exchangeable_bond_tracking.xlsx.v1"
  let expected_output_contract_ready = json_bool(
      output_validation,
      "expected_output_contract_ready",
      default=false,
    ) &&
    eb_expected_output_contract_valid(expected_output_contract)
  let standing_goal_receipt_relative = pdf_watch_moontown_standing_goal_receipt_relative_path()
  let standing_goal_receipt_path = @pathx.join(
    book_root, standing_goal_receipt_relative,
  )
  let standing_goal_receipt = read_json_file_or_object(
    standing_goal_receipt_path,
  )
  let standing_goal_registration_ready = @fs.exists(standing_goal_receipt_path) &&
    json_bool(standing_goal_receipt, "ok", default=false) &&
    json_string(standing_goal_receipt, "status", default="") == "registered" &&
    json_string(standing_goal_receipt, "target_book_id", default="") == book_id
  let goal = eb_standing_goal_for_book(root, book_id)
  let global_standing_goal_ready = json_string(
      goal,
      "target_book_id",
      default="",
    ) ==
    book_id
  let receipt_goal_id = if standing_goal_registration_ready {
    json_string(standing_goal_receipt, "goal_id", default="")
  } else {
    ""
  }
  let moonclaw_profile_path = @pathx.join(book_root, "moonclaw.jobs.json")
  let moonclaw_packet_relative = eb_moonclaw_proposal_packet_relative_path()
  let moonclaw_packet_path = @pathx.join(book_root, moonclaw_packet_relative)
  let moonclaw_import_receipt_relative = eb_moonclaw_import_receipt_relative_path()
  let moonclaw_import_receipt_path = @pathx.join(
    book_root, moonclaw_import_receipt_relative,
  )
  let moonclaw_retry_import_receipt_relative = eb_moonclaw_retry_import_receipt_relative_path()
  let moonclaw_retry_import_receipt_path = @pathx.join(
    book_root, moonclaw_retry_import_receipt_relative,
  )
  let raw_moonclaw_import_receipt = read_json_file_or_object(
    moonclaw_import_receipt_path,
  )
  let moonclaw_import_receipt = eb_recovered_moonclaw_import_receipt(
    book_root, book_id, raw_moonclaw_import_receipt, production_proof_receipt,
  )
  let moonclaw_import_receipt_recovered = json_bool(
    moonclaw_import_receipt,
    "recovered",
    default=false,
  )
  let moonclaw_import_recovery_source = json_string(
    moonclaw_import_receipt,
    "recovery_source",
    default="",
  )
  let moonclaw_retry_import_receipt = read_json_file_or_object(
    moonclaw_retry_import_receipt_path,
  )
  let moonclaw_retry_import_receipt_ready = @fs.exists(
      moonclaw_retry_import_receipt_path,
    ) &&
    json_string(moonclaw_retry_import_receipt, "kind", default="") ==
    "moonclaw-proposal-import-receipt"
  let moonclaw_retry_import_status = json_string(
    moonclaw_retry_import_receipt,
    "status",
    default=if moonclaw_retry_import_receipt_ready {
      "failed"
    } else {
      "not_retried"
    },
  )
  let moonclaw_import_status = json_string(
    moonclaw_import_receipt,
    "status",
    default=if moonclaw_import_receipt_recovered {
      "recovered"
    } else if @fs.exists(moonclaw_import_receipt_path) {
      "failed"
    } else {
      "not_imported"
    },
  )
  let moonclaw_import_run_id = json_string(
    moonclaw_import_receipt,
    "run_id",
    default="",
  )
  let moonclaw_import_home = json_string(
    moonclaw_import_receipt,
    "home",
    default="",
  )
  let moonclaw_confirmed_run_meta_path = if moonclaw_import_home == "" ||
    moonclaw_import_run_id == "" {
    ""
  } else {
    @pathx.join(
      moonclaw_import_home,
      "jobs/runs/" + moonclaw_import_run_id + "/meta.json",
    )
  }
  let moonclaw_confirmed_run_meta = if moonclaw_confirmed_run_meta_path == "" {
    Json::object({})
  } else {
    read_json_file_or_object(moonclaw_confirmed_run_meta_path)
  }
  let moonclaw_confirmed_run_status = json_string(
    moonclaw_confirmed_run_meta,
    "status",
    default=json_string(
      json_object_field_or_empty(moonclaw_import_receipt, "import_result"),
      "status",
      default="",
    ),
  )
  let moonclaw_confirmed_run_meta_ready = moonclaw_confirmed_run_meta_path != "" &&
    @fs.exists(moonclaw_confirmed_run_meta_path)
  let moonclaw_confirmed_run_succeeded = moonclaw_confirmed_run_status ==
    "Succeeded"
  let moonclaw_missing_input_step_health = eb_moonclaw_missing_input_step_health(
    moonclaw_import_home, moonclaw_import_run_id,
  )
  let moonclaw_steps_without_missing_input = json_bool(
    moonclaw_missing_input_step_health,
    "ok",
    default=false,
  )
  let moonclaw_candidate_discovery = eb_moonclaw_candidate_discovery_health(
    book_root, moonclaw_import_home, moonclaw_import_run_id, moonclaw_confirmed_run_meta,
  )
  let moonclaw_candidate_discovery_terminal_ready = json_bool(
    moonclaw_candidate_discovery,
    "terminal_evidence_ready",
    default=false,
  )
  let moonclaw_candidate_discovery_explicit_failure = json_bool(
    moonclaw_candidate_discovery,
    "explicit_failure",
    default=false,
  )
  let moonclaw_web_tool_contract = eb_moonclaw_web_tool_contract_health(
    book_root, moonclaw_import_run_id, moonclaw_confirmed_run_meta, moonclaw_packet_path,
  )
  let moonclaw_web_tool_contract_ready = json_bool(
    moonclaw_web_tool_contract,
    "ok",
    default=false,
  )
  let moonclaw_receipt_stderr = json_string(
    moonclaw_import_receipt,
    "stderr",
    default="",
  )
  let moonclaw_packet_stderr = read_text_file_or_empty(
    moonclaw_packet_path + ".import.json.err",
  )
  let moonclaw_import_stderr_text = trim_for_record(
    if moonclaw_receipt_stderr.trim().to_owned() ==
      moonclaw_packet_stderr.trim().to_owned() {
      moonclaw_receipt_stderr
    } else {
      moonclaw_receipt_stderr + "\n" + moonclaw_packet_stderr
    },
  )
  let moonclaw_import_stderr_tolerated = eb_moonclaw_import_stderr_tolerated(
    moonclaw_import_stderr_text, moonclaw_import_receipt,
  )
  let moonclaw_import_stderr_clean = moonclaw_import_stderr_text
    .trim()
    .to_owned() ==
    "" ||
    moonclaw_import_stderr_tolerated
  let moonclaw_run_receipt_relative = if moonclaw_import_run_id == "" {
    ""
  } else {
    eb_moonclaw_run_receipt_relative_path(moonclaw_import_run_id)
  }
  let moonclaw_run_receipt_path = if moonclaw_run_receipt_relative == "" {
    ""
  } else {
    @pathx.join(book_root, moonclaw_run_receipt_relative)
  }
  let moonclaw_run_receipt = if moonclaw_run_receipt_path == "" {
    Json::object({})
  } else {
    read_json_file_or_object(moonclaw_run_receipt_path)
  }
  let moonclaw_run_receipt_ready = moonclaw_run_receipt_path != "" &&
    @fs.exists(moonclaw_run_receipt_path) &&
    json_string(moonclaw_run_receipt, "kind", default="") ==
    "moonclaw-confirmed-run-receipt" &&
    json_string(moonclaw_run_receipt, "run_id", default="") ==
    moonclaw_import_run_id
  let moonclaw_run_receipt_ok = moonclaw_run_receipt_ready &&
    json_bool(moonclaw_run_receipt, "ok", default=false)
  let moonclaw_run_receipt_timed_out = moonclaw_run_receipt_ready &&
    json_bool(moonclaw_run_receipt, "timed_out", default=false)
  let moonclaw_run_orphaned_after_timeout = moonclaw_run_receipt_ready &&
    eb_moonclaw_run_receipt_orphaned_after_timeout(moonclaw_run_receipt)
  let moonclaw_run_receipt_status = json_string(
    moonclaw_run_receipt,
    "status",
    default="",
  )
  let moonclaw_run_stderr_text = trim_for_record(
    json_string(moonclaw_run_receipt, "stderr", default=""),
  )
  let moonclaw_run_stderr_clean = moonclaw_run_stderr_text.trim().to_owned() ==
    ""
  let moonclaw_execution_stderr_clean = moonclaw_import_stderr_clean ||
    (moonclaw_run_receipt_ok && moonclaw_run_stderr_clean)
  let goal_id = trimmed_payload_text(
    json_string(goal, "id", default=""),
    default=trimmed_payload_text(
      receipt_goal_id,
      default=eb_default_goal_id_for_book(book_id),
    ),
  )
  let watcher = eb_latest_watcher_record_for_goal(root, goal_id, book_id)
  let fallback_output_path = eb_first_valid_accepted_output_relative(
    output_validation,
  )
  let fallback_manifest = if fallback_output_path == "" {
    Json::object({})
  } else {
    read_json_file_or_object(
      @pathx.join(
        book_root,
        eb_output_manifest_relative_path(fallback_output_path),
      ),
    )
  }
  let fallback_run_id = json_string(fallback_manifest, "run_id", default="")
  let run_id = trimmed_payload_text(
    json_string(watcher, "run_id", default=""),
    default=fallback_run_id,
  )
  let run_result_path = if run_id == "" {
    ""
  } else {
    @pathx.join(book_root, "moonclaw-jobs/" + run_id + "/result.json")
  }
  let run_result = if run_result_path == "" {
    Json::object({})
  } else {
    read_json_file_or_object(run_result_path)
  }
  let output_path = trimmed_payload_text(
    json_string(run_result, "output_path", default=""),
    default=trimmed_payload_text(
      json_string(watcher, "output_path", default=""),
      default=fallback_output_path,
    ),
  )
  let output_absolute = if output_path == "" {
    ""
  } else {
    @pathx.join(book_root, output_path)
  }
  let source_screen_path = trimmed_payload_text(
    json_string(run_result, "source_screen_path", default=""),
    default=if run_id == "" {
      ""
    } else {
      eb_source_screen_relative_path(run_id)
    },
  )
  let source_screen_absolute = if source_screen_path == "" {
    ""
  } else {
    @pathx.join(book_root, source_screen_path)
  }
  let book_result_path = if run_id == "" {
    ""
  } else {
    @pathx.join(root, ".moontown/book-results/" + run_id + ".json")
  }
  let book_result = if book_result_path == "" {
    Json::object({})
  } else {
    read_json_file_or_object(book_result_path)
  }
  let watcher_update = json_string(
      watcher,
      "standing_goal_decision",
      default="",
    ) ==
    "update" ||
    json_string(watcher, "decision", default="") == "Update"
  let run_result_ready = run_result_path != "" && @fs.exists(run_result_path)
  let book_result_ready = book_result_path != "" &&
    @fs.exists(book_result_path) &&
    json_string(book_result, "status", default="") == "accepted"
  let output_ready = output_absolute != "" &&
    eb_accepted_output_valid(book_root, output_path)
  let workbook_validation_ready = output_path != "" &&
    eb_output_workbook_validation_valid(book_root, output_path)
  let workbook_internal_contract_ready = output_absolute != "" &&
    eb_xlsx_internal_contract_valid(output_absolute)
  let workbook_validation_sample_run = output_path != "" &&
    eb_output_workbook_validation_sample_run(book_root, output_path)
  let workbook_data_proof_ready = output_path != "" &&
    eb_output_workbook_data_proof_valid(book_root, output_path)
  let workbook_hyperlinks_ready = output_path != "" &&
    eb_output_workbook_hyperlinks_valid(book_root, output_path)
  let workbook_appendix_notes_ready = output_path != "" &&
    eb_output_appendix_notes_valid(book_root, output_path)
  let workbook_quality_proof_ready = output_path != "" &&
    eb_output_quality_proof_valid(book_root, output_path)
  let workbook_lifecycle_proof_ready = output_path != "" &&
    eb_output_lifecycle_proof_valid(book_root, output_path)
  let output_target_match = if output_path == "" {
    Json::object({
      "kind": "eb-output-target-match",
      "ok": false,
      "output_path": "",
      "failed_checks": json_from_string_array([
        "accepted workbook path is available",
      ]),
    })
  } else {
    eb_output_target_match(book_root, output_path)
  }
  let output_target_match_ready = json_bool(
    output_target_match,
    "ok",
    default=false,
  )
  let source_screen_ready = source_screen_absolute != "" &&
    eb_source_screen_valid(source_screen_absolute)
  let source_screen_production_ready = source_screen_absolute != "" &&
    eb_production_source_screen_valid_for_book(
      book_root, source_screen_absolute,
    )
  let moonclaw_profile_ready = @fs.exists(moonclaw_profile_path) &&
    file_contains(moonclaw_profile_path, "eb_pdf_evidence_watch")
  let moonclaw_packet_ready = @fs.exists(moonclaw_packet_path) &&
    file_contains(moonclaw_packet_path, "eb_pdf_evidence_watch") &&
    file_contains(moonclaw_packet_path, "raw/inbox/eb-tracking-request.json")
  let moonclaw_import_receipt_ready = (
      @fs.exists(moonclaw_import_receipt_path) ||
      moonclaw_import_receipt_recovered
    ) &&
    json_bool(moonclaw_import_receipt, "ok", default=false) &&
    json_string(moonclaw_import_receipt, "proposal_id", default="") != ""
  let moonclaw_confirmed_run_ready = moonclaw_import_receipt_ready &&
    moonclaw_import_run_id != ""
  let real_moonclaw_result_ready = run_result_ready &&
    eb_run_result_is_live_moonclaw_result(run_result)
  push_failed_unless(
    failed,
    json_bool(contract, "verified", default=false),
    "book contract verified",
  )
  push_failed_unless(
    failed, expected_output_contract_ready, "expected EB output contract receipt ready",
  )
  push_failed_unless(
    failed, moonclaw_profile_ready, "MoonClaw EB profile ready",
  )
  push_failed_unless(
    failed, moonclaw_packet_ready, "MoonClaw EB proposal packet ready",
  )
  push_failed_unless(failed, goal_id != "", "standing goal targets book")
  push_failed_unless(failed, watcher_update, "watcher ledger has update record")
  push_failed_unless(failed, run_id != "", "watcher record has run id")
  push_failed_unless(
    failed, run_result_ready, "MoonClaw-style run result exists",
  )
  push_failed_unless(failed, book_result_ready, "Moontown book result accepted")
  push_failed_unless(
    failed, output_ready, "accepted EB workbook exists with output manifest",
  )
  push_failed_unless(
    failed,
    json_bool(output_validation, "final_output_ready", default=false),
    "output validation final gate ready",
  )
  push_failed_unless(
    failed, workbook_validation_ready, "hash-bound workbook validation artifact exists",
  )
  push_failed_unless(
    failed, workbook_appendix_notes_ready, "workbook appendix notes include search keywords, retrieval date, and official source list",
  )
  push_failed_unless(
    failed, workbook_hyperlinks_ready, "workbook original-link cells contain official clickable hyperlinks",
  )
  push_failed_unless(
    failed, workbook_quality_proof_ready, "workbook quality proof covers official links, clickable source URLs, summary length, key data emphasis, cross-verification, timing, data consistency, missing disclosures, and formatting",
  )
  push_failed_unless(
    failed, workbook_lifecycle_proof_ready, "workbook lifecycle proof covers all six EB stages or marks missing disclosures",
  )
  push_failed_unless(
    failed, source_screen_ready, "official source screen exists and passes gate",
  )
  let durable_ready = failed.length() == 0
  let production_failed : Array[String] = []
  push_failed_unless(
    production_failed, moonclaw_import_receipt_ready, "MoonClaw proposal import receipt accepted",
  )
  push_failed_unless(
    production_failed, targets_production_ready, "EB target bond configuration is production-ready",
  )
  push_failed_unless(
    production_failed, moonclaw_confirmed_run_ready, "MoonClaw run confirmed",
  )
  push_failed_unless(
    production_failed, moonclaw_confirmed_run_meta_ready, "MoonClaw confirmed run metadata exists",
  )
  push_failed_unless(
    production_failed, moonclaw_confirmed_run_succeeded, "MoonClaw confirmed run succeeded",
  )
  push_failed_unless(
    production_failed,
    !moonclaw_run_orphaned_after_timeout,
    "MoonClaw timed-out run is not orphaned",
  )
  push_failed_unless(
    production_failed, moonclaw_web_tool_contract_ready, "MoonClaw runtime exposes required web_search and web_fetch tools",
  )
  push_failed_unless(
    production_failed, moonclaw_steps_without_missing_input, "MoonClaw steps completed without best-effort missing-input fallback",
  )
  push_failed_unless(
    production_failed, moonclaw_candidate_discovery_terminal_ready, "MoonClaw official PDF candidate discovery wrote terminal evidence",
  )
  push_failed_unless(
    production_failed, moonclaw_execution_stderr_clean, "MoonClaw launch or confirmed-run stderr is clean",
  )
  push_failed_unless(
    production_failed, real_moonclaw_result_ready, "MoonClaw result is from a live imported run",
  )
  push_failed_unless(
    production_failed,
    !workbook_validation_sample_run,
    "workbook validation is from a live run, not a sample",
  )
  push_failed_unless(
    production_failed, workbook_data_proof_ready, "workbook validation proves source-backed data rows in both sheets",
  )
  push_failed_unless(
    production_failed, workbook_hyperlinks_ready, "workbook XML contains official clickable hyperlinks in the original-link column",
  )
  push_failed_unless(
    production_failed, output_target_match_ready, "accepted workbook filename and manifest match the configured production EB target",
  )
  push_failed_unless(
    production_failed, source_screen_production_ready, "production source screen proves live official PDF fetch/extract",
  )
  for failed_check in failed {
    production_failed.push(failed_check)
  }
  let production_ready = production_failed.length() == 0
  let production_checklist : Array[Json] = []
  production_checklist.push(
    eb_proof_check_item(
      "book_contract",
      "Book contract verified",
      json_bool(contract, "verified", default=false),
      "The EB book layout, method, skills, schemas, standing-watch packet, MoonClaw packet, and XLSX contract are present.",
      "raw/analysis-runs/eb-contract-verification.json",
    ),
  )
  production_checklist.push(
    eb_proof_check_item(
      "expected_output_contract",
      "Expected EB workbook contract ready",
      expected_output_contract_ready,
      "The book must preserve raw/analysis-runs/eb-expected-output-contract.json with the exact final XLSX filename, sheets, headers, sidecars, lifecycle proof, official-source rules, multi-bond rule, and Bookkeeper acceptance requirements.",
      eb_expected_output_contract_relative_path(),
    ),
  )
  production_checklist.push(
    eb_proof_check_item(
      "target_config", "Production EB target configured", targets_production_ready,
      "Every EB target must have a real non-sample 132XXX code, bond name, issuer, underlying listed company, and 上交所/深交所 exchange.",
      "book.json targets plus raw/inbox/eb-tracking-request.json",
    ),
  )
  production_checklist.push(
    eb_proof_check_item(
      "standing_goal",
      "Moontown standing goal targets the book",
      goal_id != "" && standing_goal_registration_ready,
      "Moontown must own the recurring standing watch for this book, with a durable book-local registration receipt.",
      if standing_goal_registration_ready {
        standing_goal_receipt_relative
      } else {
        ".moontown/standing-goals.json"
      },
    ),
  )
  production_checklist.push(
    eb_proof_check_item(
      "production_proof_attempt", "Production proof receipt recorded", production_proof_receipt_ready,
      "The explicit production-proof action should persist its latest import/run/reconcile attempt so operators can audit whether the watch was actually tried.",
      production_proof_receipt_relative,
    ),
  )
  production_checklist.push(
    eb_proof_check_item(
      "moonclaw_import", "MoonClaw proposal import accepted", moonclaw_import_receipt_ready,
      "Moondesk must import the generated MoonClaw proposal packet and persist a receipt with proposal id.",
      moonclaw_import_receipt_relative,
    ),
  )
  production_checklist.push(
    eb_proof_check_item(
      "moonclaw_run",
      "MoonClaw run confirmed and succeeded",
      moonclaw_confirmed_run_ready &&
      moonclaw_confirmed_run_meta_ready &&
      moonclaw_confirmed_run_succeeded,
      "The confirmed MoonClaw run id must have persisted metadata and a Succeeded status.",
      moonclaw_confirmed_run_meta_path,
    ),
  )
  production_checklist.push(
    eb_proof_check_item(
      "moonclaw_run_not_orphaned",
      "MoonClaw run is not orphaned after timeout",
      !moonclaw_run_orphaned_after_timeout,
      "If Moondesk times out a bounded confirmed-run command while MoonClaw meta still says Running, the run is treated as orphaned and a fresh import/run is recommended.",
      moonclaw_run_receipt_relative,
    ),
  )
  production_checklist.push(
    eb_proof_check_item(
      "moonclaw_web_tools",
      "MoonClaw runtime exposes web tools",
      moonclaw_web_tool_contract_ready,
      "The EB watch packet must request executor/full runtime with web_search and web_fetch, and run artifacts must not show those required tools were unavailable.",
      json_string(
        moonclaw_web_tool_contract,
        "primary_evidence_path",
        default=moonclaw_packet_relative,
      ),
    ),
  )
  production_checklist.push(
    eb_proof_check_item(
      "moonclaw_no_missing_input",
      "MoonClaw did not use missing-input fallback",
      moonclaw_steps_without_missing_input,
      "A production EB watch cannot count best-effort continuation after missing input as source discovery, extraction, analysis, or Bookkeeper acceptance.",
      json_string(
        moonclaw_missing_input_step_health,
        "primary_evidence_path",
        default=moonclaw_confirmed_run_meta_path,
      ),
    ),
  )
  production_checklist.push(
    eb_proof_check_item(
      "moonclaw_pdf_candidates",
      "MoonClaw PDF candidate discovery recorded",
      moonclaw_candidate_discovery_terminal_ready,
      "The first EB watch step must write outputs/official-pdf-candidates.json with official candidates, or an explicit failed candidate record with checked domains and a reason.",
      json_string(
        moonclaw_candidate_discovery,
        "candidate_artifact_path",
        default="outputs/official-pdf-candidates.json",
      ),
    ),
  )
  production_checklist.push(
    eb_proof_check_item(
      "moonclaw_execution_stderr", "MoonClaw execution stderr clean", moonclaw_execution_stderr_clean,
      "Either import stderr is clean, or the confirmed-run receipt proves a clean successful execution.",
      moonclaw_run_receipt_relative,
    ),
  )
  production_checklist.push(
    eb_proof_check_item(
      "live_result",
      "Live MoonClaw result exists",
      real_moonclaw_result_ready,
      "The accepted result must come from a live imported MoonClaw run, not the deterministic sample runner.",
      if run_id == "" {
        "moonclaw-jobs/<run>/result.json"
      } else {
        "moonclaw-jobs/" + run_id + "/result.json"
      },
    ),
  )
  production_checklist.push(
    eb_proof_check_item(
      "watcher_update",
      "Watcher ledger records update",
      watcher_update && run_id != "",
      "Moontown watcher ledger must record an update decision with the MoonClaw run id.",
      if goal_id == "" {
        ".moontown/watchers/<goal>.jsonl"
      } else {
        ".moontown/watchers/" + goal_id + ".jsonl"
      },
    ),
  )
  production_checklist.push(
    eb_proof_check_item(
      "book_result",
      "Moontown book result accepted",
      book_result_ready,
      "Moontown must persist an accepted book-result record for the run.",
      if run_id == "" {
        ".moontown/book-results/<run>.json"
      } else {
        ".moontown/book-results/" + run_id + ".json"
      },
    ),
  )
  production_checklist.push(
    eb_proof_check_item(
      "accepted_workbook", "Accepted EB workbook valid", output_ready, "A non-placeholder EB追踪_<债券代码>_<债券简称>_<YYYYMMDD>.xlsx must pass package, filename, manifest, and workbook validation gates.",
      output_path,
    ),
  )
  production_checklist.push(
    eb_proof_check_item(
      "workbook_validation",
      "Workbook validation hash-bound",
      workbook_validation_ready && workbook_internal_contract_ready,
      "The sibling .xlsx.validation.json must bind xlsx_sha256 to the workbook bytes and prove exact EB sheet names and headers; the workbook XML must also preserve frozen headers, filters, column widths, and bold header styling.",
      if output_path == "" {
        "book/outputs/<workbook>.xlsx.validation.json"
      } else {
        eb_output_workbook_validation_relative_path(output_path)
      },
    ),
  )
  production_checklist.push(
    eb_proof_check_item(
      "appendix_notes",
      "Workbook notes prove search/source appendix",
      workbook_appendix_notes_ready,
      "The workbook validation must prove the EB output includes search keywords, retrieval date, and an official source list as required by the prompt.",
      if output_path == "" {
        "book/outputs/<workbook>.xlsx.validation.json"
      } else {
        eb_output_workbook_validation_relative_path(output_path)
      },
    ),
  )
  production_checklist.push(
    eb_proof_check_item(
      "quality_proof",
      "Workbook validation proves EB quality rules",
      workbook_quality_proof_ready,
      "The workbook validation must prove official-link-only rows, clickable source URLs, summaries within 200 characters, emphasized key data, issuer/underlying cross-verification, disclosure-timing checks, Sheet 1/Sheet 2 data reconciliation, missing-disclosure marking, and readable Excel formatting.",
      if output_path == "" {
        "book/outputs/<workbook>.xlsx.validation.json"
      } else {
        eb_output_workbook_validation_relative_path(output_path)
      },
    ),
  )
  production_checklist.push(
    eb_proof_check_item(
      "lifecycle_proof",
      "Workbook validation proves six lifecycle stages",
      workbook_lifecycle_proof_ready,
      "The workbook validation must prove issuance/listing, periodic reports, interim events, exchange-window management, redemption/sell-back, and repayment/exit were reviewed or explicitly marked missing with reasons.",
      if output_path == "" {
        "book/outputs/<workbook>.xlsx.validation.json"
      } else {
        eb_output_workbook_validation_relative_path(output_path)
      },
    ),
  )
  production_checklist.push(
    eb_proof_check_item(
      "not_sample",
      "Workbook validation is not sample",
      !workbook_validation_sample_run,
      "Production readiness rejects deterministic sample-run validation artifacts.",
      if output_path == "" {
        "book/outputs/<workbook>.xlsx.validation.json"
      } else {
        eb_output_workbook_validation_relative_path(output_path)
      },
    ),
  )
  production_checklist.push(
    eb_proof_check_item(
      "workbook_data_rows",
      "Workbook has source-backed data rows",
      workbook_data_proof_ready,
      "A non-sample EB workbook validation must prove positive announcement and indicator data-row counts with official-source-backed rows, and the workbook XML must contain non-header rows in both required sheets.",
      if output_path == "" {
        "book/outputs/<workbook>.xlsx.validation.json"
      } else {
        eb_output_workbook_validation_relative_path(output_path)
      },
    ),
  )
  production_checklist.push(
    eb_proof_check_item(
      "workbook_hyperlinks",
      "Workbook has clickable official links",
      workbook_hyperlinks_ready,
      "A non-sample EB workbook must contain OOXML hyperlink relationships for Sheet 1 original-link cells, and those external targets must be official disclosure domains.",
      if output_path == "" {
        "book/outputs/<workbook>.xlsx"
      } else {
        output_path
      },
    ),
  )
  production_checklist.push(
    eb_proof_check_item(
      "output_target_match",
      "Workbook matches configured EB target",
      output_target_match_ready,
      "The accepted workbook filename and manifest bond code/name must match a configured production EB target.",
      if output_path == "" {
        "book/outputs/<workbook>.xlsx.manifest.json"
      } else {
        eb_output_manifest_relative_path(output_path)
      },
    ),
  )
  production_checklist.push(
    eb_proof_check_item(
      "official_source_screen", "Official source screen proves live source fetch/extract",
      source_screen_production_ready, "The source screen must prove live official-domain source discovery, download, extraction, and no third-party repost URLs.",
      source_screen_path,
    ),
  )
  production_checklist.push(
    eb_proof_check_item(
      "output_validation",
      "Final output validation ready",
      json_bool(output_validation, "final_output_ready", default=false),
      "The book-level output validation must see the accepted workbook plus durable official-source evidence.",
      eb_output_validation_relative_path(),
    ),
  )
  {
    "book_id": book_id,
    "kind": "eb-durable-run-health",
    "status": if durable_ready {
      "durable_output_ready"
    } else if moonclaw_import_status == "timed_out" {
      "moonclaw_import_timed_out"
    } else if moonclaw_run_orphaned_after_timeout {
      "moonclaw_run_orphaned_after_timeout"
    } else if moonclaw_run_receipt_timed_out {
      "moonclaw_run_timed_out"
    } else if moonclaw_run_receipt_ready &&
      !moonclaw_run_receipt_ok &&
      moonclaw_run_receipt_status != "" {
      "moonclaw_run_" + moonclaw_run_receipt_status
    } else if moonclaw_confirmed_run_status == "Failed" {
      "moonclaw_run_failed"
    } else if moonclaw_confirmed_run_status == "WaitingForInput" {
      "moonclaw_run_waiting_for_input"
    } else if moonclaw_candidate_discovery_explicit_failure {
      "moonclaw_pdf_discovery_failed"
    } else if moonclaw_import_run_id != "" &&
      moonclaw_confirmed_run_status != "" &&
      moonclaw_confirmed_run_status != "Succeeded" {
      "waiting_for_moonclaw_run"
    } else if moonclaw_confirmed_run_succeeded &&
      !moonclaw_candidate_discovery_terminal_ready {
      "waiting_for_pdf_candidate_discovery"
    } else if run_id == "" {
      "waiting_for_watcher_run"
    } else if !source_screen_ready {
      "waiting_for_source_screen"
    } else if !output_ready {
      "waiting_for_accepted_workbook"
    } else {
      "durable_output_incomplete"
    },
    "durable_ready": durable_ready,
    "failed_checks": json_from_string_array(failed),
    "standing_goal_id": goal_id,
    "standing_goal_enabled": if global_standing_goal_ready {
      json_bool(goal, "enabled", default=false)
    } else {
      json_bool(standing_goal_receipt, "enabled", default=false)
    },
    "global_standing_goal_ready": global_standing_goal_ready,
    "base_type_selection_path": json_string(
      contract,
      "base_type_selection_path",
      default=pdf_watch_base_type_selection_relative_path(),
    ),
    "base_type_selection_ready": base_type_selection_ready,
    "base_type": json_string(base_type_selection, "base_type", default=""),
    "base_type_handoff_target": json_string(
      base_type_selection,
      "handoff_target",
      default="",
    ),
    "moontown_template_publish_receipt_path": moontown_template_publish_receipt_path,
    "moontown_template_publish_receipt_ready": moontown_template_publish_receipt_ready,
    "standing_goal_registration_path": standing_goal_receipt_relative,
    "standing_goal_registration_ready": standing_goal_registration_ready,
    "production_proof_receipt_path": production_proof_receipt_relative,
    "production_proof_receipt_ready": production_proof_receipt_ready,
    "production_proof_status": production_proof_status,
    "production_proof_level": production_proof_level,
    "production_proof_run_id": json_string(
      production_proof_receipt,
      "run_id",
      default="",
    ),
    "production_proof_failed_checks": json_from_string_array(
      json_string_array_items(production_proof_receipt, "failed_checks"),
    ),
    "watcher_record_id": json_string(watcher, "id", default=""),
    "watcher_decision": json_string(
      watcher,
      "standing_goal_decision",
      default="",
    ),
    "run_id": run_id,
    "moonclaw_profile_path": "moonclaw.jobs.json",
    "moonclaw_profile_ready": moonclaw_profile_ready,
    "moonclaw_proposal_packet_path": moonclaw_packet_relative,
    "moonclaw_proposal_packet_ready": moonclaw_packet_ready,
    "moonclaw_import_hint": "moon run cmd/main -- proposal import \{moonclaw_packet_relative} --confirm --cwd \{book_root}",
    "moonclaw_import_receipt_path": moonclaw_import_receipt_relative,
    "moonclaw_import_receipt_ready": moonclaw_import_receipt_ready,
    "moonclaw_import_receipt_recovered": moonclaw_import_receipt_recovered,
    "moonclaw_import_recovery_source": moonclaw_import_recovery_source,
    "moonclaw_retry_import_receipt_path": moonclaw_retry_import_receipt_relative,
    "moonclaw_retry_import_receipt_ready": moonclaw_retry_import_receipt_ready,
    "moonclaw_retry_import_status": moonclaw_retry_import_status,
    "moonclaw_confirmed_run_ready": moonclaw_confirmed_run_ready,
    "moontown_execution_receipt_path": eb_moontown_execution_receipt_relative_path(),
    "moontown_execution_receipt_ready": @fs.exists(
      @pathx.join(book_root, eb_moontown_execution_receipt_relative_path()),
    ),
    "moonclaw_import_status": moonclaw_import_status,
    "moonclaw_import_proposal_id": json_string(
      moonclaw_import_receipt,
      "proposal_id",
      default="",
    ),
    "moonclaw_import_run_id": json_string(
      moonclaw_import_receipt,
      "run_id",
      default="",
    ),
    "moonclaw_confirmed_run_home": moonclaw_import_home,
    "moonclaw_confirmed_run_meta_path": moonclaw_confirmed_run_meta_path,
    "moonclaw_confirmed_run_meta_ready": moonclaw_confirmed_run_meta_ready,
    "moonclaw_confirmed_run_status": moonclaw_confirmed_run_status,
    "moonclaw_confirmed_run_succeeded": moonclaw_confirmed_run_succeeded,
    "moonclaw_web_tool_contract": moonclaw_web_tool_contract,
    "moonclaw_web_tool_contract_ready": moonclaw_web_tool_contract_ready,
    "moonclaw_missing_input_step_health": moonclaw_missing_input_step_health,
    "moonclaw_steps_without_missing_input": moonclaw_steps_without_missing_input,
    "moonclaw_candidate_discovery": moonclaw_candidate_discovery,
    "moonclaw_candidate_discovery_terminal_ready": moonclaw_candidate_discovery_terminal_ready,
    "moonclaw_candidate_discovery_explicit_failure": moonclaw_candidate_discovery_explicit_failure,
    "target_readiness": target_readiness,
    "targets_production_ready": targets_production_ready,
    "moonclaw_import_stderr_clean": moonclaw_import_stderr_clean,
    "moonclaw_import_stderr_tolerated": moonclaw_import_stderr_tolerated,
    "moonclaw_import_stderr": moonclaw_import_stderr_text,
    "moonclaw_run_receipt_path": moonclaw_run_receipt_relative,
    "moonclaw_run_receipt_ready": moonclaw_run_receipt_ready,
    "moonclaw_run_receipt_ok": moonclaw_run_receipt_ok,
    "moonclaw_run_receipt_timed_out": moonclaw_run_receipt_timed_out,
    "moonclaw_run_orphaned_after_timeout": moonclaw_run_orphaned_after_timeout,
    "moonclaw_run_retry_recommended": moonclaw_run_orphaned_after_timeout,
    "moonclaw_run_receipt_status": moonclaw_run_receipt_status,
    "moonclaw_run_stderr_clean": moonclaw_run_stderr_clean,
    "moonclaw_run_stderr": moonclaw_run_stderr_text,
    "moonclaw_execution_stderr_clean": moonclaw_execution_stderr_clean,
    "real_moonclaw_result_ready": real_moonclaw_result_ready,
    "production_ready": production_ready,
    "production_failed_checks": json_from_string_array(production_failed),
    "production_checklist": Json::array(production_checklist),
    "expected_output_contract_path": eb_expected_output_contract_relative_path(),
    "expected_output_contract_ready": expected_output_contract_ready,
    "expected_output_contract": expected_output_contract,
    "moonclaw_result_path": if run_result_path == "" {
      ""
    } else {
      "moonclaw-jobs/" + run_id + "/result.json"
    },
    "book_result_path": if book_result_path == "" {
      ""
    } else {
      ".moontown/book-results/" + run_id + ".json"
    },
    "output_path": output_path,
    "workbook_validation_path": if output_path == "" {
      ""
    } else {
      eb_output_workbook_validation_relative_path(output_path)
    },
    "workbook_validation_ready": workbook_validation_ready,
    "workbook_internal_contract_ready": workbook_internal_contract_ready,
    "workbook_validation_sample_run": workbook_validation_sample_run,
    "workbook_data_proof_ready": workbook_data_proof_ready,
    "workbook_hyperlinks_ready": workbook_hyperlinks_ready,
    "workbook_appendix_notes_ready": workbook_appendix_notes_ready,
    "workbook_quality_proof_ready": workbook_quality_proof_ready,
    "workbook_lifecycle_proof_ready": workbook_lifecycle_proof_ready,
    "output_target_match": output_target_match,
    "output_target_match_ready": output_target_match_ready,
    "source_screen_path": source_screen_path,
    "source_screen_ready": source_screen_ready,
    "source_screen_production_ready": source_screen_production_ready,
    "output_validation": output_validation,
  }
}
