///|
fn eb_default_source_websites() -> Array[String] {
  [
    "https://www.sse.com.cn/", "https://www.szse.cn/", "https://www.cninfo.com.cn/",
    "https://www.chinabond.com.cn/", "https://www.shclearing.com.cn/", "https://www.csrc.gov.cn/",
  ]
}

///|
fn eb_seed_candidate(
  bond_code~ : String,
  bond_short_name~ : String,
  url~ : String,
  title~ : String,
  platform~ : String,
  disclosure_date~ : String,
  lifecycle_stage~ : String,
  relevance~ : String,
  source_kind? : String = "pdf",
) -> Json {
  {
    "bond_code": bond_code,
    "bond_short_name": bond_short_name,
    "url": url,
    "title": title,
    "platform": platform,
    "disclosure_date": disclosure_date,
    "lifecycle_stage": lifecycle_stage,
    "relevance": relevance,
    "source_kind": source_kind,
    "source_type": if source_kind == "pdf" {
      "official-pdf-seed"
    } else {
      "official-source-seed"
    },
    "source_policy": "official-first",
  }
}

///|
fn eb_official_source_seed_candidates(
  target_scope : String,
  target_bonds : Array[Json],
) -> Array[Json] {
  if target_scope == "active_universe" {
    []
  } else {
    eb_official_pdf_seed_candidates(target_scope, target_bonds)
  }
}

///|
fn eb_official_pdf_seed_candidates(
  target_scope : String,
  target_bonds : Array[Json],
) -> Array[Json] {
  let seeds : Array[Json] = []
  if target_scope == "active_universe" {
    return seeds
  }
  for target in target_bonds {
    let bond_code = json_string(target, "bond_code", default="")
    let bond_short_name = json_string(
      target,
      "bond_full_name_or_short_name",
      default="",
    )
    if bond_code == "132018" || bond_short_name.contains("G三峡EB1") {
      seeds.push(
        eb_seed_candidate(
          bond_code~,
          bond_short_name~,
          url="https://static.sse.com.cn/disclosure/bond/announcement/exchangeable/c/new/2024-03-27/132018_20240327_CFRC.pdf",
          title="中国长江三峡集团有限公司公开发行2019年绿色可交换公司债券（第一期）2024年本息兑付及摘牌公告",
          platform="上海证券交易所",
          disclosure_date="2024-03-27",
          lifecycle_stage="兑付与退出",
          relevance="P0 official SSE PDF for final repayment and delisting evidence.",
        ),
      )
      seeds.push(
        eb_seed_candidate(
          bond_code~,
          bond_short_name~,
          url="https://static.sse.com.cn/disclosure/bond/announcement/exchangeable/c/new/2024-03-07/132018_20240307_SMEE.pdf",
          title="中国长江三峡集团有限公司关于“G三峡EB1”停止换股及到期摘牌的第三次提示性公告",
          platform="上海证券交易所",
          disclosure_date="2024-03-07",
          lifecycle_stage="兑付与退出",
          relevance="P0 official SSE PDF for exchange-stop and maturity reminder timing proof.",
        ),
      )
      seeds.push(
        eb_seed_candidate(
          bond_code~,
          bond_short_name~,
          url="https://static.sse.com.cn/disclosure/bond/announcement/exchangeable/c/new/2023-07-19/132018_20230719_6OER.pdf",
          title="中国长江三峡集团有限公司公开发行2019年绿色可交换公司债券（第一期）换股价格调整的公告",
          platform="上海证券交易所",
          disclosure_date="2023-07-19",
          lifecycle_stage="存续期临时公告",
          relevance="P0 official SSE PDF for exchange-price adjustment evidence.",
        ),
      )
      seeds.push(
        eb_seed_candidate(
          bond_code~,
          bond_short_name~,
          url="https://static.sse.com.cn/disclosure/bond/announcement/exchangeable/c/new/2023-07-03/132018_20230703_N4IU.pdf",
          title="中国长江三峡集团有限公司关于不提前赎回“G三峡EB1”的提示性公告",
          platform="上海证券交易所",
          disclosure_date="2023-07-03",
          lifecycle_stage="赎回与回售",
          relevance="P0 official SSE PDF for redemption-trigger decision evidence.",
        ),
      )
      seeds.push(
        eb_seed_candidate(
          bond_code~,
          bond_short_name~,
          url="https://static.sse.com.cn/disclosure/bond/announcement/exchangeable/c/new/2022-10-27/132018_20221027_1_xAmE5eoo.pdf",
          title="中国长江三峡集团有限公司公开发行2019年绿色可交换公司债券（第一期）复牌公告",
          platform="上海证券交易所",
          disclosure_date="2022-10-27",
          lifecycle_stage="换股期管理",
          relevance="P0 official SSE PDF for trading/exchange resumption continuity evidence.",
        ),
      )
    }
  }
  seeds
}

