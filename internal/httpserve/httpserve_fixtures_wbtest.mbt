///|
fn book_base_type_records() -> Array[Json] {
  [
    {
      "id": "research-book",
      "title": "Research Book",
      "description": "Durable MoonBook base for source-backed research, wiki memory, source evidence, review queues, generated sites, and standing-watch workflows.",
      "owner": "MoonBook",
      "source": "moontown-template-registry + moonbook-layout",
      "creation_palette_source": "../moontown/templates/books/templates.json",
      "moonbook_layout_refs": json_from_string_array(moonbook_layout_refs()),
      "template_registry_refs": json_from_string_array(
        pdf_watch_template_registry_refs(),
      ),
      "supported_patterns": json_from_string_array([
        "pdf-evidence-watch", "exchangeable-bond-evidence-watch",
      ]),
      "required_roots": json_from_string_array([
        "book.json", "raw/", "wiki/", "skills/", "schemas/", "site/generated/",
      ]),
    },
  ]
}

///|
async fn write_eb_populated_workbook_fixture(
  path : String,
  bond_code~ : String,
  bond_short_name~ : String,
) -> Unit {
  write_bytes_file(path, eb_tracking_template_xlsx_bytes())
  let staging = path + ".parts"
  @fsx.make_directory(staging, recursive=true, exists_ok=true)
  let _ = @process.collect_output("unzip", ["-oq", path, "-d", staging]) catch {
    _ => (1, @encoding/utf8.encode(""), @encoding/utf8.encode(""))
  }
  let sheet1_path = @pathx.join(staging, "xl/worksheets/sheet1.xml")
  let sheet2_path = @pathx.join(staging, "xl/worksheets/sheet2.xml")
  let sheet1 = @fs.read_file(sheet1_path).text() catch { _ => "" }
  let sheet2 = @fs.read_file(sheet2_path).text() catch { _ => "" }
  if sheet1 != "" {
    @fsx.write_to_file(
      sheet1_path,
      eb_add_fixture_hyperlink_to_sheet1(
        sheet1.replace_all(
          old="</sheetData>",
          new=eb_announcement_fixture_row_xml(bond_code~, bond_short_name~) +
            "</sheetData>",
        ),
      ),
      create=0o644,
    )
  }
  if sheet2 != "" {
    @fsx.write_to_file(
      sheet2_path,
      sheet2.replace_all(
        old="</sheetData>",
        new=eb_indicator_fixture_row_xml(bond_code~, bond_short_name~) +
          "</sheetData>",
      ),
      create=0o644,
    )
  }
  let sheet_rels_dir = @pathx.join(staging, "xl/worksheets/_rels")
  @fsx.make_directory(sheet_rels_dir, recursive=true, exists_ok=true)
  @fsx.write_to_file(
    @pathx.join(sheet_rels_dir, "sheet1.xml.rels"),
    eb_sheet1_hyperlink_rels_xml(
      "https://www.sse.com.cn/disclosure/bond/announcement/\{bond_code}.pdf",
    ),
    create=0o644,
  )
  @fs.remove(path) catch {
    _ => ()
  }
  let command = "cd '\{staging}' && zip -qr '\{path}' ."
  let _ = @process.collect_output("/bin/sh", ["-c", command]) catch {
    _ => (1, @encoding/utf8.encode(""), @encoding/utf8.encode(""))
  }
}

///|
fn eb_add_fixture_hyperlink_to_sheet1(sheet1_xml : String) -> String {
  let hyperlinks = "<hyperlinks><hyperlink ref=\"J2\" r:id=\"rIdHyperlink1\"/></hyperlinks>"
  if sheet1_xml.contains("</hyperlinks>") {
    sheet1_xml
  } else if sheet1_xml.contains("<pageMargins") {
    sheet1_xml.replace_all(old="<pageMargins", new=hyperlinks + "<pageMargins")
  } else {
    sheet1_xml + hyperlinks
  }
}

