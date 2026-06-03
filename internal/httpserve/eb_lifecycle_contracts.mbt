///|
fn eb_tracking_output_schema_markdown() -> String {
  let lines : Array[String] = [
    "# EB Tracking Output Schema", "", "Filename: `EB追踪_[债券代码]_[债券简称]_[YYYYMMDD].xlsx`",
    "", "## Workbook", "", "- Format: `.xlsx` OOXML workbook", "- Required sheets: `公告追踪主表`, `关键指标监控表`",
    "- Required filename pattern: `EB追踪_[债券代码]_[债券简称]_[YYYYMMDD].xlsx`",
    "- Accepted output path: `book/outputs/`", "- Multi-bond runs: group Sheet 1 rows by bond code; Sheet 2 has one row per bond.",
    "", "## Sheet 1: 公告追踪主表", "",
  ]
  for header in eb_announcement_sheet_headers() {
    lines.push("- \{header}")
  }
  lines.push("")
  lines.push("## Sheet 2: 关键指标监控表")
  lines.push("")
  for header in eb_indicator_sheet_headers() {
    lines.push("- \{header}")
  }
  lines.push("")
  lines.push("## Required Manifest Sidecar")
  lines.push("")
  lines.push("- Path: `<workbook>.manifest.json`")
  lines.push(
    "- Required fields: `kind`, `book_id`, `run_id`, `bond_code`, `bond_short_name`, `as_of`, `xlsx_path`, `xlsx_sha256`, `source_screen_path`, `output_contract`, `accepted_by_bookkeeper`, `sample_run`, `sheets`.",
  )
  lines.push(
    "- `output_contract` must be `moondesk.exchangeable_bond_tracking.xlsx.v1`.",
  )
  lines.push("- `xlsx_sha256` must match the workbook bytes.")
  lines.push(
    "- Production outputs must set `accepted_by_bookkeeper: true` and `sample_run: false`.",
  )
  lines.push("")
  lines.push("## Required Workbook Validation Sidecar")
  lines.push("")
  lines.push("- Path: `<workbook>.validation.json`")
  lines.push(
    "- Required fields: `kind`, `book_id`, `run_id`, `xlsx_path`, `xlsx_sha256`, `output_contract`, `workbook_package_valid`, `headers_valid`, `sample_run`, `workbook_data_proof`, `appendix_notes`, `quality_proof`, `lifecycle_stage_proof`, `sheets`.",
  )
  lines.push("- `xlsx_sha256` must match the workbook bytes.")
  lines.push("- Production outputs must set `sample_run: false`.")
  lines.push(
    "- Production `workbook_data_proof` must prove positive announcement and indicator data-row counts plus official-source-backed rows, and the XLSX sheet XML must contain rows beyond the header in both required sheets.",
  )
  lines.push(
    "- Production workbooks must include OOXML hyperlink relationships for Sheet 1 `原文链接` cells, and each external target must be an official disclosure domain.",
  )
  lines.push(
    "- `appendix_notes` must prove search keywords, retrieval date, and official information-source list.",
  )
  lines.push(
    "- `quality_proof` must prove official-link-only rows, clickable official source links, summaries within 200 characters, key data emphasis, issuer/underlying cross-verification, disclosure-timing checks, Sheet 1 / Sheet 2 data reconciliation, missing-disclosure marking, and readable Excel formatting.",
  )
  lines.push(
    "- `lifecycle_stage_proof` must prove all six EB lifecycle stages were reviewed or expected-but-missing disclosures were marked `未检索到` with reasons.",
  )
  lines.push("")
  lines.push("## Lifecycle Stage Proof")
  lines.push("")
  for stage in eb_lifecycle_stage_names() {
    lines.push("- \{stage}: `covered_or_marked_missing`")
  }
  lines.push("")
  lines.push("## Official Source Screen")
  lines.push("")
  lines.push(
    "- Path: `raw/analysis-runs/*-official-source-screen.json` or MoonClaw result `outputs/official-source-screen.json`.",
  )
  lines.push(
    "- Production source screens must set `live_fetch_performed: true`, include official-domain URLs, reject third-party repost URLs, and prove positive PDF download and extraction counts.",
  )
  lines.join("\n")
}

///|
fn eb_official_domains() -> Array[String] {
  [
    "sse.com.cn", "szse.cn", "cninfo.com.cn", "chinabond.com.cn", "shclearing.com.cn",
    "csrc.gov.cn",
  ]
}

///|
fn eb_announcement_sheet_headers() -> Array[String] {
  [
    "序号", "债券代码", "债券简称", "阶段", "公告类型", "公告标题",
    "披露日期", "披露主体", "披露平台", "原文链接", "核心内容摘要",
    "关键数据", "是否触发投资者行动", "备注",
  ]
}

///|
fn eb_indicator_sheet_headers() -> Array[String] {
  [
    "债券代码", "债券简称", "发行规模（亿元）", "当前余额（亿元）",
    "初始换股价格", "最新换股价格", "换股价格调整次数", "累计换股数量（股）",
    "累计换股比例", "预备交换股票数量（股）", "担保股票市值（亿元）",
    "担保覆盖率（市值/余额）", "换股期起止日期", "赎回条款触发情况",
    "回售条款触发情况", "最新信用评级", "标的股票最新状态",
    "控制权变动风险", "下次付息日", "到期兑付日", "最后更新日期",
  ]
}

