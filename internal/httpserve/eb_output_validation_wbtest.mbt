///|
async test "eb production source screen accepts structured official pdf records" {
  let root = "/tmp/moondesk-eb-production-source-screen-wbtest"
  let structured_path = @pathx.join(root, "structured.json")
  let unofficial_path = @pathx.join(root, "unofficial.json")
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  let structured_screen : Json = {
    "kind": "eb-official-source-screen",
    "status": "official_source_screened",
    "official_domain_count": eb_official_domains().length(),
    "live_fetch_performed": true,
    "sources": json_from_json_array([
      {
        "url": "https://www.sse.com.cn/disclosure/bond/announcement/132001.pdf",
        "title": "示例EB募集说明书",
        "publisher": "上交所",
        "download_status": "downloaded",
        "extract_status": "extracted",
        "sha256": "abc123",
        "extracted_text_sha256": "def456",
      },
    ]),
  }
  @fsx.write_to_file(
    structured_path,
    structured_screen.stringify(indent=2) + "\n",
    create=0o644,
  )
  assert_true(eb_production_source_screen_valid(structured_path))
  let unofficial_screen : Json = {
    "kind": "eb-official-source-screen",
    "status": "official_source_screened",
    "official_domain_count": eb_official_domains().length(),
    "live_fetch_performed": true,
    "downloaded_pdf_count": 1,
    "extracted_pdf_count": 1,
    "sources": json_from_json_array([
      {
        "url": "https://example.com/reposted/132001.pdf",
        "title": "第三方转载",
        "download_status": "downloaded",
        "extract_status": "extracted",
      },
    ]),
  }
  @fsx.write_to_file(
    unofficial_path,
    unofficial_screen.stringify(indent=2) + "\n",
    create=0o644,
  )
  assert_false(eb_production_source_screen_valid(unofficial_path))
}

///|
test "eb sheet2 core metric gate rejects placeholder-only indicator rows" {
  let header = "<row r=\"1\"><c r=\"A1\" t=\"inlineStr\"><is><t>债券代码</t></is></c><c r=\"B1\" t=\"inlineStr\"><is><t>债券简称</t></is></c></row>"
  let placeholder_row = "<row r=\"2\"><c r=\"A2\" t=\"inlineStr\"><is><t>132024</t></is></c><c r=\"B2\" t=\"inlineStr\"><is><t>26江铜EB</t></is></c><c r=\"C2\" t=\"inlineStr\"><is><t>未检索到</t></is></c><c r=\"D2\" t=\"inlineStr\"><is><t>未检索到</t></is></c><c r=\"E2\" t=\"inlineStr\"><is><t>未检索到（募集说明书/发行公告原文未纳入当前证据包）</t></is></c><c r=\"F2\" t=\"inlineStr\"><is><t>未检索到</t></is></c></row>"
  let populated_row = "<row r=\"2\"><c r=\"A2\" t=\"inlineStr\"><is><t>132024</t></is></c><c r=\"B2\" t=\"inlineStr\"><is><t>26江铜EB</t></is></c><c r=\"C2\" t=\"inlineStr\"><is><t>50亿元</t></is></c><c r=\"D2\" t=\"inlineStr\"><is><t>50亿元（未见兑付/摘牌）</t></is></c><c r=\"E2\" t=\"inlineStr\"><is><t>53元/股</t></is></c><c r=\"F2\" t=\"inlineStr\"><is><t>53元/股（未见调整公告）</t></is></c></row>"
  assert_false(
    eb_xlsx_indicator_core_metrics_valid_xml(
      "<worksheet><sheetData>" +
      header +
      placeholder_row +
      "</sheetData></worksheet>",
    ),
  )
  assert_true(
    eb_xlsx_indicator_core_metrics_valid_xml(
      "<worksheet><sheetData>" +
      header +
      populated_row +
      "</sheetData></worksheet>",
    ),
  )
}

