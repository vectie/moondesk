///|
async test "eb recovered accepted output writes durable ledger without production proof" {
  let root = "/tmp/moondesk-eb-recovered-output-wbtest"
  let book_id = "research-eb-recovered-output-eb-watch"
  let run_id = "run-eb-recovered-output"
  let book_root = @pathx.join(@pathx.join(root, ".moontown/books"), book_id)
  let output_relative = "book/outputs/EB追踪_132018_G三峡EB1_20260602.xlsx"
  let target : Json = {
    "bond_full_name_or_short_name": "G三峡EB1",
    "bond_code": "132018",
    "issuer": "中国长江三峡集团有限公司",
    "underlying_listed_company": "长江电力",
    "exchange": "上交所",
  }
  @fs.rmdir(root, recursive=true) catch {
    _ => ()
  }
  ignore(create_pdf_watch_book_dirs(book_root))
  let goal = pdf_watch_standing_goal(
    book_id~,
    topic="EB recovered output",
    pattern_id="exchangeable-bond-evidence-watch",
    purpose="Validate recovered output acceptance without live MoonClaw proof.",
    cadence=30,
    source_policy="web-first",
    daemon_tick=0,
  )
  @fsx.make_directory(
    @pathx.join(root, ".moontown"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    town_standing_goals_path(root),
    Json::array([goal]).stringify(indent=2) + "\n",
    create=0o644,
  )
  ignore(
    write_pdf_watch_book_files(
      book_root~,
      book_id~,
      topic="EB recovered output",
      pattern_id="exchangeable-bond-evidence-watch",
      purpose="Validate recovered output acceptance without live MoonClaw proof.",
      book_json=pdf_watch_book_json(
        book_id~,
        topic="EB recovered output",
        pattern_id="exchangeable-bond-evidence-watch",
        purpose="Validate recovered output acceptance without live MoonClaw proof.",
        cadence=30,
        websites=eb_default_source_websites(),
        source_policy="web-first",
        method_path="wiki/methods/my-analysis-method.md",
        notify_on=["accepted_new_knowledge"],
        eb_target_bonds=[target],
      ),
      method_body=default_eb_analysis_method("EB recovered output"),
      websites=eb_default_source_websites(),
      eb_target_fields=target,
      eb_target_bonds=[target],
    ),
  )
  @fsx.write_to_file(
    town_moonbooks_path(root),
    Json::array([
      pdf_watch_catalog_entry(
        book_id~,
        topic="EB recovered output",
        pattern_id="exchangeable-bond-evidence-watch",
        purpose="Validate recovered output acceptance without live MoonClaw proof.",
        book_root~,
      ),
    ]).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  @fsx.make_directory(
    town_moondesk_requests_root(root),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    @pathx.join(town_moondesk_requests_root(root), book_id + ".json"),
    pdf_watch_handoff_record(
      book_id~,
      topic="EB recovered output",
      pattern_id="exchangeable-bond-evidence-watch",
      purpose="Validate recovered output acceptance without live MoonClaw proof.",
      book_root~,
      goal~,
    ).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  ignore(
    write_moontown_standing_goal_registration(
      root~,
      book_root~,
      book_id~,
      pattern_id="exchangeable-bond-evidence-watch",
      goal~,
    ),
  )
  ignore(
    write_moontown_book_template_publish(
      root~,
      book_root~,
      book_id~,
      topic="EB recovered output",
      pattern_id="exchangeable-bond-evidence-watch",
      purpose="Validate recovered output acceptance without live MoonClaw proof.",
      cadence=30,
      websites=eb_default_source_websites(),
      method_body=default_eb_analysis_method("EB recovered output"),
      skill_pack=default_skill_pack_for_pattern(
        "exchangeable-bond-evidence-watch",
      ),
      goal~,
    ),
  )
  write_eb_populated_workbook_fixture(
    @pathx.join(book_root, output_relative),
    bond_code="132018",
    bond_short_name="G三峡EB1",
  )
  let output_hash = eb_file_sha256(@pathx.join(book_root, output_relative))
  @fsx.write_to_file(
    @pathx.join(book_root, eb_output_manifest_relative_path(output_relative)),
    eb_tracking_output_manifest_json(
      book_id~,
      run_id~,
      bond_code="132018",
      bond_short_name="G三峡EB1",
      as_of="20260602",
      output_relative~,
      source_screen_relative=eb_source_screen_relative_path(run_id),
      pdf_candidates_relative=eb_pdf_candidates_relative_path(run_id),
      accepted_by_bookkeeper=true,
      sample_run=false,
      xlsx_sha256=output_hash,
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
      sample_run=false,
      xlsx_sha256=output_hash,
    ).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  @fsx.make_directory(
    @pathx.join(book_root, "raw/pdfs"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(
    @pathx.join(book_root, "raw/extracted"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "raw/pdfs/" + run_id + "-official-evidence.pdf"),
    "%PDF-1.4\n% recovered official EB evidence fixture\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "raw/extracted/" + run_id + "-official-evidence.txt"),
    "G三峡EB1 recovered official extracted text fixture\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, eb_source_screen_relative_path(run_id)),
    eb_live_official_source_screen_json(
      book_id~,
      run_id~,
      bond_code="132018",
      bond_short_name="G三峡EB1",
      as_of="20260602",
      official_url="https://www.sse.com.cn/disclosure/bond/announcement/132018.pdf",
    ).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, eb_pdf_candidates_relative_path(run_id)),
    eb_official_pdf_candidates_json(
      book_id~,
      run_id~,
      bond_code="132018",
      bond_short_name="G三峡EB1",
      as_of="20260602",
      official_url="https://www.sse.com.cn/disclosure/bond/announcement/132018.pdf",
      sample_run=false,
    ).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  let health_before = eb_durable_run_health(root, book_root, book_id)
  assert_false(json_bool(health_before, "durable_ready", default=true))
  assert_false(json_bool(health_before, "production_ready", default=true))
  assert_eq(json_string(health_before, "run_id", default=""), run_id)
  assert_eq(
    json_string(health_before, "output_path", default=""),
    output_relative,
  )
  assert_true(
    json_bool(health_before, "workbook_validation_ready", default=false),
  )
  assert_true(
    json_bool(health_before, "source_screen_production_ready", default=false),
  )
  assert_true(
    json_bool(health_before, "output_target_match_ready", default=false),
  )
  assert_false(
    @fs.exists(
      @pathx.join(book_root, "moonclaw-jobs/" + run_id + "/result.json"),
    ),
  )
  let recovered = accept_recovered_eb_output(
    root~,
    book_root~,
    book_id~,
    reason="test recovery",
  )
  assert_true(json_bool(recovered, "ok", default=false))
  assert_eq(
    json_string(recovered, "status", default=""),
    "accepted_recovered_output",
  )
  assert_true(
    @fs.exists(
      @pathx.join(
        book_root,
        eb_accepted_output_recovery_receipt_relative_path(run_id),
      ),
    ),
  )
  assert_true(
    @fs.exists(
      @pathx.join(book_root, "moonclaw-jobs/" + run_id + "/result.json"),
    ),
  )
  assert_true(
    @fs.exists(@pathx.join(root, ".moontown/book-results/" + run_id + ".json")),
  )
  assert_true(
    @fs.exists(
      @pathx.join(
        root,
        ".moontown/watchers/" + json_string(goal, "id", default="") + ".jsonl",
      ),
    ),
  )
  let run_result = read_json_file_or_object(
    @pathx.join(book_root, "moonclaw-jobs/" + run_id + "/result.json"),
  )
  assert_eq(
    json_string(run_result, "kind", default=""),
    "moonclaw-eb-recovered-accepted-output",
  )
  assert_eq(
    json_string(run_result, "recovery_mode", default=""),
    "accepted_output_recovery",
  )
  assert_false(eb_run_result_is_live_moonclaw_result(run_result))
  let health = json_object_field_or_empty(recovered, "run_health")
  assert_true(json_bool(health, "durable_ready", default=false))
  assert_false(json_bool(health, "production_ready", default=true))
  assert_false(json_bool(health, "real_moonclaw_result_ready", default=true))
  assert_true(json_bool(health, "workbook_data_proof_ready", default=false))
  assert_true(json_bool(health, "workbook_hyperlinks_ready", default=false))
  assert_true(
    json_bool(health, "source_screen_production_ready", default=false),
  )
  let production_checklist = json_array_items(health, "production_checklist")
  assert_true(eb_checklist_item_ok(production_checklist, "watcher_update"))
  assert_true(eb_checklist_item_ok(production_checklist, "book_result"))
  assert_true(eb_checklist_item_ok(production_checklist, "accepted_workbook"))
  assert_true(eb_checklist_item_ok(production_checklist, "output_validation"))
  assert_true(eb_checklist_item_ok(production_checklist, "not_sample"))
  assert_true(eb_checklist_item_ok(production_checklist, "output_target_match"))
  assert_true(
    eb_checklist_item_ok(production_checklist, "official_source_screen"),
  )
  assert_false(eb_checklist_item_ok(production_checklist, "moonclaw_run"))
  assert_false(eb_checklist_item_ok(production_checklist, "live_result"))
  assert_true(
    json_string_array_items(health, "production_failed_checks").contains(
      "MoonClaw result is from a live imported run",
    ),
  )
}

///|
async test "eb generated packager output reconciles into production health" {
  let root = "/tmp/moondesk-eb-packager-reconcile-wbtest"
  let book_id = "research-eb-packager-reconcile-eb-watch"
  let run_id = "run-eb-packager-reconcile"
  let book_root = @pathx.join(@pathx.join(root, ".moontown/books"), book_id)
  let home = @pathx.join(root, ".moonclaw")
  let run_workspace = @pathx.join(book_root, "moonclaw-jobs/" + run_id)
  let output_relative = "book/outputs/EB追踪_ACTIVEEB_可交换债全集_20260603.xlsx"
  let aggregate_output_relative = "book/outputs/EB追踪汇总_ACTIVEEB_可交换债全集_20260603.xlsx"
  @fs.rmdir(root, recursive=true) catch {
    _ => ()
  }
  ignore(create_pdf_watch_book_dirs(book_root))
  let goal = pdf_watch_standing_goal(
    book_id~,
    topic="EB generated packager reconcile",
    pattern_id="exchangeable-bond-evidence-watch",
    purpose="Validate generated packager output reconciliation.",
    cadence=30,
    source_policy="web-first",
    daemon_tick=0,
  )
  @fsx.make_directory(
    @pathx.join(root, ".moontown"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    town_standing_goals_path(root),
    Json::array([goal]).stringify(indent=2) + "\n",
    create=0o644,
  )
  ignore(
    write_pdf_watch_book_files(
      book_root~,
      book_id~,
      topic="EB generated packager reconcile",
      pattern_id="exchangeable-bond-evidence-watch",
      purpose="Validate generated packager output reconciliation.",
      book_json=pdf_watch_book_json(
        book_id~,
        topic="EB generated packager reconcile",
        pattern_id="exchangeable-bond-evidence-watch",
        purpose="Validate generated packager output reconciliation.",
        cadence=30,
        websites=eb_default_source_websites(),
        source_policy="web-first",
        method_path="wiki/methods/my-analysis-method.md",
        notify_on=["accepted_new_knowledge"],
        eb_target_scope="active_universe",
      ),
      method_body=default_eb_analysis_method("EB generated packager reconcile"),
      websites=eb_default_source_websites(),
      eb_target_scope="active_universe",
    ),
  )
  @fsx.write_to_file(
    town_moonbooks_path(root),
    Json::array([
      pdf_watch_catalog_entry(
        book_id~,
        topic="EB generated packager reconcile",
        pattern_id="exchangeable-bond-evidence-watch",
        purpose="Validate generated packager output reconciliation.",
        book_root~,
      ),
    ]).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  @fsx.make_directory(
    town_moondesk_requests_root(root),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    @pathx.join(town_moondesk_requests_root(root), book_id + ".json"),
    pdf_watch_handoff_record(
      book_id~,
      topic="EB generated packager reconcile",
      pattern_id="exchangeable-bond-evidence-watch",
      purpose="Validate generated packager output reconciliation.",
      book_root~,
      goal~,
    ).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  ignore(
    write_moontown_standing_goal_registration(
      root~,
      book_root~,
      book_id~,
      pattern_id="exchangeable-bond-evidence-watch",
      goal~,
    ),
  )
  ignore(
    write_moontown_book_template_publish(
      root~,
      book_root~,
      book_id~,
      topic="EB generated packager reconcile",
      pattern_id="exchangeable-bond-evidence-watch",
      purpose="Validate generated packager output reconciliation.",
      cadence=30,
      websites=eb_default_source_websites(),
      method_body=default_eb_analysis_method("EB generated packager reconcile"),
      skill_pack=default_skill_pack_for_pattern(
        "exchangeable-bond-evidence-watch",
      ),
      goal~,
    ),
  )
  let import_receipt : Json = {
    "kind": "moonclaw-proposal-import-receipt",
    "book_id": book_id,
    "ok": true,
    "status": "run_confirmed",
    "proposal_id": "proposal-eb-packager-reconcile",
    "run_id": run_id,
    "home": home,
    "exit_code": 0,
    "stderr": "tcc: error: invalid option -- '--home'",
  }
  @fsx.write_to_file(
    @pathx.join(book_root, eb_moonclaw_import_receipt_relative_path()),
    import_receipt.stringify(indent=2) + "\n",
    create=0o644,
  )
  @fsx.make_directory(
    @pathx.join(home, "jobs/runs/" + run_id),
    recursive=true,
    exists_ok=true,
  )
  let run_meta : Json = {
    "id": run_id,
    "status": "Succeeded",
    "workspace_dir": run_workspace,
  }
  @fsx.write_to_file(
    @pathx.join(home, "jobs/runs/" + run_id + "/meta.json"),
    run_meta.stringify(indent=2) + "\n",
    create=0o644,
  )
  let run_receipt : Json = {
    "kind": "moonclaw-confirmed-run-receipt",
    "book_id": book_id,
    "run_id": run_id,
    "ok": true,
    "status": "succeeded",
    "timed_out": false,
    "timeout_ms": 120000,
    "exit_code": 0,
    "moonclaw_root": "../moonclaw",
    "home": home,
    "cwd": book_root,
    "meta_path": @pathx.join(home, "jobs/runs/" + run_id + "/meta.json"),
    "meta": run_meta,
    "command": "moon -C ../moonclaw run cmd/main -- proposal run \{run_id} --home \{home} --cwd \{book_root}",
    "stdout": "",
    "stderr": "",
    "recorded_at": "2026-06-02T00:00:00Z",
  }
  @fsx.write_to_file(
    @pathx.join(book_root, eb_moonclaw_run_receipt_relative_path(run_id)),
    run_receipt.stringify(indent=2) + "\n",
    create=0o644,
  )
  @fsx.make_directory(
    @pathx.join(run_workspace, "outputs"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(
    @pathx.join(book_root, "raw/pdfs"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(
    @pathx.join(book_root, "raw/html"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(
    @pathx.join(book_root, "raw/extracted"),
    recursive=true,
    exists_ok=true,
  )
  let source_records : Array[Json] = []
  let candidate_records : Array[Json] = []
  let ai_instruments : Array[Json] = []
  let official_urls : Array[String] = []
  let mut source_index = 0
  for seed in eb_regression_active_universe_source_candidates() {
    source_index = source_index + 1
    let source_kind = json_string(seed, "source_kind", default="pdf")
    let bond_code = json_string(seed, "bond_code", default="")
    let bond_short_name = json_string(seed, "bond_short_name", default="")
    let title = json_string(seed, "title", default="")
    let disclosure_date = json_string(seed, "disclosure_date", default="")
    let platform = json_string(seed, "platform", default="")
    let official_url = json_string(seed, "url", default="")
    official_urls.push(official_url)
    let source_stem = run_id + "-official-" + bond_code + "-\{source_index}"
    let raw_relative = if source_kind == "pdf" {
      "raw/pdfs/" + source_stem + ".pdf"
    } else {
      "raw/html/" + source_stem + ".html"
    }
    let text_relative = "raw/extracted/" + source_stem + ".txt"
    if source_kind == "pdf" {
      @fsx.write_to_file(
        @pathx.join(book_root, raw_relative),
        "%PDF-1.4\n% generated packager official EB active universe evidence fixture \{source_index}\n",
        create=0o644,
      )
    } else {
      @fsx.write_to_file(
        @pathx.join(book_root, raw_relative),
        "<html><body><h1>\{title}</h1><p>债券代码：\{bond_code}。债券简称：\{bond_short_name}。披露日期：\{disclosure_date}。官方通知页面。</p></body></html>\n",
        create=0o644,
      )
    }
    @fsx.write_to_file(
      @pathx.join(book_root, text_relative),
      "\{title}。债券代码：\{bond_code}。债券简称：\{bond_short_name}。披露日期：\{disclosure_date}。发行规模10亿元，初始换股价格为10.00元/股，最新换股价格为10.00元/股。累计换股0股，占总股本0%。换股期限为2026年1月1日至2029年1月1日。担保覆盖比例为125%。\n",
      create=0o644,
    )
    let record : Json = {
      "title": title,
      "bond_code": bond_code,
      "bond_short_name": bond_short_name,
      "disclosure_date": disclosure_date,
      "within_lookback": true,
      "url": official_url,
      "platform": platform,
      "lifecycle_stage": json_string(seed, "lifecycle_stage", default=""),
      "relevance": json_string(seed, "relevance", default=""),
      "source_kind": source_kind,
      "source_type": json_string(
        seed,
        "source_type",
        default="official-source-seed",
      ),
      "source_policy": "official-first",
      "pdf_path": if source_kind == "pdf" {
        raw_relative
      } else {
        ""
      },
      "local_pdf_path": if source_kind == "pdf" {
        raw_relative
      } else {
        ""
      },
      "source_path": if source_kind == "pdf" {
        ""
      } else {
        raw_relative
      },
      "html_path": if source_kind == "html_notice" {
        raw_relative
      } else {
        ""
      },
      "text_path": text_relative,
      "extracted_text_path": text_relative,
      "downloaded": true,
      "download_status": "downloaded",
      "extracted": true,
      "text_extracted": true,
      "extract_status": "extracted",
    }
    source_records.push(record)
    candidate_records.push(record)
    if source_index == 1 {
      ai_instruments.push({
        "bond_code": bond_code,
        "bond_short_name": bond_short_name,
        "facts": {
          "担保覆盖率": {
            "value": "125%",
            "source_url": official_url,
            "text_path": text_relative,
            "snippet": "担保覆盖比例为125%",
          },
        },
      })
    }
  }
  let stale_pdf_relative = "raw/pdfs/baseline-stale-132018.pdf"
  let stale_text_relative = "raw/extracted/baseline-stale-132018.txt"
  @fsx.write_to_file(
    @pathx.join(book_root, stale_pdf_relative),
    "%PDF-1.4\n% stale historical EB baseline fixture\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, stale_text_relative),
    "中国长江三峡集团有限公司公开发行2019年绿色可交换公司债券（第一期）2024年本息兑付及摘牌公告。债券代码：132018。债券简称：G三峡EB1。披露日期：2024年03月27日。该债券已到期兑付并摘牌，仅作为历史基线。\n",
    create=0o644,
  )
  let stale_baseline_record : Json = {
    "title": "中国长江三峡集团有限公司公开发行2019年绿色可交换公司债券（第一期）2024年本息兑付及摘牌公告",
    "bond_code": "132018",
    "bond_short_name": "G三峡EB1",
    "disclosure_date": "2024-03-27",
    "within_lookback": false,
    "url": "https://www.sse.com.cn/disclosure/bond/announcement/132018-20240327.pdf",
    "platform": "上海证券交易所",
    "relevance": "historical baseline only",
    "pdf_path": stale_pdf_relative,
    "local_pdf_path": stale_pdf_relative,
    "text_path": stale_text_relative,
    "extracted_text_path": stale_text_relative,
    "downloaded": true,
    "download_status": "downloaded",
    "extracted": true,
    "text_extracted": true,
    "extract_status": "extracted",
  }
  let pdf_records : Array[Json] = []
  for record in source_records {
    if json_string(record, "source_kind", default="") == "pdf" {
      pdf_records.push(record)
    }
  }
  let active_instrument_codes = eb_regression_active_universe_codes()
  let source_screen : Json = {
    "kind": "eb-official-source-screen",
    "status": "official_source_screened",
    "book_id": book_id,
    "run_id": run_id,
    "target_scope": "active_universe",
    "active_universe_default": true,
    "official_domain_count": 6,
    "live_fetch_performed": true,
    "checked_sources_count": 19,
    "downloaded_source_count": 19,
    "downloaded_pdf_count": 13,
    "html_notice_count": 6,
    "extracted_source_count": 19,
    "extracted_pdf_count": 13,
    "checked_official_urls": json_from_string_array(official_urls),
    "source_records": Json::array(source_records),
    "pdf_sources": Json::array(pdf_records),
    "kept_candidates": Json::array(source_records),
    "standing_goal_decision": "continue",
    "notify_town": false,
  }
  let candidate_artifact : Json = {
    "kind": "eb-official-pdf-candidates",
    "status": "official_candidates_ready",
    "book_id": book_id,
    "run_id": run_id,
    "target_scope": "active_universe",
    "active_universe_default": true,
    "candidate_count": 19,
    "official_url_count": 19,
    "instrument_count": 8,
    "instrument_codes": json_from_string_array(active_instrument_codes),
    "observed_instrument_codes": json_from_string_array(active_instrument_codes),
    "recommended_review_instrument_count": 8,
    "fact_based_universe_evidence": true,
    "universe_evidence_basis": "fixture official source records observed within lookback; no count threshold used",
    "universe_evidence_sources": json_from_string_array([
      "fixture-sse-szse-official-source-index",
    ]),
    "discovery_completeness_ok": true,
    "source_kind_counts": { "pdf": 13, "html_notice": 6 },
    "pdf_candidate_count": 13,
    "html_notice_count": 6,
    "lookback_candidate_count": 19,
    "lookback_no_recent_sources": false,
    "candidates": Json::array(candidate_records),
    "kept_candidates": Json::array(candidate_records),
    "checked_domains": json_from_string_array([
      "sse.com.cn", "szse.cn", "cninfo.com.cn",
    ]),
    "standing_goal_decision": "continue",
  }
  @fsx.write_to_file(
    @pathx.join(run_workspace, "outputs/official-source-screen.json"),
    source_screen.stringify(indent=2) + "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(run_workspace, "outputs/official-pdf-candidates.json"),
    candidate_artifact.stringify(indent=2) + "\n",
    create=0o644,
  )
  let stale_baseline_screen : Json = {
    "kind": "eb-official-source-screen",
    "status": "official_source_screened",
    "source_records": json_from_json_array([stale_baseline_record]),
    "pdf_sources": json_from_json_array([stale_baseline_record]),
    "kept_candidates": json_from_json_array([stale_baseline_record]),
    "standing_goal_decision": "continue",
  }
  @fsx.write_to_file(
    @pathx.join(
      book_root, "raw/analysis-runs/baseline-official-source-screen.json",
    ),
    stale_baseline_screen.stringify(indent=2) + "\n",
    create=0o644,
  )
  let ai_analysis : Json = {
    "kind": "eb-lifecycle-analysis",
    "status": "accepted",
    "result_decision": "accepted",
    "facts": json_from_string_array([
      "发行总额200亿元", "调整前15.92元/股，调整后15.10元/股", "累计换股1,276,432,794股，占总股本5.22%",
      "到期本息108.50元/张，本息兑付日2024-04-09",
    ]),
    "standing_goal_decision": "update",
  }
  @fsx.write_to_file(
    @pathx.join(run_workspace, "outputs/eb-lifecycle-analysis.json"),
    ai_analysis.stringify(indent=2) + "\n",
    create=0o644,
  )
  let ai_extraction : Json = {
    "kind": "eb-indicator-ai-extraction",
    "status": "extracted",
    "extractor": "moonclaw-ai",
    "source_backing_required": true,
    "instruments": Json::array(ai_instruments),
  }
  @fsx.write_to_file(
    @pathx.join(run_workspace, "outputs/eb-indicator-extraction.json"),
    ai_extraction.stringify(indent=2) + "\n",
    create=0o644,
  )
  let mut exit_code = -1
  let mut stdout = ""
  let mut stderr = ""
  let collected = Some(
    @process.collect_output("python3", [
      @pathx.join(book_root, "raw/bootstrap/eb_package_workbook.py"),
      "--book-root",
      book_root,
      "--run-root",
      run_workspace,
      "--as-of",
      "20260603",
    ]),
  ) catch {
    error => {
      stderr = "\{error}"
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
  assert_eq(exit_code, 0)
  assert_true(stdout.contains("\"status\": \"completed\""))
  assert_true(stdout.contains("\"aggregate_output_path\""))
  assert_eq(stderr, "")
  assert_true(@fs.exists(@pathx.join(book_root, output_relative)))
  assert_true(@fs.exists(@pathx.join(book_root, aggregate_output_relative)))
  assert_true(eb_xlsx_data_rows_valid(@pathx.join(book_root, output_relative)))
  assert_true(
    eb_xlsx_data_rows_valid(@pathx.join(book_root, aggregate_output_relative)),
  )
  assert_true(
    eb_xlsx_indicator_core_metrics_valid(
      @pathx.join(book_root, output_relative),
    ),
  )
  assert_true(
    eb_xlsx_indicator_core_metrics_valid(
      @pathx.join(book_root, aggregate_output_relative),
    ),
  )
  assert_true(
    eb_xlsx_official_hyperlinks_valid(@pathx.join(book_root, output_relative)),
  )
  assert_true(
    eb_xlsx_official_hyperlinks_valid(
      @pathx.join(book_root, aggregate_output_relative),
    ),
  )
  let aggregate_manifest = read_json_file_or_object(
    @pathx.join(book_root, aggregate_output_relative + ".manifest.json"),
  )
  assert_eq(
    json_string(aggregate_manifest, "kind", default=""),
    "eb-aggregate-output-manifest",
  )
  assert_eq(
    json_string(aggregate_manifest, "xlsx_path", default=""),
    aggregate_output_relative,
  )
  assert_true(json_int(aggregate_manifest, "source_url_count", default=0) > 0)
  assert_eq(json_int(aggregate_manifest, "instrument_count", default=0), 8)
  assert_eq(json_int(aggregate_manifest, "source_record_count", default=0), 19)
  assert_eq(json_int(aggregate_manifest, "pdf_source_count", default=0), 13)
  assert_eq(json_int(aggregate_manifest, "html_notice_count", default=0), 6)
  assert_true(
    json_bool(
      aggregate_manifest,
      "indicator_core_metrics_populated",
      default=false,
    ),
  )
  assert_eq(
    json_int(aggregate_manifest, "indicator_core_metric_rows", default=0),
    8,
  )
  assert_true(
    json_int(
      aggregate_manifest,
      "indicator_metric_min_non_placeholder_cells",
      default=0,
    ) >=
    4,
  )
  assert_eq(
    json_int(aggregate_manifest, "current_window_record_count", default=0),
    19,
  )
  assert_eq(
    json_int(aggregate_manifest, "historical_baseline_record_count", default=-1),
    1,
  )
  let output_validation = read_json_file_or_object(
    @pathx.join(book_root, output_relative + ".validation.json"),
  )
  let workbook_proof = json_object_field_or_empty(
    output_validation, "workbook_data_proof",
  )
  assert_true(
    json_bool(
      workbook_proof,
      "structured_ai_extraction_available",
      default=false,
    ),
  )
  assert_true(
    json_int(
      workbook_proof,
      "structured_ai_source_backed_fact_count",
      default=0,
    ) >
    0,
  )
  let aggregate_sheet1 = eb_xlsx_xml_part(
    @pathx.join(book_root, aggregate_output_relative),
    "xl/worksheets/sheet1.xml",
  )
  let aggregate_sheet2 = eb_xlsx_xml_part(
    @pathx.join(book_root, aggregate_output_relative),
    "xl/worksheets/sheet2.xml",
  )
  for code in active_instrument_codes {
    assert_true(aggregate_sheet1.contains(code))
    assert_true(aggregate_sheet2.contains(code))
  }
  assert_true(aggregate_sheet2.contains("10亿元"))
  assert_true(aggregate_sheet2.contains("125%"))
  assert_false(aggregate_sheet2.contains("待AI复核补全关键数字"))
  assert_false(aggregate_sheet1.contains("132018"))
  assert_false(aggregate_sheet2.contains("132018"))
  assert_false(aggregate_sheet1.contains("132099"))
  assert_false(aggregate_sheet1.contains("132100"))
  assert_false(aggregate_sheet2.contains("132099"))
  assert_false(aggregate_sheet2.contains("132100"))
  assert_true(
    @fs.exists(
      @pathx.join(book_root, eb_output_manifest_relative_path(output_relative)),
    ),
  )
  assert_true(
    @fs.exists(
      @pathx.join(
        book_root,
        eb_output_workbook_validation_relative_path(output_relative),
      ),
    ),
  )
  assert_true(@fs.exists(@pathx.join(run_workspace, "result.json")))
  let reconciled = reconcile_eb_moonclaw_run(
    root~,
    book_root~,
    book_id~,
    requested_run_id="",
  )
  assert_true(json_bool(reconciled, "ok", default=false))
  assert_eq(
    json_string(reconciled, "status", default=""),
    "accepted_live_result",
  )
  let health = json_object_field_or_empty(reconciled, "run_health")
  assert_true(json_bool(health, "durable_ready", default=false))
  assert_true(json_bool(health, "production_ready", default=false))
  assert_eq(json_string(health, "run_id", default=""), run_id)
  assert_eq(json_string(health, "output_path", default=""), output_relative)
  assert_true(
    json_bool(health, "expected_output_contract_ready", default=false),
  )
  assert_true(
    eb_checklist_item_ok(
      json_array_items(health, "production_checklist"),
      "expected_output_contract",
    ),
  )
  assert_true(json_bool(health, "real_moonclaw_result_ready", default=false))
  assert_true(json_bool(health, "workbook_data_proof_ready", default=false))
  assert_true(json_bool(health, "workbook_hyperlinks_ready", default=false))
  assert_true(
    json_bool(health, "source_screen_production_ready", default=false),
  )
  assert_true(
    json_bool(
      health,
      "moonclaw_candidate_discovery_terminal_ready",
      default=false,
    ),
  )
  let proof = run_eb_production_proof(
    root~,
    book_root~,
    book_id~,
    moonclaw_root="../moonclaw",
    home~,
    launch_if_missing=false,
    execute_moonclaw=false,
    force_execute=false,
    timeout_ms=1000,
  )
  assert_true(json_bool(proof, "ok", default=false))
  assert_eq(json_string(proof, "status", default=""), "production_ready")
  assert_eq(json_string(proof, "proof_level", default=""), "live-production")
}

///|
async test "eb moonclaw target gate blocks sample target before import or run" {
  let root = "/tmp/moondesk-eb-target-gate-blocked-wbtest"
  let book_id = "research-eb-target-gate-blocked"
  let book_root = @pathx.join(@pathx.join(root, ".moontown/books"), book_id)
  ignore(create_pdf_watch_book_dirs(book_root))
  ignore(
    write_pdf_watch_book_files(
      book_root~,
      book_id~,
      topic="EB target gate blocked",
      pattern_id="exchangeable-bond-evidence-watch",
      purpose="Validate target gate blocks sample EB targets.",
      book_json={ "id": book_id, "pattern": "exchangeable-bond-evidence-watch" },
      method_body=default_eb_analysis_method("EB target gate blocked"),
      websites=eb_default_source_websites(),
      eb_target_fields={
        "bond_full_name_or_short_name": "示例EB",
        "bond_code": "132001",
        "issuer": "示例发行人",
        "underlying_listed_company": "示例标的公司",
        "exchange": "上交所",
      },
    ),
  )
  let gate = eb_moonclaw_target_gate(book_root, book_id)
  assert_false(json_bool(gate, "ok", default=true))
  assert_eq(json_string(gate, "status", default=""), "target_not_ready")
  let readiness = json_object_field_or_empty(gate, "target_readiness")
  assert_false(json_bool(readiness, "ok", default=true))
  assert_eq(json_int(readiness, "target_count", default=0), 1)
  let failed_text = json_string_array_items(gate, "failed_checks").join("\n")
  assert_true(
    failed_text.contains(
      "target bond code is a real 132XXX EB code, not the sample 132001",
    ),
  )
  assert_true(
    failed_text.contains("target issuer is filled and not a placeholder"),
  )
}

///|
async test "eb moonclaw target gate accepts active universe without configured bonds" {
  let root = "/tmp/moondesk-eb-target-gate-active-universe-wbtest"
  let book_id = "research-eb-target-gate-active-universe"
  let book_root = @pathx.join(@pathx.join(root, ".moontown/books"), book_id)
  ignore(create_pdf_watch_book_dirs(book_root))
  let book_json = pdf_watch_book_json(
    book_id~,
    topic="EB active universe target gate",
    pattern_id="exchangeable-bond-evidence-watch",
    purpose="Validate active-universe EB discovery does not need configured bonds.",
    cadence=30,
    websites=eb_default_source_websites(),
    source_policy="web-first",
    method_path="wiki/methods/my-analysis-method.md",
    notify_on=["accepted_new_knowledge"],
  )
  ignore(
    write_pdf_watch_book_files(
      book_root~,
      book_id~,
      topic="EB active universe target gate",
      pattern_id="exchangeable-bond-evidence-watch",
      purpose="Validate active-universe EB discovery does not need configured bonds.",
      book_json~,
      method_body=default_eb_analysis_method("EB active universe target gate"),
      websites=eb_default_source_websites(),
    ),
  )
  let request = read_json_file_or_object(
    @pathx.join(book_root, "raw/inbox/eb-tracking-request.json"),
  )
  assert_eq(json_string(request, "target_scope", default=""), "active_universe")
  assert_eq(json_array_items(request, "target_bonds").length(), 0)
  let gate = eb_moonclaw_target_gate(book_root, book_id)
  assert_true(json_bool(gate, "ok", default=false))
  assert_eq(json_string(gate, "status", default=""), "target_ready")
  let readiness = json_object_field_or_empty(gate, "target_readiness")
  assert_true(json_bool(readiness, "ok", default=false))
  assert_eq(
    json_string(readiness, "target_scope", default=""),
    "active_universe",
  )
  assert_true(json_bool(readiness, "active_universe_default", default=false))
  assert_eq(json_int(readiness, "target_count", default=-1), 0)
  assert_eq(json_int(readiness, "ready_target_count", default=-1), 0)
}

///|
async test "eb moonclaw target gate accepts production target fields fallback" {
  let root = "/tmp/moondesk-eb-target-gate-ready-wbtest"
  let book_id = "research-eb-target-gate-ready"
  let book_root = @pathx.join(@pathx.join(root, ".moontown/books"), book_id)
  ignore(create_pdf_watch_book_dirs(book_root))
  ignore(
    write_pdf_watch_book_files(
      book_root~,
      book_id~,
      topic="EB target gate ready",
      pattern_id="exchangeable-bond-evidence-watch",
      purpose="Validate target gate accepts production target fields fallback.",
      book_json={ "id": book_id, "pattern": "exchangeable-bond-evidence-watch" },
      method_body=default_eb_analysis_method("EB target gate ready"),
      websites=eb_default_source_websites(),
      eb_target_fields={
        "bond_full_name_or_short_name": "G三峡EB1",
        "bond_code": "132018",
        "issuer": "中国长江三峡集团有限公司",
        "underlying_listed_company": "长江电力",
        "exchange": "上交所",
      },
    ),
  )
  let request = read_json_file_or_object(
    @pathx.join(book_root, "raw/inbox/eb-tracking-request.json"),
  )
  assert_eq(json_array_items(request, "target_bonds").length(), 1)
  assert_true(
    eb_target_has_identity(json_array_items(request, "target_bonds")[0]),
  )
  let gate = eb_moonclaw_target_gate(book_root, book_id)
  assert_true(json_bool(gate, "ok", default=false))
  assert_eq(json_string(gate, "status", default=""), "target_ready")
  let readiness = json_object_field_or_empty(gate, "target_readiness")
  assert_true(json_bool(readiness, "ok", default=false))
  assert_eq(json_int(readiness, "target_count", default=0), 1)
  assert_eq(json_int(readiness, "ready_target_count", default=0), 1)
  let targets = json_array_items(readiness, "targets")
  assert_eq(targets.length(), 1)
  let target = json_object_field_or_empty(targets[0], "target")
  assert_eq(json_string(target, "bond_code", default=""), "132018")
}

///|
async test "eb production proof records blocked state without moonclaw run" {
  let root = "/tmp/moondesk-eb-production-proof-blocked-wbtest"
  let book_id = "research-eb-production-proof-blocked"
  let book_root = @pathx.join(@pathx.join(root, ".moontown/books"), book_id)
  ignore(create_pdf_watch_book_dirs(book_root))
  ignore(
    write_pdf_watch_book_files(
      book_root~,
      book_id~,
      topic="EB production proof blocked",
      pattern_id="exchangeable-bond-evidence-watch",
      purpose="Validate proof blocks without a live MoonClaw run.",
      book_json={ "id": book_id, "pattern": "exchangeable-bond-evidence-watch" },
      method_body=default_eb_analysis_method("EB production proof blocked"),
      websites=eb_default_source_websites(),
      eb_target_fields={
        "bond_full_name_or_short_name": "示例EB",
        "bond_code": "132001",
        "issuer": "示例发行人",
        "underlying_listed_company": "示例标的公司",
        "exchange": "上交所",
      },
    ),
  )
  let proof = run_eb_production_proof(
    root~,
    book_root~,
    book_id~,
    moonclaw_root="../moonclaw",
    home=@pathx.join(root, ".moonclaw"),
    launch_if_missing=false,
    execute_moonclaw=false,
    force_execute=false,
    timeout_ms=1000,
  )
  assert_false(json_bool(proof, "ok", default=true))
  assert_eq(json_string(proof, "proof_level", default=""), "not-proven")
  assert_eq(json_string(proof, "run_id", default="missing"), "")
  assert_eq(
    json_string(proof, "receipt_path", default=""),
    eb_production_proof_receipt_relative_path(),
  )
  assert_true(
    @fs.exists(
      @pathx.join(book_root, eb_production_proof_receipt_relative_path()),
    ),
  )
  let failed = json_string_array_items(proof, "failed_checks")
  let failed_text = failed.join("\n")
  assert_true(failed.contains("MoonClaw run id available"))
  assert_true(
    failed_text.contains(
      "target bond code is a real 132XXX EB code, not the sample 132001",
    ),
  )
  assert_true(
    failed_text.contains(
      "target bond short/full name is filled and not a placeholder",
    ),
  )
  assert_true(
    failed_text.contains("target issuer is filled and not a placeholder"),
  )
  let health = eb_durable_run_health(root, book_root, book_id)
  assert_true(
    json_bool(health, "production_proof_receipt_ready", default=false),
  )
  assert_eq(
    json_string(health, "production_proof_status", default=""),
    json_string(proof, "status", default=""),
  )
  assert_eq(
    json_string(health, "production_proof_level", default=""),
    "not-proven",
  )
  assert_true(
    json_string_array_items(health, "production_proof_failed_checks").contains(
      "MoonClaw run id available",
    ),
  )
}

///|
async test "eb production proof progress receipt replaces stale audit state before long run" {
  let root = "/tmp/moondesk-eb-production-progress-wbtest"
  let book_id = "research-eb-production-progress"
  let book_root = @pathx.join(@pathx.join(root, ".moontown/books"), book_id)
  ignore(create_pdf_watch_book_dirs(book_root))
  ignore(
    write_pdf_watch_book_files(
      book_root~,
      book_id~,
      topic="EB production progress",
      pattern_id="exchangeable-bond-evidence-watch",
      purpose="Validate production proof progress survives long MoonClaw runs.",
      book_json={ "id": book_id, "pattern": "exchangeable-bond-evidence-watch" },
      method_body=default_eb_analysis_method("EB production progress"),
      websites=eb_default_source_websites(),
      eb_target_fields={
        "bond_full_name_or_short_name": "G三峡EB1",
        "bond_code": "132018",
        "issuer": "中国长江三峡集团有限公司",
        "underlying_listed_company": "长江电力",
        "exchange": "上交所",
      },
    ),
  )
  ignore(sync_book_standing_goal(root, book_root, book_id))
  let import_receipt : Json = {
    "kind": "moonclaw-proposal-import-receipt",
    "book_id": book_id,
    "ok": true,
    "status": "run_confirmed",
    "proposal_id": "proposal-progress",
    "run_id": "run-progress",
    "recovered": false,
  }
  write_eb_production_proof_progress(
    root,
    book_root,
    book_id,
    "run-progress",
    "relaunched_after_orphaned_timeout",
    "executing_confirmed_run",
    900000,
    import_receipt,
    Json::object({}),
    false,
    false,
  )
  let proof = read_json_file_or_object(
    @pathx.join(book_root, eb_production_proof_receipt_relative_path()),
  )
  assert_eq(
    json_string(proof, "status", default=""),
    "moonclaw_confirmed_run_in_progress",
  )
  assert_eq(json_string(proof, "proof_level", default=""), "in-progress")
  assert_eq(json_string(proof, "run_id", default=""), "run-progress")
  assert_eq(
    json_string(proof, "moonclaw_run_receipt_path", default=""),
    eb_moonclaw_run_receipt_relative_path("run-progress"),
  )
  let health = eb_durable_run_health(root, book_root, book_id)
  assert_true(
    json_bool(health, "production_proof_receipt_ready", default=false),
  )
  assert_eq(
    json_string(health, "production_proof_status", default=""),
    "moonclaw_confirmed_run_in_progress",
  )
  assert_eq(
    json_string(health, "production_proof_run_id", default=""),
    "run-progress",
  )
}

///|
test "standing goal upsert replaces by id" {
  let original : Json = { "id": "watch-a", "title": "A" }
  let replacement : Json = { "id": "watch-a", "title": "B" }
  let records = upsert_record_by_id([original], replacement)
  assert_eq(records.length(), 1)
  assert_eq(json_string(records[0], "title", default=""), "B")
}

///|
test "eb production proof API timeout is workflow-aware for execution" {
  assert_eq(
    eb_production_proof_effective_timeout_ms(
      130000,
      execute_moonclaw=true,
      force_execute=false,
    ),
    eb_production_proof_min_execution_timeout_ms(),
  )
  assert_eq(
    eb_production_proof_effective_timeout_ms(
      130000,
      execute_moonclaw=false,
      force_execute=false,
    ),
    130000,
  )
  assert_eq(
    eb_production_proof_effective_timeout_ms(
      900000,
      execute_moonclaw=true,
      force_execute=true,
    ),
    900000,
  )
}

///|
test "search snippets are bounded and single line" {
  let snippet = search_snippet(
    "alpha beta gamma\ndelta epsilon zeta",
    "epsilon",
    fallback="fallback",
  )
  assert_true(snippet.contains("epsilon"))
  assert_eq(snippet.contains("\n"), false)
}
