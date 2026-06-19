///|
async fn write_pdf_watch_book_files(
  book_root~ : String,
  book_id~ : String,
  topic~ : String,
  pattern_id~ : String,
  purpose~ : String,
  book_json~ : Json,
  method_body~ : String,
  websites~ : Array[String],
) -> Bool {
  @fsx.write_to_file(
    @pathx.join(book_root, "book.json"),
    book_json.stringify(indent=2) + "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, pdf_watch_operator_config_relative_path()),
    pdf_watch_operator_config_json(book_json).stringify(indent=2) + "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, pdf_watch_base_type_selection_relative_path()),
    pdf_watch_base_type_selection_json(book_json).stringify(indent=2) + "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "wiki/index.md"),
    pdf_watch_index_markdown(topic, book_id, pattern_id, purpose, websites),
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "wiki/methods/analysis-method.md"),
    method_body + "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "wiki/methods/my-analysis-method.md"),
    method_body + "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "skills/pdf-watch/SKILL.md"),
    pdf_watch_skill_markdown(topic),
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "skills/pdf-analysis/SKILL.md"),
    pdf_analysis_skill_markdown(topic),
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "skills/tool-watch/SKILL.md"),
    tool_watch_skill_markdown(topic),
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "skills/tool-build/SKILL.md"),
    tool_build_skill_markdown(topic),
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "schemas/pdf-source.schema.md"),
    pdf_source_schema_markdown(),
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "schemas/analysis-result.schema.md"),
    analysis_result_schema_markdown(),
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "raw/bootstrap/PDF_WATCH_CONTRACT.md"),
    pdf_watch_contract_markdown(pattern_id, topic),
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "raw/inbox/.keep"),
    "",
    create=0o644,
  )
  @fsx.write_to_file(@pathx.join(book_root, "raw/pdfs/.keep"), "", create=0o644)
  @fsx.write_to_file(@pathx.join(book_root, "raw/html/.keep"), "", create=0o644)
  @fsx.write_to_file(
    @pathx.join(book_root, "raw/extracted/.keep"),
    "",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "raw/analysis-runs/.keep"),
    "",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "wiki/sources/README.md"),
    pdf_watch_sources_readme(topic),
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "wiki/evidence-matrix.md"),
    pdf_watch_evidence_matrix_markdown(pattern_id, topic),
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "wiki/findings/README.md"),
    pdf_watch_findings_readme(pattern_id, topic),
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "wiki/reviews/pdf-watch-review.md"),
    pdf_watch_review_markdown(topic),
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "wiki/history/standing-watch.md"),
    pdf_watch_history_markdown(topic, book_id),
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "wiki/tools/tool-spec.md"),
    [
      "# Evidence Tool Spec", "", "- Template: `app-tool-book`", "- Tool id: `pdf-evidence-tool`",
      "- Inputs: downloaded PDFs/HTML source pages, extracted text, analysis results, and Bookkeeper decisions.",
      "- Outputs: `book/site/generated/tool.html`, `tool-manifest.json`, `wiki/reports/latest-analysis.md`, and optional book-local artifacts.",
      "- Evidence rule: every visible claim links to source-backed evidence.", "",
    ].join("\n"),
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "tool-manifest.json"),
    toolbook_manifest_seed_json(book_id).stringify(indent=2) + "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "app/index.html"),
    "<!doctype html><meta charset=\"utf-8\"><title>PDF Evidence Tool</title><p>Run the PDF evidence watch to generate this miniapp.</p>",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "book/site/generated/tool.html"),
    "<!doctype html><meta charset=\"utf-8\"><title>PDF Evidence Tool</title><p>Run the PDF evidence watch to generate this miniapp.</p>",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "book/Home.html"),
    pdf_watch_site_html(topic, book_id, pattern_id, purpose, websites),
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "book/site/generated/index.html"),
    pdf_watch_site_html(topic, book_id, pattern_id, purpose, websites),
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "site/generated/index.html"),
    pdf_watch_site_html(topic, book_id, pattern_id, purpose, websites),
    create=0o644,
  )
  true
}
