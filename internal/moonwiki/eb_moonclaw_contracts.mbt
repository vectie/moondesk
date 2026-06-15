///|
fn eb_moonclaw_import_receipt_relative_path() -> String {
  "raw/analysis-runs/moonclaw-proposal-import.json"
}

///|
fn eb_moonclaw_retry_import_receipt_relative_path() -> String {
  "raw/analysis-runs/moonclaw-proposal-retry-import.json"
}

///|
fn eb_moonclaw_run_receipt_relative_path(run_id : String) -> String {
  "raw/analysis-runs/" + run_id + "-moonclaw-run.json"
}

///|
async fn write_eb_production_proof_progress(
  root : String,
  book_root : String,
  book_id : String,
  run_id : String,
  import_step : String,
  run_step : String,
  timeout_ms : Int,
  import_receipt : Json,
  retry_import_receipt : Json,
  import_receipt_recovered : Bool,
  retry_import_receipt_ready : Bool,
) -> Unit {
  let proof_path = @pathx.join(
    book_root,
    eb_production_proof_receipt_relative_path(),
  )
  @fsx.make_directory(
    @pathx.dirname(proof_path).to_owned(),
    recursive=true,
    exists_ok=true,
  )
  let run_receipt_relative = if run_id == "" {
    ""
  } else {
    eb_moonclaw_run_receipt_relative_path(run_id)
  }
  let proof : Json = {
    "kind": "eb-production-proof",
    "book_id": book_id,
    "ok": false,
    "status": "moonclaw_confirmed_run_in_progress",
    "proof_level": "in-progress",
    "run_id": run_id,
    "import_step": import_step,
    "run_step": run_step,
    "timeout_ms": timeout_ms,
    "receipt_path": eb_production_proof_receipt_relative_path(),
    "moonclaw_import_receipt_path": eb_moonclaw_import_receipt_relative_path(),
    "moonclaw_import_receipt_recovered": import_receipt_recovered,
    "moonclaw_import_recovery_source": json_string(
      import_receipt,
      "recovery_source",
      default="",
    ),
    "moonclaw_retry_import_receipt_path": eb_moonclaw_retry_import_receipt_relative_path(),
    "moonclaw_retry_import_receipt_ready": retry_import_receipt_ready,
    "moonclaw_run_receipt_path": run_receipt_relative,
    "reconciliation_receipt_path": if run_id == "" {
      ""
    } else {
      eb_reconciliation_receipt_relative_path(run_id)
    },
    "import_receipt": import_receipt,
    "retry_import_receipt": retry_import_receipt,
    "run_health": eb_durable_run_health(root, book_root, book_id),
    "failed_checks": json_from_string_array([
      "MoonClaw confirmed run still in progress", "MoonClaw result is from a live imported run",
    ]),
    "recorded_at": @async.now().to_string(),
  }
  @fsx.write_to_file(proof_path, proof.stringify(indent=2) + "\n", create=0o644)
}

///|
fn eb_moonclaw_run_receipt_orphaned_after_timeout(receipt : Json) -> Bool {
  json_string(receipt, "kind", default="") == "moonclaw-confirmed-run-receipt" &&
  json_bool(receipt, "timed_out", default=false) &&
  (
    json_string(receipt, "status", default="") == "timed_out" ||
    !json_bool(receipt, "ok", default=true)
  ) &&
  json_string(json_object_field_or_empty(receipt, "meta"), "status", default="") ==
  "Running"
}

///|
fn eb_moonclaw_import_receipt_has_run(receipt : Json) -> Bool {
  json_string(receipt, "kind", default="") == "moonclaw-proposal-import-receipt" &&
  json_string(receipt, "run_id", default="").trim().to_owned() != ""
}

