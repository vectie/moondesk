///|
test "resolve request path rejects traversal" {
  assert_true(
    resolve_request_path("/tmp/moondesk", "/")
    is Some("/tmp/moondesk/index.html"),
  )
  assert_true(resolve_request_path("/tmp/moondesk", "/../secret") is None)
}

///|
test "eb workbook formatting contract requires readable workbook features" {
  let formatted_sheet = "<worksheet><sheetViews><sheetView><pane state=\"frozen\"/></sheetView></sheetViews><cols><col customWidth=\"1\"/></cols><sheetData><row><c s=\"1\"/></row></sheetData><autoFilter ref=\"A1:N1\"/></worksheet>"
  let indicator_sheet = formatted_sheet.replace_all(old="A1:N1", new="A1:U1")
  let styles = "<styleSheet><fonts><font><b/></font></fonts><cellXfs><xf applyFont=\"1\"/></cellXfs></styleSheet>"
  assert_true(
    eb_xlsx_formatting_contract_valid(formatted_sheet, indicator_sheet, styles),
  )
  assert_false(
    eb_xlsx_formatting_contract_valid(
      formatted_sheet.replace_all(old="customWidth=\"1\"", new=""),
      indicator_sheet,
      styles,
    ),
  )
  assert_false(
    eb_xlsx_formatting_contract_valid(
      formatted_sheet,
      indicator_sheet,
      styles.replace_all(old="<b/>", new=""),
    ),
  )
}

///|
test "eb workbook hyperlink contract requires official external links" {
  let sheet = "<worksheet><sheetData><row r=\"2\"><c r=\"J2\"/></row></sheetData><hyperlinks><hyperlink ref=\"J2\" r:id=\"rIdHyperlink1\"/></hyperlinks></worksheet>"
  let official_rels = eb_sheet1_hyperlink_rels_xml(
    "https://www.sse.com.cn/disclosure/bond/announcement/132018.pdf",
  )
  let unofficial_rels = eb_sheet1_hyperlink_rels_xml(
    "https://example.com/repost/132018.pdf",
  )
  assert_true(eb_xlsx_sheet1_official_hyperlinks_valid(sheet, official_rels))
  assert_false(
    eb_xlsx_sheet1_official_hyperlinks_valid(
      sheet.replace_all(old="ref=\"J2\"", new="ref=\"A2\""),
      official_rels,
    ),
  )
  assert_false(eb_xlsx_sheet1_official_hyperlinks_valid(sheet, unofficial_rels))
  assert_true(
    xml_attribute_values(official_rels, "Target") ==
    ["https://www.sse.com.cn/disclosure/bond/announcement/132018.pdf"],
  )
}

///|
test "api path helpers handle queries and traversal" {
  assert_eq(
    strip_query("/api/workspaces/book/entries?path=wiki"),
    "/api/workspaces/book/entries",
  )
  assert_true(
    query_value("/api?path=wiki%2Findex.md&other=1", "path")
    is Some("wiki%2Findex.md"),
  )
  assert_eq(encode_query_value("/tmp/moon book"), "%2Ftmp%2Fmoon%20book")
  assert_eq(
    decode_query_value(encode_query_value("/tmp/moon book")),
    "/tmp/moon book",
  )
  assert_eq(decode_query_value("wiki%2Findex.md"), "wiki/index.md")
  assert_eq(
    decode_query_value(
      "book%2Foutputs%2FEB%E8%BF%BD%E8%B8%AA_%5B%E5%80%BA%E5%88%B8%E4%BB%A3%E7%A0%81%5D_%5B%E5%80%BA%E5%88%B8%E7%AE%80%E7%A7%B0%5D_%5BYYYYMMDD%5D.xlsx",
    ),
    "book/outputs/EB追踪_[债券代码]_[债券简称]_[YYYYMMDD].xlsx",
  )
  assert_true(path_segments("/api/workspaces") == ["api", "workspaces"])
  assert_true(
    clean_relative_path("wiki/../raw/README.md") is Some("raw/README.md"),
  )
  assert_true(clean_relative_path("../secret") is None)
  assert_true(clean_relative_path("/tmp/secret") is None)
}

///|
test "request body helpers handle optional strings" {
  let payload : Json = { "title": "Draft", "path": "inbox/draft.md" }
  assert_eq(json_string(payload, "title", default="Fallback"), "Draft")
  assert_true(json_string_opt(payload, "path") is Some("inbox/draft.md"))
  assert_true(json_string_opt(payload, "missing") is None)
}

