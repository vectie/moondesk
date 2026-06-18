///|
async test "pdf evidence watch workspace matches Moontown template contract" {
  let book_id = "research-policy-reports-pdf-watch"
  let root = "/tmp/moondesk-pdf-watch-contract-wbtest"
  let book_root = @pathx.join(root, ".moontown/books/" + book_id)
  let config = pdf_watch_book_json(
    book_id~,
    topic="Policy Reports",
    pattern_id="pdf-evidence-watch",
    purpose="Watch policy reports",
    cadence=30,
    websites=["https://example.org/reports"],
    source_policy="web-first",
    method_path="wiki/methods/my-analysis-method.md",
    notify_on=["accepted_new_knowledge"],
  )
  ignore(create_pdf_watch_book_dirs(book_root))
  ignore(
    write_pdf_watch_book_files(
      book_root~,
      book_id~,
      topic="Policy Reports",
      pattern_id="pdf-evidence-watch",
      purpose="Watch policy reports",
      book_json=config,
      method_body=default_pdf_analysis_method("Policy Reports"),
      websites=["https://example.org/reports"],
    ),
  )
  for path in pdf_watch_required_paths("pdf-evidence-watch") {
    assert_true(@fs.exists(@pathx.join(book_root, path)))
  }
  assert_true(@fs.exists(@pathx.join(book_root, "raw/inbox/.keep")))
  let written = read_json_file_or_object(@pathx.join(book_root, "book.json"))
  assert_eq(json_string(written, "book_type", default=""), "research-book")
  let layout = json_object_field_or_empty(written, "layout")
  assert_eq(json_string(layout, "raw_inbox", default=""), "raw/inbox/")
  assert_eq(json_string(layout, "raw_pdfs", default=""), "raw/pdfs/")
  assert_eq(json_string(layout, "raw_extracted", default=""), "raw/extracted/")
  assert_eq(
    json_string(layout, "raw_analysis_runs", default=""),
    "raw/analysis-runs/",
  )
  assert_eq(
    json_string(layout, "site_generated", default=""),
    "site/generated/",
  )
  assert_true(
    pdf_watch_base_type_provenance_valid(
      json_object_field_or_empty(written, "base_type_provenance"),
    ),
  )
  assert_eq(
    json_string(
      json_object_field_or_empty(written, "analysis"),
      "method_page",
      default="",
    ),
    "wiki/methods/my-analysis-method.md",
  )
  assert_true(
    file_contains(
      @pathx.join(book_root, "wiki/methods/my-analysis-method.md"),
      "Policy Reports",
    ),
  )
  let operator_config = read_json_file_or_object(
    @pathx.join(book_root, pdf_watch_operator_config_relative_path()),
  )
  assert_eq(json_string(operator_config, "type", default=""), "research-book")
  assert_eq(json_string(operator_config, "id", default=""), book_id)
  assert_true(
    json_string_array_items(
      json_object_field_or_empty(operator_config, "watch"),
      "dedupe_by",
    ) ==
    ["url", "title", "sha256"],
  )
  assert_eq(
    json_string(
      json_object_field_or_empty(operator_config, "analysis"),
      "method_page",
      default="",
    ),
    "wiki/methods/my-analysis-method.md",
  )
  let base_type_selection = read_json_file_or_object(
    @pathx.join(book_root, pdf_watch_base_type_selection_relative_path()),
  )
  assert_true(
    pdf_watch_base_type_selection_valid_for_book(written, base_type_selection),
  )
  assert_true(json_bool(base_type_selection, "verified", default=false))
  assert_eq(
    json_string(base_type_selection, "base_type", default=""),
    "research-book",
  )
  assert_eq(
    json_string(base_type_selection, "selected_from", default=""),
    "GET /api/books/base-types",
  )
  let goal = pdf_watch_standing_goal(
    book_id~,
    topic="Policy Reports",
    pattern_id="pdf-evidence-watch",
    purpose="Watch policy reports",
    cadence=30,
    source_policy="web-first",
    daemon_tick=0,
  )
  assert_eq(json_string(goal, "title", default=""), "Watch Policy Reports PDFs")
  assert_eq(json_string(goal, "target_book_id", default=""), book_id)
  assert_eq(json_int(goal, "cadence_ticks", default=0), 30)
  assert_eq(json_string(goal, "source_policy", default=""), "web-first")
  assert_true(
    json_string(goal, "prompt", default="").contains(
      "Watch configured websites for new relevant PDFs",
    ),
  )
  assert_true(
    json_string(goal, "prompt", default="").contains(
      "notify the operator only after accepted new knowledge",
    ),
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
  @fsx.write_to_file(
    town_moonbooks_path(root),
    Json::array([
      pdf_watch_catalog_entry(
        book_id~,
        topic="Policy Reports",
        pattern_id="pdf-evidence-watch",
        purpose="Watch policy reports",
        book_root~,
      ),
    ]).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  let standing_registration = write_moontown_standing_goal_registration(
    root~,
    book_root~,
    book_id~,
    pattern_id="pdf-evidence-watch",
    goal~,
  )
  assert_eq(
    json_string(standing_registration, "status", default=""),
    "registered",
  )
  assert_eq(
    json_string(
      json_object_field_or_empty(standing_registration, "output_contract"),
      "output_contract",
      default="",
    ),
    "moontown.pdf_evidence_watch.result.v1",
  )
  assert_true(
    @fs.exists(
      @pathx.join(
        book_root,
        pdf_watch_moontown_standing_goal_receipt_relative_path(),
      ),
    ),
  )
  let publish = write_moontown_book_template_publish(
    root~,
    book_root~,
    book_id~,
    topic="Policy Reports",
    pattern_id="pdf-evidence-watch",
    purpose="Watch policy reports",
    cadence=30,
    websites=["https://example.org/reports"],
    method_body=default_pdf_analysis_method("Policy Reports"),
    skill_pack=["pdf-watch", "pdf-analysis"],
    goal~,
  )
  assert_eq(json_string(publish, "status", default=""), "installed")
  assert_eq(
    json_string(publish, "publish_mode", default=""),
    "moondesk-research-book-direct-create-plus-installed-moontown-template-request",
  )
  assert_eq(
    json_string(publish, "book_ownership_contract", default=""),
    "research-book + source adapter + extractor + analysis skill + standing watch",
  )
  assert_true(
    pdf_watch_base_type_provenance_valid(
      json_object_field_or_empty(publish, "base_type_provenance"),
    ),
  )
  assert_eq(json_string(publish, "target_book_id", default=""), book_id)
  assert_eq(
    json_string(publish, "standing_goal_id", default=""),
    "watch-\{book_id}-pdfs",
  )
  assert_eq(
    json_string(publish, "template_request_lifecycle", default=""),
    "already-installed-by-moondesk",
  )
  assert_eq(
    json_string(publish, "operator_config_path", default=""),
    pdf_watch_operator_config_relative_path(),
  )
  assert_eq(
    json_string(publish, "base_type_selection_path", default=""),
    pdf_watch_base_type_selection_relative_path(),
  )
  let publish_output_contract = json_object_field_or_empty(
    publish, "output_contract",
  )
  assert_eq(
    json_string(publish_output_contract, "output_contract", default=""),
    "moontown.pdf_evidence_watch.result.v1",
  )
  assert_eq(
    json_string(publish_output_contract, "result_schema_path", default=""),
    "schemas/analysis-result.schema.md",
  )
  let standing_goal_contract = json_object_field_or_empty(
    publish, "standing_goal_contract",
  )
  assert_eq(
    json_string(standing_goal_contract, "notify_rule", default=""),
    "accepted-new-knowledge-only",
  )
  assert_eq(
    json_string(standing_goal_contract, "target_book_id", default=""),
    book_id,
  )
  assert_eq(json_int(standing_goal_contract, "cadence_ticks", default=0), 30)
  assert_eq(
    json_string(publish, "daemon_job", default=""),
    "standing-goal-dispatch",
  )
  let request = json_record_by_id(
    json_array_items(
      read_json_file_or_object(town_book_template_request_path(root)),
      "requests",
    ),
    @desk.stable_id("book-template-request", book_id),
  ).unwrap()
  assert_eq(json_string(request, "status", default=""), "installed")
  assert_eq(
    json_string(
      json_object_field_or_empty(request, "output_contract"),
      "output_contract",
      default="",
    ),
    "moontown.pdf_evidence_watch.result.v1",
  )
  assert_true(
    @fs.exists(
      @pathx.join(book_root, pdf_watch_moontown_publish_receipt_relative_path()),
    ),
  )
  let install_config = read_json_file_or_object(
    @pathx.join(town_book_template_config_root(root), book_id + ".json"),
  )
  assert_eq(json_string(install_config, "book_id", default=""), book_id)
  assert_eq(
    json_string(install_config, "pattern_id", default=""),
    "pdf-evidence-watch",
  )
  assert_eq(
    json_string(
      json_object_field_or_empty(install_config, "output_contract"),
      "output_contract",
      default="",
    ),
    "moontown.pdf_evidence_watch.result.v1",
  )
  assert_eq(json_int(install_config, "cadence_ticks", default=0), 30)
  assert_true(
    json_string_array_items(install_config, "websites") ==
    ["https://example.org/reports"],
  )
  assert_eq(
    json_string(install_config, "workspace_root", default=""),
    "../books/" + book_id,
  )
  let verification = book_contract_verification(
    root, book_root, book_id, "pdf-evidence-watch",
  )
  assert_true(json_bool(verification, "verified", default=false))
  assert_true(
    json_string_array_items(verification, "checks").contains(
      "book.json records MoonBook/Moontown base-type provenance",
    ),
  )
  assert_true(
    json_string_array_items(verification, "checks").contains(
      "book records durable base-type selection from Moondesk catalog",
    ),
  )
  assert_true(
    json_string_array_items(verification, "checks").contains(
      "book.json records the requested PDF Evidence Watch book layout",
    ),
  )
  assert_true(
    json_string_array_items(verification, "checks").contains(
      "Moontown standing goal uses the PDF Evidence Watch pipeline prompt",
    ),
  )
  assert_true(
    json_string_array_items(verification, "checks").contains(
      "Moontown publish receipt records accepted-knowledge-only notification",
    ),
  )
  assert_true(
    json_string_array_items(verification, "checks").contains(
      "Moontown publish receipt preserves base-type provenance",
    ),
  )
  assert_true(
    json_string_array_items(verification, "checks").contains(
      "Moontown publish receipt preserves output contract handoff",
    ),
  )
  assert_true(
    json_string_array_items(verification, "checks").contains(
      "Moontown install config preserves output contract handoff",
    ),
  )
  assert_eq(
    json_string(verification, "moontown_request_status", default=""),
    "installed",
  )
}

///|
test "exchangeable bond pattern keeps research book base and EB output contract" {
  let patterns = book_pattern_records()
  assert_eq(patterns.length(), 2)
  let book_id = pdf_watch_book_id(
    "Exchangeable Bond Credit Compliance",
    pattern_id="exchangeable-bond-evidence-watch",
  )
  assert_eq(book_id, "research-exchangeable-bond-credit-compliance-eb-watch")
  let analysis_text = default_analysis_method_for_pattern(
    "exchangeable-bond-evidence-watch", "Exchangeable Bond Credit Compliance",
  )
  assert_true(analysis_text.contains("EB追踪_"))
  assert_true(analysis_text.contains("公告追踪主表"))
  assert_true(analysis_text.contains("关键指标监控表"))
  assert_true(analysis_text.contains("P0"))
  assert_true(analysis_text.contains("cninfo.com.cn"))
  assert_true(analysis_text.contains("Stage 3"))
  assert_true(analysis_text.contains("2 trading days"))
  assert_true(analysis_text.contains("未检索到"))
  assert_true(analysis_text.contains("担保覆盖率"))
  assert_true(analysis_text.contains("Cross-verify"))
  assert_true(
    analysis_text.contains("Canonical Chinese Operator Prompt Contract"),
  )
  assert_true(analysis_text.contains("债券全称/简称"))
  assert_true(analysis_text.contains("赎回实施提示性公告"))
  assert_true(analysis_text.contains("Sheet 1 headers"))
  assert_true(analysis_text.contains("是否触发投资者行动"))
  assert_true(analysis_text.contains("Sheet 2 headers"))
  assert_true(analysis_text.contains("控制权变动风险"))
  assert_true(analysis_text.contains("列宽自适应"))
  let schema_text = eb_tracking_output_schema_markdown()
  assert_true(schema_text.contains("披露平台"))
  assert_true(schema_text.contains("担保覆盖率（市值/余额）"))
  assert_true(schema_text.contains(".manifest.json"))
  assert_true(schema_text.contains(".validation.json"))
  assert_true(schema_text.contains("xlsx_sha256"))
  assert_true(schema_text.contains("workbook_data_proof"))
  assert_true(schema_text.contains("appendix_notes"))
  assert_true(schema_text.contains("quality_proof"))
  assert_true(schema_text.contains("lifecycle_stage_proof"))
  assert_true(schema_text.contains("official-source-screen.json"))
  assert_true(schema_text.contains("one row per bond"))
  let catalog = pdf_watch_catalog_entry(
    book_id~,
    topic="Exchangeable Bond Credit Compliance",
    pattern_id="exchangeable-bond-evidence-watch",
    purpose="Official EB tracking",
    book_root="/tmp/book",
  )
  assert_eq(json_string(catalog, "memory_scope", default=""), "BookPrivate")
  assert_true(catalog.stringify().contains("eb-credit-compliance"))
  assert_true(
    book_pattern_output_files("exchangeable-bond-evidence-watch").contains(
      eb_output_template_relative_path(),
    ),
  )
  assert_true(
    book_pattern_output_files("exchangeable-bond-evidence-watch").contains(
      "raw/inbox/eb-tracking-request.json",
    ),
  )
  assert_true(
    book_pattern_output_files("exchangeable-bond-evidence-watch").contains(
      "raw/inbox/eb-standing-watch-dispatch.json",
    ),
  )
  assert_true(
    book_pattern_output_files("exchangeable-bond-evidence-watch").contains(
      pdf_watch_operator_config_relative_path(),
    ),
  )
  assert_true(
    book_pattern_output_files("exchangeable-bond-evidence-watch").contains(
      pdf_watch_base_type_selection_relative_path(),
    ),
  )
  assert_true(
    book_pattern_output_files("exchangeable-bond-evidence-watch").contains(
      "wiki/evidence-matrix.md",
    ),
  )
  assert_true(
    book_pattern_output_files("exchangeable-bond-evidence-watch").contains(
      "moonclaw.jobs.json",
    ),
  )
  assert_true(
    book_pattern_output_files("exchangeable-bond-evidence-watch").contains(
      eb_moonclaw_proposal_packet_relative_path(),
    ),
  )
  assert_true(
    book_pattern_output_files("exchangeable-bond-evidence-watch").contains(
      "raw/bootstrap/EB_WATCH_CONTRACT.md",
    ),
  )
  assert_true(
    book_pattern_output_files("exchangeable-bond-evidence-watch").contains(
      eb_operator_prompt_relative_path(),
    ),
  )
  assert_true(
    book_pattern_output_files("exchangeable-bond-evidence-watch").contains(
      "raw/bootstrap/eb_extract_pdf_text.py",
    ),
  )
  assert_true(
    book_pattern_output_files("exchangeable-bond-evidence-watch").contains(
      "raw/bootstrap/eb_package_workbook.py",
    ),
  )
  assert_true(
    book_pattern_output_files("exchangeable-bond-evidence-watch").contains(
      "raw/analysis-runs/eb-contract-verification.json",
    ),
  )
  assert_true(
    book_pattern_output_files("exchangeable-bond-evidence-watch").contains(
      eb_prompt_contract_receipt_relative_path(),
    ),
  )
  assert_true(
    book_pattern_output_files("exchangeable-bond-evidence-watch").contains(
      eb_expected_output_contract_relative_path(),
    ),
  )
  assert_true(
    book_pattern_output_files("exchangeable-bond-evidence-watch").contains(
      "raw/analysis-runs/eb-output-validation.json",
    ),
  )
  let expected_output_contract = eb_expected_output_contract_json(book_id)
  assert_true(eb_expected_output_contract_valid(expected_output_contract))
  assert_eq(
    json_string(expected_output_contract, "filename_pattern", default=""),
    "EB追踪_[债券代码]_[债券简称]_[YYYYMMDD].xlsx",
  )
  assert_eq(
    json_string(expected_output_contract, "output_directory", default=""),
    "book/outputs/",
  )
  assert_true(
    json_string(expected_output_contract, "multi_bond_rule", default="").contains(
      "Sheet 1 rows by bond code",
    ),
  )
  assert_true(
    json_string(expected_output_contract, "multi_bond_rule", default="").contains(
      "one Sheet 2 row per bond",
    ),
  )
  assert_eq(json_array_items(expected_output_contract, "sheets").length(), 2)
  assert_true(
    eb_expected_output_contract_has_sheet(
      expected_output_contract,
      "公告追踪主表",
      eb_announcement_sheet_headers(),
    ),
  )
  assert_true(
    eb_expected_output_contract_has_sheet(
      expected_output_contract,
      "关键指标监控表",
      eb_indicator_sheet_headers(),
    ),
  )
  let eb_handoff_output_contract = pdf_watch_output_contract_handoff(
    "exchangeable-bond-evidence-watch",
  )
  assert_eq(
    json_string(eb_handoff_output_contract, "output_contract", default=""),
    "moondesk.exchangeable_bond_tracking.xlsx.v1",
  )
  assert_eq(
    json_string(
      eb_handoff_output_contract,
      "expected_output_contract_path",
      default="",
    ),
    eb_expected_output_contract_relative_path(),
  )
  assert_eq(
    json_string(
      eb_handoff_output_contract,
      "output_validation_path",
      default="",
    ),
    eb_output_validation_relative_path(),
  )
  let operator_prompt = eb_operator_prompt_markdown(
    "Exchangeable Bond Credit Compliance", book_id,
  )
  assert_true(operator_prompt.contains("角色设定"))
  assert_true(operator_prompt.contains("阶段1：发行与上市"))
  assert_true(operator_prompt.contains("阶段6：兑付与退出"))
  assert_true(operator_prompt.contains("七、执行指令"))
  assert_true(operator_prompt.contains("系统性信息检索"))
  assert_true(operator_prompt.contains("公告追踪主表"))
  assert_true(operator_prompt.contains("关键指标监控表"))
  assert_true(operator_prompt.contains("Sheet 1 中按债券代码分组"))
  assert_true(operator_prompt.contains("Sheet 2 每只债券占一行"))
  assert_true(
    operator_prompt.contains(
      "EB追踪_[债券代码]_[债券简称]_[YYYYMMDD].xlsx",
    ),
  )
  assert_true(operator_prompt.contains("Excel (.xlsx)"))
  assert_false(
    is_accepted_eb_output_name(
      "EB追踪_[债券代码]_[债券简称]_[YYYYMMDD].xlsx",
    ),
  )
  assert_true(
    is_accepted_eb_output_name("EB追踪_132001_示例EB_20260601.xlsx"),
  )
  let default_book_json = pdf_watch_book_json(
    book_id~,
    topic="Exchangeable Bond Credit Compliance",
    pattern_id="exchangeable-bond-evidence-watch",
    purpose="Official EB active universe watch",
    cadence=30,
    websites=eb_default_source_websites(),
    source_policy="web-first",
    method_path="wiki/methods/my-analysis-method.md",
    notify_on=["accepted_new_knowledge"],
  )
  let default_operator_config = pdf_watch_operator_config_json(
    default_book_json,
  )
  let default_operator_watch = json_object_field_or_empty(
    default_operator_config, "watch",
  )
  assert_eq(
    json_string(default_operator_watch, "target_scope", default=""),
    "active_universe",
  )
  assert_true(
    json_bool(default_operator_watch, "active_universe_default", default=false),
  )
  assert_eq(
    json_array_items(default_operator_watch, "official_source_seeds").length(),
    0,
  )
  assert_eq(
    json_string(default_operator_watch, "discovery_mode", default=""),
    "dynamic_official_source_search",
  )
  let active_universe_request = eb_tracking_request_json(
    book_id,
    "Exchangeable Bond Credit Compliance",
    eb_default_source_websites(),
  )
  assert_eq(
    json_string(active_universe_request, "target_scope", default=""),
    "active_universe",
  )
  assert_eq(
    json_array_items(active_universe_request, "target_bonds").length(),
    0,
  )
  assert_eq(
    json_array_items(active_universe_request, "official_pdf_seeds").length(),
    0,
  )
  assert_eq(
    json_array_items(active_universe_request, "official_source_seeds").length(),
    0,
  )
  assert_eq(
    json_string(active_universe_request, "discovery_mode", default=""),
    "dynamic_official_source_search",
  )
  let active_universe_request_text = active_universe_request.stringify()
  for code in eb_regression_active_universe_codes() {
    assert_false(active_universe_request_text.contains(code))
  }
  for url in eb_regression_active_universe_urls() {
    assert_false(active_universe_request_text.contains(url))
  }
  assert_false(active_universe_request_text.contains("static.sse.com.cn"))
  assert_false(
    active_universe_request_text.contains("minimum_expected_instrument_count"),
  )
  assert_false(
    active_universe_request_text.contains("expected_instrument_codes"),
  )
  let request_json = eb_tracking_request_json(
    book_id,
    "Exchangeable Bond Credit Compliance",
    eb_default_source_websites(),
    target_fields={
      "bond_full_name_or_short_name": "示例EB",
      "bond_code": "132001",
      "issuer": "示例发行人",
      "underlying_listed_company": "示例标的公司",
      "exchange": "上交所",
    },
    target_bonds=[
      {
        "bond_full_name_or_short_name": "示例EB",
        "bond_code": "132001",
        "issuer": "示例发行人",
        "underlying_listed_company": "示例标的公司",
        "exchange": "上交所",
      },
      {
        "bond_full_name_or_short_name": "第二只EB",
        "bond_code": "132002",
        "issuer": "第二发行人",
        "underlying_listed_company": "第二标的公司",
        "exchange": "深交所",
      },
    ],
  )
  let request = request_json.stringify()
  assert_true(request.contains("six_lifecycle_stages"))
  assert_true(request.contains("发行与上市"))
  assert_true(request.contains("132001"))
  assert_true(request.contains("示例发行人"))
  assert_true(request.contains("target_bond_count"))
  assert_eq(json_string(request_json, "target_scope", default=""), "portfolio")
  assert_true(request.contains("multi_bond_mode"))
  assert_true(request.contains("第二只EB"))
  assert_true(request.contains("If multiple bonds are configured"))
  assert_true(request.contains("standing_goal_decision"))
  assert_true(request.contains("workbook_data_proof"))
  assert_true(request.contains("appendix_notes"))
  assert_true(request.contains("quality_proof"))
  assert_true(request.contains("lifecycle_stage_proof"))
  assert_true(request.contains("official_source_seeds"))
  assert_true(request.contains("official_pdf_seeds"))
  assert_true(
    request.contains("EB追踪_[债券代码]_[债券简称]_[YYYYMMDD].xlsx"),
  )
  let first_target : Json = {
    "bond_full_name_or_short_name": "G三峡EB1",
    "bond_code": "132018",
    "issuer": "中国长江三峡集团有限公司",
    "underlying_listed_company": "长江电力",
    "exchange": "上交所",
  }
  let mirrored_target = effective_eb_target_fields(
    eb_target_fields_from_payload(Json::object({})),
    [first_target],
  )
  assert_eq(json_string(mirrored_target, "bond_code", default=""), "132018")
  assert_eq(
    json_string(mirrored_target, "bond_full_name_or_short_name", default=""),
    "G三峡EB1",
  )
  let seeded_request = eb_tracking_request_json(
    book_id,
    "Exchangeable Bond Credit Compliance",
    eb_default_source_websites(),
    target_fields=first_target,
    target_bonds=[first_target],
  ).stringify()
  assert_true(seeded_request.contains("official_source_seeds"))
  assert_true(seeded_request.contains("official_pdf_seeds"))
  assert_true(seeded_request.contains("\"ai_extractor\""))
  assert_true(seeded_request.contains("source_backing_required"))
  assert_true(seeded_request.contains("static.sse.com.cn"))
  let dispatch = eb_standing_watch_dispatch_json(
    book_id,
    "Exchangeable Bond Credit Compliance",
    eb_default_source_websites(),
    target_fields={
      "bond_full_name_or_short_name": "示例EB",
      "bond_code": "132001",
      "issuer": "示例发行人",
      "underlying_listed_company": "示例标的公司",
      "exchange": "上交所",
    },
    target_bonds=[
      { "bond_full_name_or_short_name": "示例EB", "bond_code": "132001" },
      { "bond_full_name_or_short_name": "第二只EB", "bond_code": "132002" },
    ],
  ).stringify()
  assert_true(dispatch.contains("moontown-standing-watch-dispatch"))
  assert_true(dispatch.contains("MoonClaw"))
  assert_true(dispatch.contains("Bookkeeper"))
  assert_true(dispatch.contains("standing_goal_decision"))
  assert_true(dispatch.contains("accepted_facts_count"))
  assert_true(dispatch.contains("target_bond_count"))
  assert_true(dispatch.contains("第二只EB"))
  assert_true(dispatch.contains("sse.com.cn"))
  assert_true(dispatch.contains("workbook_data_proof"))
  assert_true(dispatch.contains("appendix_notes"))
  assert_true(dispatch.contains("quality_proof"))
  assert_true(dispatch.contains("lifecycle_stage_proof"))
  let moonclaw_profile = eb_moonclaw_profile_json().stringify()
  assert_true(moonclaw_profile.contains("eb_pdf_evidence_watch"))
  assert_true(moonclaw_profile.contains("\"role\":\"eb_pdf_evidence_worker\""))
  assert_false(moonclaw_profile.contains("\"role\":\"controller\""))
  assert_true(moonclaw_profile.contains("package_result"))
  assert_true(moonclaw_profile.contains("workbook_data_proof"))
  assert_true(moonclaw_profile.contains("lifecycle_stage_proof"))
  assert_true(moonclaw_profile.contains("\"enable_tools\":true"))
  assert_true(moonclaw_profile.contains("\"web_search\":true"))
  assert_true(moonclaw_profile.contains("\"timeout_ms\":300000"))
  assert_true(moonclaw_profile.contains("\"max_total_tokens\":48000"))
  assert_true(moonclaw_profile.contains("\"retry_max_attempts\":1"))
  assert_true(moonclaw_profile.contains("outputs/official-pdf-candidates.json"))
  assert_true(moonclaw_profile.contains("outputs/eb-indicator-extraction.json"))
  assert_true(moonclaw_profile.contains("structured AI facts"))
  assert_true(
    moonclaw_profile.contains("raw/bootstrap/eb_discover_pdf_candidates.py"),
  )
  assert_true(moonclaw_profile.contains("ai_discovery_required=true"))
  assert_true(moonclaw_profile.contains("do not use a minimum, maximum"))
  assert_false(moonclaw_profile.contains("configured official_source_seeds"))
  assert_true(moonclaw_profile.contains("raw/bootstrap/eb_extract_pdf_text.py"))
  assert_true(moonclaw_profile.contains("raw/bootstrap/eb_package_workbook.py"))
  assert_true(moonclaw_profile.contains("official_source_screened"))
  assert_true(
    moonclaw_profile.contains(
      "Do not convert incomplete lifecycle coverage into a runtime needs_input verdict",
    ),
  )
  assert_true(
    moonclaw_profile.contains(
      "Do not convert partial discovery or inaccessible dynamic pages into a runtime needs_input verdict",
    ),
  )
  assert_true(moonclaw_profile.contains("current-run candidate driven"))
  assert_true(moonclaw_profile.contains("refuses to reuse stale local PDFs"))
  assert_true(
    moonclaw_profile.contains(
      "Do not convert partial extraction/source-screen coverage into a runtime needs_input verdict",
    ),
  )
  assert_true(moonclaw_profile.contains("source_records with official URLs"))
  assert_true(
    moonclaw_profile.contains(
      "python3 ../../raw/bootstrap/eb_package_workbook.py",
    ),
  )
  assert_true(moonclaw_profile.contains("\"web_fetch\":true"))
  assert_true(moonclaw_profile.contains("\"role_runtime\""))
  assert_true(
    moonclaw_profile.contains("\"role_id\":\"eb_pdf_evidence_worker\""),
  )
  assert_true(moonclaw_profile.contains("\"planning_layer\":\"execution\""))
  assert_true(moonclaw_profile.contains("\"runtime_mode\":\"executor\""))
  assert_true(moonclaw_profile.contains("\"tool_access\":\"full\""))
  assert_true(moonclaw_profile.contains("\"allow_execution_tools\":true"))
  assert_true(moonclaw_profile.contains("\"required_runtime_tools\""))
  assert_true(moonclaw_profile.contains("\"disable_waiting_for_input\":true"))
  assert_true(
    moonclaw_profile.contains("\"best_effort_on_missing_input\":false"),
  )
  let moonclaw_packet = eb_moonclaw_proposal_packet_json(
    "/tmp/book",
    book_id,
    "Exchangeable Bond Credit Compliance",
    eb_default_source_websites(),
    target_fields={
      "bond_full_name_or_short_name": "示例EB",
      "bond_code": "132001",
      "issuer": "示例发行人",
      "underlying_listed_company": "示例标的公司",
      "exchange": "上交所",
    },
    target_bonds=[
      { "bond_full_name_or_short_name": "示例EB", "bond_code": "132001" },
      { "bond_full_name_or_short_name": "第二只EB", "bond_code": "132002" },
    ],
  ).stringify()
  assert_true(moonclaw_packet.contains("eb_pdf_evidence_watch"))
  assert_true(moonclaw_packet.contains("raw/inbox/eb-tracking-request.json"))
  assert_true(moonclaw_packet.contains("target_bond_count"))
  assert_true(moonclaw_packet.contains("第二只EB"))
  assert_true(
    moonclaw_packet.contains("moondesk.exchangeable_bond_tracking.xlsx.v1"),
  )
  assert_true(moonclaw_packet.contains("CNInfo"))
  assert_true(moonclaw_packet.contains("expected-but-missing"))
  assert_true(moonclaw_packet.contains("official URLs"))
  assert_true(moonclaw_packet.contains(".xlsx.validation.json"))
  assert_true(moonclaw_packet.contains("sample_run"))
  assert_true(moonclaw_packet.contains("workbook_data_proof"))
  assert_true(moonclaw_packet.contains("appendix_notes"))
  assert_true(moonclaw_packet.contains("quality_proof"))
  assert_true(moonclaw_packet.contains("lifecycle_stage_proof"))
  assert_true(moonclaw_packet.contains("readable Excel formatting"))
  assert_true(
    moonclaw_packet.contains(
      "Incomplete official evidence is not operator input",
    ),
  )
  assert_true(
    moonclaw_packet.contains("Extraction is current-run candidate driven"),
  )
  assert_true(
    moonclaw_packet.contains(
      "Partial discovery/extraction is not operator input",
    ),
  )
  assert_true(moonclaw_packet.contains("\"enable_tools\":true"))
  assert_true(moonclaw_packet.contains("\"web_search\":true"))
  assert_true(moonclaw_packet.contains("\"timeout_ms\":300000"))
  assert_true(moonclaw_packet.contains("\"max_total_tokens\":48000"))
  assert_true(moonclaw_packet.contains("\"retry_max_attempts\":1"))
  assert_true(moonclaw_packet.contains("outputs/official-pdf-candidates.json"))
  assert_true(moonclaw_packet.contains("outputs/eb-indicator-extraction.json"))
  assert_true(moonclaw_packet.contains("source-backed AI fact fallback"))
  assert_true(
    moonclaw_packet.contains("snippet copied from official extracted text"),
  )
  assert_true(
    moonclaw_packet.contains("raw/bootstrap/eb_discover_pdf_candidates.py"),
  )
  assert_true(moonclaw_packet.contains("configured_target_source_adapter"))
  assert_true(moonclaw_packet.contains("official-source-seeds"))
  assert_true(moonclaw_packet.contains("official_source_seeds"))
  assert_true(moonclaw_packet.contains("source_adapter"))
  assert_true(moonclaw_packet.contains("raw/bootstrap/eb_extract_pdf_text.py"))
  assert_true(moonclaw_packet.contains("raw/bootstrap/eb_package_workbook.py"))
  assert_true(
    moonclaw_packet.contains(
      "python3 ../../raw/bootstrap/eb_extract_pdf_text.py",
    ),
  )
  assert_true(
    moonclaw_packet.contains(
      "python3 ../../raw/bootstrap/eb_package_workbook.py",
    ),
  )
  assert_true(moonclaw_packet.contains("\"web_fetch\":true"))
  assert_true(moonclaw_packet.contains("\"role_runtime\""))
  assert_true(
    moonclaw_packet.contains("\"role_id\":\"eb_pdf_evidence_worker\""),
  )
  assert_true(moonclaw_packet.contains("\"planning_layer\":\"execution\""))
  assert_true(moonclaw_packet.contains("\"runtime_mode\":\"executor\""))
  assert_true(moonclaw_packet.contains("\"tool_access\":\"full\""))
  assert_true(moonclaw_packet.contains("\"allow_execution_tools\":true"))
  assert_true(moonclaw_packet.contains("\"required_runtime_tools\""))
  assert_true(moonclaw_packet.contains("\"disable_waiting_for_input\":true"))
  assert_true(
    moonclaw_packet.contains("\"best_effort_on_missing_input\":false"),
  )
  let relative_root_packet = eb_moonclaw_proposal_packet_json(
    "../moontown/.moontown/books/\{book_id}",
    book_id,
    "Exchangeable Bond Credit Compliance",
    eb_default_source_websites(),
    target_fields={
      "bond_full_name_or_short_name": "示例EB",
      "bond_code": "132001",
      "issuer": "示例发行人",
      "underlying_listed_company": "示例标的公司",
      "exchange": "上交所",
    },
  )
  assert_true(
    @pathx.is_absolute(
      json_string(relative_root_packet, "source_path", default=""),
    ),
  )
  assert_true(
    json_string(relative_root_packet, "source_path", default="").contains(
      "/raw/inbox/eb-tracking-request.json",
    ),
  )
  assert_true(
    @pathx.is_absolute(
      json_string(
        json_object_field_or_empty(relative_root_packet, "metadata"),
        "book_root",
        default="",
      ),
    ),
  )
  let watch_contract = eb_watch_contract_markdown(
    "Exchangeable Bond Credit Compliance",
  )
  assert_true(watch_contract.contains("standing_goal_decision"))
  assert_true(watch_contract.contains("book_changed"))
  let template = eb_tracking_template_xlsx_bytes()
  assert_eq(template.length(), 3609)
  assert_eq(template[0], b'P')
  assert_eq(template[1], b'K')
  let install_config = pdf_watch_moontown_install_config(
    book_id~,
    topic="Exchangeable Bond Credit Compliance",
    pattern_id="exchangeable-bond-evidence-watch",
    purpose="Official EB tracking",
    book_root="/tmp/book",
    cadence=30,
    websites=eb_default_source_websites(),
    method_body=analysis_text,
    skill_pack=default_skill_pack_for_pattern(
      "exchangeable-bond-evidence-watch",
    ),
  )
  assert_eq(json_string(install_config, "book_id", default=""), book_id)
  assert_eq(
    json_string(install_config, "pattern_id", default=""),
    "exchangeable-bond-evidence-watch",
  )
  assert_eq(
    json_string(
      json_object_field_or_empty(install_config, "output_contract"),
      "expected_output_contract_path",
      default="",
    ),
    eb_expected_output_contract_relative_path(),
  )
  assert_eq(json_int(install_config, "cadence_ticks", default=0), 30)
  assert_eq(
    json_string(install_config, "analysis_method_path", default="missing"),
    "",
  )
  assert_eq(
    json_string(install_config, "workspace_root", default=""),
    "/tmp/book",
  )
  assert_true(json_object_field(install_config, "watch") is None)
  assert_true(json_object_field(install_config, "book_type") is None)
  assert_true(json_object_field(install_config, "skill_pack") is None)
  let publish_request = pdf_watch_moontown_template_request(
    book_id~,
    topic="Exchangeable Bond Credit Compliance",
    pattern_id="exchangeable-bond-evidence-watch",
    config_rel="book-template-configs/" + book_id + ".json",
    goal={ "id": pdf_watch_goal_id(book_id), "target_book_id": book_id },
  )
  assert_eq(
    json_string(publish_request, "template_id", default=""),
    "pdf-evidence-watch",
  )
  assert_eq(json_string(publish_request, "status", default=""), "installed")
  assert_true(
    json_string(publish_request, "summary", default="").contains(
      "standing goal",
    ),
  )
}

///|
test "eb packager preserves failed official rows in final source artifacts" {
  let script = eb_package_workbook_script()
  assert_true(script.contains("records = current_watch_records"))
  assert_true(script.contains("def first_ai_extraction(book_root, run_root)"))
  assert_true(script.contains("structured_ai_indicator_facts"))
  assert_true(script.contains("structured_ai_source_backed_fact_count"))
  assert_false(
    script.contains("records = verified_records(current_watch_records)"),
  )
}

///|
async test "eb generated extractor refuses stale PDFs without current official candidates" {
  let root = "/tmp/moondesk-eb-extractor-current-candidates-wbtest"
  let book_root = @pathx.join(root, "book")
  let run_workspace = @pathx.join(book_root, "moonclaw-jobs/run-no-candidates")
  let script_path = @pathx.join(
    book_root, "raw/bootstrap/eb_extract_pdf_text.py",
  )
  @fsx.make_directory(
    @pathx.join(book_root, "raw/bootstrap"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(
    @pathx.join(book_root, "raw/pdfs"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(
    @pathx.join(run_workspace, "outputs"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(script_path, eb_extract_pdf_text_script(), create=0o644)
  @fsx.write_to_file(
    @pathx.join(book_root, "raw/pdfs/stale-local.pdf"),
    "%PDF-1.4\n% stale fixture that must not be reused\n",
    create=0o644,
  )
  let failed_candidates : Json = {
    "status": "failed",
    "failure_reason": "dynamic official pages returned no target PDFs",
    "checked_domains": json_from_string_array(["sse.com.cn"]),
    "standing_goal_decision": "failed",
    "notify_town": false,
  }
  @fsx.write_to_file(
    @pathx.join(run_workspace, "outputs/official-pdf-candidates.json"),
    failed_candidates.stringify(indent=2) + "\n",
    create=0o644,
  )
  let (code, _stdout, _stderr) = @process.collect_output("python3", [
    script_path, "--book-root", book_root, "--run-root", run_workspace, "--screen",
    "outputs/official-source-screen.json",
  ])
  assert_true(code != 0)
  let screen = read_json_file_or_object(
    @pathx.join(run_workspace, "outputs/official-source-screen.json"),
  )
  assert_eq(json_string(screen, "status", default=""), "failed")
  assert_false(json_bool(screen, "live_fetch_performed", default=true))
  assert_eq(json_int(screen, "downloaded_pdf_count", default=-1), 0)
  assert_eq(json_int(screen, "extracted_pdf_count", default=-1), 0)
  assert_eq(json_string(screen, "standing_goal_decision", default=""), "failed")
  assert_true(
    json_string(screen, "failure_reason", default="").contains(
      "refusing to reuse stale local PDFs",
    ),
  )
}

///|
async test "eb generated discovery helper materializes official seed candidates" {
  let root = "/tmp/moondesk-eb-discovery-seeds-wbtest"
  let book_root = @pathx.join(root, "book")
  let run_workspace = @pathx.join(book_root, "moonclaw-jobs/run-seeded")
  let script_path = @pathx.join(
    book_root, "raw/bootstrap/eb_discover_pdf_candidates.py",
  )
  @fsx.make_directory(
    @pathx.join(book_root, "raw/bootstrap"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(
    @pathx.join(book_root, "raw/inbox"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(
    @pathx.join(run_workspace, "outputs"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    script_path,
    eb_discover_pdf_candidates_script(),
    create=0o644,
  )
  let target : Json = {
    "bond_full_name_or_short_name": "G三峡EB1",
    "bond_code": "132018",
    "issuer": "中国长江三峡集团有限公司",
    "underlying_listed_company": "长江电力",
    "exchange": "上交所",
  }
  let seed_fixture_path = @pathx.join(
    book_root, "raw/inbox/seeded-official-source-index.html",
  )
  @fsx.write_to_file(
    seed_fixture_path,
    "<html><body>No dynamic official candidates for this seeded fixture.</body></html>\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "raw/inbox/eb-tracking-request.json"),
    eb_tracking_request_json(
      "research-eb-seeded",
      "EB seeded discovery",
      ["file://" + seed_fixture_path],
      target_fields=target,
      target_bonds=[target],
    ).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  let (code, _stdout, _stderr) = @process.collect_output("python3", [
    script_path, "--book-root", book_root, "--run-root", run_workspace, "--output",
    "outputs/official-pdf-candidates.json", "--as-of", "20240401",
  ])
  assert_eq(code, 0)
  let candidates = read_json_file_or_object(
    @pathx.join(run_workspace, "outputs/official-pdf-candidates.json"),
  )
  assert_eq(
    json_string(candidates, "status", default=""),
    "official_candidates_ready",
  )
  assert_eq(json_int(candidates, "candidate_count", default=0), 5)
  assert_eq(json_int(candidates, "official_url_count", default=0), 5)
  assert_eq(
    json_string(candidates, "standing_goal_decision", default=""),
    "continue",
  )
  assert_true(
    candidates
    .stringify()
    .contains(
      "https://static.sse.com.cn/disclosure/bond/announcement/exchangeable/c/new/2024-03-27/132018_20240327_CFRC.pdf",
    ),
  )
  let (stale_code, _stale_stdout, _stale_stderr) = @process.collect_output(
    "python3",
    [
      script_path, "--book-root", book_root, "--run-root", run_workspace, "--output",
      "outputs/stale-official-pdf-candidates.json", "--as-of", "20260603",
    ],
  )
  assert_eq(stale_code, 2)
  let stale_candidates = read_json_file_or_object(
    @pathx.join(run_workspace, "outputs/stale-official-pdf-candidates.json"),
  )
  assert_eq(json_string(stale_candidates, "status", default=""), "failed")
  assert_true(
    json_bool(stale_candidates, "target_stale_blocked", default=false),
  )
  assert_eq(
    json_string(stale_candidates, "target_scope", default=""),
    "single_bond",
  )
  assert_true(
    json_string(stale_candidates, "failure_reason", default="").contains(
      "no official sources in the lookback window",
    ),
  )
  let active_fixture_path = @pathx.join(
    book_root, "raw/inbox/active-eb-official-source-index.html",
  )
  let active_fixture_parts : Array[String] = [
    "<html><body><h1>Active EB official source index fixture</h1>",
  ]
  for seed in eb_regression_active_universe_source_candidates() {
    let url = json_string(seed, "url", default="")
    let bond_code = json_string(seed, "bond_code", default="")
    let bond_short_name = json_string(seed, "bond_short_name", default="")
    let disclosure_date = json_string(seed, "disclosure_date", default="")
    let title = json_string(seed, "title", default="")
    active_fixture_parts.push(
      "<a href=\"\{url}\">\{bond_code} \{bond_short_name} \{disclosure_date} \{title} 可交换公司债券</a>\n",
    )
  }
  active_fixture_parts.push("</body></html>\n")
  @fsx.write_to_file(
    active_fixture_path,
    active_fixture_parts.join(""),
    create=0o644,
  )
  let active_request_json : Json = {
    "id": "research-eb-active-universe-request",
    "kind": "moonclaw-execution-request",
    "book_id": "research-eb-active-universe",
    "book_type": "research-book",
    "pattern_id": "exchangeable-bond-evidence-watch",
    "topic": "EB active universe discovery",
    "source_policy": "official-first",
    "target_scope": "active_universe",
    "active_universe_default": true,
    "discovery_mode": "dynamic_official_source_search",
    "recommended_review_instrument_count": 8,
    "watch_websites": json_from_string_array(["file://" + active_fixture_path]),
    "official_source_seeds": Json::array([]),
    "official_pdf_seeds": Json::array([]),
  }
  @fsx.write_to_file(
    @pathx.join(book_root, "raw/inbox/eb-tracking-request.json"),
    active_request_json.stringify(indent=2) + "\n",
    create=0o644,
  )
  assert_eq(
    json_array_items(active_request_json, "official_source_seeds").length(),
    0,
  )
  let (active_code, active_stdout, active_stderr) = @process.collect_output(
    "python3",
    [
      script_path, "--book-root", book_root, "--run-root", run_workspace, "--output",
      "outputs/active-universe-official-source-candidates.json", "--as-of", "20260603",
    ],
  )
  assert_eq(active_code, 0)
  assert_true(active_stdout.text().contains("\"candidate_count\": 19"))
  assert_eq(active_stderr.text(), "")
  let active_candidates = read_json_file_or_object(
    @pathx.join(
      run_workspace, "outputs/active-universe-official-source-candidates.json",
    ),
  )
  assert_eq(
    json_string(active_candidates, "status", default=""),
    "official_candidates_ready",
  )
  assert_eq(
    json_string(active_candidates, "target_scope", default=""),
    "active_universe",
  )
  assert_eq(json_int(active_candidates, "candidate_count", default=0), 19)
  assert_eq(json_int(active_candidates, "official_url_count", default=0), 19)
  assert_eq(json_int(active_candidates, "instrument_count", default=0), 8)
  assert_eq(
    json_int(
      active_candidates,
      "recommended_review_instrument_count",
      default=0,
    ),
    8,
  )
  assert_true(
    json_bool(active_candidates, "fact_based_universe_evidence", default=false),
  )
  assert_true(
    json_bool(active_candidates, "discovery_completeness_ok", default=false),
  )
  assert_eq(
    json_array_items(active_candidates, "universe_evidence_sources").length(),
    1,
  )
  assert_eq(json_int(active_candidates, "pdf_candidate_count", default=0), 13)
  assert_eq(json_int(active_candidates, "html_notice_count", default=0), 6)
  let active_text = active_candidates.stringify()
  assert_false(active_text.contains("minimum_expected_instrument_count"))
  assert_false(active_text.contains("expected_instrument_codes"))
  assert_false(active_text.contains("missing_expected_instruments"))
  for code in eb_regression_active_universe_codes() {
    assert_true(active_text.contains(code))
  }
  for url in eb_regression_active_universe_urls() {
    assert_true(active_text.contains(url))
  }
  assert_false(active_text.contains("132099"))
  assert_false(active_text.contains("132100"))
}

///|
async test "eb output validation distinguishes template from accepted workbook" {
  let book_id = "research-eb-output-validation"
  let book_root = "/tmp/moondesk-eb-output-validation-wbtest"
  let root = book_root
  let accepted_path = @pathx.join(
    book_root, "book/outputs/EB追踪_132001_示例EB_20260601.xlsx",
  )
  let accepted_manifest_path = @pathx.join(
    book_root, "book/outputs/EB追踪_132001_示例EB_20260601.xlsx.manifest.json",
  )
  let accepted_validation_path = @pathx.join(
    book_root, "book/outputs/EB追踪_132001_示例EB_20260601.xlsx.validation.json",
  )
  let fake_output_path = @pathx.join(
    book_root, "book/outputs/EB追踪_132002_坏样本_20260601.xlsx",
  )
  let wrong_hash_output_path = @pathx.join(
    book_root, "book/outputs/EB追踪_132003_哈希错_20260601.xlsx",
  )
  let wrong_hash_output_relative = "book/outputs/EB追踪_132003_哈希错_20260601.xlsx"
  let fake_named_output_relative = "book/outputs/EB追踪_132004_名义包_20260601.xlsx"
  let fake_named_output_path = @pathx.join(
    book_root, fake_named_output_relative,
  )
  let screen_path = @pathx.join(
    book_root,
    eb_source_screen_relative_path("run-output-validation"),
  )
  let candidate_path = @pathx.join(
    book_root,
    eb_pdf_candidates_relative_path("run-output-validation"),
  )
  if @fs.exists(accepted_path) {
    @fs.remove(accepted_path) catch {
      _ => ()
    }
  }
  if @fs.exists(accepted_manifest_path) {
    @fs.remove(accepted_manifest_path) catch {
      _ => ()
    }
  }
  if @fs.exists(accepted_validation_path) {
    @fs.remove(accepted_validation_path) catch {
      _ => ()
    }
  }
  if @fs.exists(fake_output_path) {
    @fs.remove(fake_output_path) catch {
      _ => ()
    }
  }
  if @fs.exists(wrong_hash_output_path) {
    @fs.remove(wrong_hash_output_path) catch {
      _ => ()
    }
  }
  if @fs.exists(fake_named_output_path) {
    @fs.remove(fake_named_output_path) catch {
      _ => ()
    }
  }
  let wrong_hash_manifest_path = @pathx.join(
    book_root,
    eb_output_manifest_relative_path(wrong_hash_output_relative),
  )
  let fake_named_manifest_path = @pathx.join(
    book_root,
    eb_output_manifest_relative_path(fake_named_output_relative),
  )
  let fake_named_validation_path = @pathx.join(
    book_root,
    eb_output_workbook_validation_relative_path(fake_named_output_relative),
  )
  if @fs.exists(wrong_hash_manifest_path) {
    @fs.remove(wrong_hash_manifest_path) catch {
      _ => ()
    }
  }
  if @fs.exists(fake_named_manifest_path) {
    @fs.remove(fake_named_manifest_path) catch {
      _ => ()
    }
  }
  if @fs.exists(fake_named_validation_path) {
    @fs.remove(fake_named_validation_path) catch {
      _ => ()
    }
  }
  if @fs.exists(screen_path) {
    @fs.remove(screen_path) catch {
      _ => ()
    }
  }
  if @fs.exists(candidate_path) {
    @fs.remove(candidate_path) catch {
      _ => ()
    }
  }
  ignore(create_pdf_watch_book_dirs(book_root))
  ignore(
    write_pdf_watch_book_files(
      book_root~,
      book_id~,
      topic="EB output validation",
      pattern_id="exchangeable-bond-evidence-watch",
      purpose="Validate workbook output readiness.",
      book_json={ "id": book_id, "pattern": "exchangeable-bond-evidence-watch" },
      method_body=default_eb_analysis_method("EB output validation"),
      websites=eb_default_source_websites(),
    ),
  )
  let initial = eb_output_validation(book_root, book_id)
  assert_true(json_bool(initial, "template_ready", default=false))
  assert_true(
    json_bool(initial, "expected_output_contract_ready", default=false),
  )
  assert_eq(
    json_string(initial, "expected_output_contract_path", default=""),
    eb_expected_output_contract_relative_path(),
  )
  assert_true(
    json_bool(initial, "template_workbook_validation_ready", default=false),
  )
  assert_false(
    json_bool(initial, "template_appendix_notes_ready", default=true),
  )
  assert_true(
    json_bool(
      initial,
      "template_internal_workbook_contract_ready",
      default=false,
    ),
  )
  assert_false(json_bool(initial, "final_output_ready", default=true))
  assert_eq(
    json_string(initial, "status", default=""),
    "template_ready_waiting_for_accepted_output",
  )
  assert_true(
    @fs.exists(@pathx.join(book_root, eb_output_validation_relative_path())),
  )
  let expected_output_contract_path = @pathx.join(
    book_root,
    eb_expected_output_contract_relative_path(),
  )
  @fs.remove(expected_output_contract_path) catch {
    _ => ()
  }
  let missing_expected_contract = eb_output_validation(book_root, book_id)
  assert_false(
    json_bool(
      missing_expected_contract,
      "expected_output_contract_ready",
      default=true,
    ),
  )
  assert_false(
    json_bool(missing_expected_contract, "template_ready", default=true),
  )
  assert_eq(
    json_string(missing_expected_contract, "status", default=""),
    "missing_or_invalid_template",
  )
  @fsx.write_to_file(
    expected_output_contract_path,
    eb_expected_output_contract_json(book_id).stringify(indent=2) + "\n",
    create=0o644,
  )
  write_bytes_file(accepted_path, eb_tracking_template_xlsx_bytes())
  assert_false(eb_xlsx_data_rows_valid(accepted_path))
  assert_false(eb_xlsx_official_hyperlinks_valid(accepted_path))
  let accepted_without_manifest = eb_output_validation(book_root, book_id)
  assert_eq(
    json_int(accepted_without_manifest, "accepted_output_count", default=0),
    1,
  )
  assert_eq(
    json_int(
      accepted_without_manifest,
      "valid_accepted_output_count",
      default=-1,
    ),
    0,
  )
  assert_eq(
    json_string(accepted_without_manifest, "status", default=""),
    "template_ready_waiting_for_accepted_output",
  )
  let missing_candidate_manifest : Json = {
    "kind": "eb-tracking-output-manifest",
    "manifest_version": "1",
    "book_id": book_id,
    "run_id": "run-output-validation",
    "bond_code": "132001",
    "bond_short_name": "示例EB",
    "as_of": "20260601",
    "xlsx_path": "book/outputs/EB追踪_132001_示例EB_20260601.xlsx",
    "xlsx_sha256": eb_file_sha256(accepted_path),
    "source_screen_path": eb_source_screen_relative_path(
      "run-output-validation",
    ),
    "output_contract": "moondesk.exchangeable_bond_tracking.xlsx.v1",
    "accepted_by_bookkeeper": true,
    "sample_run": true,
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
  }
  @fsx.write_to_file(
    accepted_manifest_path,
    missing_candidate_manifest.stringify(indent=2) + "\n",
    create=0o644,
  )
  assert_false(
    eb_output_manifest_valid(
      book_root,
      "book/outputs/EB追踪_132001_示例EB_20260601.xlsx",
      accepted_required=true,
    ),
  )
  @fsx.write_to_file(
    @pathx.join(
      book_root,
      eb_output_manifest_relative_path(
        "book/outputs/EB追踪_132001_示例EB_20260601.xlsx",
      ),
    ),
    eb_tracking_output_manifest_json(
      book_id~,
      run_id="run-output-validation",
      bond_code="132001",
      bond_short_name="示例EB",
      as_of="20260601",
      output_relative="book/outputs/EB追踪_132001_示例EB_20260601.xlsx",
      source_screen_relative=eb_source_screen_relative_path(
        "run-output-validation",
      ),
      pdf_candidates_relative=eb_pdf_candidates_relative_path(
        "run-output-validation",
      ),
      accepted_by_bookkeeper=true,
      sample_run=true,
      xlsx_sha256=eb_file_sha256(accepted_path),
    ).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  let accepted_without_validation = eb_output_validation(book_root, book_id)
  assert_eq(
    json_int(accepted_without_validation, "accepted_output_count", default=0),
    1,
  )
  assert_eq(
    json_int(
      accepted_without_validation,
      "valid_accepted_output_count",
      default=0,
    ),
    0,
  )
  assert_eq(
    json_string(accepted_without_validation, "status", default=""),
    "template_ready_waiting_for_accepted_output",
  )
  let no_appendix_validation : Json = {
    "kind": "eb-tracking-workbook-validation",
    "validation_version": "1",
    "book_id": book_id,
    "run_id": "run-output-validation",
    "xlsx_path": "book/outputs/EB追踪_132001_示例EB_20260601.xlsx",
    "xlsx_sha256": eb_file_sha256(accepted_path),
    "output_contract": "moondesk.exchangeable_bond_tracking.xlsx.v1",
    "workbook_package_valid": true,
    "headers_valid": true,
    "sample_run": true,
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
  }
  @fsx.write_to_file(
    accepted_validation_path,
    no_appendix_validation.stringify(indent=2) + "\n",
    create=0o644,
  )
  assert_true(
    eb_output_workbook_validation_valid(
      book_root, "book/outputs/EB追踪_132001_示例EB_20260601.xlsx",
    ),
  )
  assert_false(
    eb_output_appendix_notes_valid(
      book_root, "book/outputs/EB追踪_132001_示例EB_20260601.xlsx",
    ),
  )
  let accepted_without_appendix = eb_output_validation(book_root, book_id)
  assert_eq(
    json_int(
      accepted_without_appendix,
      "valid_accepted_output_count",
      default=0,
    ),
    0,
  )
  assert_eq(
    json_string(accepted_without_appendix, "status", default=""),
    "template_ready_waiting_for_accepted_output",
  )
  let no_quality_validation : Json = {
    "kind": "eb-tracking-workbook-validation",
    "validation_version": "1",
    "book_id": book_id,
    "run_id": "run-output-validation",
    "xlsx_path": "book/outputs/EB追踪_132001_示例EB_20260601.xlsx",
    "xlsx_sha256": eb_file_sha256(accepted_path),
    "output_contract": "moondesk.exchangeable_bond_tracking.xlsx.v1",
    "workbook_package_valid": true,
    "headers_valid": true,
    "sample_run": true,
    "appendix_notes": {
      "present": true,
      "search_keywords": json_from_string_array([
        "132001", "示例EB", "132001 可交换债", "示例EB 可交换债 公告",
      ]),
      "retrieval_date": "20260601",
      "information_sources": json_from_string_array(
        eb_default_source_websites(),
      ),
    },
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
  }
  @fsx.write_to_file(
    accepted_validation_path,
    no_quality_validation.stringify(indent=2) + "\n",
    create=0o644,
  )
  assert_true(
    eb_output_workbook_validation_valid(
      book_root, "book/outputs/EB追踪_132001_示例EB_20260601.xlsx",
    ),
  )
  assert_true(
    eb_output_appendix_notes_valid(
      book_root, "book/outputs/EB追踪_132001_示例EB_20260601.xlsx",
    ),
  )
  assert_false(
    eb_output_quality_proof_valid(
      book_root, "book/outputs/EB追踪_132001_示例EB_20260601.xlsx",
    ),
  )
  assert_false(
    eb_output_lifecycle_proof_valid(
      book_root, "book/outputs/EB追踪_132001_示例EB_20260601.xlsx",
    ),
  )
  let accepted_without_quality = eb_output_validation(book_root, book_id)
  assert_eq(
    json_int(accepted_without_quality, "valid_accepted_output_count", default=0),
    0,
  )
  assert_eq(
    json_string(accepted_without_quality, "status", default=""),
    "template_ready_waiting_for_accepted_output",
  )
  let no_lifecycle_validation : Json = {
    "kind": "eb-tracking-workbook-validation",
    "validation_version": "1",
    "book_id": book_id,
    "run_id": "run-output-validation",
    "xlsx_path": "book/outputs/EB追踪_132001_示例EB_20260601.xlsx",
    "xlsx_sha256": eb_file_sha256(accepted_path),
    "output_contract": "moondesk.exchangeable_bond_tracking.xlsx.v1",
    "workbook_package_valid": true,
    "headers_valid": true,
    "sample_run": true,
    "appendix_notes": {
      "present": true,
      "search_keywords": json_from_string_array([
        "132001", "示例EB", "132001 可交换债", "示例EB 可交换债 公告",
      ]),
      "retrieval_date": "20260601",
      "information_sources": json_from_string_array(
        eb_default_source_websites(),
      ),
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
    },
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
  }
  @fsx.write_to_file(
    accepted_validation_path,
    no_lifecycle_validation.stringify(indent=2) + "\n",
    create=0o644,
  )
  assert_true(
    eb_output_workbook_validation_valid(
      book_root, "book/outputs/EB追踪_132001_示例EB_20260601.xlsx",
    ),
  )
  assert_true(
    eb_output_appendix_notes_valid(
      book_root, "book/outputs/EB追踪_132001_示例EB_20260601.xlsx",
    ),
  )
  assert_true(
    eb_output_quality_proof_valid(
      book_root, "book/outputs/EB追踪_132001_示例EB_20260601.xlsx",
    ),
  )
  assert_false(
    eb_output_lifecycle_proof_valid(
      book_root, "book/outputs/EB追踪_132001_示例EB_20260601.xlsx",
    ),
  )
  let accepted_without_lifecycle = eb_output_validation(book_root, book_id)
  assert_eq(
    json_int(
      accepted_without_lifecycle,
      "valid_accepted_output_count",
      default=0,
    ),
    0,
  )
  assert_eq(
    json_string(accepted_without_lifecycle, "status", default=""),
    "template_ready_waiting_for_accepted_output",
  )
  @fsx.write_to_file(
    accepted_validation_path,
    eb_tracking_workbook_validation_json(
      book_id~,
      run_id="run-output-validation",
      output_relative="book/outputs/EB追踪_132001_示例EB_20260601.xlsx",
      sample_run=true,
      xlsx_sha256=eb_file_sha256(accepted_path),
    ).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  let accepted_without_source = eb_output_validation(book_root, book_id)
  assert_false(
    json_bool(accepted_without_source, "final_output_ready", default=true),
  )
  assert_eq(
    json_int(accepted_without_source, "accepted_output_count", default=0),
    1,
  )
  assert_eq(
    json_int(accepted_without_source, "valid_accepted_output_count", default=0),
    1,
  )
  assert_eq(
    json_string(accepted_without_source, "status", default=""),
    "accepted_output_waiting_for_source_screen",
  )
  @fsx.write_to_file(
    @pathx.join(
      book_root,
      eb_source_screen_relative_path("run-output-validation"),
    ),
    eb_official_source_screen_json(
      book_id~,
      run_id="run-output-validation",
      bond_code="132001",
      bond_short_name="示例EB",
      as_of="20260601",
    ).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  let deterministic_source_screen_path = @pathx.join(
    book_root,
    eb_source_screen_relative_path("run-output-validation"),
  )
  assert_true(eb_source_screen_valid(deterministic_source_screen_path))
  assert_false(
    eb_production_source_screen_valid(deterministic_source_screen_path),
  )
  let accepted_without_candidates = eb_output_validation(book_root, book_id)
  assert_eq(
    json_string(accepted_without_candidates, "status", default=""),
    "accepted_output_waiting_for_pdf_candidates",
  )
  assert_true(
    json_bool(
      accepted_without_candidates,
      "source_evidence_ready",
      default=false,
    ),
  )
  assert_false(
    json_bool(
      accepted_without_candidates,
      "pdf_candidate_evidence_ready",
      default=true,
    ),
  )
  assert_false(
    json_bool(accepted_without_candidates, "final_output_ready", default=true),
  )
  let candidate_artifact : Json = {
    "kind": "eb-official-pdf-candidates",
    "status": "completed",
    "run_id": "run-output-validation",
    "candidates": [
      {
        "url": "https://www.sse.com.cn/disclosure/bond/announcement/132001.pdf",
        "title": "示例EB official candidate",
      },
    ],
    "checked_domains": json_from_string_array(["sse.com.cn"]),
    "standing_goal_decision": "update",
  }
  @fsx.write_to_file(
    candidate_path,
    candidate_artifact.stringify(indent=2) + "\n",
    create=0o644,
  )
  let accepted = eb_output_validation(book_root, book_id)
  assert_true(json_bool(accepted, "source_evidence_ready", default=false))
  assert_true(
    json_bool(accepted, "pdf_candidate_evidence_ready", default=false),
  )
  assert_true(json_bool(accepted, "final_output_ready", default=false))
  assert_eq(
    json_string(accepted, "status", default=""),
    "accepted_output_ready",
  )
  let health_without_watcher = eb_durable_run_health(root, book_root, book_id)
  assert_eq(
    json_string(health_without_watcher, "output_path", default=""),
    "book/outputs/EB追踪_132001_示例EB_20260601.xlsx",
  )
  assert_eq(
    json_string(health_without_watcher, "run_id", default=""),
    "run-output-validation",
  )
  assert_true(
    json_bool(
      health_without_watcher,
      "workbook_validation_ready",
      default=false,
    ),
  )
  assert_true(
    json_bool(health_without_watcher, "source_screen_ready", default=false),
  )
  assert_false(json_bool(health_without_watcher, "durable_ready", default=true))
  assert_false(
    json_bool(health_without_watcher, "production_ready", default=true),
  )
  write_bytes_file(wrong_hash_output_path, eb_tracking_template_xlsx_bytes())
  @fsx.write_to_file(
    wrong_hash_manifest_path,
    eb_tracking_output_manifest_json(
      book_id~,
      run_id="run-output-validation",
      bond_code="132003",
      bond_short_name="哈希错",
      as_of="20260601",
      output_relative=wrong_hash_output_relative,
      source_screen_relative=eb_source_screen_relative_path(
        "run-output-validation",
      ),
      pdf_candidates_relative=eb_pdf_candidates_relative_path(
        "run-output-validation",
      ),
      accepted_by_bookkeeper=true,
      sample_run=true,
      xlsx_sha256="deadbeef",
    ).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  assert_false(
    eb_output_manifest_valid(
      book_root,
      wrong_hash_output_relative,
      accepted_required=true,
    ),
  )
  let accepted_with_wrong_hash = eb_output_validation(book_root, book_id)
  assert_eq(
    json_int(accepted_with_wrong_hash, "accepted_output_count", default=0),
    2,
  )
  assert_eq(
    json_int(accepted_with_wrong_hash, "valid_accepted_output_count", default=0),
    1,
  )
  let fake_bytes : Array[Byte] = [b'P', b'K']
  while fake_bytes.length() < 180 {
    fake_bytes.push(b'x')
  }
  write_bytes_file(fake_output_path, Bytes::from_array(fake_bytes))
  assert_false(eb_xlsx_package_valid(fake_output_path))
  let accepted_with_invalid_package = eb_output_validation(book_root, book_id)
  assert_eq(
    json_int(accepted_with_invalid_package, "accepted_output_count", default=0),
    3,
  )
  assert_eq(
    json_int(
      accepted_with_invalid_package,
      "valid_accepted_output_count",
      default=0,
    ),
    1,
  )
  assert_true(
    json_bool(
      accepted_with_invalid_package,
      "final_output_ready",
      default=false,
    ),
  )
  let fake_named_package_text = "PK\n" +
    eb_xlsx_required_package_parts().join("\n") +
    "\nnot a real zip package\n" +
    "padding-padding-padding-padding-padding-padding-padding-padding-padding-padding-padding-padding-padding-padding\n"
  @fsx.write_to_file(
    fake_named_output_path,
    fake_named_package_text,
    create=0o644,
  )
  assert_true(eb_xlsx_package_valid(fake_named_output_path))
  assert_false(eb_xlsx_internal_contract_valid(fake_named_output_path))
  @fsx.write_to_file(
    fake_named_manifest_path,
    eb_tracking_output_manifest_json(
      book_id~,
      run_id="run-output-validation",
      bond_code="132004",
      bond_short_name="名义包",
      as_of="20260601",
      output_relative=fake_named_output_relative,
      source_screen_relative=eb_source_screen_relative_path(
        "run-output-validation",
      ),
      pdf_candidates_relative=eb_pdf_candidates_relative_path(
        "run-output-validation",
      ),
      accepted_by_bookkeeper=true,
      sample_run=true,
      xlsx_sha256=eb_file_sha256(fake_named_output_path),
    ).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    fake_named_validation_path,
    eb_tracking_workbook_validation_json(
      book_id~,
      run_id="run-output-validation",
      output_relative=fake_named_output_relative,
      sample_run=true,
      xlsx_sha256=eb_file_sha256(fake_named_output_path),
    ).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  assert_false(eb_accepted_output_valid(book_root, fake_named_output_relative))
  let accepted_with_fake_named_package = eb_output_validation(
    book_root, book_id,
  )
  assert_eq(
    json_int(
      accepted_with_fake_named_package,
      "accepted_output_count",
      default=0,
    ),
    4,
  )
  assert_eq(
    json_int(
      accepted_with_fake_named_package,
      "valid_accepted_output_count",
      default=0,
    ),
    1,
  )
}