///|
fn default_eb_analysis_method(topic : String) -> String {
  [
    "# Exchangeable Bond Tracking Method",
    "",
    "Topic: \{topic}",
    "",
    "Role: act as an exchangeable-bond credit research and compliance tracking analyst. Track one or more target EB instruments through their full lifecycle and convert official disclosure evidence into reviewed wiki findings plus the required Excel workbook. For active-universe runs, first complete instrument/source discovery before any analysis.",
    "",
    "## Target Object",
    "",
    "Record these fields before execution. If multiple bonds are configured, repeat the same workflow per bond and group Sheet 1 by bond code.",
    "",
    "- Bond full name / short name",
    "- Bond code, e.g. `132XXX`",
    "- Issuer, usually the listed-company shareholder",
    "- Underlying listed company",
    "- Exchange: SSE or SZSE",
    "",
    "## Official Source Priority",
    "",
    "Use official exchange/source records first and reject third-party repost URLs for accepted knowledge. Official records may be PDFs or exchange HTML notice pages.",
    "",
    "Active-universe fact gate: before analysis, write the candidate artifact with `instrument_count`, `observed_instrument_codes`, `source_kind_counts`, `fact_based_universe_evidence`, `universe_evidence_basis`, `universe_evidence_sources`, `ai_discovery_required`, and `discovery_completeness_ok`. Counts are review hints only; do not use a minimum, maximum, prompt-provided list, or hardcoded list as universe coverage. Discover the current official universe from official source pages or use MoonClaw web_search/web_fetch to prove observed facts.",
    "",
    "| Priority | Platform | Use | Typical domain |",
    "| --- | --- | --- | --- |",
    "| P0 | 上海证券交易所 / 深圳证券交易所 | Bond disclosure pages, prospectus, issuance, listing, exchange, redemption, sell-back notices | `sse.com.cn` / `szse.cn` |",
    "| P1 | 巨潮资讯网 | Underlying listed-company mirrored announcements, equity-change reports, control-risk notices, periodic reports | `cninfo.com.cn` |",
    "| P2 | 中国债券信息网 | Issuance, tendering, valuation, custody information | `chinabond.com.cn` |",
    "| P3 | 上海清算所 | Registration, custody, coupon, redemption and repayment information | `shclearing.com.cn` |",
    "| P4 | 中国证监会 / exchange review sites | Approval, registration, review progress | `csrc.gov.cn` and official exchange review domains |",
    "",
    "## Lifecycle Disclosure Checklist",
    "",
    "For every relevant announcement node, record announcement title, disclosure date, disclosure platform URL, concise summary, and key extracted data. If an expected node is not found, write `未检索到` with the likely reason, such as private EB disclosure differences or no triggered event.",
    "",
    "### Stage 1: 发行与上市",
    "",
    "1. 发行核准/注册公告（证监会批文）",
    "2. 募集说明书全文",
    "3. 发行公告：发行规模、期限、票面利率、初始换股价格、担保股票数量",
    "4. 上市公告书",
    "5. 担保及信托登记公告：预备用于交换的股票质押/信托专户设立",
    "",
    "### Stage 2: 存续期定期报告",
    "",
    "1. 年报/半年报中的可交债专项披露：换股价格历次调整/修正、累计换股数量及比例、期末预备用于交换股票市值 vs 债券余额比例、赎回及回售情况",
    "2. 跟踪评级报告（如有）",
    "",
    "### Stage 3: 存续期临时公告",
    "",
    "Triggered matters should normally be disclosed within 2 trading days. Check for: 换股价格调整/修正, 标的股票 ST/*ST 或暂停/终止上市, 预备用于交换股票司法冻结/扣划/权利瑕疵, 担保覆盖率重大不利变化, and possible control-transfer risk notices.",
    "",
    "### Stage 4: 换股期管理",
    "",
    "1. 换股开始公告：start disclosed at least 3 trading days ahead, including exchange period, current exchange price, and procedure",
    "2. 换股进展公告：regular or threshold-based progress",
    "3. 换股期结束提示性公告：20 trading days before the end, at least 3 reminder notices",
    "4. 投资者权益变动报告：when exchange causes holdings above 5% or material movement requiring takeover/equity-change disclosure",
    "",
    "### Stage 5: 赎回与回售",
    "",
    "1. 赎回触发条件满足公告：within 2 trading days disclose whether the issuer exercises redemption",
    "2. 赎回实施提示性公告：at least 3 reminders before the redemption registration date",
    "3. 赎回结果公告",
    "4. 回售触发条件满足公告：within 2 trading days",
    "5. 回售实施提示性公告：at least 3 reminders before the declaration period ends",
    "6. 回售结果公告",
    "",
    "### Stage 6: 兑付与退出",
    "",
    "1. 付息公告：3-5 trading days before coupon payment",
    "2. 本息兑付公告：normally within 2 trading days after maturity",
    "3. 终止上市/挂牌公告：within 2 trading days after full exchange or repayment completion",
    "4. 担保股票解除质押/信托登记公告",
    "",
    "Required outputs:",
    "- Maintain reviewed findings in `wiki/findings/`.",
    "- Produce XLSX files under `book/outputs/` named `EB追踪_[债券代码]_[债券简称]_[YYYYMMDD].xlsx` only after Bookkeeper acceptance.",
    "- Include Sheet 1 `公告追踪主表` with announcement title, date, platform, original URL, summary, key data, investor-action flag, and review notes.",
    "- Include Sheet 2 `关键指标监控表` with issuance scale, balance, exchange price, pledged stock coverage, redemption/sell-back status, latest rating, stock status, control-risk, coupon date, maturity date, and last update.",
    "- Cover the six EB lifecycle stages: issuance/listing, periodic reports, interim events, exchange-window management, redemption/sell-back, and repayment/exit.",
    "- Notify only when accepted new source-backed knowledge changes the baseline.",
    "",
    "## Workbook Quality Rules",
    "",
    "1. Cross-verify the same matter, such as exchange-price adjustment, between issuer bond announcements and underlying listed-company announcements when both should exist. If only one side is found, mark `待验证`.",
    "2. Validate announcement dates against exchange timing rules, including 2-trading-day event disclosure, 3-reminder redemption/sell-back notices, and 20-trading-day exchange-end reminders.",
    "3. Reconcile Sheet 2 cumulative exchanged shares with all Sheet 1 exchange progress announcements.",
    "4. Every URL used for accepted knowledge must be an official domain: `sse.com.cn`, `szse.cn`, `cninfo.com.cn`, `chinabond.com.cn`, `shclearing.com.cn`, or `csrc.gov.cn`.",
    "5. Mark missing expected disclosures as `未检索到` with a reason.",
    "6. Include search keywords, search date, and source list in the workbook note area or a companion note.",
  ].join("\n") +
  "\n\n" +
  eb_canonical_operator_prompt_markdown()
}