///|
async fn eb_moonclaw_recovered_import_from_health(
  book_root : String,
  book_id : String,
  health : Json,
  source : String,
) -> Json {
  let run_id = json_string(health, "moonclaw_import_run_id", default="")
    .trim()
    .to_owned()
  if run_id == "" ||
    !@fs.exists(
      @pathx.join(book_root, eb_moonclaw_run_receipt_relative_path(run_id)),
    ) {
    return Json::object({})
  }
  let proposal_id = json_string(
    health,
    "moonclaw_import_proposal_id",
    default="",
  )
  let home = json_string(health, "moonclaw_confirmed_run_home", default="")
  let status = json_string(health, "moonclaw_import_status", default="")
  {
    "kind": "moonclaw-proposal-import-receipt",
    "book_id": book_id,
    "packet_id": @desk.stable_id("eb-watch-packet", book_id),
    "ok": proposal_id != "",
    "status": if proposal_id != "" {
      "recovered_confirmed_run"
    } else {
      "recovered_run_without_import_receipt"
    },
    "proposal_id": proposal_id,
    "run_id": run_id,
    "confirmed": true,
    "inline": false,
    "timed_out": false,
    "timeout_ms": 0,
    "exit_code": if proposal_id != "" {
      0
    } else {
      -1
    },
    "moonclaw_root": "",
    "home": home,
    "cwd": book_root,
    "packet_path": eb_moonclaw_proposal_packet_relative_path(),
    "command": "",
    "stdout": "",
    "stderr": json_string(health, "moonclaw_import_stderr", default=""),
    "import_result": {
      "status": status,
      "proposal_id": proposal_id,
      "run_id": run_id,
    },
    "recovered": true,
    "recovery_source": source,
    "recorded_at": json_string(health, "recorded_at", default=""),
  }
}

///|
async fn eb_latest_moonclaw_run_receipt(
  book_root : String,
  book_id : String,
) -> Json {
  let root = @pathx.join(book_root, "raw/analysis-runs")
  let mut latest : Json = Json::object({})
  for name in read_directory_names(root, include_hidden=false) {
    if !name.has_suffix("-moonclaw-run.json") {
      continue
    }
    let receipt = read_json_file_or_object(@pathx.join(root, name))
    if json_string(receipt, "kind", default="") ==
      "moonclaw-confirmed-run-receipt" &&
      json_string(receipt, "book_id", default="") == book_id &&
      json_string(receipt, "run_id", default="") != "" {
      latest = receipt
    }
  }
  latest
}

///|
async fn eb_recovered_moonclaw_import_receipt(
  book_root : String,
  book_id : String,
  canonical_receipt : Json,
  production_proof_receipt : Json,
) -> Json {
  if eb_moonclaw_import_receipt_has_run(canonical_receipt) {
    return canonical_receipt
  }
  let standing_health = json_object_field_or_empty(
    json_object_field_or_empty(production_proof_receipt, "standing_goal_sync"),
    "run_health",
  )
  let recovered_from_standing = eb_moonclaw_recovered_import_from_health(
    book_root, book_id, standing_health, "eb-production-proof.standing_goal_sync.run_health",
  )
  if eb_moonclaw_import_receipt_has_run(recovered_from_standing) {
    return recovered_from_standing
  }
  let proof_health = json_object_field_or_empty(
    production_proof_receipt, "run_health",
  )
  let recovered_from_proof = eb_moonclaw_recovered_import_from_health(
    book_root, book_id, proof_health, "eb-production-proof.run_health",
  )
  if eb_moonclaw_import_receipt_has_run(recovered_from_proof) {
    return recovered_from_proof
  }
  let run_receipt = eb_latest_moonclaw_run_receipt(book_root, book_id)
  let run_id = json_string(run_receipt, "run_id", default="").trim().to_owned()
  if run_id == "" {
    return canonical_receipt
  }
  {
    "kind": "moonclaw-proposal-import-receipt",
    "book_id": book_id,
    "packet_id": @desk.stable_id("eb-watch-packet", book_id),
    "ok": false,
    "status": "recovered_run_without_import_receipt",
    "proposal_id": "",
    "run_id": run_id,
    "confirmed": true,
    "inline": false,
    "timed_out": false,
    "timeout_ms": 0,
    "exit_code": -1,
    "moonclaw_root": json_string(run_receipt, "moonclaw_root", default=""),
    "home": json_string(run_receipt, "home", default=""),
    "cwd": json_string(run_receipt, "cwd", default=book_root),
    "packet_path": eb_moonclaw_proposal_packet_relative_path(),
    "command": "",
    "stdout": "",
    "stderr": "",
    "import_result": {},
    "recovered": true,
    "recovery_source": "raw/analysis-runs/*-moonclaw-run.json",
    "recorded_at": json_string(run_receipt, "recorded_at", default=""),
  }
}

