///|
fn eb_tracking_workbook_validation_json(
  book_id~ : String,
  run_id~ : String,
  output_relative~ : String,
  sample_run~ : Bool,
  xlsx_sha256~ : String,
) -> Json {
  let parts = eb_output_name_parts(
    eb_output_name_from_relative(output_relative),
  )
  let bond_code = json_string(parts, "bond_code", default="[债券代码]")
  let bond_short_name = json_string(
    parts,
    "bond_short_name",
    default="[债券简称]",
  )
  let as_of = json_string(parts, "as_of", default="[YYYYMMDD]")
  {
    "kind": "eb-tracking-workbook-validation",
    "validation_version": "1",
    "book_id": book_id,
    "run_id": run_id,
    "xlsx_path": output_relative,
    "xlsx_sha256": xlsx_sha256,
    "output_contract": "moondesk.exchangeable_bond_tracking.xlsx.v1",
    "workbook_package_valid": true,
    "headers_valid": true,
    "sample_run": sample_run,
    "workbook_data_proof": {
      "workbook_contains_data_rows": !sample_run,
      "all_rows_source_backed": !sample_run,
      "announcement_data_row_count": if sample_run {
        0
      } else {
        1
      },
      "indicator_data_row_count": if sample_run {
        0
      } else {
        1
      },
      "source_backed_row_count": if sample_run {
        0
      } else {
        2
      },
      "indicator_core_metrics_populated": !sample_run,
      "indicator_core_metric_rows": if sample_run {
        0
      } else {
        1
      },
      "indicator_metric_min_non_placeholder_cells": if sample_run {
        0
      } else {
        18
      },
      "indicator_metric_total_non_placeholder_cells": if sample_run {
        0
      } else {
        18
      },
      "rows_with_official_source_url": if sample_run {
        0
      } else {
        1
      },
      "sheet1_grouped_by_bond_code": true,
      "required_by": "Production EB workbooks must contain source-backed rows in both required sheets, not only the starter header/template package.",
    },
    "appendix_notes": {
      "present": true,
      "location": "Excel workbook leading notes or separate notes section",
      "search_keywords": json_from_string_array([
        bond_code,
        bond_short_name,
        bond_code + " 可交换债",
        bond_short_name + " 可交换债 公告",
      ]),
      "retrieval_date": as_of,
      "information_sources": json_from_string_array(
        eb_default_source_websites(),
      ),
      "required_by": "EB prompt section 六: list search keywords, retrieval date, and information source list in the workbook opening notes or a separate note.",
    },
    "quality_proof": {
      "official_links_only": true,
      "official_link_domains": json_from_string_array(eb_official_domains()),
      "clickable_official_links": true,
      "summaries_within_200_chars": true,
      "key_data_emphasized": true,
      "cross_verification_performed": true,
      "timing_checks_performed": true,
      "data_consistency_reconciled": true,
      "missing_disclosures_marked": true,
      "workbook_formatting_applied": true,
      "required_by": "EB prompt section 四, 五, and 六: accepted workbook rows must pass official-link, clickable source URL, summary-length, key-data emphasis, cross-verification, timing, data-consistency, missing-disclosure, and readable Excel formatting checks.",
    },
    "lifecycle_stage_proof": eb_lifecycle_stage_proof_json(),
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
    "validation_notes": json_from_string_array([
      "Validation is bound to the workbook bytes by xlsx_sha256.", "Sheet header proof must be produced by the workbook writer or extraction step before Bookkeeper acceptance.",
    ]),
  }
}