///|
fn eb_canonical_operator_prompt_markdown() -> String {
  [
    "## Canonical Chinese Operator Prompt Contract",
    "",
    "Moondesk preserves the operator-facing EB research contract below so MoonClaw and Bookkeeper can execute the book without relying on external prompt memory.",
    "",
    "### 角色设定",
    "",
    "你是一名专注可交换债券（Exchangeable Bond, EB）的信用研究与合规追踪分析师。任务是对指定的一只或多只可交债进行全生命周期信息追踪，并将所有关键节点、公告原文链接、核心数据提取整理为结构化表格。",
    "",
    "### 一、追踪对象",
    "",
    "- 债券全称/简称",
    "- 债券代码（如 132XXX）",
    "- 发行人（上市公司股东）",
    "- 标的上市公司",
    "- 交易所（上交所/深交所）",
    "",
    "### 二、追踪维度与公告节点",
    "",
    "每个节点必须记录：公告标题、披露日期、披露平台（URL）、核心内容摘要、关键数据。",
    "",
    "#### 阶段1：发行与上市",
    "",
    "1. 发行核准/注册公告（证监会批文）",
    "2. 募集说明书全文",
    "3. 发行公告（发行规模、期限、票面利率、初始换股价格、担保股票数量）",
    "4. 上市公告书",
    "5. 担保及信托登记公告（预备用于交换的股票质押/信托专户设立）",
    "",
    "#### 阶段2：存续期定期报告",
    "",
    "1. 年报/半年报中的可交债专项披露：换股价格历次调整/修正情况、累计换股数量及比例、期末预备用于交换的股票市值 vs 债券余额比例、赎回及回售情况（如有）",
    "2. 跟踪评级报告（如有）",
    "",
    "#### 阶段3：存续期临时公告（触发即披露）",
    "",
    "出现换股价格调整/修正、标的股票 ST/*ST 或暂停/终止上市、预备用于交换股票司法冻结/扣划/权利瑕疵、担保股票市值重大不利变化、可能导致控制权转移风险时，必须检查是否在 2 个交易日内披露。",
    "",
    "#### 阶段4：换股期管理",
    "",
    "1. 换股开始公告（开始前 3 个交易日披露，含换股起止日期、当前换股价格、程序）",
    "2. 换股进展公告（定期或累计达到一定比例时）",
    "3. 换股期结束提示性公告（结束前 20 个交易日，至少 3 次提示）",
    "4. 投资者权益变动报告（因换股导致持股 5% 以上变动时）",
    "",
    "#### 阶段5：赎回与回售",
    "",
    "1. 赎回触发条件满足公告（2 个交易日内披露是否行使赎回权）",
    "2. 赎回实施提示性公告（赎回登记日前至少 3 次）",
    "3. 赎回结果公告",
    "4. 回售触发条件满足公告（2 个交易日内）",
    "5. 回售实施提示性公告（回售申报期结束前至少 3 次）",
    "6. 回售结果公告",
    "",
    "#### 阶段6：兑付与退出",
    "",
    "1. 付息公告（付息日前 3-5 个交易日）",
    "2. 本息兑付公告（期满后 2 个交易日内）",
    "3. 终止上市/挂牌公告（全部换股或兑付完成后 2 个交易日内）",
    "4. 担保股票解除质押/信托登记公告",
    "",
    "### 三、法定披露平台（检索优先级）",
    "",
    "| 优先级 | 平台 | 用途 | 典型 URL |",
    "| --- | --- | --- | --- |",
    "| P0 | 上海证券交易所/深圳证券交易所官网 | 债券信息披露专区 | sse.com.cn / szse.cn |",
    "| P1 | 巨潮资讯网 | 标的上市公司同步公告 | cninfo.com.cn |",
    "| P2 | 中国债券信息网 | 发行、招标、估值、托管信息 | chinabond.com.cn |",
    "| P3 | 上海清算所 | 债券登记托管、兑付信息 | shclearing.com.cn |",
    "| P4 | 中国证监会/交易所审核网站 | 发行审批/注册进度 | csrc.gov.cn / official review sites |",
    "",
    "### 四、数据字段设计（Excel 表头）",
    "",
    "- Sheet 1：公告追踪主表",
    "- Sheet 1 headers: " + eb_announcement_sheet_headers().join(" | "),
    "- Sheet 2：关键指标监控表",
    "- Sheet 2 headers: " + eb_indicator_sheet_headers().join(" | "),
    "",
    "### 五、质量检查规则",
    "",
    "1. 交叉验证：同一事项必须在发行人债券公告和标的上市公司公告中同时出现；若仅一方披露需标记 `待验证`。",
    "2. 时间校验：公告日期必须符合交易所规则时限。",
    "3. 数据一致性：Sheet 2 中的累计换股数量必须与 Sheet 1 中所有换股进展公告加总一致。",
    "4. 链接有效性：所有 URL 需为官方域名，禁止第三方转载链接。",
    "5. 缺失标记：若某阶段应披露但未找到公告，需标记 `未检索到` 并说明可能原因。",
    "",
    "### 六、输出要求",
    "",
    "- 文件格式：Excel (.xlsx)",
    "- 文件命名：`EB追踪_[债券代码]_[债券简称]_[YYYYMMDD].xlsx`",
    "- 交付内容：两张工作表（Sheet 1 + Sheet 2），格式清晰、列宽自适应、关键数据加粗或标色",
    "- 附注：列出本次追踪使用的检索关键词、检索日期、信息来源清单",
    "",
    "### 七、执行指令",
    "",
    "请基于上述框架，对指定的一只或多只可交债进行系统性信息检索、提取、校验，并生成最终的 Excel 文件。若涉及多只债券，请在 Sheet 1 中按债券代码分组，Sheet 2 每只债券占一行。",
  ].join("\n")
}