///|
test "eb moonclaw task execution record mirrors Moontown confirmed run state" {
  let confirmed = eb_moontown_task_execution_record(
    book_id="research-eb-watch",
    packet_id="packet-1",
    packet_path="/tmp/book/moonclaw-packets/eb-standing-watch-proposal.json",
    packet_relative="moonclaw-packets/eb-standing-watch-proposal.json",
    proposal_id="proposal-1",
    run_id="run-1",
    ok=true,
    confirm=true,
    command="moon run cmd/main -- proposal import packet --confirm",
    tick=17,
  )
  assert_eq(json_string(confirmed, "status", default=""), "RunConfirmed")
  assert_eq(json_string(confirmed, "run_id", default=""), "run-1")
  assert_eq(json_int(confirmed, "heartbeat_tick", default=0), 17)
  assert_eq(json_int(confirmed, "stale_after_tick", default=0), 47)
  assert_eq(
    json_string(confirmed, "output_contract", default=""),
    "moondesk.exchangeable_bond_tracking.xlsx.v1",
  )
  assert_true(
    confirmed.stringify().contains("schemas/eb-tracking-output.schema.md"),
  )
  let imported = eb_moontown_task_execution_record(
    book_id="research-eb-watch",
    packet_id="packet-1",
    packet_path="/tmp/book/moonclaw-packets/eb-standing-watch-proposal.json",
    packet_relative="moonclaw-packets/eb-standing-watch-proposal.json",
    proposal_id="proposal-1",
    run_id="",
    ok=true,
    confirm=false,
    command="moon run cmd/main -- proposal import packet",
    tick=1,
  )
  assert_eq(json_string(imported, "status", default=""), "ProposalImported")
  let failed = eb_moontown_task_execution_record(
    book_id="research-eb-watch",
    packet_id="packet-1",
    packet_path="/tmp/book/moonclaw-packets/eb-standing-watch-proposal.json",
    packet_relative="moonclaw-packets/eb-standing-watch-proposal.json",
    proposal_id="",
    run_id="",
    ok=false,
    confirm=true,
    command="moon run cmd/main -- proposal import packet --confirm",
    tick=1,
  )
  assert_eq(json_string(failed, "status", default=""), "Failed")
}