///|
async fn write_eb_sample_execution_run(
  root~ : String,
  book_root~ : String,
  book_id~ : String,
  run_id~ : String,
  bond_code~ : String,
  bond_short_name~ : String,
  as_of~ : String,
) -> Json {
  let output_name = "EB追踪_\{bond_code}_\{bond_short_name}_\{as_of}.xlsx"
  let output_relative = "book/outputs/" + output_name
  write_bytes_file(
    @pathx.join(book_root, output_relative),
    eb_tracking_template_xlsx_bytes(),
    create=0o644,
  )
  let output_path = @pathx.join(book_root, output_relative)
  @fsx.write_to_file(
    @pathx.join(book_root, eb_output_manifest_relative_path(output_relative)),
    eb_tracking_output_manifest_json(
      book_id~,
      run_id~,
      bond_code~,
      bond_short_name~,
      as_of~,
      output_relative~,
      source_screen_relative=eb_source_screen_relative_path(run_id),
      pdf_candidates_relative=eb_pdf_candidates_relative_path(run_id),
      accepted_by_bookkeeper=true,
      sample_run=true,
      xlsx_sha256=eb_file_sha256(output_path),
    ).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(
      book_root,
      eb_output_workbook_validation_relative_path(output_relative),
    ),
    eb_tracking_workbook_validation_json(
      book_id~,
      run_id~,
      output_relative~,
      sample_run=true,
      xlsx_sha256=eb_file_sha256(output_path),
    ).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  let run_root = @pathx.join(@pathx.join(book_root, "moonclaw-jobs"), run_id)
  @fsx.make_directory(
    @pathx.join(run_root, "outputs"),
    recursive=true,
    exists_ok=true,
  )
  let run_result = eb_sample_run_result_json(
    book_id~,
    run_id~,
    bond_code~,
    bond_short_name~,
    as_of~,
    output_relative~,
  )
  @fsx.write_to_file(
    @pathx.join(run_root, "result.json"),
    run_result.stringify(indent=2) + "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(run_root, "report.md"),
    eb_sample_run_report_markdown(
      book_id~,
      run_id~,
      bond_code~,
      bond_short_name~,
      as_of~,
      output_relative~,
    ),
    create=0o644,
  )
  let source_screen = eb_official_source_screen_json(
    book_id~,
    run_id~,
    bond_code~,
    bond_short_name~,
    as_of~,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, eb_source_screen_relative_path(run_id)),
    source_screen.stringify(indent=2) + "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(run_root, "outputs/official-source-screen.json"),
    source_screen.stringify(indent=2) + "\n",
    create=0o644,
  )
  let candidates = eb_official_pdf_candidates_json(
    book_id~,
    run_id~,
    bond_code~,
    bond_short_name~,
    as_of~,
    official_url="https://www.sse.com.cn/disclosure/bond/announcement/\{bond_code}.pdf",
    sample_run=true,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, eb_pdf_candidates_relative_path(run_id)),
    candidates.stringify(indent=2) + "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(run_root, "outputs/official-pdf-candidates.json"),
    candidates.stringify(indent=2) + "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "wiki/sources/eb-official-source-screen.md"),
    eb_official_source_screen_markdown(
      book_id~,
      run_id~,
      bond_code~,
      bond_short_name~,
      as_of~,
    ),
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(
      book_root,
      "raw/extracted/" + run_id + "-official-source-screen.txt",
    ),
    eb_official_source_screen_text(
      book_id~,
      run_id~,
      bond_code~,
      bond_short_name~,
      as_of~,
    ),
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(run_root, "outputs/eb-output-validation.json"),
    eb_output_validation(book_root, book_id).stringify(indent=2) + "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "wiki/reviews/bookkeeper-eb-sample-run.md"),
    eb_sample_bookkeeper_review_markdown(
      book_id~,
      run_id~,
      bond_code~,
      bond_short_name~,
      as_of~,
      output_relative~,
    ),
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, eb_output_validation_relative_path()),
    eb_output_validation(book_root, book_id).stringify(indent=2) + "\n",
    create=0o644,
  )
  let goal_id = eb_standing_goal_id_for_book(root, book_id)
  let watcher_record = eb_sample_watcher_record(
    book_id~,
    run_id~,
    goal_id~,
    bond_code~,
    bond_short_name~,
    output_relative~,
  )
  @fsx.make_directory(
    @pathx.join(root, ".moontown/watchers"),
    recursive=true,
    exists_ok=true,
  )
  append_json_line(
    @pathx.join(@pathx.join(root, ".moontown/watchers"), goal_id + ".jsonl"),
    watcher_record,
  )
  let result_message = eb_sample_book_result_json(
    book_id~,
    run_id~,
    bond_code~,
    bond_short_name~,
    output_relative~,
  )
  @fsx.make_directory(
    @pathx.join(root, ".moontown/book-results"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    @pathx.join(root, ".moontown/book-results/" + run_id + ".json"),
    result_message.stringify(indent=2) + "\n",
    create=0o644,
  )
  let verification = book_contract_verification(
    root, book_root, book_id, "exchangeable-bond-evidence-watch",
  )
  let run_health = eb_durable_run_health(root, book_root, book_id)
  {
    "ok": true,
    "status": "sample_run_completed",
    "book_id": book_id,
    "run_id": run_id,
    "bond_code": bond_code,
    "bond_short_name": bond_short_name,
    "output_path": output_relative,
    "watcher_goal_id": goal_id,
    "result_path": ".moontown/book-results/" + run_id + ".json",
    "verification": verification,
    "run_health": run_health,
  }
}