///|
fn eb_operator_prompt_relative_path() -> String {
  "raw/bootstrap/EB_OPERATOR_PROMPT.md"
}

///|
fn eb_prompt_contract_receipt_relative_path() -> String {
  "raw/analysis-runs/eb-prompt-contract.json"
}

///|
fn eb_operator_prompt_markdown(topic : String, book_id : String) -> String {
  [
    "# EB Operator Prompt",
    "",
    "- Book: `\{book_id}`",
    "- Topic: \{topic}",
    "- Base type: `research-book`",
    "- Pattern: `exchangeable-bond-evidence-watch`",
    "- Contract: `moondesk.exchangeable_bond.operator_prompt.v1`",
    "",
    "This prompt is a durable MoonBook artifact. Moondesk writes it, Moontown schedules it through the standing watch, MoonClaw executes from it, and Bookkeeper uses it while deciding whether new evidence becomes accepted knowledge.",
    "",
    "## Moondesk Required EB Output Contract",
    "",
    "MoonClaw must produce candidate evidence and Bookkeeper must accept new knowledge before the book publishes the required workbook, wiki findings, or notification.",
    "",
    eb_canonical_operator_prompt_markdown(),
  ].join("\n")
}

///|
async fn eb_prompt_contract_verification(
  book_root : String,
  book_id : String,
) -> Json {
  let failed : Array[String] = []
  let prompt_relative = eb_operator_prompt_relative_path()
  let prompt_path = @pathx.join(book_root, prompt_relative)
  let text = @fs.read_file(prompt_path).text() catch { _ => "" }
  push_failed_unless(failed, text != "", "operator prompt artifact exists")
  for
    token in [
      "角色设定", "一、追踪对象", "Moondesk Required EB Output Contract",
    ] {
    push_failed_unless(
      failed,
      text.contains(token),
      "operator prompt includes required section: \{token}",
    )
  }
  let mut lifecycle_stage_count = 0
  for
    stage in [
      "阶段1：发行与上市", "阶段2：存续期定期报告", "阶段3：存续期临时公告",
      "阶段4：换股期管理", "阶段5：赎回与回售", "阶段6：兑付与退出",
    ] {
    if text.contains(stage) {
      lifecycle_stage_count += 1
    }
    push_failed_unless(
      failed,
      text.contains(stage),
      "operator prompt includes lifecycle stage: \{stage}",
    )
  }
  let mut official_domain_count = 0
  for domain in eb_official_domains() {
    if text.contains(domain) {
      official_domain_count += 1
    }
    push_failed_unless(
      failed,
      text.contains(domain),
      "operator prompt includes official domain: \{domain}",
    )
  }
  let mut announcement_header_count = 0
  for header in eb_announcement_sheet_headers() {
    if text.contains(header) {
      announcement_header_count += 1
    }
    push_failed_unless(
      failed,
      text.contains(header),
      "operator prompt includes Sheet 1 header: \{header}",
    )
  }
  let mut indicator_header_count = 0
  for header in eb_indicator_sheet_headers() {
    if text.contains(header) {
      indicator_header_count += 1
    }
    push_failed_unless(
      failed,
      text.contains(header),
      "operator prompt includes Sheet 2 header: \{header}",
    )
  }
  for
    token in [
      "EB追踪_[债券代码]_[债券简称]_[YYYYMMDD].xlsx", "公告追踪主表",
      "关键指标监控表", "未检索到", "待验证", "Bookkeeper", "Excel (.xlsx)",
      "七、执行指令", "系统性信息检索", "Sheet 1 中按债券代码分组",
      "Sheet 2 每只债券占一行",
    ] {
    push_failed_unless(
      failed,
      text.contains(token),
      "operator prompt includes execution rule: \{token}",
    )
  }
  {
    "kind": "eb-operator-prompt-contract",
    "contract_version": "1",
    "book_id": book_id,
    "pattern_id": "exchangeable-bond-evidence-watch",
    "prompt_path": prompt_relative,
    "verified": failed.length() == 0,
    "failed_checks": json_from_string_array(failed),
    "official_domain_count": official_domain_count,
    "official_domain_required_count": eb_official_domains().length(),
    "lifecycle_stage_count": lifecycle_stage_count,
    "lifecycle_stage_required_count": 6,
    "announcement_header_count": announcement_header_count,
    "announcement_header_required_count": eb_announcement_sheet_headers().length(),
    "indicator_header_count": indicator_header_count,
    "indicator_header_required_count": eb_indicator_sheet_headers().length(),
  }
}