///|
fn eb_sheet1_hyperlink_rels_xml(url : String) -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
  "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
  "<Relationship Id=\"rIdHyperlink1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink\" Target=\"\{url}\" TargetMode=\"External\"/>" +
  "</Relationships>"
}

///|
fn eb_inline_cell_xml(cell : String, value : String) -> String {
  "<c r=\"\{cell}\" t=\"inlineStr\"><is><t>\{value}</t></is></c>"
}

///|
fn eb_announcement_fixture_row_xml(
  bond_code~ : String,
  bond_short_name~ : String,
) -> String {
  "<row r=\"2\">" +
  eb_inline_cell_xml("A2", "1") +
  eb_inline_cell_xml("B2", bond_code) +
  eb_inline_cell_xml("C2", bond_short_name) +
  eb_inline_cell_xml("D2", "发行") +
  eb_inline_cell_xml("E2", "募集说明书") +
  eb_inline_cell_xml("F2", bond_short_name + " 募集说明书") +
  eb_inline_cell_xml("G2", "2026-06-01") +
  eb_inline_cell_xml("H2", "发行人") +
  eb_inline_cell_xml("I2", "上交所") +
  eb_inline_cell_xml(
    "J2",
    "https://www.sse.com.cn/disclosure/bond/announcement/\{bond_code}.pdf",
  ) +
  eb_inline_cell_xml("K2", "官方PDF证据行。") +
  eb_inline_cell_xml("L2", "换股价格等关键数据") +
  eb_inline_cell_xml("M2", "否") +
  eb_inline_cell_xml("N2", "Bookkeeper accepted") +
  "</row>"
}

///|
fn eb_indicator_fixture_row_xml(
  bond_code~ : String,
  bond_short_name~ : String,
) -> String {
  "<row r=\"2\">" +
  eb_inline_cell_xml("A2", bond_code) +
  eb_inline_cell_xml("B2", bond_short_name) +
  eb_inline_cell_xml("C2", "10") +
  eb_inline_cell_xml("D2", "10") +
  eb_inline_cell_xml("E2", "10.00") +
  eb_inline_cell_xml("F2", "10.00") +
  eb_inline_cell_xml("G2", "0") +
  eb_inline_cell_xml("H2", "0") +
  eb_inline_cell_xml("I2", "0%") +
  eb_inline_cell_xml("J2", "1000000") +
  eb_inline_cell_xml("K2", "12") +
  eb_inline_cell_xml("L2", "1.2") +
  eb_inline_cell_xml("M2", "未开始") +
  eb_inline_cell_xml("N2", "未触发") +
  eb_inline_cell_xml("O2", "未触发") +
  eb_inline_cell_xml("P2", "AAA") +
  eb_inline_cell_xml("Q2", "正常") +
  eb_inline_cell_xml("R2", "低") +
  eb_inline_cell_xml("S2", "2026-12-01") +
  eb_inline_cell_xml("T2", "2030-06-01") +
  eb_inline_cell_xml("U2", "2026-06-01") +
  "</row>"
}