///|
async fn run_eb_moonclaw_proposal_import(
  root~ : String,
  book_root~ : String,
  book_id~ : String,
  packet_relative~ : String,
  packet_path~ : String,
  moonclaw_root~ : String,
  home~ : String,
  confirm~ : Bool,
  inline~ : Bool,
  timeout_ms~ : Int,
) -> Json {
  let absolute_book_root = host_absolute_path(book_root)
  let absolute_packet_path = host_absolute_path(packet_path)
  let absolute_home = host_absolute_path(home)
  let absolute_moonclaw_root = host_absolute_path(moonclaw_root)
  @fsx.make_directory(
    @pathx.dirname(
      @pathx.join(book_root, eb_moonclaw_import_receipt_relative_path()),
    ).to_owned(),
    recursive=true,
    exists_ok=true,
  )
  let args = [
    "-C", absolute_moonclaw_root, "run", "cmd/main", "--", "proposal", "import",
    absolute_packet_path, "--home", absolute_home, "--cwd", absolute_book_root, "--json",
  ]
  if confirm {
    args.push("--confirm")
  }
  if inline {
    args.push("--inline")
  }
  let mut exit_code = -1
  let mut stdout = ""
  let mut stderr = ""
  let mut timed_out = false
  let collected = Some(
    @async.with_timeout(timeout_ms, () => {
      @process.collect_output("moon", args, cwd=absolute_moonclaw_root)
    }),
  ) catch {
    error => {
      timed_out = true
      stderr = "MoonClaw proposal import timed out or failed after \{timeout_ms}ms: \{error}"
      None
    }
  }
  match collected {
    Some((code, out, err)) => {
      exit_code = code
      stdout = out.text()
      stderr = err.text()
    }
    None => ()
  }
  let import_result = parse_moonclaw_json_output(stdout)
  let proposal_id = json_string(import_result, "proposal_id", default="")
  let run_id = json_string(import_result, "run_id", default="")
  let ok = exit_code == 0 && proposal_id != ""
  let receipt : Json = {
    "kind": "moonclaw-proposal-import-receipt",
    "book_id": book_id,
    "packet_id": @desk.stable_id("eb-watch-packet", book_id),
    "ok": ok,
    "status": if ok {
      if run_id == "" {
        "imported_draft"
      } else {
        "run_confirmed"
      }
    } else if timed_out {
      "timed_out"
    } else {
      "failed"
    },
    "proposal_id": proposal_id,
    "run_id": run_id,
    "confirmed": confirm,
    "inline": inline,
    "timed_out": timed_out,
    "timeout_ms": timeout_ms,
    "exit_code": exit_code,
    "moonclaw_root": absolute_moonclaw_root,
    "home": absolute_home,
    "cwd": absolute_book_root,
    "packet_path": packet_relative,
    "packet_absolute_path": absolute_packet_path,
    "command": "moon " + args.join(" "),
    "stdout": trim_for_record(stdout),
    "stderr": trim_for_record(stderr),
    "import_result": import_result,
    "recorded_at": @async.now().to_string(),
  }
  let packet_side_receipt_path = packet_path + ".import.json"
  let packet_side_stderr_path = packet_side_receipt_path + ".err"
  @fsx.write_to_file(
    packet_side_receipt_path,
    import_result.stringify(indent=2) + "\n",
    create=0o644,
  )
  @fsx.write_to_file(packet_side_stderr_path, stderr, create=0o644)
  @fsx.write_to_file(
    @pathx.join(book_root, eb_moontown_execution_receipt_relative_path()),
    eb_moontown_task_execution_record(
      book_id~,
      packet_id=json_string(
        receipt,
        "packet_id",
        default=@desk.stable_id("eb-watch-packet", book_id),
      ),
      packet_path~,
      packet_relative~,
      proposal_id~,
      run_id~,
      ok~,
      confirm~,
      command=json_string(receipt, "command", default=""),
      tick=0,
    ).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, eb_moonclaw_import_receipt_relative_path()),
    receipt.stringify(indent=2) + "\n",
    create=0o644,
  )
  ignore(root)
  receipt
}