///|
test "town request listing normalizes book-pattern handoff records" {
  let record : Json = {
    "id": "request-publish-research-eb-ui-audit-panel-smoke",
    "kind": "book-pattern-publish",
    "status": "ready-for-moontown",
    "book_id": "research-eb-ui-audit-panel-smoke",
    "title": "EB UI audit panel smoke Exchangeable Bond Evidence Watch",
    "pattern_id": "exchangeable-bond-evidence-watch",
    "purpose": "Standing research-book for official-source discovery.",
  }
  let listing = town_request_listing_record(
    record, "research-eb-ui-audit-panel-smoke.json",
  )
  assert_eq(
    json_string(listing, "id", default=""),
    "request-publish-research-eb-ui-audit-panel-smoke",
  )
  assert_eq(json_string(listing, "status", default=""), "ready-for-moontown")
  assert_eq(
    json_string(listing, "path", default=""),
    ".moontown/moondesk-requests/research-eb-ui-audit-panel-smoke.json",
  )
  let request = json_object_field_or_empty(listing, "request")
  assert_eq(
    json_string(request, "title", default=""),
    "EB UI audit panel smoke Exchangeable Bond Evidence Watch",
  )
  assert_eq(
    json_string(request, "book_id", default=""),
    "research-eb-ui-audit-panel-smoke",
  )
  assert_eq(
    json_string(request, "pattern_id", default=""),
    "exchangeable-bond-evidence-watch",
  )
}

///|
test "moonclaw json parser tolerates log-prefixed pretty json" {
  let parsed = parse_moonclaw_json_output(
    "{\"level\":\"Info\",\"msg\":\"started\"}\n" +
    "{\n  \"proposal_id\": \"proposal-1\",\n  \"run_id\": \"run-1\",\n  \"status\": \"WaitingForInput\"\n}\n",
  )
  assert_eq(json_string(parsed, "proposal_id", default=""), "proposal-1")
  assert_eq(json_string(parsed, "run_id", default=""), "run-1")
  assert_eq(json_string(parsed, "status", default=""), "WaitingForInput")
}

///|
test "import markdown records URL and attachment sidecar" {
  let markdown = import_markdown(
    {
      "url": "https://example.com",
      "note": "keep this",
      "data_url": "data:image/png;base64,abc",
    },
    "url",
    "Example",
  )
  assert_true(markdown.contains("# Example"))
  assert_true(markdown.contains("- URL: https://example.com"))
  assert_true(markdown.contains("keep this"))
  assert_true(markdown.contains(".data-url.txt"))
}

///|
test "calendar escaping keeps ICS text single-line" {
  let escaped = ics_escape("A, B; C\nD")
  assert_eq(escaped, "A\\, B\\; C D")
}

///|
test "standing goal records normalize host payloads" {
  let record = standing_goal_record_from_payload(
    {
      "title": "Track APIs",
      "prompt": "Watch API docs",
      "target_book_id": "research-api",
      "cadence_ticks": "0",
      "quality_threshold": 120,
      "source_policy": "web-first",
    },
    daemon_tick=42,
  )
  assert_eq(json_string(record, "id", default=""), "watch-track-apis")
  assert_eq(json_int(record, "cadence_ticks", default=0), 1)
  assert_eq(json_int(record, "quality_threshold", default=0), 100)
  assert_eq(json_int(record, "next_due_tick", default=0), 42)
}