///|
fn eb_production_proof_receipt_relative_path() -> String {
  "raw/analysis-runs/eb-production-proof.json"
}

///|
fn eb_moontown_execution_receipt_relative_path() -> String {
  "raw/analysis-runs/moontown-task-execution.json"
}

///|
fn default_moonclaw_root() -> String {
  @pathx.normalize("../moonclaw")
}

///|
fn eb_moonclaw_profile_json() -> Json {
  {
    "jobs": {
      "profiles": {
        "eb_pdf_evidence_watch": {
          "family": "eb_pdf_evidence_watch",
          "role": "eb_pdf_evidence_worker",
          "priority": 120,
          "tags": json_from_string_array([
            "research", "pdf-evidence", "exchangeable-bond", "official-source",
          ]),
          "match": {
            "any": json_from_string_array([
              "exchangeable bond", "EB", "可交换债", "pdf-evidence", "standing-watch",
            ]),
          },
          "steps": json_from_json_array([
            {
              "id": "discover_official_sources",
              "title": "Discover official EB sources",
              "kind": "job.analysis",
              "prompt_template": "Use the packet source websites, official-domain policy, and current target metadata to discover the exchangeable-bond official source universe for the configured scope before analysis. First run `python3 raw/bootstrap/eb_discover_pdf_candidates.py --book-root . --output outputs/official-pdf-candidates.json` from the book root or `python3 ../../raw/bootstrap/eb_discover_pdf_candidates.py --book-root ../.. --run-root . --output outputs/official-pdf-candidates.json` from a moonclaw-jobs/<run> workspace. If the helper writes status=official_candidates_ready with fact_based_universe_evidence=true and discovery_completeness_ok=true, proceed. If the helper writes ai_discovery_required=true or status=failed for an active-universe run, use web_search/web_fetch on official domains only to discover the current EB universe, then rewrite outputs/official-pdf-candidates.json with URL/title/platform/disclosure date/relevance/source_kind, instrument_count, observed_instrument_codes, source_kind_counts, fact_based_universe_evidence=true, universe_evidence_basis, universe_evidence_sources, ai_discovery_required=false, and discovery_completeness_ok=true. Count fields are review hints only; do not use a minimum, maximum, prompt-provided list, or hardcoded current instrument list as proof. This is an intermediate step: set notify_town=false and standing_goal_decision=continue unless discovery terminally fails. If web tools or official pages cannot be reached, write outputs/official-pdf-candidates.json with status=failed, failure_reason, checked_domains, and standing_goal_decision=failed instead of waiting for operator input. Do not convert partial discovery or inaccessible dynamic pages into a runtime needs_input verdict; a failed candidates artifact is the terminal output for this step.",
              "metadata": eb_moonclaw_analysis_step_metadata_json(),
            },
            {
              "id": "extract_and_screen",
              "title": "Download, extract, and source-screen",
              "kind": "job.analysis",
              "prompt_template": "Read outputs/official-pdf-candidates.json from the previous step, download official candidate PDFs into raw/pdfs, official HTML/source pages into raw/html, and run `python3 raw/bootstrap/eb_extract_pdf_text.py --book-root . --screen outputs/official-source-screen.json` from the book root or `python3 ../../raw/bootstrap/eb_extract_pdf_text.py --book-root ../.. --run-root . --screen outputs/official-source-screen.json` from a moonclaw-jobs/<run> workspace. The helper is current-run candidate driven: it refuses to reuse stale local PDFs/source files when the current candidates artifact has no official URL records, extracts text into raw/extracted, and writes an eb-official-source-screen artifact. Do not ask for input and do not stop at prose. Do not convert partial extraction/source-screen coverage into a runtime needs_input verdict; encode download/extraction failures in outputs/official-source-screen.json and finish with standing_goal_decision=failed when the helper fails. A successful screen must set kind=eb-official-source-screen, status=official_source_screened, live_fetch_performed=true, checked_sources_count>0, downloaded_source_count>0, extracted_source_count>0, source_records with official URLs and text_path values, and notify_town=false because Bookkeeper has not accepted knowledge yet.",
              "metadata": eb_moonclaw_analysis_step_metadata_json(),
            },
            {
              "id": "analyze_lifecycle",
              "title": "Analyze EB lifecycle and compliance",
              "kind": "job.analysis",
              "prompt_template": "Use raw/extracted text plus outputs/official-source-screen.json. Apply the book method and EB skill to the six lifecycle stages. Cross-check issuer and underlying-company disclosures, mark missing expected disclosures as 未检索到 with reasons, and write outputs/eb-lifecycle-analysis.json. Also write outputs/eb-indicator-extraction.json as a structured AI extractor artifact with kind=eb-indicator-ai-extraction, status=extracted, extractor=moonclaw-ai, and instruments[].facts for the Sheet 2 metric keys. Every non-missing AI fact must include value, source_url or source_path/text_path, and snippet copied from the official extracted text; uncited facts must be omitted or marked 未检索到. Do not wait for operator input. Do not convert incomplete lifecycle coverage into a runtime needs_input verdict; encode gaps as 未检索到/待验证 in the artifact and continue. If official extracted text exists and the analysis artifact is written, finish with result_decision=accepted, requires_review=false, notify_town=true, standing_goal_decision=update, delta_score=100, new_source_count>0, checked_sources_count>0, accepted_facts_count>0, wiki_pages_changed_count=1, and book_changed=yes. The final response must include those machine-readable marker lines exactly once. If no extracted text is available, write status=failed and standing_goal_decision=failed.",
              "metadata": eb_moonclaw_analysis_step_metadata_json(),
            },
            {
              "id": "package_result",
              "title": "Package accepted EB output",
              "kind": "job.analysis",
              "prompt_template": "If Bookkeeper accepts new source-backed knowledge, run `python3 raw/bootstrap/eb_package_workbook.py --book-root . --run-root .` from the book root or `python3 ../../raw/bootstrap/eb_package_workbook.py --book-root ../.. --run-root .` from a moonclaw-jobs/<run> workspace. The helper updates durable source/candidate artifacts, consumes source-backed structured AI facts from outputs/eb-indicator-extraction.json when deterministic text extraction leaves a Sheet 2 field blank, writes result.json/report.md, and produces the required EB追踪_[债券代码]_[债券简称]_[YYYYMMDD].xlsx workbook plus sibling .xlsx.manifest.json and .xlsx.validation.json files. Both sidecars must contain xlsx_sha256 for the workbook bytes; the validation file must set sample_run=false, prove the exact EB sheet/header contract, include workbook_data_proof with positive announcement and indicator data-row counts plus source-backed row counts, ensure the XLSX itself contains rows beyond the header in both required sheets and OOXML hyperlink relationships for official original-link cells, include appendix_notes with search keywords/retrieval date/official source list, include quality_proof for official links, clickable source URLs, summaries within 200 characters, emphasized key data, cross-verification, timing, data reconciliation, missing-disclosure marking, structured AI fact source backing, and workbook formatting, and include lifecycle_stage_proof for all six EB stages. Include the required standing_goal_decision marker in the final summary.",
              "metadata": eb_moonclaw_analysis_step_metadata_json(),
            },
          ]),
          "metadata": {
            "output_contract": "moondesk.exchangeable_bond_tracking.xlsx.v1",
            "role_runtime": eb_moonclaw_executor_role_runtime_json(),
            "runtime_mode": "executor",
            "tool_access": "full",
            "allow_execution_tools": true,
            "allow_workspace_write": true,
            "required_runtime_tools": json_from_string_array([
              "web_search", "web_fetch",
            ]),
            "fail_on_missing_required_tools": true,
            "requires_standing_watch_marker": true,
            "disable_waiting_for_input": true,
            "best_effort_on_missing_input": false,
            "step_metadata": eb_moonclaw_analysis_step_metadata_json(),
            "official_domains": json_from_string_array(eb_official_domains()),
          },
        },
      },
    },
  }
}