///|
fn eb_credit_compliance_skill_markdown(topic : String) -> String {
  [
    "# Exchangeable Bond Credit Compliance",
    "",
    "Use this skill for \{topic} official-source evidence watch runs.",
    "",
    "- Prefer official exchange, issuer, trustee, clearing, regulator, and disclosure-platform URLs.",
    "- Follow source priority P0 SSE/SZSE, P1 CNInfo, P2 ChinaBond, P3 SHCH, P4 CSRC or official review sites.",
    "- Complete discovery before analysis: active-universe runs must first prove the full current official source universe, not a small sample.",
    "- For active-universe runs, discover the current full official set from official source pages or MoonClaw web_search/web_fetch; do not treat prompt hints, dated examples, or hardcoded instrument lists as accepted coverage.",
    "- Accept official source records from SSE PDFs, SZSE official HTML notice pages, and CNInfo issuer PDFs; do not invent placeholder EB codes.",
    "- Cover all six stages: 发行与上市, 存续期定期报告, 存续期临时公告, 换股期管理, 赎回与回售, 兑付与退出.",
    "- Extract bond code, short name, issuer, shareholder/pledged shares, conversion/exchange price, rating, guarantee, maturity, exchange window, redemption/sell-back/default events, and compliance flags.",
    "- Normalize findings into the `公告追踪主表` and `关键指标监控表` output contract.",
    "- Apply cross-verification, timing checks, data-consistency checks, official-link validation, and missing-disclosure marking before Bookkeeper review.",
    "- Treat every extracted value as candidate knowledge until Bookkeeper accepts it.",
    "- Write accepted spreadsheet outputs to `book/outputs/` using the EB tracking filename contract.",
  ].join("\n")
}

