///|
fn pdf_watch_contract_markdown(pattern_id : String, topic : String) -> String {
  [
    "# PDF Watch Contract",
    "",
    "- Topic: \{topic}",
    "- Pattern: `\{pattern_id}`",
    "- Base type: `research-book`",
    "- Source adapter: configured websites",
    "- Extractor: PDF full text and tables",
    "- Analysis skill: book-local method and skills",
    "- Standing watch: Moontown recurring goal",
    "",
    "The watcher may add raw evidence and review candidates, but accepted knowledge requires Bookkeeper review.",
  ].join("\n")
}

///|
fn pdf_watch_sources_readme(topic : String) -> String {
  [
    "# Sources",
    "",
    "One source card per relevant \{topic} PDF. Include canonical URL, title, publisher, retrieval time, sha256, local PDF path, extracted text path, and screening decision.",
  ].join("\n")
}

///|
fn pdf_watch_evidence_matrix_markdown(
  pattern_id : String,
  topic : String,
) -> String {
  ignore(pattern_id)
  let extra = "Each accepted finding must trace back to source URL, downloaded PDF hash, extracted text path, method output, baseline delta, and Bookkeeper decision."
  [
    "# Evidence Matrix",
    "",
    "- Topic: \{topic}",
    "- Status: initialized",
    "",
    "This page is the durable MoonBook evidence matrix. MoonClaw may append candidate rows, but Bookkeeper decides which rows become accepted knowledge.",
    "",
    extra,
    "",
    "| Source | Local PDF | Extracted text | Claim or row | Baseline delta | Review decision | Output path |",
    "| --- | --- | --- | --- | --- | --- | --- |",
    "| pending | pending | pending | pending | pending | pending | pending |",
    "",
  ].join("\n")
}

///|
fn pdf_watch_findings_readme(pattern_id : String, topic : String) -> String {
  ignore(pattern_id)
  let extra = "Accepted findings should update wiki pages only when source-backed knowledge changes."
  [
    "# Findings",
    "",
    "Accepted \{topic} findings live here after Bookkeeper review.",
    "",
    extra,
  ].join("\n")
}

///|
fn pdf_watch_review_markdown(topic : String) -> String {
  [
    "# PDF Watch Review Queue",
    "",
    "Use this page to decide whether candidate \{topic} source evidence becomes accepted book knowledge.",
    "",
    "- Accept only source-backed deltas.",
    "- Reject duplicates and low-quality sources.",
    "- Record why conclusions changed.",
  ].join("\n")
}

///|
fn pdf_watch_history_markdown(topic : String, book_id : String) -> String {
  [
    "# Standing Watch History",
    "",
    "- Book: `\{book_id}`",
    "- Topic: \{topic}",
    "- Current state: initialized",
    "",
    "Each watcher run must append checked websites, PDFs discovered, PDFs downloaded, accepted findings, rejected findings, wiki pages changed, output files changed, and notification status.",
  ].join("\n")
}

///|
fn pdf_watch_site_html(
  topic : String,
  book_id : String,
  pattern_id : String,
  purpose : String,
  websites : Array[String],
) -> String {
  let site_list = if websites.length() == 0 {
    "<li>No websites configured.</li>"
  } else {
    websites.map(fn(site) { "<li>\{site}</li>" }).join("")
  }
  "<!doctype html><html><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"><title>\{book_pattern_title(pattern_id, topic)}</title><style>body{margin:0;font-family:system-ui,-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#f6f7f3;color:#172018}main{max-width:960px;margin:0 auto;padding:48px 24px}section{border:1px solid #cdd6c5;background:white;border-radius:8px;padding:24px}code{background:#edf1e8;padding:2px 6px;border-radius:4px}li{margin:6px 0}</style></head><body><main><section><p><code>\{book_id}</code> · <code>\{pattern_id}</code></p><h1>\{book_pattern_title(pattern_id, topic)}</h1><p>\{purpose}</p><h2>Watch Sites</h2><ul>\{site_list}</ul><h2>Workflow</h2><ol><li>Discover changed PDFs from configured websites.</li><li>Download PDFs and extract text/tables with provenance.</li><li>Analyze with the book-local method and skills.</li><li>Promote accepted findings into the wiki and notify only on new knowledge.</li></ol></section></main></body></html>\n"
}