///|
fn eb_moonclaw_analysis_step_metadata_json() -> Json {
  {
    "enable_tools": true,
    "web_search": true,
    "timeout_ms": eb_moonclaw_analysis_step_timeout_ms(),
    "max_total_tokens": eb_moonclaw_analysis_step_max_total_tokens(),
    "retry_max_attempts": 1,
    "retry_backoff_ms": 0,
    "role_runtime": eb_moonclaw_executor_role_runtime_json(),
    "runtime_mode": "executor",
    "tool_access": "full",
    "allow_execution_tools": true,
    "allow_workspace_write": true,
    "required_runtime_tools": json_from_string_array(["web_search", "web_fetch"]),
    "fail_on_missing_required_tools": true,
    "disable_waiting_for_input": true,
    "best_effort_on_missing_input": false,
    "tool_contract": {
      "web_fetch": true,
      "web_search": true,
      "list_files": true,
      "read_files": true,
      "search_files": true,
      "file_write": true,
    },
  }
}

///|
fn eb_moonclaw_analysis_step_timeout_ms() -> Int {
  300000
}

///|
fn eb_moonclaw_analysis_step_max_total_tokens() -> Int {
  48000
}

///|
fn eb_moonclaw_executor_role_runtime_json() -> Json {
  {
    "role_id": "eb_pdf_evidence_worker",
    "planning_layer": "execution",
    "runtime_mode": "executor",
    "tool_access": "full",
    "memory_scope": "workspace",
    "allow_delegate": false,
    "allow_workspace_write": true,
    "allow_execution_tools": true,
    "output_contract": "moondesk.exchangeable_bond_tracking.xlsx.v1",
  }
}