///|
async test "eb sample run writes durable output and town handoff artifacts" {
  let root = "/tmp/moondesk-eb-sample-run-wbtest"
  let book_id = "research-eb-sample-run-eb-watch"
  let book_root = @pathx.join(@pathx.join(root, ".moontown/books"), book_id)
  let run_id = "run-eb-sample-durable"
  ignore(create_pdf_watch_book_dirs(book_root))
  let goal = pdf_watch_standing_goal(
    book_id~,
    topic="EB sample run",
    pattern_id="exchangeable-bond-evidence-watch",
    purpose="Validate durable EB output run.",
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
      topic="EB sample run",
      pattern_id="exchangeable-bond-evidence-watch",
      purpose="Validate durable EB output run.",
      book_json={ "id": book_id, "pattern": "exchangeable-bond-evidence-watch" },
      method_body=default_eb_analysis_method("EB sample run"),
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
  @fsx.write_to_file(
    town_moonbooks_path(root),
    Json::array([
      pdf_watch_catalog_entry(
        book_id~,
        topic="EB sample run",
        pattern_id="exchangeable-bond-evidence-watch",
        purpose="Validate durable EB output run.",
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
      topic="EB sample run",
      pattern_id="exchangeable-bond-evidence-watch",
      purpose="Validate durable EB output run.",
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
      topic="EB sample run",
      pattern_id="exchangeable-bond-evidence-watch",
      purpose="Validate durable EB output run.",
      cadence=30,
      websites=eb_default_source_websites(),
      method_body=default_eb_analysis_method("EB sample run"),
      skill_pack=default_skill_pack_for_pattern(
        "exchangeable-bond-evidence-watch",
      ),
      goal~,
    ),
  )
  let result = write_eb_sample_execution_run(
    root~,
    book_root~,
    book_id~,
    run_id~,
    bond_code="132001",
    bond_short_name="示例EB",
    as_of="20260601",
  )
  assert_eq(json_string(result, "status", default=""), "sample_run_completed")
  assert_true(
    @fs.exists(
      @pathx.join(
        book_root, "book/outputs/EB追踪_132001_示例EB_20260601.xlsx",
      ),
    ),
  )
  assert_true(
    @fs.exists(
      @pathx.join(
        book_root, "book/outputs/EB追踪_132001_示例EB_20260601.xlsx.manifest.json",
      ),
    ),
  )
  assert_true(
    @fs.exists(
      @pathx.join(
        book_root, "book/outputs/EB追踪_132001_示例EB_20260601.xlsx.validation.json",
      ),
    ),
  )
  assert_true(
    eb_output_manifest_valid(
      book_root,
      "book/outputs/EB追踪_132001_示例EB_20260601.xlsx",
      accepted_required=true,
    ),
  )
  assert_true(
    @fs.exists(
      @pathx.join(book_root, "moonclaw-jobs/" + run_id + "/result.json"),
    ),
  )
  assert_true(
    @fs.exists(@pathx.join(book_root, "moonclaw-jobs/" + run_id + "/report.md")),
  )
  assert_true(
    @fs.exists(@pathx.join(book_root, eb_source_screen_relative_path(run_id))),
  )
  assert_true(
    @fs.exists(
      @pathx.join(book_root, "raw/inbox/eb-standing-watch-dispatch.json"),
    ),
  )
  assert_true(@fs.exists(@pathx.join(book_root, "moonclaw.jobs.json")))
  assert_true(
    @fs.exists(
      @pathx.join(book_root, eb_moonclaw_proposal_packet_relative_path()),
    ),
  )
  assert_true(
    @fs.exists(@pathx.join(book_root, "raw/bootstrap/EB_WATCH_CONTRACT.md")),
  )
  assert_true(
    @fs.exists(
      @pathx.join(
        book_root,
        "moonclaw-jobs/" + run_id + "/outputs/official-source-screen.json",
      ),
    ),
  )
  assert_true(
    @fs.exists(
      @pathx.join(book_root, "wiki/sources/eb-official-source-screen.md"),
    ),
  )
  assert_true(
    @fs.exists(
      @pathx.join(book_root, "wiki/reviews/bookkeeper-eb-sample-run.md"),
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
  let validation = read_json_file_or_object(
    @pathx.join(book_root, eb_output_validation_relative_path()),
  )
  assert_eq(
    json_string(validation, "status", default=""),
    "accepted_output_ready",
  )
  assert_true(json_bool(validation, "source_evidence_ready", default=false))
  assert_true(json_bool(validation, "final_output_ready", default=false))
  assert_eq(json_int(validation, "valid_accepted_output_count", default=0), 1)
  let verification = json_object_field_or_empty(result, "verification")
  assert_true(json_bool(verification, "verified", default=false))
  let run_health = json_object_field_or_empty(result, "run_health")
  assert_true(json_bool(run_health, "durable_ready", default=false))
  assert_eq(
    json_string(run_health, "status", default=""),
    "durable_output_ready",
  )
  assert_eq(json_string(run_health, "run_id", default=""), run_id)
  assert_true(json_bool(run_health, "workbook_validation_ready", default=false))
  assert_true(
    json_bool(run_health, "workbook_validation_sample_run", default=false),
  )
  assert_true(json_bool(run_health, "moonclaw_profile_ready", default=false))
  assert_true(
    json_bool(run_health, "moonclaw_proposal_packet_ready", default=false),
  )
  assert_false(
    json_bool(run_health, "moonclaw_import_receipt_ready", default=true),
  )
  assert_false(
    json_bool(run_health, "moonclaw_confirmed_run_ready", default=true),
  )
  assert_false(
    json_bool(run_health, "moonclaw_confirmed_run_meta_ready", default=true),
  )
  assert_false(
    json_bool(run_health, "moonclaw_confirmed_run_succeeded", default=true),
  )
  assert_true(
    json_bool(run_health, "moonclaw_import_stderr_clean", default=false),
  )
  assert_eq(
    json_string(run_health, "moonclaw_confirmed_run_status", default=""),
    "",
  )
  assert_false(
    json_bool(run_health, "moontown_execution_receipt_ready", default=true),
  )
  assert_false(json_bool(run_health, "production_ready", default=true))
  assert_false(json_bool(run_health, "targets_production_ready", default=true))
  assert_false(
    json_bool(run_health, "real_moonclaw_result_ready", default=true),
  )
  assert_eq(
    json_string(run_health, "moontown_execution_receipt_path", default=""),
    eb_moontown_execution_receipt_relative_path(),
  )
  assert_eq(
    json_string(run_health, "moonclaw_import_status", default=""),
    "not_imported",
  )
  assert_eq(
    json_string(run_health, "output_path", default=""),
    "book/outputs/EB追踪_132001_示例EB_20260601.xlsx",
  )
  assert_eq(
    json_string(run_health, "source_screen_path", default=""),
    eb_source_screen_relative_path(run_id),
  )
  assert_true(
    json_bool(run_health, "expected_output_contract_ready", default=false),
  )
  assert_eq(
    json_string(run_health, "expected_output_contract_path", default=""),
    eb_expected_output_contract_relative_path(),
  )
  let sample_checklist = json_array_items(run_health, "production_checklist")
  assert_true(sample_checklist.length() >= 10)
  assert_false(
    eb_checklist_item_ok(sample_checklist, "target_config", default=true),
  )
  assert_false(
    eb_checklist_item_ok(sample_checklist, "moonclaw_run", default=true),
  )
  assert_false(
    eb_checklist_item_ok(sample_checklist, "live_result", default=true),
  )
  assert_true(
    eb_checklist_item_ok(sample_checklist, "expected_output_contract"),
  )
  assert_true(eb_checklist_item_ok(sample_checklist, "accepted_workbook"))
  assert_true(eb_checklist_item_ok(sample_checklist, "workbook_validation"))
  assert_true(eb_checklist_item_ok(sample_checklist, "appendix_notes"))
  assert_true(eb_checklist_item_ok(sample_checklist, "quality_proof"))
  assert_true(eb_checklist_item_ok(sample_checklist, "lifecycle_proof"))
  assert_false(
    eb_checklist_item_ok(sample_checklist, "not_sample", default=true),
  )
  assert_false(
    eb_checklist_item_ok(sample_checklist, "output_target_match", default=true),
  )
  assert_false(
    eb_checklist_item_ok(
      sample_checklist,
      "official_source_screen",
      default=true,
    ),
  )
}

///|
async test "eb run health resolves standing goal from registration receipt when global ledger is stale" {
  let root = "/tmp/moondesk-eb-standing-goal-receipt-fallback-wbtest"
  let book_id = "research-eb-standing-goal-receipt-fallback-eb-watch"
  let book_root = @pathx.join(@pathx.join(root, ".moontown/books"), book_id)
  ignore(create_pdf_watch_book_dirs(book_root))
  let goal = pdf_watch_standing_goal(
    book_id~,
    topic="EB standing goal receipt fallback",
    pattern_id="exchangeable-bond-evidence-watch",
    purpose="Validate run-health goal identity fallback.",
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
    Json::array([]).stringify(indent=2) + "\n",
    create=0o644,
  )
  ignore(
    write_pdf_watch_book_files(
      book_root~,
      book_id~,
      topic="EB standing goal receipt fallback",
      pattern_id="exchangeable-bond-evidence-watch",
      purpose="Validate run-health goal identity fallback.",
      book_json={ "id": book_id, "pattern": "exchangeable-bond-evidence-watch" },
      method_body=default_eb_analysis_method(
        "EB standing goal receipt fallback",
      ),
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
  let standing_registration = write_moontown_standing_goal_registration(
    root~,
    book_root~,
    book_id~,
    pattern_id="exchangeable-bond-evidence-watch",
    goal~,
  )
  assert_eq(
    json_string(standing_registration, "goal_id", default=""),
    pdf_watch_goal_id(book_id),
  )
  @fsx.write_to_file(
    town_moonbooks_path(root),
    Json::array([
      pdf_watch_catalog_entry(
        book_id~,
        topic="EB standing goal receipt fallback",
        pattern_id="exchangeable-bond-evidence-watch",
        purpose="Validate run-health goal identity fallback.",
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
      topic="EB standing goal receipt fallback",
      pattern_id="exchangeable-bond-evidence-watch",
      purpose="Validate run-health goal identity fallback.",
      book_root~,
      goal~,
    ).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  ignore(
    write_moontown_book_template_publish(
      root~,
      book_root~,
      book_id~,
      topic="EB standing goal receipt fallback",
      pattern_id="exchangeable-bond-evidence-watch",
      purpose="Validate run-health goal identity fallback.",
      cadence=30,
      websites=eb_default_source_websites(),
      method_body=default_eb_analysis_method(
        "EB standing goal receipt fallback",
      ),
      skill_pack=default_skill_pack_for_pattern(
        "exchangeable-bond-evidence-watch",
      ),
      goal~,
    ),
  )
  let verification = book_contract_verification(
    root, book_root, book_id, "exchangeable-bond-evidence-watch",
  )
  assert_true(json_bool(verification, "verified", default=false))
  assert_false(
    json_bool(verification, "moontown_global_standing_goal_ready", default=true),
  )
  assert_true(
    json_bool(
      verification,
      "moontown_standing_goal_registration_ready",
      default=false,
    ),
  )
  let health = eb_durable_run_health(root, book_root, book_id)
  assert_eq(
    json_string(health, "standing_goal_id", default=""),
    pdf_watch_goal_id(book_id),
  )
  assert_true(
    json_bool(health, "standing_goal_registration_ready", default=false),
  )
  assert_false(json_bool(health, "global_standing_goal_ready", default=true))
  assert_true(json_bool(health, "standing_goal_enabled", default=false))
  assert_true(
    eb_checklist_item_ok(
      json_array_items(health, "production_checklist"),
      "standing_goal",
    ),
  )
  let sync = sync_book_standing_goal(root, book_root, book_id)
  assert_true(json_bool(sync, "ok", default=false))
  assert_eq(json_string(sync, "status", default=""), "synced")
  assert_false(
    json_bool(sync, "global_standing_goal_ready_before", default=true),
  )
  assert_true(json_bool(sync, "global_standing_goal_ready", default=false))
  let synced_verification = json_object_field_or_empty(sync, "verification")
  assert_true(json_bool(synced_verification, "verified", default=false))
  assert_true(
    json_bool(
      synced_verification,
      "moontown_global_standing_goal_ready",
      default=false,
    ),
  )
  let synced_health = json_object_field_or_empty(sync, "run_health")
  assert_true(
    json_bool(synced_health, "global_standing_goal_ready", default=false),
  )
}