///|
fn eb_live_official_source_screen_json(
  book_id~ : String,
  run_id~ : String,
  bond_code~ : String,
  bond_short_name~ : String,
  as_of~ : String,
  official_url~ : String,
) -> Json {
  {
    "kind": "eb-official-source-screen",
    "status": "official_source_screened",
    "book_id": book_id,
    "run_id": run_id,
    "bond_code": bond_code,
    "bond_short_name": bond_short_name,
    "as_of": as_of,
    "official_domains": json_from_string_array(eb_official_domains()),
    "official_domain_count": eb_official_domains().length(),
    "screened_source_roots": json_from_string_array(eb_official_source_roots()),
    "checked_official_urls": json_from_string_array([official_url]),
    "accepted_official_urls": json_from_string_array([official_url]),
    "checked_sources_count": 1,
    "downloaded_pdf_count": 1,
    "extracted_pdf_count": 1,
    "source_records": json_from_json_array([
      {
        "url": official_url,
        "platform": if official_url.contains("sse.com.cn") {
          "上海证券交易所"
        } else {
          "官方披露平台"
        },
        "title": "\{bond_code} \{bond_short_name} official EB PDF evidence",
        "downloaded": true,
        "extracted": true,
        "download_status": "downloaded",
        "extract_status": "extracted",
        "pdf_sha256": "moonclaw-recorded-pdf-sha256",
        "extracted_text_sha256": "moonclaw-recorded-text-sha256",
        "local_pdf_path": "raw/pdfs/\{run_id}-official-evidence.pdf",
        "extracted_text_path": "raw/extracted/\{run_id}-official-evidence.txt",
      },
    ]),
    "live_fetch_performed": true,
    "missing_stage_policy": "If an expected stage has no official PDF evidence, mark 未检索到 with the reason instead of fabricating a row.",
    "quality_checks": json_from_string_array([
      "official-domain URL gate", "downloaded PDF gate", "extracted PDF text gate",
      "Bookkeeper acceptance before XLSX publication",
    ]),
    "note": "Production source-screen artifact for a live MoonClaw run. Moondesk requires this stronger shape before production reconciliation.",
  }
}

///|
fn eb_checklist_item_ok(
  checklist : Array[Json],
  id : String,
  default? : Bool = false,
) -> Bool {
  for item in checklist {
    if json_string(item, "id", default="") == id {
      return json_bool(item, "ok", default~)
    }
  }
  default
}