///|
fn eb_moonclaw_proposal_packet_json(
  book_root : String,
  book_id : String,
  topic : String,
  websites : Array[String],
  target_scope? : String = "",
  target_fields? : Json = eb_target_fields_from_payload(Json::object({})),
  target_bonds? : Array[Json] = [],
) -> Json {
  let target_scope = infer_eb_target_scope(
    target_scope, target_fields, target_bonds,
  )
  let target_bonds = eb_effective_target_bonds(
    target_scope, target_fields, target_bonds,
  )
  let absolute_book_root = host_absolute_path(book_root)
  let request_path = @pathx.join(
    absolute_book_root, "raw/inbox/eb-tracking-request.json",
  )
  {
    "packet_id": @desk.stable_id("eb-watch-packet", book_id),
    "title": "Run EB official-source evidence watch for \{topic}",
    "summary": "Bounded MoonClaw packet for official-source exchangeable-bond discovery, extraction, lifecycle analysis, Bookkeeper review, and XLSX packaging.",
    "request_text": eb_moonclaw_proposal_request_text(book_id, topic),
    "profile": "eb_pdf_evidence_watch",
    "output_contract": "moondesk.exchangeable_bond_tracking.xlsx.v1",
    "source_path": request_path,
    "context_pages": json_from_string_array([
      "raw/inbox/eb-tracking-request.json", "raw/inbox/eb-standing-watch-dispatch.json",
      "raw/bootstrap/EB_WATCH_CONTRACT.md", "wiki/methods/my-analysis-method.md",
      "schemas/eb-tracking-output.schema.md", "raw/bootstrap/eb_discover_pdf_candidates.py",
      "raw/bootstrap/eb_extract_pdf_text.py", "raw/bootstrap/eb_package_workbook.py",
      "outputs/eb-indicator-extraction.json",
    ]),
    "skill_paths": json_from_string_array([
      "skills/pdf-watch/SKILL.md", "skills/pdf-analysis/SKILL.md", "skills/eb-credit-compliance/SKILL.md",
    ]),
    "notes": json_from_string_array([
      "Official domains only: do not rely on third-party reposts.", "Download/extract PDFs before analysis when a PDF is available.",
      "No durable wiki or workbook update may be counted as progress until Bookkeeper accepts source-backed knowledge.",
      "For current-run discovery, run `python3 raw/bootstrap/eb_discover_pdf_candidates.py --book-root . --output outputs/official-pdf-candidates.json` from the book root, or `python3 ../../raw/bootstrap/eb_discover_pdf_candidates.py --book-root ../.. --run-root . --output outputs/official-pdf-candidates.json` from a moonclaw run workspace; active-universe discovery must be dynamic, not a baked current EB list.",
      "For active-universe discovery, the candidates artifact must prove fact-based source coverage before analysis: instrument_count, observed_instrument_codes, source_kind_counts, fact_based_universe_evidence=true, universe_evidence_basis, universe_evidence_sources, ai_discovery_required=false, and discovery_completeness_ok=true. Counts are review hints only, never pass/fail thresholds.",
      "For extraction, run `python3 raw/bootstrap/eb_extract_pdf_text.py --book-root . --screen outputs/official-source-screen.json` from the book root, or `python3 ../../raw/bootstrap/eb_extract_pdf_text.py --book-root ../.. --run-root . --screen outputs/official-source-screen.json` from a moonclaw run workspace.",
      "Extraction is current-run candidate driven: if outputs/official-pdf-candidates.json has no official URL records, the helper writes a failed source-screen artifact and refuses to reuse stale local PDFs or source pages.",
      "For AI-assisted extraction, write `outputs/eb-indicator-extraction.json` with kind=eb-indicator-ai-extraction, status=extracted, extractor=moonclaw-ai, instruments[].bond_code/bond_short_name, and facts keyed by the Sheet 2 metric names or canonical metric ids. Every non-missing fact must include value, source_url or source_path/text_path, and a snippet copied from official extracted text.",
      "For accepted packaging, run `python3 raw/bootstrap/eb_package_workbook.py --book-root . --run-root .` from the book root, or `python3 ../../raw/bootstrap/eb_package_workbook.py --book-root ../.. --run-root .` from a moonclaw run workspace.",
      "The packager uses deterministic official-text extraction first, then source-backed structured AI facts as fallback; uncited AI prose must not be counted as a workbook metric.",
      "For production reconciliation, outputs/official-source-screen.json must set live_fetch_performed=true, include at least one official-domain URL, and report downloaded_source_count plus extracted_source_count above zero.",
      "Every accepted workbook manifest must include xlsx_sha256 matching the workbook bytes.",
      "Every accepted workbook validation artifact must include xlsx_sha256, sample_run=false, exact sheet/header proof for 公告追踪主表 and 关键指标监控表, workbook_data_proof with positive source-backed row counts, actual XLSX rows beyond the header in both sheets, actual OOXML hyperlinks for Sheet 1 official original-link cells, appendix_notes, quality_proof, and lifecycle_stage_proof.",
      "appendix_notes must prove search keywords, retrieval date, and official information-source list.",
      "quality_proof must prove official-link-only rows, clickable official source links, summaries within 200 characters, key data emphasis, issuer/underlying cross-verification, disclosure-timing checks, Sheet 1 / Sheet 2 data reconciliation, missing-disclosure marking, and readable Excel formatting.",
      "lifecycle_stage_proof must prove all six EB lifecycle stages were reviewed or expected disclosures were marked 未检索到 with reasons.",
      "Partial discovery/extraction is not operator input: write failed artifacts with standing_goal_decision=failed instead of returning needs_input.",
      "Incomplete official evidence is not operator input: lifecycle gaps must be encoded as 未检索到/待验证, then the analysis should finish with standing_goal_decision=update when official extracted text and an accepted artifact exist.",
      "Final summary must include standing_goal_decision, delta_score, new_source_count, checked_sources_count, accepted_facts_count, wiki_pages_changed_count, and book_changed.",
    ]),
    "tags": json_from_string_array([
      "research", "standing-watch", "pdf-evidence", "exchangeable-bond", book_id,
    ]),
    "metadata": {
      "producer": "moondesk",
      "target_book_id": book_id,
      "book_root": absolute_book_root,
      "book_type": "research-book",
      "pattern_id": "exchangeable-bond-evidence-watch",
      "watch_websites": json_from_string_array(websites),
      "target_scope": target_scope,
      "active_universe_default": target_scope == "active_universe",
      "target_fields": target_fields,
      "target_bonds": Json::array(target_bonds),
      "target_bond_count": target_bonds.length(),
      "multi_bond_mode": target_bonds.length() > 1,
      "discovery_mode": if target_scope == "active_universe" {
        "dynamic_official_source_search"
      } else {
        "configured_target_source_adapter"
      },
      "official_source_seeds": Json::array(
        eb_official_source_seed_candidates(target_scope, target_bonds),
      ),
      "official_pdf_seeds": Json::array(
        eb_official_pdf_seed_candidates(target_scope, target_bonds),
      ),
      "source_adapter": {
        "kind": if target_scope == "active_universe" {
          "dynamic-official-source-search"
        } else {
          "official-source-seeds"
        },
        "path": if target_scope == "active_universe" {
          "raw/bootstrap/eb_discover_pdf_candidates.py"
        } else {
          "raw/inbox/eb-tracking-request.json#official_source_seeds"
        },
        "current_run_materializer": "raw/bootstrap/eb_discover_pdf_candidates.py",
        "seed_count": eb_official_source_seed_candidates(
          target_scope, target_bonds,
        ).length(),
      },
      "expected_output_path": "book/outputs/",
      "expected_output_filename": "EB追踪_[债券代码]_[债券简称]_[YYYYMMDD].xlsx",
      "standing_watch_dispatch_path": "raw/inbox/eb-standing-watch-dispatch.json",
      "execution_request_path": "raw/inbox/eb-tracking-request.json",
      "watch_contract_path": "raw/bootstrap/EB_WATCH_CONTRACT.md",
      "moonclaw_profile": "eb_pdf_evidence_watch",
      "import_hint": "moon run cmd/main -- proposal import \{eb_moonclaw_proposal_packet_relative_path()} --confirm --cwd \{absolute_book_root}",
      "disable_waiting_for_input": true,
      "best_effort_on_missing_input": false,
      "profile_metadata": {
        "role_runtime": eb_moonclaw_executor_role_runtime_json(),
        "runtime_mode": "executor",
        "tool_access": "full",
        "allow_execution_tools": true,
        "allow_workspace_write": true,
        "required_runtime_tools": json_from_string_array([
          "web_search", "web_fetch",
        ]),
        "fail_on_missing_required_tools": true,
        "disable_waiting_for_input": true,
        "best_effort_on_missing_input": false,
      },
      "step_metadata": eb_moonclaw_analysis_step_metadata_json(),
    },
  }
}