///|
fn eb_lifecycle_stage_json() -> Json {
  json_from_json_array([
    {
      "stage": "发行与上市",
      "nodes": json_from_string_array([
        "发行核准/注册公告", "募集说明书全文", "发行公告", "上市公告书",
        "担保及信托登记公告",
      ]),
    },
    {
      "stage": "存续期定期报告",
      "nodes": json_from_string_array([
        "可交债专项披露", "跟踪评级报告",
      ]),
    },
    {
      "stage": "存续期临时公告",
      "nodes": json_from_string_array([
        "换股价格调整/修正", "标的股票风险警示或暂停/终止上市",
        "预备用于交换股票权利瑕疵", "担保覆盖率重大不利变化",
        "控制权转移风险提示",
      ]),
    },
    {
      "stage": "换股期管理",
      "nodes": json_from_string_array([
        "换股开始公告", "换股进展公告", "换股期结束提示性公告",
        "投资者权益变动报告",
      ]),
    },
    {
      "stage": "赎回与回售",
      "nodes": json_from_string_array([
        "赎回触发条件满足公告", "赎回实施提示性公告", "赎回结果公告",
        "回售触发条件满足公告", "回售实施提示性公告", "回售结果公告",
      ]),
    },
    {
      "stage": "兑付与退出",
      "nodes": json_from_string_array([
        "付息公告", "本息兑付公告", "终止上市/挂牌公告", "担保股票解除质押/信托登记公告",
      ]),
    },
  ])
}

///|
fn eb_lifecycle_stage_names() -> Array[String] {
  [
    "发行与上市", "存续期定期报告", "存续期临时公告", "换股期管理",
    "赎回与回售", "兑付与退出",
  ]
}

///|
fn eb_lifecycle_stage_proof_json() -> Json {
  {
    "all_six_stages_reviewed": true,
    "missing_expected_disclosures_marked": true,
    "stages": json_from_json_array([
      {
        "stage": "发行与上市",
        "status": "covered_or_marked_missing",
        "required_nodes": json_from_string_array([
          "发行核准/注册公告", "募集说明书全文", "发行公告", "上市公告书",
          "担保及信托登记公告",
        ]),
      },
      {
        "stage": "存续期定期报告",
        "status": "covered_or_marked_missing",
        "required_nodes": json_from_string_array([
          "可交债专项披露", "跟踪评级报告",
        ]),
      },
      {
        "stage": "存续期临时公告",
        "status": "covered_or_marked_missing",
        "required_nodes": json_from_string_array([
          "换股价格调整/修正", "标的股票风险警示或暂停/终止上市",
          "预备用于交换股票权利瑕疵", "担保覆盖率重大不利变化",
          "控制权转移风险提示",
        ]),
      },
      {
        "stage": "换股期管理",
        "status": "covered_or_marked_missing",
        "required_nodes": json_from_string_array([
          "换股开始公告", "换股进展公告", "换股期结束提示性公告",
          "投资者权益变动报告",
        ]),
      },
      {
        "stage": "赎回与回售",
        "status": "covered_or_marked_missing",
        "required_nodes": json_from_string_array([
          "赎回触发条件满足公告", "赎回实施提示性公告", "赎回结果公告",
          "回售触发条件满足公告", "回售实施提示性公告", "回售结果公告",
        ]),
      },
      {
        "stage": "兑付与退出",
        "status": "covered_or_marked_missing",
        "required_nodes": json_from_string_array([
          "付息公告", "本息兑付公告", "终止上市/挂牌公告", "担保股票解除质押/信托登记公告",
        ]),
      },
    ]),
    "required_by": "EB prompt section 二 and 五: every accepted workbook must prove all six lifecycle stages were reviewed and expected-but-missing disclosures were marked with reasons.",
  }
}

///|
fn eb_outputs_readme_markdown(book_id : String) -> String {
  [
    "# EB Tracking Outputs",
    "",
    "Accepted Excel outputs for `\{book_id}` belong here.",
    "",
    "- Filename: `EB追踪_[债券代码]_[债券简称]_[YYYYMMDD].xlsx`",
    "- Do not publish no-change scans.",
    "- Include source URLs and review status in every row that changes the baseline.",
  ].join("\n")
}