///|
test "pdf evidence watch pattern builds reusable book and goal ids" {
  let base_types = book_base_type_records()
  assert_eq(base_types.length(), 1)
  assert_eq(json_string(base_types[0], "id", default=""), "research-book")
  assert_true(base_types[0].stringify().contains("pdf-evidence-watch"))
  assert_eq(book_pattern_base_type("pdf-evidence-watch"), "research-book")
  assert_eq(
    book_pattern_base_type("exchangeable-bond-evidence-watch"),
    "research-book",
  )
  assert_eq(
    normalize_pdf_watch_book_id(
      "research-my-domain-pdf-watch",
      topic="Ignored Topic",
      pattern_id="pdf-evidence-watch",
    ),
    "research-my-domain-pdf-watch",
  )
  let book_id = pdf_watch_book_id("Policy Reports")
  assert_eq(book_id, "research-policy-reports-pdf-watch")
  let goal = pdf_watch_standing_goal(
    book_id~,
    topic="Policy Reports",
    pattern_id="pdf-evidence-watch",
    purpose="Watch policy reports",
    cadence=30,
    source_policy="web-first",
    daemon_tick=7,
  )
  assert_eq(json_string(goal, "target_book_id", default=""), book_id)
  assert_eq(json_string(goal, "id", default=""), "watch-\{book_id}-pdfs")
  assert_eq(json_int(goal, "cadence_ticks", default=0), 30)
  assert_true(json_string(goal, "prompt", default="").contains("Bookkeeper"))
  let config = pdf_watch_book_json(
    book_id~,
    topic="Policy Reports",
    pattern_id="pdf-evidence-watch",
    purpose="Watch policy reports",
    cadence=30,
    websites=["https://example.org/reports"],
    source_policy="web-first",
    method_path="wiki/methods/analysis-method.md",
    notify_on=["accepted_new_knowledge"],
    skill_pack=["pdf-watch", "pdf-analysis", "source-screening"],
  )
  assert_eq(json_string(config, "type", default=""), "research-book")
  assert_eq(json_string(config, "book_type", default=""), "research-book")
  assert_eq(json_string(config, "pattern", default=""), "pdf-evidence-watch")
  assert_eq(
    json_string(config, "specialization", default=""),
    "pdf-evidence-watch",
  )
  let targets = json_object_field_or_empty(config, "targets")
  assert_eq(json_int(targets, "target_count", default=-1), 0)
  assert_false(json_bool(targets, "multi_target_supported", default=true))
  let watch = json_object_field_or_empty(config, "watch")
  assert_true(json_string_array_items(watch, "file_types") == ["pdf"])
  assert_true(
    json_string_array_items(watch, "notify_on") == ["accepted_new_knowledge"],
  )
  let analysis = json_object_field_or_empty(config, "analysis")
  assert_eq(
    json_string(analysis, "method_page", default=""),
    "wiki/methods/analysis-method.md",
  )
  assert_eq(
    json_string(analysis, "source_schema", default=""),
    "schemas/pdf-source.schema.md",
  )
  assert_true(
    json_string_array_items(analysis, "skills").contains("source-screening"),
  )
  assert_true(
    json_string_array_items(
      json_object_field_or_empty(config, "moondesk"),
      "skill_pack",
    ).contains("pdf-analysis"),
  )
  assert_true(
    pdf_watch_notify_on_from_payload({ "notify_on": ["new_finding"] }) ==
    ["new_finding"],
  )
  assert_true(
    pdf_watch_notify_on_from_payload({ "notify_rule": "changed_conclusion" }) ==
    ["changed_conclusion"],
  )
  let nested_payload : Json = {
    "watch": {
      "cadence_minutes": 45,
      "source_policy": "web-first",
      "websites": ["https://example.org/reports"],
    },
    "analysis": {
      "method_page": "wiki/methods/my-analysis-method.md",
      "notify_on": ["new_finding", "changed_conclusion"],
    },
  }
  assert_true(
    pdf_watch_websites_from_payload(nested_payload) ==
    ["https://example.org/reports"],
  )
  assert_eq(pdf_watch_cadence_from_payload(nested_payload), 45)
  assert_eq(pdf_watch_source_policy_from_payload(nested_payload), "web-first")
  assert_true(
    pdf_watch_notify_on_from_payload(nested_payload) ==
    ["new_finding", "changed_conclusion"],
  )
  assert_eq(
    json_string(
      eb_target_fields_from_payload({
        "target_fields": {
          "bond_full_name_or_short_name": "示例EB",
          "bond_code": "132001",
          "issuer": "示例发行人",
          "underlying_listed_company": "示例标的公司",
          "exchange": "上交所",
        },
      }),
      "bond_code",
      default="",
    ),
    "132001",
  )
  assert_eq(
    json_string(
      eb_target_fields_from_payload({
        "eb_target_fields": {
          "bond_short_name": "示例EB",
          "underlying_company": "示例标的公司",
        },
      }),
      "underlying_listed_company",
      default="",
    ),
    "示例标的公司",
  )
  let target_bonds = eb_target_bonds_from_payload({
    "target_bonds": [
      {
        "bond_code": "132001",
        "bond_short_name": "示例EB",
        "issuer": "示例发行人",
      },
      {
        "bond_code": "132002",
        "bond_short_name": "第二只EB",
        "underlying_company": "第二标的公司",
      },
    ],
  })
  assert_eq(target_bonds.length(), 2)
  assert_eq(json_string(target_bonds[0], "bond_code", default=""), "132001")
  assert_eq(
    json_string(target_bonds[1], "bond_full_name_or_short_name", default=""),
    "第二只EB",
  )
  assert_eq(
    json_string(target_bonds[1], "underlying_listed_company", default=""),
    "第二标的公司",
  )
}