///|
fn eb_watch_contract_markdown(topic : String) -> String {
  [
    "# EB Standing Watch Contract",
    "",
    "- Topic: \{topic}",
    "- Base type: `research-book`",
    "- Pattern: `exchangeable-bond-evidence-watch`",
    "- Scheduler: Moontown",
    "- Executor: MoonClaw",
    "- Durable owner: MoonBook",
    "- Reviewer: Bookkeeper",
    "",
    "## Execution Loop",
    "",
    "1. Read `raw/inbox/eb-standing-watch-dispatch.json`.",
    "2. Search only configured official websites for exchangeable-bond official sources, including PDFs and official notice pages.",
    "3. Complete the source-universe gate before analysis: active-universe runs must prove expected instruments, missing instruments, source-kind counts, and official URL counts.",
    "4. Download PDFs into `raw/pdfs/`, official HTML/source pages into `raw/html/`, and extract text into `raw/extracted/`.",
    "5. Write per-source metadata under `wiki/sources/` and per-run analysis under `raw/analysis-runs/`.",
    "6. Compare against the current wiki and workbook baseline.",
    "7. Queue Bookkeeper review before accepted knowledge changes `wiki/findings/` or `book/outputs/`.",
    "8. Notify only when Bookkeeper accepts new source-backed knowledge.",
    "",
    "## Required Standing Watch Marker",
    "",
    "Every MoonClaw result summary must include:",
    "",
    "```text",
    "standing_goal_decision: update | no_change | needs_review | failed",
    "delta_score: 0-100",
    "new_source_count: <integer>",
    "next_check_hint: normal | slower | faster | review",
    "checked_sources_count: <integer>",
    "new_sources_found: <integer>",
    "accepted_facts_count: <integer>",
    "rejected_facts_count: <integer>",
    "wiki_pages_changed_count: <integer>",
    "book_changed: yes | no",
    "```",
    "",
    "No-change scans, retries, and wrapper runs are operational evidence only. Accepted EB facts, review items, and changed durable book pages are domain progress.",
  ].join("\n")
}

