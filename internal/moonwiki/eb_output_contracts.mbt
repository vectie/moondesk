///|
fn eb_output_validation_relative_path() -> String {
  "raw/analysis-runs/eb-output-validation.json"
}

///|
fn eb_expected_output_contract_relative_path() -> String {
  "raw/analysis-runs/eb-expected-output-contract.json"
}

///|
fn eb_expected_output_contract_json(book_id : String) -> Json {
  {
    "kind": "eb-expected-output-contract",
    "contract_version": "1",
    "book_id": book_id,
    "pattern_id": "exchangeable-bond-evidence-watch",
    "base_type": "research-book",
    "output_contract": "moondesk.exchangeable_bond_tracking.xlsx.v1",
    "file_format": "xlsx",
    "filename_pattern": "EB追踪_[债券代码]_[债券简称]_[YYYYMMDD].xlsx",
    "output_directory": "book/outputs/",
    "sheets": json_from_json_array([
      {
        "name": "公告追踪主表",
        "headers": json_from_string_array(eb_announcement_sheet_headers()),
      },
      {
        "name": "关键指标监控表",
        "headers": json_from_string_array(eb_indicator_sheet_headers()),
      },
    ]),
    "required_sidecars": json_from_string_array([
      ".manifest.json", ".validation.json",
    ]),
    "manifest_required_fields": json_from_string_array([
      "kind", "book_id", "run_id", "bond_code", "bond_short_name", "as_of", "xlsx_path",
      "xlsx_sha256", "source_screen_path", "output_contract", "accepted_by_bookkeeper",
      "sample_run", "sheets",
    ]),
    "validation_required_fields": json_from_string_array([
      "kind", "book_id", "run_id", "xlsx_path", "xlsx_sha256", "output_contract",
      "workbook_package_valid", "headers_valid", "sample_run", "workbook_data_proof",
      "appendix_notes", "quality_proof", "lifecycle_stage_proof", "sheets",
    ]),
    "production_acceptance": {
      "accepted_by_bookkeeper": true,
      "sample_run": false,
      "requires_positive_data_rows": true,
      "requires_official_source_screen": true,
      "official_source_screen_path": "raw/analysis-runs/*-official-source-screen.json or MoonClaw result outputs/official-source-screen.json",
      "bookkeeper_acceptance_required": true,
    },
    "proof_requirements": json_from_string_array([
      "xlsx_sha256 matches workbook bytes", "workbook_data_proof has positive Sheet 1 and Sheet 2 data rows",
      "appendix_notes include search keywords, retrieval date, and official information-source list",
      "quality_proof covers official links, clickable links, summary length, key-data emphasis, cross-verification, timing checks, data reconciliation, missing-disclosure marking, and readable formatting",
      "lifecycle_stage_proof covers all six EB lifecycle stages or marks expected missing disclosures as 未检索到 with reasons",
      "official-source-screen.json proves live official-domain fetch, positive PDF downloads, and positive extraction count",
      "Bookkeeper acceptance is required before publishing final workbook knowledge",
    ]),
    "quality_rules": json_from_string_array([
      "official-domain URLs only", "clickable official source links", "summaries within 200 characters",
      "key data emphasized", "issuer/underlying cross-verification when applicable",
      "disclosure timing checks", "Sheet 1 and Sheet 2 data consistency", "missing disclosures marked 未检索到 with reason",
      "readable workbook formatting",
    ]),
    "lifecycle_stage_count": eb_lifecycle_stage_names().length(),
    "lifecycle_stages": json_from_string_array(eb_lifecycle_stage_names()),
    "official_domains": json_from_string_array(eb_official_domains()),
    "multi_bond_rule": "If multiple bonds are configured, group Sheet 1 rows by bond code and write one Sheet 2 row per bond.",
    "verified": true,
  }
}