///|
fn eb_discover_pdf_candidates_script() -> String {
  [
    "#!/usr/bin/env python3", "import argparse", "import calendar", "import datetime",
    "import json", "import re", "import urllib.parse", "import urllib.request", "from pathlib import Path",
    "", "OFFICIAL_DOMAINS = ['sse.com.cn', 'szse.cn', 'cninfo.com.cn', 'chinabond.com.cn', 'shclearing.com.cn', 'csrc.gov.cn']",
    "", "def load_json(path):", "    if not path.exists():", "        return {}",
    "    try:", "        return json.loads(path.read_text(encoding='utf-8'))", "    except Exception:",
    "        return {}", "", "def official_url(url):", "    return isinstance(url, str) and url.startswith(('http://', 'https://')) and any(domain in url for domain in OFFICIAL_DOMAINS)",
    "", "def seed_items(data):", "    items = []", "    for key in ['official_source_seeds', 'official_pdf_seeds', 'pdf_seed_candidates', 'seed_pdf_candidates']:",
    "        value = data.get(key)", "        if isinstance(value, list):", "            items.extend([item for item in value if isinstance(item, dict)])",
    "    for key in ['watch', 'targets', 'source_adapter']:", "        value = data.get(key)",
    "        if isinstance(value, dict):", "            items.extend(seed_items(value))",
    "    return items", "", "def normalize_seed(seed, index):", "    url = seed.get('url') or seed.get('pdf_url') or seed.get('source_url') or ''",
    "    if not official_url(url):", "        return None", "    lower_url = url.lower()",
    "    source_kind = str(seed.get('source_kind') or '').strip().lower()", "    if not source_kind:",
    "        source_kind = 'pdf' if '.pdf' in lower_url else ('html_notice' if lower_url.endswith('.html') or '.html?' in lower_url else 'official_source')",
    "    title = seed.get('title') or seed.get('name') or url.rsplit('/', 1)[-1]",
    "    source_type = seed.get('source_type') or ('official-pdf-seed' if source_kind == 'pdf' else ('official-html-notice-seed' if source_kind == 'html_notice' else 'official-source-seed'))",
    "    return {", "        'title': title,", "        'url': url,", "        'platform': seed.get('platform') or next((domain for domain in OFFICIAL_DOMAINS if domain in url), 'official'),",
    "        'disclosure_date': seed.get('disclosure_date') or '',", "        'lifecycle_stage': seed.get('lifecycle_stage') or '',",
    "        'relevance': seed.get('relevance') or 'configured official source seed',",
    "        'source_kind': source_kind,", "        'source_type': source_type,",
    "        'source_policy': seed.get('source_policy') or 'official-first',", "        'bond_code': seed.get('bond_code') or '',",
    "        'bond_short_name': seed.get('bond_short_name') or '',", "        'discovered_from': seed.get('discovered_from') or '',",
    "        'rank': index + 1,", "    }", "", "def watch_websites(data):", "    sites = []",
    "    for key in ['watch_websites', 'websites']:", "        value = data.get(key)",
    "        if isinstance(value, list):", "            sites.extend([item for item in value if isinstance(item, str)])",
    "    for key in ['watch', 'source_adapter']:", "        value = data.get(key)",
    "        if isinstance(value, dict):", "            sites.extend(watch_websites(value))",
    "    deduped = []", "    for site in sites:", "        if site not in deduped:",
    "            deduped.append(site)", "    return deduped", "", "def normalize_target_scope(value):",
    "    clean = str(value or '').strip().lower().replace('-', '_')", "    if clean in ['active_universe', 'universe', 'active']:",
    "        return 'active_universe'", "    if clean in ['portfolio', 'multi_bond', 'multi']:",
    "        return 'portfolio'", "    if clean in ['single_bond', 'single']:", "        return 'single_bond'",
    "    return ''", "", "def target_has_identity(target):", "    if not isinstance(target, dict):",
    "        return False", "    return any(str(target.get(key) or '').strip() for key in ['bond_code', 'bond_full_name_or_short_name', 'bond_short_name', 'issuer', 'underlying_listed_company'])",
    "", "def configured_target_bonds(request, book):", "    bonds = [item for item in (request.get('target_bonds') if isinstance(request.get('target_bonds'), list) else []) if isinstance(item, dict) and target_has_identity(item)]",
    "    if bonds:", "        return bonds", "    book_targets = book.get('targets') if isinstance(book.get('targets'), dict) else {}",
    "    bonds = [item for item in (book_targets.get('bonds') if isinstance(book_targets.get('bonds'), list) else []) if isinstance(item, dict) and target_has_identity(item)]",
    "    fields = request.get('target_fields') if isinstance(request.get('target_fields'), dict) else {}",
    "    if not bonds and target_has_identity(fields):", "        bonds = [fields]",
    "    return bonds", "", "def target_scope(request, book, bonds):", "    book_targets = book.get('targets') if isinstance(book.get('targets'), dict) else {}",
    "    scope = normalize_target_scope(request.get('target_scope') or book_targets.get('target_scope'))",
    "    if scope:", "        return scope", "    return 'portfolio' if len(bonds) > 1 else ('single_bond' if bonds else 'active_universe')",
    "", "def target_keywords(request, scope, bonds):", "    keywords = []", "    if scope == 'active_universe':",
    "        keywords.extend(['可交换公司债券', '可交换债', '交换公司债券', '换股', '赎回', '回售'])",
    "    else:", "        for target in bonds:", "            for key in ['bond_code', 'bond_full_name_or_short_name', 'bond_short_name', 'issuer', 'underlying_listed_company']:",
    "                value = str(target.get(key) or '').strip()", "                if value:",
    "                    keywords.append(value)", "        keywords.extend(['可交换公司债券', '可交换债', '交换公司债券'])",
    "    deduped = []", "    for item in keywords:", "        if item and item not in deduped:",
    "            deduped.append(item)", "    return deduped", "", "def target_label(target):",
    "    return str(target.get('bond_code') or target.get('bond_full_name_or_short_name') or target.get('bond_short_name') or target.get('issuer') or 'unknown-target')",
    "", "def target_text(target):", "    return ' '.join(str(target.get(key) or '') for key in ['bond_code', 'bond_full_name_or_short_name', 'bond_short_name', 'issuer', 'underlying_listed_company', 'lifecycle_status', 'maturity_date'])",
    "", "def target_matches_candidate(target, candidate):", "    blob = ' '.join(str(candidate.get(key) or '') for key in ['bond_code', 'bond_short_name', 'title', 'url', 'relevance'])",
    "    for key in ['bond_code', 'bond_full_name_or_short_name', 'bond_short_name', 'issuer', 'underlying_listed_company']:",
    "        value = str(target.get(key) or '').strip()", "        if value and value in blob:",
    "            return True", "    return False", "", "def filter_dynamic_candidates_for_scope(candidates, scope, target_bonds):",
    "    if scope == 'active_universe' or not target_bonds:", "        return candidates",
    "    filtered = []", "    for candidate in candidates:", "        if any(target_matches_candidate(target, candidate) for target in target_bonds):",
    "            filtered.append(candidate)", "    return filtered", "", "def target_stale_reason(target):",
    "    text = target_text(target).lower()", "    stale_tokens = ['redeemed', 'delisted', 'matured', 'expired', 'stopped', '已兑付', '摘牌', '终止上市', '停止换股', '到期']",
    "    if any(token in text for token in stale_tokens):", "        return 'target metadata indicates redeemed, delisted, matured, or exchange-stopped status'",
    "    if str(target.get('bond_code') or '') == '132018' or 'G三峡EB1' in target_text(target):",
    "        return 'known historical EB example 132018/G三峡EB1 matured and delisted in 2024'",
    "    return ''", "", "def stale_target_warnings(scope, bonds, candidates):",
    "    if scope == 'active_universe':", "        return []", "    warnings = []",
    "    for target in bonds:", "        reason = target_stale_reason(target)", "        if not reason:",
    "            continue", "        recent = [item for item in candidates if item.get('within_lookback') and target_matches_candidate(target, item)]",
    "        if not recent:", "            warnings.append({'target': target_label(target), 'reason': reason, 'lookback_recent_source_count': 0, 'action': 'remove from current watch target or keep only as historical baseline'})",
    "    return warnings", "", "def configured_recommended_instrument_count(request, book):",
    "    values = []", "    for data in [request, book]:", "        if isinstance(data, dict):",
    "            for key in ['recommended_review_instrument_count', 'recommended_instrument_count']:",
    "                value = data.get(key)", "                if isinstance(value, int) and value > 0:",
    "                    values.append(value)", "            for key in ['watch', 'targets', 'source_adapter']:",
    "                nested = data.get(key)", "                if isinstance(nested, dict):",
    "                    value = configured_recommended_instrument_count(nested, {})",
    "                    if value > 0:", "                        values.append(value)",
    "    return max(values) if values else 0", "", "def source_kind_for_url(url):",
    "    lower_url = str(url or '').lower()", "    if '.pdf' in lower_url:", "        return 'pdf'",
    "    if lower_url.endswith('.html') or '.html?' in lower_url or '.html#' in lower_url:",
    "        return 'html_notice'", "    return 'official_source'", "", "def official_source_link(url, window, keywords):",
    "    if not official_url(url):", "        return False", "    kind = source_kind_for_url(url)",
    "    blob = url + ' ' + window", "    has_eb_signal = any(token in blob for token in ['可交换公司债券', '可交换债', '交换公司债券', 'EB', 'KEB', '换股'])",
    "    has_keyword = not keywords or any(keyword in blob for keyword in keywords)",
    "    return (kind == 'pdf' and has_keyword) or (kind == 'html_notice' and has_eb_signal and has_keyword)",
    "", "def infer_bond_code(url, window):", "    for text in [url, window]:", "        match = re.search(r'\\b(1[13][0-9]{4})\\b', text)",
    "        if match:", "            return match.group(1)", "    return ''", "",
    "def infer_disclosure_date(url, window):", "    for text in [url, window]:",
    "        match = re.search(r'(20[0-9]{2})[-_/]?(0[1-9]|1[0-2])[-_/]?([0-2][0-9]|3[01])', text)",
    "        if match:", "            return f'{match.group(1)}-{match.group(2)}-{match.group(3)}'",
    "    return ''", "", "def fetch_web_pdf_candidates(websites, keywords, start_index):",
    "    candidates, errors = [], []", "    pattern = re.compile(r'''(?:href=|url\\()\\s*[\"']?([^\"'()<>\\s]+(?:\\.pdf|\\.html)(?:\\?[^\"'()<>\\s]*)?)[\"']?''', re.IGNORECASE)",
    "    for site in websites:", "        try:", "            request = urllib.request.Request(site, headers={'User-Agent': 'Moondesk PDF evidence watch'})",
    "            with urllib.request.urlopen(request, timeout=8) as response:", "                text = response.read(2000000).decode('utf-8', errors='ignore')",
    "        except Exception as exc:", "            errors.append({'website': site, 'error': str(exc)})",
    "            continue", "        for match in pattern.finditer(text):", "            url = urllib.parse.urljoin(site, match.group(1))",
    "            anchor_start = text.rfind('<a', 0, match.start())", "            if anchor_start == -1:",
    "                anchor_start = match.start()", "            anchor_end = text.find('</a>', match.end())",
    "            if anchor_end == -1:", "                anchor_end = min(len(text), match.end() + 240)",
    "            else:", "                anchor_end = min(len(text), anchor_end + 4)",
    "            window = text[anchor_start:anchor_end]", "            if not official_source_link(url, window, keywords):",
    "                continue", "            title = re.sub(r'<[^>]+>', ' ', window)",
    "            title = re.sub(r'\\s+', ' ', title).strip()[:120] or url.rsplit('/', 1)[-1]",
    "            source_kind = source_kind_for_url(url)", "            source_type = 'official-web-pdf-link' if source_kind == 'pdf' else ('official-web-html-notice-link' if source_kind == 'html_notice' else 'official-web-source-link')",
    "            candidates.append({'title': title, 'url': url, 'platform': next((domain for domain in OFFICIAL_DOMAINS if domain in url), 'official'), 'disclosure_date': infer_disclosure_date(url, window), 'lifecycle_stage': '', 'relevance': 'discovered from configured official-source page link', 'source_kind': source_kind, 'source_type': source_type, 'source_policy': 'web-first', 'bond_code': infer_bond_code(url, window), 'bond_short_name': '', 'rank': start_index + len(candidates) + 1, 'discovered_from': site})",
    "    return candidates, errors", "", "def fetch_text(url, timeout=8):", "    request = urllib.request.Request(url, headers={'User-Agent': 'Moondesk PDF evidence watch', 'Referer': 'https://www.sse.com.cn/'})",
    "    with urllib.request.urlopen(request, timeout=timeout) as response:", "        return response.read(3000000).decode('utf-8', errors='ignore')",
    "", "def eb_title_signal(title):", "    blob = str(title or '')", "    return any(token in blob for token in ['可交换公司债券', '可交换债券', '科技创新可交换', 'KEB', 'EB'])",
    "", "def szse_notice_pages(websites):", "    pages = []", "    if any('szse.cn' in site for site in websites):",
    "        for base in ['https://www.szse.cn/disclosure/notice/bond/', 'https://www.szse.cn/disclosure/notice/']:",
    "            pages.append(base + 'index.html')", "            for index in range(1, 16):",
    "                pages.append(base + 'index_' + str(index) + '.html')", "    return pages",
    "", "def fetch_szse_notice_candidates(websites, start_index):", "    candidates, errors = [], []",
    "    block_pattern = re.compile(r\"var\\s+curHref\\s*=\\s*'([^']+)';.*?var\\s+curTitle\\s*=\\s*'([^']*)';.*?<span class=\\\"time\\\">\\s*([0-9]{4}-[0-9]{2}-[0-9]{2})\\s*</span>\", re.DOTALL)",
    "    consecutive_failures = 0", "    for page in szse_notice_pages(websites):",
    "        try:", "            text = fetch_text(page, timeout=5)", "        except Exception as exc:",
    "            errors.append({'website': page, 'error': str(exc)})", "            consecutive_failures += 1",
    "            if consecutive_failures >= 2:", "                break", "            continue",
    "        consecutive_failures = 0", "        for match in block_pattern.finditer(text):",
    "            href, title, date = match.group(1), re.sub(r'\\\\s+', ' ', match.group(2)).strip(), match.group(3)",
    "            if not eb_title_signal(title):", "                continue", "            url = urllib.parse.urljoin(page, href)",
    "            if not official_url(url):", "                continue", "            candidates.append({'title': title, 'url': url, 'platform': '深圳证券交易所', 'disclosure_date': date, 'lifecycle_stage': '', 'relevance': 'discovered from SZSE official notice page', 'source_kind': 'html_notice', 'source_type': 'official-szse-html-notice', 'source_policy': 'official-first', 'bond_code': infer_bond_code(url, title), 'bond_short_name': '', 'rank': start_index + len(candidates) + 1, 'discovered_from': page})",
    "    return candidates, errors", "", "def clean_html_text(value):", "    text = re.sub(r'<[^>]+>', '', str(value or ''))",
    "    return re.sub(r'\\s+', ' ', text).strip()", "", "def szse_row_date(row):",
    "    value = row.get('docpubtime')", "    if isinstance(value, (int, float)):",
    "        try:", "            return datetime.datetime.fromtimestamp(value / 1000).date()",
    "        except Exception:", "            pass", "    url = str(row.get('docpuburl') or row.get('docpubjsonurl') or '')",
    "    match = re.search(r't(20[0-9]{6})_', url)", "    if match:", "        try:",
    "            return datetime.datetime.strptime(match.group(1), '%Y%m%d').date()",
    "        except Exception:", "            pass", "    return None", "", "def fetch_szse_search_candidates(websites, start_index, start, as_of_date):",
    "    if not any('szse.cn' in site for site in websites):", "        return [], []",
    "    endpoint = 'https://www.szse.cn/api/search/content'", "    headers = {'User-Agent': 'Moondesk PDF evidence watch', 'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8', 'Referer': 'https://www.szse.cn/disclosure/notice/bond/index.html'}",
    "    candidates, errors, seen = [], [], set()", "    for keyword in ['可交换公司债券', '可交换债']:",
    "        for page in range(1, 8):", "            form = urllib.parse.urlencode([('keyword', keyword), ('range', 'title'), ('channelCode[]', 'bond_news'), ('currentPage', str(page)), ('pageSize', '20'), ('time', '0')]).encode('utf-8')",
    "            try:", "                request = urllib.request.Request(endpoint, data=form, headers=headers)",
    "                with urllib.request.urlopen(request, timeout=8) as response:",
    "                    data = json.loads(response.read(3000000).decode('utf-8', errors='ignore'))",
    "            except Exception as exc:", "                errors.append({'website': endpoint, 'keyword': keyword, 'page': page, 'error': str(exc)})",
    "                break", "            rows = data.get('data') if isinstance(data.get('data'), list) else []",
    "            if not rows:", "                break", "            older_rows = 0",
    "            for row in rows:", "                if not isinstance(row, dict):",
    "                    continue", "                date = szse_row_date(row)",
    "                if date and date < start:", "                    older_rows += 1",
    "                    continue", "                if date and date > as_of_date:",
    "                    continue", "                title = clean_html_text(row.get('doctitle') or row.get('doccontent') or '')",
    "                if not eb_title_signal(title):", "                    continue",
    "                raw_url = str(row.get('docpuburl') or row.get('docpubjsonurl') or '')",
    "                if not raw_url:", "                    continue", "                url = urllib.parse.urljoin('https://www.szse.cn/', raw_url)",
    "                if url.startswith('http://'):", "                    url = 'https://' + url[len('http://'):]",
    "                if not official_url(url) or url in seen:", "                    continue",
    "                seen.add(url)", "                candidates.append({'title': title, 'url': url, 'platform': '深圳证券交易所', 'disclosure_date': date.isoformat() if date else '', 'lifecycle_stage': '', 'relevance': 'discovered from SZSE official search API', 'source_kind': 'html_notice', 'source_type': 'official-szse-search-api', 'source_policy': 'official-first', 'bond_code': infer_bond_code(url, title), 'bond_short_name': '', 'rank': start_index + len(candidates) + 1, 'discovered_from': endpoint + '?keyword=' + urllib.parse.quote(keyword)})",
    "            if older_rows == len(rows):", "                break", "    return candidates, errors",
    "", "def fetch_sse_exchangeable_candidates(websites, start_index, start, as_of_date):",
    "    if not any('sse.com.cn' in site for site in websites):", "        return [], []",
    "    params = {", "        'jsonCallBack': 'jsonpCallback', 'isPagination': 'true', 'pageHelp.pageSize': '100',",
    "        'pageHelp.pageNo': '1', 'pageHelp.cacheSize': '1', 'type': 'inParams',",
    "        'sqlId': 'BS_ZQ_GGLL', 'sseDate': start.isoformat() + ' 00:00:00',",
    "        'sseDateEnd': as_of_date.isoformat() + ' 23:59:59', 'securityCode': '',",
    "        'title': '', 'orgBulletinType': '', 'bondType': 'EXCHANGEABLE_COMPANY_BOND_BULLETIN',",
    "        'order': 'sseDate|desc,securityCode|asc,bulletinId|asc',", "    }",
    "    query_url = 'https://query.sse.com.cn/commonSoaQuery.do?' + urllib.parse.urlencode(params)",
    "    try:", "        text = fetch_text(query_url)", "    except Exception as exc:",
    "        return [], [{'website': query_url, 'error': str(exc)}]", "    match = re.search(r'^[^(]+\\((.*)\\)\\s*$', text, re.DOTALL)",
    "    payload_text = match.group(1) if match else text", "    try:", "        data = json.loads(payload_text)",
    "    except Exception as exc:", "        return [], [{'website': query_url, 'error': 'SSE JSON parse failed: ' + str(exc)}]",
    "    rows = data.get('result') if isinstance(data.get('result'), list) else []",
    "    candidates = []", "    for row in rows:", "        if not isinstance(row, dict):",
    "            continue", "        raw_url = str(row.get('url') or '')", "        if not raw_url:",
    "            continue", "        url = urllib.parse.urljoin('https://static.sse.com.cn/', raw_url)",
    "        if not official_url(url):", "            continue", "        candidates.append({'title': row.get('title') or raw_url.rsplit('/', 1)[-1], 'url': url, 'platform': '上海证券交易所', 'disclosure_date': str(row.get('sseDate') or '').split(' ')[0], 'lifecycle_stage': '', 'relevance': 'discovered from SSE official exchangeable-bond query endpoint', 'source_kind': source_kind_for_url(url), 'source_type': 'official-sse-exchangeable-query', 'source_policy': 'official-first', 'bond_code': row.get('securityCode') or infer_bond_code(url, row.get('title') or ''), 'bond_short_name': row.get('securityAbbr') or '', 'rank': start_index + len(candidates) + 1, 'discovered_from': query_url})",
    "    return candidates, []", "", "def fetch_official_adapter_candidates(websites, start_index, start, as_of_date):",
    "    candidates, errors = [], []", "    sse_candidates, sse_errors = fetch_sse_exchangeable_candidates(websites, start_index, start, as_of_date)",
    "    candidates.extend(sse_candidates)", "    errors.extend(sse_errors)", "    szse_search_candidates, szse_search_errors = fetch_szse_search_candidates(websites, start_index + len(candidates), start, as_of_date)",
    "    candidates.extend(szse_search_candidates)", "    errors.extend(szse_search_errors)",
    "    szse_candidates, szse_errors = fetch_szse_notice_candidates(websites, start_index + len(candidates))",
    "    candidates.extend([item for item in szse_candidates if item.get('url') not in {candidate.get('url') for candidate in candidates}])",
    "    errors.extend(szse_errors)", "    return candidates, errors", "", "def main():",
    "    parser = argparse.ArgumentParser()", "    parser.add_argument('--book-root', default='.')",
    "    parser.add_argument('--run-root', default='')", "    parser.add_argument('--output', default='outputs/official-pdf-candidates.json')",
    "    parser.add_argument('--as-of', default='')", "    parser.add_argument('--lookback-months', type=int, default=6)",
    "    args = parser.parse_args()", "    book_root = Path(args.book_root).resolve()",
    "    run_root = Path(args.run_root).resolve() if args.run_root else book_root",
    "    as_of = args.as_of or datetime.datetime.utcnow().strftime('%Y%m%d')", "    as_of_date = datetime.date(int(as_of[:4]), int(as_of[4:6]), int(as_of[6:8])) if len(as_of) == 8 and as_of.isdigit() else datetime.date.today()",
    "    month = as_of_date.month - args.lookback_months", "    year = as_of_date.year + (month - 1) // 12",
    "    month = (month - 1) % 12 + 1", "    start = datetime.date(year, month, min(as_of_date.day, calendar.monthrange(year, month)[1]))",
    "    def parse_date(value):", "        text = str(value or '').strip()", "        for fmt in ['%Y-%m-%d', '%Y%m%d']:",
    "            try:", "                return datetime.datetime.strptime(text, fmt).date()",
    "            except Exception:", "                pass", "        return None",
    "    request = load_json(book_root / 'raw' / 'inbox' / 'eb-tracking-request.json')",
    "    book = load_json(book_root / 'book.json')", "    target_bonds = configured_target_bonds(request, book)",
    "    scope = target_scope(request, book, target_bonds)", "    keywords = target_keywords(request, scope, target_bonds)",
    "    websites = list(dict.fromkeys(watch_websites(request) + watch_websites(book)))",
    "    seed_candidates = seed_items(request) + seed_items(book)", "    web_candidates, web_errors = fetch_web_pdf_candidates(websites, keywords, len(seed_candidates))",
    "    adapter_candidates, adapter_errors = fetch_official_adapter_candidates(websites, len(seed_candidates) + len(web_candidates), start, as_of_date)",
    "    web_candidates = filter_dynamic_candidates_for_scope(web_candidates, scope, target_bonds)",
    "    adapter_candidates = filter_dynamic_candidates_for_scope(adapter_candidates, scope, target_bonds)",
    "    seeds = seed_candidates + web_candidates + adapter_candidates", "    candidates = []",
    "    seen = set()", "    for seed in seeds:", "        item = normalize_seed(seed, len(candidates))",
    "        if not item:", "            continue", "        if item['url'] in seen:",
    "            continue", "        seen.add(item['url'])", "        d = parse_date(item.get('disclosure_date'))",
    "        item['within_lookback'] = bool(d and start <= d <= as_of_date)", "        candidates.append(item)",
    "    stale_warnings = stale_target_warnings(scope, target_bonds, candidates)",
    "    target_stale_blocked = scope == 'single_bond' and bool(stale_warnings)",
    "    instrument_codes = sorted({str(item.get('bond_code') or '').strip() for item in candidates if str(item.get('bond_code') or '').strip()})",
    "    source_kind_counts = {}", "    for item in candidates:", "        kind = str(item.get('source_kind') or 'official_source')",
    "        source_kind_counts[kind] = source_kind_counts.get(kind, 0) + 1", "    html_notice_count = source_kind_counts.get('html_notice', 0)",
    "    pdf_candidate_count = source_kind_counts.get('pdf', 0)", "    recommended_review_instrument_count = configured_recommended_instrument_count(request, book) if scope == 'active_universe' else 0",
    "    current_window_candidates = [item for item in candidates if item.get('within_lookback')]",
    "    observed_instrument_codes = sorted({str(item.get('bond_code') or '').strip() for item in current_window_candidates if str(item.get('bond_code') or '').strip()})",
    "    dynamic_discovery_sources = sorted({str(item.get('discovered_from') or '') for item in candidates if str(item.get('discovered_from') or '').strip()})",
    "    fact_based_universe_evidence = scope != 'active_universe' or (bool(current_window_candidates) and bool(dynamic_discovery_sources))",
    "    universe_evidence_basis = 'configured target scope' if scope != 'active_universe' else ('official source pages scanned and deduped within lookback; no count threshold used' if fact_based_universe_evidence else 'no dynamic official-source discovery evidence for the active universe')",
    "    discovery_completeness_ok = fact_based_universe_evidence", "    ai_discovery_required = scope == 'active_universe' and not fact_based_universe_evidence",
    "    fact_evidence_failure_reasons = []", "    if scope == 'active_universe' and not current_window_candidates:",
    "        fact_evidence_failure_reasons.append('no current-window official source records were discovered')",
    "    if scope == 'active_universe' and not dynamic_discovery_sources:", "        fact_evidence_failure_reasons.append('configured seeds and count hints are not accepted as universe proof')",
    "    candidate_source = 'configured_official_source_seeds_plus_web_scan' if seed_candidates else 'configured_websites_official_source_scan'",
    "    coverage_scope = 'active exchangeable-bond universe across official source records, including SSE PDFs, SZSE HTML notices, and CNInfo PDFs' if scope == 'active_universe' else 'configured websites plus official source seed adapter for selected EB targets'",
    "    out_arg = Path(args.output)", "    out_path = out_arg if out_arg.is_absolute() else run_root / out_arg",
    "    out_path.parent.mkdir(parents=True, exist_ok=True)", "    if candidates and not target_stale_blocked and discovery_completeness_ok:",
    "        artifact = {", "            'kind': 'eb-official-pdf-candidates',",
    "            'status': 'official_candidates_ready',", "            'candidate_source': candidate_source,",
    "            'candidate_count': len(candidates),", "            'official_url_count': len(candidates),",
    "            'instrument_codes': instrument_codes,", "            'instrument_count': len(instrument_codes),",
    "            'observed_instrument_codes': observed_instrument_codes,", "            'recommended_review_instrument_count': recommended_review_instrument_count,",
    "            'fact_based_universe_evidence': fact_based_universe_evidence,",
    "            'universe_evidence_basis': universe_evidence_basis,", "            'universe_evidence_sources': dynamic_discovery_sources,",
    "            'discovery_completeness_ok': discovery_completeness_ok,", "            'ai_discovery_required': False,",
    "            'discovery_next_step': 'proceed_to_download_extract_and_screen',",
    "            'source_kind_counts': source_kind_counts,", "            'pdf_candidate_count': pdf_candidate_count,",
    "            'html_notice_count': html_notice_count,", "            'as_of': as_of_date.isoformat(),",
    "            'lookback_months': args.lookback_months,", "            'lookback_window_start': start.isoformat(),",
    "            'lookback_window_end': as_of_date.isoformat(),", "            'lookback_candidate_count': len([item for item in candidates if item.get('within_lookback')]),",
    "            'lookback_no_recent_sources': len([item for item in candidates if item.get('within_lookback')]) == 0,",
    "            'target_scope': scope,", "            'active_universe_default': scope == 'active_universe',",
    "            'target_bonds': target_bonds,", "            'search_keywords': keywords,",
    "            'stale_target_warnings': stale_warnings,", "            'target_stale_blocked': False,",
    "            'coverage_scope': coverage_scope,", "            'checked_websites': websites,",
    "            'website_check_count': len(websites),", "            'website_pdf_candidate_count': len([item for item in web_candidates + adapter_candidates if item.get('source_kind') == 'pdf']),",
    "            'website_source_candidate_count': len(web_candidates) + len(adapter_candidates),",
    "            'official_adapter_candidate_count': len(adapter_candidates),", "            'web_fetch_errors': web_errors + adapter_errors,",
    "            'checked_domains': sorted({domain for item in candidates for domain in OFFICIAL_DOMAINS if domain in item.get('url', '')}),",
    "            'candidates': candidates,", "            'kept_candidates': candidates,",
    "            'notify_town': False,", "            'standing_goal_decision': 'continue',",
    "        }", "    else:", "        failure_reason = 'Selected EB target has no official sources in the lookback window and appears redeemed or delisted.' if target_stale_blocked else ('Active-universe discovery lacks fact-based official-source evidence; use web_search/web_fetch on official domains and write the observed source universe, not an expected-count threshold.' if ai_discovery_required else 'No official source candidates were available for this current run.')",
    "        artifact = {", "            'kind': 'eb-official-pdf-candidates',",
    "            'status': 'failed',", "            'candidate_source': candidate_source,",
    "            'candidate_count': len(candidates),", "            'official_url_count': len(candidates),",
    "            'instrument_codes': instrument_codes,", "            'instrument_count': len(instrument_codes),",
    "            'observed_instrument_codes': observed_instrument_codes,", "            'recommended_review_instrument_count': recommended_review_instrument_count,",
    "            'fact_based_universe_evidence': fact_based_universe_evidence,",
    "            'universe_evidence_basis': universe_evidence_basis,", "            'universe_evidence_sources': dynamic_discovery_sources,",
    "            'fact_evidence_failure_reasons': fact_evidence_failure_reasons,",
    "            'discovery_completeness_ok': discovery_completeness_ok,", "            'ai_discovery_required': ai_discovery_required,",
    "            'discovery_next_step': 'use MoonClaw web_search/web_fetch on official domains, write observed official candidates with fact_based_universe_evidence=true, and keep any count only as a recommendation' if ai_discovery_required else 'fix configured websites or target metadata',",
    "            'source_kind_counts': source_kind_counts,", "            'pdf_candidate_count': pdf_candidate_count,",
    "            'html_notice_count': html_notice_count,", "            'as_of': as_of_date.isoformat(),",
    "            'lookback_months': args.lookback_months,", "            'lookback_window_start': start.isoformat(),",
    "            'lookback_window_end': as_of_date.isoformat(),", "            'lookback_candidate_count': len([item for item in candidates if item.get('within_lookback')]),",
    "            'lookback_no_recent_sources': True,", "            'target_scope': scope,",
    "            'active_universe_default': scope == 'active_universe',", "            'target_bonds': target_bonds,",
    "            'search_keywords': keywords,", "            'stale_target_warnings': stale_warnings,",
    "            'target_stale_blocked': target_stale_blocked,", "            'coverage_scope': coverage_scope,",
    "            'checked_websites': websites,", "            'website_check_count': len(websites),",
    "            'website_pdf_candidate_count': len([item for item in web_candidates + adapter_candidates if item.get('source_kind') == 'pdf']),",
    "            'website_source_candidate_count': len(web_candidates) + len(adapter_candidates),",
    "            'official_adapter_candidate_count': len(adapter_candidates),", "            'web_fetch_errors': web_errors + adapter_errors,",
    "            'checked_domains': OFFICIAL_DOMAINS,", "            'candidates': candidates,",
    "            'kept_candidates': [] if target_stale_blocked else candidates,",
    "            'notify_town': False,", "            'standing_goal_decision': 'failed',",
    "            'failure_reason': failure_reason,", "        }", "    out_path.write_text(json.dumps(artifact, ensure_ascii=False, indent=2) + '\\n', encoding='utf-8')",
    "    print(json.dumps({'status': artifact['status'], 'candidate_count': artifact['candidate_count'], 'target_scope': scope, 'target_stale_blocked': target_stale_blocked, 'output': str(out_path)}, ensure_ascii=False))",
    "    return 0 if artifact['status'] == 'official_candidates_ready' else 2", "",
    "if __name__ == '__main__':", "    raise SystemExit(main())", "",
  ].join("\n")
}