///|
fn eb_standing_watch_dispatch_json(
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
  {
    "id": @desk.stable_id("eb-standing-watch-dispatch", book_id),
    "kind": "moontown-standing-watch-dispatch",
    "book_id": book_id,
    "book_type": "research-book",
    "pattern_id": "exchangeable-bond-evidence-watch",
    "target_book_id": book_id,
    "executor": "MoonClaw",
    "reviewer": "Bookkeeper",
    "topic": topic,
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
    "source_policy": "official-first",
    "watch_websites": json_from_string_array(websites),
    "allowed_domains": json_from_string_array(eb_official_domains()),
    "official_source_seeds": Json::array(
      eb_official_source_seed_candidates(target_scope, target_bonds),
    ),
    "official_source_seed_count": eb_official_source_seed_candidates(
      target_scope, target_bonds,
    ).length(),
    "method_page": "wiki/methods/my-analysis-method.md",
    "skill_paths": json_from_string_array([
      "skills/pdf-watch/SKILL.md", "skills/pdf-analysis/SKILL.md", "skills/eb-credit-compliance/SKILL.md",
    ]),
    "execution_request_path": "raw/inbox/eb-tracking-request.json",
    "watch_contract_path": "raw/bootstrap/EB_WATCH_CONTRACT.md",
    "source_outputs": json_from_string_array([
      "raw/pdfs/", "raw/extracted/", "wiki/sources/",
    ]),
    "analysis_outputs": json_from_string_array([
      "raw/analysis-runs/", "wiki/reviews/", "wiki/findings/",
    ]),
    "accepted_output_contract": {
      "format": "xlsx",
      "filename": "EB追踪_[债券代码]_[债券简称]_[YYYYMMDD].xlsx",
      "path": "book/outputs/",
      "sheets": json_from_string_array([
        "公告追踪主表", "关键指标监控表",
      ]),
      "validation_sidecar": {
        "required": true,
        "suffix": ".validation.json",
        "required_fields": json_from_string_array([
          "xlsx_sha256", "sample_run", "workbook_data_proof", "appendix_notes", "quality_proof",
          "lifecycle_stage_proof",
        ]),
      },
    },
    "standing_watch_marker": {
      "required": true,
      "fields": json_from_string_array([
        "standing_goal_decision", "delta_score", "new_source_count", "next_check_hint",
        "checked_sources_count", "new_sources_found", "accepted_facts_count", "rejected_facts_count",
        "wiki_pages_changed_count", "book_changed",
      ]),
      "decisions": json_from_string_array([
        "update", "no_change", "needs_review", "failed",
      ]),
    },
    "quality_rules": json_from_string_array([
      "official-domain URLs only", "download and extract PDFs before analysis", "cross-verify issuer and underlying-company disclosures when applicable",
      "mark expected-but-missing lifecycle nodes as 未检索到 with reason", "publish workbook only after Bookkeeper acceptance",
    ]),
  }
}