///|
fn eb_expected_output_contract_valid(contract : Json) -> Bool {
  json_string(contract, "kind", default="") == "eb-expected-output-contract" &&
  json_string(contract, "contract_version", default="") == "1" &&
  json_string(contract, "pattern_id", default="") ==
  "exchangeable-bond-evidence-watch" &&
  json_string(contract, "base_type", default="") == "research-book" &&
  json_string(contract, "output_contract", default="") ==
  "moondesk.exchangeable_bond_tracking.xlsx.v1" &&
  json_string(contract, "file_format", default="") == "xlsx" &&
  json_string(contract, "filename_pattern", default="") ==
  "EB追踪_[债券代码]_[债券简称]_[YYYYMMDD].xlsx" &&
  json_string(contract, "output_directory", default="") == "book/outputs/" &&
  json_bool(contract, "verified", default=false) &&
  json_int(contract, "lifecycle_stage_count", default=0) == 6 &&
  json_string_array_items(contract, "official_domains").length() ==
  eb_official_domains().length() &&
  json_string_array_items(contract, "lifecycle_stages").length() ==
  eb_lifecycle_stage_names().length() &&
  json_string_array_items(contract, "required_sidecars").contains(
    ".manifest.json",
  ) &&
  json_string_array_items(contract, "required_sidecars").contains(
    ".validation.json",
  ) &&
  json_string_array_items(contract, "proof_requirements")
  .join("\n")
  .contains("official-source-screen.json") &&
  json_string(contract, "multi_bond_rule", default="").contains(
    "Sheet 1 rows by bond code",
  ) &&
  json_string(contract, "multi_bond_rule", default="").contains(
    "one Sheet 2 row per bond",
  ) &&
  eb_expected_output_contract_has_sheet(
    contract,
    "公告追踪主表",
    eb_announcement_sheet_headers(),
  ) &&
  eb_expected_output_contract_has_sheet(
    contract,
    "关键指标监控表",
    eb_indicator_sheet_headers(),
  )
}

///|
fn eb_expected_output_contract_has_sheet(
  contract : Json,
  sheet_name : String,
  headers : Array[String],
) -> Bool {
  for sheet in json_array_items(contract, "sheets") {
    if json_string(sheet, "name", default="") == sheet_name {
      let sheet_headers = json_string_array_items(sheet, "headers")
      for header in headers {
        if !sheet_headers.contains(header) {
          return false
        }
      }
      return true
    }
  }
  false
}

///|
fn eb_output_manifest_relative_path(output_relative : String) -> String {
  output_relative + ".manifest.json"
}

///|
fn eb_output_workbook_validation_relative_path(
  output_relative : String,
) -> String {
  output_relative + ".validation.json"
}

///|
fn eb_tracking_output_manifest_json(
  book_id~ : String,
  run_id~ : String,
  bond_code~ : String,
  bond_short_name~ : String,
  as_of~ : String,
  output_relative~ : String,
  source_screen_relative~ : String,
  pdf_candidates_relative? : String = "",
  accepted_by_bookkeeper~ : Bool,
  sample_run~ : Bool,
  xlsx_sha256? : String = "",
) -> Json {
  {
    "kind": "eb-tracking-output-manifest",
    "manifest_version": "1",
    "book_id": book_id,
    "run_id": run_id,
    "bond_code": bond_code,
    "bond_short_name": bond_short_name,
    "as_of": as_of,
    "xlsx_path": output_relative,
    "xlsx_sha256": xlsx_sha256,
    "source_screen_path": source_screen_relative,
    "pdf_candidates_path": pdf_candidates_relative,
    "output_contract": "moondesk.exchangeable_bond_tracking.xlsx.v1",
    "filename_pattern": "EB追踪_[债券代码]_[债券简称]_[YYYYMMDD].xlsx",
    "accepted_by_bookkeeper": accepted_by_bookkeeper,
    "sample_run": sample_run,
    "official_source_required": true,
    "sheets": json_from_json_array([
      {
        "name": "公告追踪主表",
        "headers": json_from_string_array(eb_announcement_sheet_headers()),
      },
      {
        "name": "关键指标监控表",
        "headers": json_from_string_array(eb_indicator_sheet_headers()),
      },
    ]),
    "quality_checks": json_from_string_array([
      "official-domain URLs only", "cross-verify issuer and underlying-company disclosures when applicable",
      "validate disclosure timing against exchange rules", "reconcile cumulative exchange share counts between sheets",
      "mark expected-but-missing stages as 未检索到 with reason",
    ]),
  }
}