///|
fn eb_regression_active_universe_source_candidates() -> Array[Json] {
  [
    eb_seed_candidate(
      bond_code="132026",
      bond_short_name="G三峡EB2",
      url="https://www.sse.com.cn/disclosure/bond/announcement/exchangeable/c/new/2026-05-25/132026_20260525_7PY5.pdf",
      title="G三峡EB2 2026年付息公告",
      platform="上海证券交易所",
      disclosure_date="2026-05-25",
      lifecycle_stage="兑付与退出",
      relevance="SSE official active-universe current-window EB source.",
    ),
    eb_seed_candidate(
      bond_code="132026",
      bond_short_name="G三峡EB2",
      url="https://www.sse.com.cn/disclosure/bond/announcement/exchangeable/c/new/2026-04-30/132026_20260430_UQSO.pdf",
      title="G三峡EB2 公司债券年度报告（2025年）",
      platform="上海证券交易所",
      disclosure_date="2026-04-30",
      lifecycle_stage="存续期定期报告",
      relevance="SSE official active-universe current-window EB source.",
    ),
    eb_seed_candidate(
      bond_code="132026",
      bond_short_name="G三峡EB2",
      url="https://www.sse.com.cn/disclosure/bond/announcement/exchangeable/c/new/2026-04-30/132026_20260430_TFZH.pdf",
      title="G三峡EB2 2025年度审计报告",
      platform="上海证券交易所",
      disclosure_date="2026-04-30",
      lifecycle_stage="存续期定期报告",
      relevance="SSE official active-universe current-window EB source.",
    ),
    eb_seed_candidate(
      bond_code="132026",
      bond_short_name="G三峡EB2",
      url="https://www.sse.com.cn/disclosure/bond/announcement/exchangeable/c/new/2026-02-09/132026_20260209_0DVS.pdf",
      title="G三峡EB2 换股价格调整公告",
      platform="上海证券交易所",
      disclosure_date="2026-02-09",
      lifecycle_stage="换股期管理",
      relevance="SSE official active-universe current-window EB source.",
    ),
    eb_seed_candidate(
      bond_code="132024",
      bond_short_name="26江铜EB",
      url="https://www.sse.com.cn/disclosure/bond/announcement/exchangeable/c/new/2026-04-29/132024_20260429_YZCX.pdf",
      title="26江铜EB 公司债券年度报告（2025年）",
      platform="上海证券交易所",
      disclosure_date="2026-04-29",
      lifecycle_stage="存续期定期报告",
      relevance="SSE official active-universe current-window EB source.",
    ),
    eb_seed_candidate(
      bond_code="132024",
      bond_short_name="26江铜EB",
      url="https://www.sse.com.cn/disclosure/bond/announcement/exchangeable/c/new/2026-04-29/132024_20260429_EXPV.pdf",
      title="26江铜EB 2025年度审计报告",
      platform="上海证券交易所",
      disclosure_date="2026-04-29",
      lifecycle_stage="存续期定期报告",
      relevance="SSE official active-universe current-window EB source.",
    ),
    eb_seed_candidate(
      bond_code="132024",
      bond_short_name="26江铜EB",
      url="https://www.sse.com.cn/disclosure/bond/announcement/exchangeable/c/new/2026-04-09/132024_20260409_14IW.pdf",
      title="26江铜EB 发行结果公告",
      platform="上海证券交易所",
      disclosure_date="2026-04-09",
      lifecycle_stage="发行与上市",
      relevance="SSE official active-universe current-window EB source.",
    ),
    eb_seed_candidate(
      bond_code="132024",
      bond_short_name="26江铜EB",
      url="https://www.sse.com.cn/disclosure/bond/announcement/exchangeable/c/new/2026-04-03/132024_20260403_JAMC.pdf",
      title="26江铜EB 票面利率公告",
      platform="上海证券交易所",
      disclosure_date="2026-04-03",
      lifecycle_stage="发行与上市",
      relevance="SSE official active-universe current-window EB source.",
    ),
    eb_seed_candidate(
      bond_code="132024",
      bond_short_name="26江铜EB",
      url="https://www.sse.com.cn/disclosure/bond/announcement/exchangeable/c/new/2026-04-02/132024_20260402_DL2M.pdf",
      title="26江铜EB 发行公告",
      platform="上海证券交易所",
      disclosure_date="2026-04-02",
      lifecycle_stage="发行与上市",
      relevance="SSE official active-universe current-window EB source.",
    ),
    eb_seed_candidate(
      bond_code="132024",
      bond_short_name="26江铜EB",
      url="https://www.sse.com.cn/disclosure/bond/announcement/exchangeable/c/new/2026-04-02/132024_20260402_CCV0.pdf",
      title="26江铜EB 募集说明书",
      platform="上海证券交易所",
      disclosure_date="2026-04-02",
      lifecycle_stage="发行与上市",
      relevance="SSE official active-universe current-window EB source.",
    ),
    eb_seed_candidate(
      bond_code="117248",
      bond_short_name="26盈峰EB",
      url="https://www.szse.cn/disclosure/notice/t20260119_618637.html",
      title="关于为盈峰集团有限公司2026年面向专业投资者非公开发行可交换公司债券（第一期）提供转让服务有关事项的通知",
      platform="深圳证券交易所",
      disclosure_date="2026-01-19",
      lifecycle_stage="发行与上市",
      relevance="SZSE official active-universe current-window EB transfer-service notice.",
      source_kind="html_notice",
    ),
    eb_seed_candidate(
      bond_code="117249",
      bond_short_name="26希望KEB1",
      url="https://www.szse.cn/disclosure/notice/bond/t20260127_618744.html",
      title="关于为新希望集团有限公司2026年面向专业投资者非公开发行科技创新可交换公司债券（第一期）提供转让服务有关事项的通知",
      platform="深圳证券交易所",
      disclosure_date="2026-01-27",
      lifecycle_stage="发行与上市",
      relevance="SZSE official active-universe current-window EB transfer-service notice.",
      source_kind="html_notice",
    ),
    eb_seed_candidate(
      bond_code="117250",
      bond_short_name="26国泰E1",
      url="https://www.szse.cn/disclosure/notice/t20260129_618810.html",
      title="关于为江苏国泰国际集团股份有限公司2026年面向专业投资者非公开发行可交换公司债券（第一期）提供转让服务有关事项的通知",
      platform="深圳证券交易所",
      disclosure_date="2026-01-29",
      lifecycle_stage="发行与上市",
      relevance="SZSE official active-universe current-window EB transfer-service notice.",
      source_kind="html_notice",
    ),
    eb_seed_candidate(
      bond_code="117251",
      bond_short_name="26顺控KEB1",
      url="https://www.szse.cn/disclosure/notice/t20260204_618938.html",
      title="关于为广东顺德控股集团有限公司2026年面向专业投资者非公开发行科技创新可交换公司债券（第一期）提供转让服务有关事项的通知",
      platform="深圳证券交易所",
      disclosure_date="2026-02-04",
      lifecycle_stage="发行与上市",
      relevance="SZSE official active-universe current-window EB transfer-service notice.",
      source_kind="html_notice",
    ),
    eb_seed_candidate(
      bond_code="117252",
      bond_short_name="26九洲KEB1",
      url="https://www.szse.cn/disclosure/notice/t20260311_619372.html",
      title="关于为四川九洲投资控股集团有限公司2026年面向专业投资者非公开发行科技创新可交换公司债券（第一期）提供转让服务有关事项的通知",
      platform="深圳证券交易所",
      disclosure_date="2026-03-11",
      lifecycle_stage="发行与上市",
      relevance="SZSE official active-universe current-window EB transfer-service notice.",
      source_kind="html_notice",
    ),
    eb_seed_candidate(
      bond_code="117253",
      bond_short_name="26华邦EB",
      url="https://www.szse.cn/disclosure/notice/t20260327_619709.html",
      title="关于为华邦生命健康股份有限公司2026年面向专业投资者非公开发行科技创新可交换公司债券提供转让服务有关事项的通知",
      platform="深圳证券交易所",
      disclosure_date="2026-03-27",
      lifecycle_stage="发行与上市",
      relevance="SZSE official active-universe current-window EB transfer-service notice.",
      source_kind="html_notice",
    ),
    eb_seed_candidate(
      bond_code="117249",
      bond_short_name="26希望KEB1",
      url="https://static.cninfo.com.cn/finalpage/2026-01-24/1224946940.PDF",
      title="新希望关于控股股东2026年面向专业投资者非公开发行科技创新可交换公司债券（第一期）发行完成的公告",
      platform="巨潮资讯网",
      disclosure_date="2026-01-24",
      lifecycle_stage="发行与上市",
      relevance="CNInfo issuer-side official PDF for SZSE active-universe EB.",
    ),
    eb_seed_candidate(
      bond_code="117251",
      bond_short_name="26顺控KEB1",
      url="https://static.cninfo.com.cn/finalpage/2026-01-30/1224957105.PDF",
      title="顺控集团关于控股股东可交换公司债券发行完成相关公告",
      platform="巨潮资讯网",
      disclosure_date="2026-01-30",
      lifecycle_stage="发行与上市",
      relevance="CNInfo issuer-side official PDF for SZSE active-universe EB.",
    ),
    eb_seed_candidate(
      bond_code="117253",
      bond_short_name="26华邦EB",
      url="https://static.cninfo.com.cn/finalpage/2026-03-26/1225029841.PDF",
      title="华邦健康关于非公开发行科技创新可交换公司债券发行完成的提示性公告",
      platform="巨潮资讯网",
      disclosure_date="2026-03-26",
      lifecycle_stage="发行与上市",
      relevance="CNInfo issuer-side official PDF for SZSE active-universe EB.",
    ),
  ]
}

///|
fn eb_regression_active_universe_codes() -> Array[String] {
  let codes : Array[String] = []
  for seed in eb_regression_active_universe_source_candidates() {
    let code = json_string(seed, "bond_code", default="")
    if code != "" && !codes.contains(code) {
      codes.push(code)
    }
  }
  codes
}

///|
fn eb_regression_active_universe_urls() -> Array[String] {
  let urls : Array[String] = []
  for seed in eb_regression_active_universe_source_candidates() {
    let url = json_string(seed, "url", default="")
    if url != "" && !urls.contains(url) {
      urls.push(url)
    }
  }
  urls
}