///|
fn eb_tracking_request_json(
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
  {
    "id": @desk.stable_id("eb-tracking-request", book_id),
    "kind": "moonclaw-execution-request",
    "book_id": book_id,
    "book_type": "research-book",
    "pattern_id": "exchangeable-bond-evidence-watch",
    "topic": topic,
    "bounded_executor": "MoonClaw",
    "reviewer": "Bookkeeper",
    "source_policy": "official-first",
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
    "official_domains": json_from_string_array(eb_official_domains()),
    "ai_extractor": {
      "enabled": true,
      "artifact_path": "outputs/eb-indicator-extraction.json",
      "kind": "eb-indicator-ai-extraction",
      "source_backing_required": true,
      "required_fact_fields": json_from_string_array([
        "value", "source_url_or_path", "snippet",
      ]),
      "merge_policy": "deterministic official-text facts first; source-backed AI facts only fill missing Sheet 2 metrics",
    },
    "six_lifecycle_stages": eb_lifecycle_stage_json(),
    "output_contract": {
      "format": "xlsx",
      "filename": "EB追踪_[债券代码]_[债券简称]_[YYYYMMDD].xlsx",
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
      "validation_sidecar": {
        "required": true,
        "suffix": ".validation.json",
        "required_fields": json_from_string_array([
          "xlsx_sha256", "sample_run", "workbook_data_proof", "appendix_notes", "quality_proof",
          "lifecycle_stage_proof",
        ]),
        "workbook_data_proof": json_from_string_array([
          "positive Sheet 1 announcement data rows", "positive Sheet 2 indicator data rows",
          "official-source-backed row count",
        ]),
        "appendix_notes": json_from_string_array([
          "search keywords", "retrieval date", "official source list",
        ]),
        "quality_proof": json_from_string_array([
          "official links only", "clickable official source links", "issuer/underlying cross-verification",
          "timing checks", "Sheet 1 / Sheet 2 data reconciliation", "summary <= 200 characters",
          "key data emphasized", "missing-disclosure marking", "readable workbook formatting",
        ]),
        "lifecycle_stage_proof": json_from_string_array(
          eb_lifecycle_stage_names(),
        ),
      },
    },
    "quality_checks": json_from_string_array([
      "cross-verify issuer bond announcements against underlying-company announcements when applicable",
      "validate disclosure timing against exchange rules", "reconcile cumulative exchange share counts between sheets",
      "accept official-domain URLs only", "mark expected-but-missing stages as 未检索到 with reason",
    ]),
    "standing_watch_dispatch_path": "raw/inbox/eb-standing-watch-dispatch.json",
    "standing_watch_marker": {
      "required": true,
      "decision_field": "standing_goal_decision",
      "allowed_decisions": json_from_string_array([
        "update", "no_change", "needs_review", "failed",
      ]),
    },
    "publish_rule": "update wiki/report/xlsx only after accepted new knowledge",
    "notify_rule": "accepted new knowledge only",
    "multi_bond_output_rule": "If multiple bonds are configured, group Sheet 1 rows by bond code and write one Sheet 2 row per bond.",
  }
}
