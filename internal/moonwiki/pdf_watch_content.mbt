///|
fn pdf_watch_skill_markdown(topic : String) -> String {
  [
    "# PDF Watch",
    "",
    "Use this skill to watch configured websites for \{topic} official evidence sources.",
    "",
    "- Keep browsing bounded to the configured website list.",
    "- Prefer direct PDF links and official publication or notice pages that identify the source.",
    "- Deduplicate by URL, title, and sha256.",
    "- Save candidate PDFs under `raw/pdfs/`, HTML/source pages under `raw/html/`, extracted text under `raw/extracted/`, and source metadata under `wiki/sources/`.",
    "- Report no-change scans without updating durable findings.",
    "",
  ].join("\n")
}

///|
fn pdf_analysis_skill_markdown(topic : String) -> String {
  [
    "# PDF Analysis",
    "",
    "Use this skill to analyze extracted \{topic} PDF text against the book baseline.",
    "",
    "- Read `wiki/methods/my-analysis-method.md` first.",
    "- Compare claims against current `wiki/` pages before writing.",
    "- Produce an analysis result under `raw/analysis-runs/`.",
    "- Queue review under `wiki/reviews/` when a finding may become accepted knowledge.",
    "- Do not notify for routine no-change scans.",
    "",
  ].join("\n")
}

///|
fn tool_watch_skill_markdown(topic : String) -> String {
  [
    "# Tool Watch",
    "",
    "Use this tool-watch skill to keep generated \{topic} miniapps synchronized with accepted Bookkeeper results.",
    "",
    "- Treat `tool-manifest.json` as the MoonTown-facing ToolBook manifest.",
    "- Rebuild `book/site/generated/tool.html` and `app/index.html` only from accepted source-screen, validation, and analysis artifacts.",
    "- Keep every visible record linked to its source URL.",
    "- Mark missing or mismatched extracted text explicitly; do not reuse unrelated source text.",
    "- Publish no-change scans as status only, not as accepted knowledge.",
    "",
  ].join("\n")
}

///|
fn tool_build_skill_markdown(topic : String) -> String {
  [
    "# Tool Build",
    "",
    "Use this tool-build skill when packaging \{topic} research evidence as an executable app-tool-book surface.",
    "",
    "- Inputs: source records, extracted text, analysis results, and accepted review decisions.",
    "- Outputs: `tool-manifest.json`, `wiki/reports/latest-analysis.md`, `book/site/generated/tool.html`, and `app/index.html`.",
    "- Preserve the research-book workflow while exposing reusable ToolBook entrypoints.",
    "- Verify source links, provenance, row counts, sidecar hashes, and text-match status before publishing.",
    "",
  ].join("\n")
}

///|
fn pdf_source_schema_markdown() -> String {
  [
    "# PDF Source Schema", "", "- `id`: stable source id", "- `url`: canonical URL",
    "- `title`: source title", "- `publisher`: publisher or host", "- `retrieved_at`: retrieval timestamp",
    "- `sha256`: PDF content hash", "- `local_pdf_path`: path under `raw/pdfs/`",
    "- `extracted_text_path`: path under `raw/extracted/`", "- `screening_decision`: relevant, duplicate, rejected, or needs-review",
    "",
  ].join("\n")
}

///|
fn analysis_result_schema_markdown() -> String {
  [
    "# Analysis Result Schema", "", "- `run_id`: MoonClaw run id", "- `source_ids`: PDF source ids considered",
    "- `baseline_pages`: wiki pages compared", "- `new_findings`: candidate new findings",
    "- `changed_conclusions`: conclusions whose evidence changed", "- `review_required`: whether Bookkeeper review is required",
    "- `book_changed`: whether durable book files changed", "- `notification`: accepted-new-knowledge, review-needed, or no-change",
    "",
  ].join("\n")
}

///|
fn pdf_watch_index_markdown(
  topic : String,
  book_id : String,
  pattern_id : String,
  purpose : String,
  websites : Array[String],
) -> String {
  let site_lines = if websites.length() == 0 {
    "- pending"
  } else {
    websites.map(site => "- \{site}").join("\n")
  }
  [
    "# \{book_pattern_title(pattern_id, topic)}",
    "",
    "- Book: `\{book_id}`",
    "- Pattern: `\{pattern_id}`",
    "- Status: initialized",
    "",
    purpose,
    "",
    "## Source Websites",
    "",
    site_lines,
    "",
    "## Workflow",
    "",
    "1. Watch configured websites for new PDFs.",
    "2. Download PDFs and extract full text with provenance.",
    "3. Analyze sources using `wiki/methods/my-analysis-method.md`.",
    "4. Compare against the current wiki baseline.",
    "5. Queue Bookkeeper review and publish only accepted knowledge.",
    "",
  ].join("\n")
}

///|
fn book_pattern_title(pattern_id : String, topic : String) -> String {
  ignore(pattern_id)
  "\{topic} PDF Evidence Watch"
}

///|
fn topic_from_book_title(
  title : String,
  pattern_id : String,
  fallback : String,
) -> String {
  let clean = title.trim().to_owned()
  ignore(pattern_id)
  let suffix = " PDF Evidence Watch"
  if clean.has_suffix(suffix) && clean.length() > suffix.length() {
    clean[:clean.length() - suffix.length()].trim().to_owned()
  } else if clean != "" {
    clean
  } else {
    fallback
  }
}

///|
fn pdf_watch_goal_prompt(
  pattern_id : String,
  topic : String,
  purpose : String,
) -> String {
  ignore(pattern_id)
  ignore(topic)
  ignore(purpose)
  "Watch configured websites for new relevant PDFs, download and extract them, analyze using the book's method page, compare against the existing MoonBook baseline, update durable book files only when new knowledge appears, queue Bookkeeper review, and notify the operator only after accepted new knowledge."
}

///|
fn pdf_watch_catalog_entry(
  book_id~ : String,
  topic~ : String,
  pattern_id~ : String,
  purpose~ : String,
  book_root~ : String,
  skill_pack~ : Array[String],
) -> Json {
  let skills = if skill_pack.length() == 0 {
    default_skill_pack_for_pattern(pattern_id)
  } else {
    skill_pack
  }
  {
    "id": book_id,
    "name": "MoonBook / \{book_pattern_title(pattern_id, topic)}",
    "purpose": purpose,
    "workspace_root": book_root,
    "memory_scope": "BookPrivate",
    "tags": json_from_string_array([
      "research",
      "standing-watch",
      "pdf-evidence",
      "source-first",
      "template:pdf-evidence-watch",
      "pattern:\{pattern_id}",
    ]),
    "skills": json_from_string_array(skills),
  }
}

///|
fn pdf_watch_handoff_record(
  book_id~ : String,
  topic~ : String,
  pattern_id~ : String,
  purpose~ : String,
  book_root~ : String,
  goal~ : Json,
) -> Json {
  {
    "id": @desk.stable_id("request", "publish-" + book_id),
    "kind": "book-pattern-publish",
    "status": "ready-for-moontown",
    "book_id": book_id,
    "title": book_pattern_title(pattern_id, topic),
    "pattern_id": pattern_id,
    "purpose": purpose,
    "book_root": book_root,
    "standing_goal": goal,
    "created_by": "MoonDesk",
    "output_contract": pdf_watch_output_contract_handoff(pattern_id),
    "expected_outputs": json_from_string_array(
      book_pattern_output_files(pattern_id),
    ),
    "handoff": {
      "owner": "MoonTown",
      "action": "schedule standing watch and dispatch bounded MoonClaw runs",
    },
  }
}
