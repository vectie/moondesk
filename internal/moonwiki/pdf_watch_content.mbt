///|
fn pdf_watch_skill_markdown(topic : String) -> String {
  [
    "# PDF Watch",
    "",
    "Use this skill to watch configured websites for \{topic} official evidence sources.",
    "",
    "- Keep browsing bounded to the configured website list.",
    "- Prefer direct PDF links and official publication or notice pages that identify the source, including exchange HTML notices when no separate PDF exists.",
    "- For exchangeable-bond active-universe runs, enumerate the complete official source universe first and prove instrument coverage before analysis starts.",
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
fn eb_tool_watch_skill_markdown(topic : String) -> String {
  [
    "# EB Tool Watch",
    "",
    "Use this tool-watch skill to keep the \{topic} EB evidence dashboard synchronized with accepted Bookkeeper results.",
    "",
    "- Treat `tool-manifest.json` as the Moontown-facing ToolBook manifest.",
    "- Rebuild `book/site/generated/tool.html` and `app/index.html` only from accepted source-screen, validation, and workbook artifacts.",
    "- Keep every visible announcement row linked to its official source URL, whether that source is a PDF or an exchange notice page.",
    "- Mark missing or mismatched extracted text explicitly; do not reuse unrelated PDF text.",
    "- Publish no-change scans as status only, not as accepted knowledge.",
    "",
  ].join("\n")
}

///|
fn eb_tool_build_skill_markdown(topic : String) -> String {
  [
    "# EB Tool Build",
    "",
    "Use this tool-build skill when packaging the \{topic} EB watch as an app-tool-book surface.",
    "",
    "- Inputs: `raw/analysis-runs/*official-source-screen.json`, `raw/analysis-runs/*official-pdf-candidates.json`, official-source records, extracted text, and MoonClaw AI analysis.",
    "- Outputs: the EB XLSX workbook, workbook sidecars, `tool-manifest.json`, `wiki/reports/latest-analysis.md`, `book/site/generated/tool.html`, and `app/index.html`.",
    "- Preserve the research-book workflow while exposing reusable ToolBook entrypoints.",
    "- Verify source-universe completeness, official hyperlinks, row counts, sidecar hashes, and text-match status before publishing.",
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
fn book_pattern_title(pattern_id : String, topic : String) -> String {
  if pattern_id == "exchangeable-bond-evidence-watch" {
    "\{topic} Exchangeable Bond Evidence Watch"
  } else {
    "\{topic} PDF Evidence Watch"
  }
}

///|
fn topic_from_book_title(
  title : String,
  pattern_id : String,
  fallback : String,
) -> String {
  let clean = title.trim().to_owned()
  let suffix = if pattern_id == "exchangeable-bond-evidence-watch" {
    " Exchangeable Bond Evidence Watch"
  } else {
    " PDF Evidence Watch"
  }
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
  if pattern_id == "exchangeable-bond-evidence-watch" {
    [
      "Watch configured official websites for new exchangeable-bond PDFs for \{topic}.",
      "",
      "Purpose: \{purpose}",
      "",
      "Download and extract relevant PDFs, analyze lifecycle/credit/compliance fields using `wiki/methods/my-analysis-method.md`, compare against the existing MoonBook baseline, update wiki and XLSX output contracts only when accepted knowledge changes, queue Bookkeeper review, and notify only after accepted new knowledge.",
    ].join("\n")
  } else {
    "Watch configured websites for new relevant PDFs, download and extract them, analyze using the book's method page, compare against the existing MoonBook baseline, update durable book files only when new knowledge appears, queue Bookkeeper review, and notify the operator only after accepted new knowledge."
  }
}

///|
fn pdf_watch_catalog_entry(
  book_id~ : String,
  topic~ : String,
  pattern_id~ : String,
  purpose~ : String,
  book_root~ : String,
  skill_pack? : Array[String] = [],
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
    "created_by": "Moondesk",
    "output_contract": pdf_watch_output_contract_handoff(pattern_id),
    "expected_outputs": json_from_string_array(
      book_pattern_output_files(pattern_id),
    ),
    "handoff": {
      "owner": "Moontown",
      "action": "schedule standing watch and dispatch bounded MoonClaw runs",
    },
  }
}