///|
fn eb_moonclaw_proposal_request_text(
  book_id : String,
  topic : String,
) -> String {
  [
    "Run the Exchangeable Bond PDF evidence watch for MoonBook `\{book_id}`.",
    "",
    "Topic: \{topic}",
    "",
    "Use the book-local files as the source of truth:",
    "- `raw/inbox/eb-tracking-request.json` for target bond fields, official websites, discovery mode, lifecycle stages, output headers, and quality rules.",
    "- `raw/inbox/eb-standing-watch-dispatch.json` for Moontown/MoonClaw/Bookkeeper ownership and required output paths.",
    "- `raw/bootstrap/EB_WATCH_CONTRACT.md` for the final standing-watch marker.",
    "- `raw/bootstrap/eb_discover_pdf_candidates.py` for current-run official-source discovery and completeness proof.",
    "- `raw/bootstrap/eb_extract_pdf_text.py` for deterministic PDF/HTML source extraction.",
    "- `raw/bootstrap/eb_package_workbook.py` for deterministic accepted workbook and sidecar packaging with source-backed AI fact fallback.",
    "- `wiki/methods/my-analysis-method.md` and `skills/eb-credit-compliance/SKILL.md` for the analysis method.",
    "",
    "Required work:",
    "1. Search configured official websites and, when deterministic crawling cannot prove coverage, use MoonClaw web_search/web_fetch on official domains for the complete relevant EB source universe in source priority order: SSE/SZSE, CNInfo, ChinaBond, SHCH, CSRC or official review sites.",
    "2. Write `outputs/official-pdf-candidates.json` with all observed official candidates, not a sample; active-universe output must include `instrument_count`, `observed_instrument_codes`, `source_kind_counts`, `fact_based_universe_evidence: true`, `universe_evidence_basis`, `universe_evidence_sources`, `ai_discovery_required: false`, and `discovery_completeness_ok: true` before analysis. Do not rely on prompt-provided or hardcoded current EB seeds, and do not use minimum/maximum counts as proof.",
    "3. Download official PDFs into `raw/pdfs/`, official HTML/source pages into `raw/html/`, then run `python3 raw/bootstrap/eb_extract_pdf_text.py --book-root . --screen outputs/official-source-screen.json` from the book root or the documented `--run-root` variant to extract full text into `raw/extracted/`.",
    "4. Source-screen every candidate by official domain, URL, title, date, publisher, source_kind, and sha256 when available.",
    "5. Write `outputs/official-source-screen.json` with `live_fetch_performed: true`, `checked_official_urls`, `downloaded_source_count`, and `extracted_source_count`; Moondesk will reject production reconciliation without these fields.",
    "6. Analyze all six EB lifecycle stages: issuance/listing, periodic reports, interim events, exchange-window management, redemption/sell-back, and repayment/exit.",
    "7. Write `outputs/eb-indicator-extraction.json` as the AI extractor output. Use `kind: eb-indicator-ai-extraction`, `status: extracted`, `extractor: moonclaw-ai`, and one `instruments[]` entry per bond. Each non-missing Sheet 2 fact must include `value`, `source_url` or `source_path`/`text_path`, and a `snippet` copied from official extracted text. Do not put model-only guesses into this artifact.",
    "8. For every lifecycle node, record announcement title, disclosure date, platform URL, summary, key data, investor-action flag, and notes; mark expected-but-missing nodes as `未检索到` with reason.",
    "9. Apply quality checks: cross-verify issuer and underlying-company disclosures, validate disclosure timing, reconcile cumulative exchange shares, and reject non-official URLs.",
    "10. Compare against the existing wiki/workbook baseline.",
    "11. Queue Bookkeeper review for new or changed knowledge.",
    "12. Write the accepted EB workbook only when source-backed knowledge is accepted; use `raw/bootstrap/eb_package_workbook.py` so the workbook, result, manifest, validation, source-screen, PDF-candidate, and structured AI extraction artifacts are bound together.",
    "13. Write the sibling `.xlsx.manifest.json` with `xlsx_sha256` matching the workbook bytes.",
    "14. Write the sibling `.xlsx.validation.json` with matching `xlsx_sha256`, `sample_run: false`, exact sheet/header proof for `公告追踪主表` and `关键指标监控表`, `workbook_data_proof` with positive source-backed announcement/indicator row counts, actual XLSX rows beyond the header in both sheets, actual OOXML hyperlinks for Sheet 1 official original-link cells, `appendix_notes`, `quality_proof`, and `lifecycle_stage_proof`.",
    "15. In `appendix_notes`, prove search keywords, retrieval date, and official information-source list.",
    "16. In `quality_proof`, prove official-link-only rows, clickable official source links, summaries within 200 characters, key data emphasis, issuer/underlying cross-verification, disclosure-timing checks, Sheet 1 / Sheet 2 data reconciliation, missing-disclosure marking, structured AI fact source backing, and readable Excel formatting.",
    "17. In `lifecycle_stage_proof`, prove all six EB lifecycle stages were reviewed or explicitly marked `未检索到` with reasons.",
    "18. End with the required standing_goal_decision marker.",
  ].join("\n")
}

///|
fn eb_output_template_relative_path() -> String {
  "book/outputs/EB追踪_[债券代码]_[债券简称]_[YYYYMMDD].xlsx"
}
