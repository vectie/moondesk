///|
async fn create_pdf_watch_book_dirs(book_root : String) -> Bool {
  let dirs = [
    "", "raw", "raw/bootstrap", "raw/inbox", "raw/pdfs", "raw/html", "raw/extracted",
    "raw/analysis-runs", "raw/excel", "wiki", "wiki/sources", "wiki/findings", "wiki/methods",
    "wiki/reports", "wiki/tools", "wiki/reviews", "wiki/history", "skills", "skills/pdf-watch",
    "skills/pdf-analysis", "skills/eb-credit-compliance", "skills/tool-watch", "skills/tool-build",
    "schemas", "moonclaw-packets", "app", "book", "book/outputs", "book/site", "book/site/generated",
    "site", "site/generated",
  ]
  for dir in dirs {
    let path = if dir == "" { book_root } else { @pathx.join(book_root, dir) }
    @fsx.make_directory(path, recursive=true, exists_ok=true)
  }
  true
}

///|
fn default_pdf_analysis_method(topic : String) -> String {
  [
    "# PDF Evidence Watch Method",
    "",
    "Topic: \{topic}",
    "",
    "1. Treat PDFs as candidate evidence, not accepted knowledge.",
    "2. Record source URL, title, publisher, retrieval time, and sha256 before analysis.",
    "3. Extract full text and screen for relevance to the configured domain.",
    "4. Compare new claims against the existing wiki baseline and evidence matrix.",
    "5. Queue review when a source changes a finding, adds a material source, or changes a conclusion.",
    "6. Notify only after Bookkeeper accepts new source-backed knowledge.",
    "",
  ].join("\n")
}

///|
fn default_analysis_method_for_pattern(
  pattern_id : String,
  topic : String,
) -> String {
  if pattern_id == "exchangeable-bond-evidence-watch" {
    default_eb_analysis_method(topic)
  } else {
    default_pdf_analysis_method(topic)
  }
}

///|
fn analysis_method_for_pattern(
  pattern_id : String,
  topic : String,
  requested : String,
) -> String {
  let requested = requested.trim().to_owned()
  if requested == "" {
    return default_analysis_method_for_pattern(pattern_id, topic)
  }
  if pattern_id != "exchangeable-bond-evidence-watch" ||
    eb_analysis_method_contract_ready(requested) {
    requested
  } else {
    [
      requested,
      "",
      "---",
      "",
      "## Moondesk Required EB Output Contract",
      "",
      "The operator method above is preserved. The following guardrails are appended by Moondesk so MoonClaw and Bookkeeper cannot drop the EB lifecycle, official-source, workbook, or validation contract.",
      "",
      default_eb_analysis_method(topic),
    ].join("\n")
  }
}

///|
fn eb_analysis_method_contract_ready(text : String) -> Bool {
  text.contains("公告追踪主表") &&
  text.contains("关键指标监控表") &&
  text.contains("EB追踪_[债券代码]_[债券简称]_[YYYYMMDD].xlsx") &&
  text.contains("未检索到") &&
  text.contains("sse.com.cn") &&
  text.contains("szse.cn") &&
  text.contains("cninfo.com.cn") &&
  text.contains("chinabond.com.cn") &&
  text.contains("shclearing.com.cn") &&
  text.contains("发行与上市") &&
  text.contains("存续期定期报告") &&
  text.contains("存续期临时公告") &&
  text.contains("换股期管理") &&
  text.contains("赎回与回售") &&
  text.contains("兑付与退出") &&
  text.contains("Canonical Chinese Operator Prompt Contract") &&
  text.contains("Sheet 1 headers") &&
  text.contains("Sheet 2 headers")
}

///|
fn default_book_pattern_purpose(pattern_id : String, topic : String) -> String {
  if pattern_id == "exchangeable-bond-evidence-watch" {
    "Standing research-book for \{topic}: official-source discovery, exchangeable bond lifecycle extraction, credit/compliance review, Bookkeeper acceptance, and durable XLSX/wiki outputs when accepted knowledge changes."
  } else {
    "Standing MoonBook workspace for \{topic} PDF discovery, download, extraction, method-specific analysis, durable findings, and operator notification when accepted new knowledge appears."
  }
}

///|
fn book_pattern_output_files(pattern_id : String) -> Array[String] {
  let files = [
    "raw/pdfs/",
    "raw/extracted/",
    pdf_watch_operator_config_relative_path(),
    pdf_watch_base_type_selection_relative_path(),
    "wiki/sources/",
    "wiki/evidence-matrix.md",
    "wiki/findings/",
    "book/site/generated/index.html",
    pdf_watch_moontown_standing_goal_receipt_relative_path(),
    pdf_watch_moontown_publish_receipt_relative_path(),
  ]
  if pattern_id == "exchangeable-bond-evidence-watch" {
    files.push("raw/inbox/eb-tracking-request.json")
    files.push("raw/inbox/eb-standing-watch-dispatch.json")
    files.push("moonclaw.jobs.json")
    files.push(eb_moonclaw_proposal_packet_relative_path())
    files.push("raw/bootstrap/EB_WATCH_CONTRACT.md")
    files.push(eb_operator_prompt_relative_path())
    files.push("raw/bootstrap/eb_discover_pdf_candidates.py")
    files.push("raw/bootstrap/eb_extract_pdf_text.py")
    files.push("raw/bootstrap/eb_package_workbook.py")
    files.push(eb_prompt_contract_receipt_relative_path())
    files.push(eb_expected_output_contract_relative_path())
    files.push("raw/analysis-runs/eb-contract-verification.json")
    files.push("raw/analysis-runs/eb-output-validation.json")
    files.push(eb_output_template_relative_path())
    files.push(
      eb_output_manifest_relative_path(eb_output_template_relative_path()),
    )
    files.push(
      eb_output_workbook_validation_relative_path(
        eb_output_template_relative_path(),
      ),
    )
    files.push("book/outputs/README.md")
  }
  files
}

///|
fn pdf_watch_book_json(
  book_id~ : String,
  topic~ : String,
  pattern_id~ : String,
  purpose~ : String,
  cadence~ : Int,
  websites~ : Array[String],
  source_policy~ : String,
  method_path~ : String,
  notify_on~ : Array[String],
  skill_pack? : Array[String] = [],
  eb_target_scope? : String = "",
  eb_target_bonds? : Array[Json] = [],
) -> Json {
  let skills = if skill_pack.length() == 0 {
    default_skill_pack_for_pattern(pattern_id)
  } else {
    skill_pack
  }
  let eb_target_scope = infer_eb_target_scope(
    eb_target_scope,
    eb_target_fields_from_payload(Json::object({})),
    eb_target_bonds,
  )
  let eb_target_bonds = eb_effective_target_bonds(
    eb_target_scope,
    eb_target_fields_from_payload(Json::object({})),
    eb_target_bonds,
  )
  {
    "id": book_id,
    "type": "research-book",
    "book_type": "research-book",
    "pattern": pattern_id,
    "specialization": pattern_id,
    "template_id": "pdf-evidence-watch",
    "template_version": "1",
    "tags": json_from_string_array([
      "research",
      "standing-watch",
      "pdf-evidence",
      "source-first",
      "domain-specific-analysis",
      "pattern:\{pattern_id}",
    ]),
    "required_paths": json_from_string_array(
      pdf_watch_required_paths(pattern_id),
    ),
    "pattern_components": {
      "base_type": "research-book",
      "source_adapter": "websites",
      "extractor": "pdf-full-text",
      "analysis_skill": "pdf-analysis",
      "standing_watch": true,
    },
    "toolbook": {
      "enabled": pattern_id == "exchangeable-bond-evidence-watch",
      "template_id": "app-tool-book",
      "manifest_path": "tool-manifest.json",
      "entrypoints": json_from_string_array([
        "book/site/generated/tool.html", "app/index.html",
      ]),
      "skills": json_from_string_array(["tool-watch", "tool-build"]),
    },
    "layout": {
      "book": "book.json",
      "raw_inbox": "raw/inbox/",
      "raw_pdfs": "raw/pdfs/",
      "raw_html": "raw/html/",
      "raw_extracted": "raw/extracted/",
      "raw_analysis_runs": "raw/analysis-runs/",
      "wiki_index": "wiki/index.md",
      "wiki_sources": "wiki/sources/",
      "wiki_findings": "wiki/findings/",
      "wiki_methods": "wiki/methods/",
      "wiki_reviews": "wiki/reviews/",
      "skills": "skills/",
      "schemas": "schemas/",
      "site_generated": "site/generated/",
    },
    "base_type_provenance": pdf_watch_base_type_provenance_json(),
    "title": book_pattern_title(pattern_id, topic),
    "purpose": purpose,
    "ownership": {
      "desktop": "Moondesk",
      "scheduler": "Moontown",
      "durable_book": "MoonBook",
      "execution": "MoonClaw",
      "review": "Bookkeeper",
    },
    "watch": {
      "cadence_minutes": cadence,
      "source_policy": source_policy,
      "websites": json_from_string_array(websites),
      "file_types": json_from_string_array(["pdf"]),
      "dedupe_by": json_from_string_array(["url", "title", "sha256"]),
      "notify_on": json_from_string_array(notify_on),
      "target_scope": eb_target_scope,
      "active_universe_default": pattern_id ==
      "exchangeable-bond-evidence-watch" &&
      eb_target_scope == "active_universe",
      "discovery_mode": if pattern_id == "exchangeable-bond-evidence-watch" &&
        eb_target_scope == "active_universe" {
        "dynamic_official_source_search"
      } else {
        "configured_target_source_adapter"
      },
      "official_source_seeds": Json::array(
        eb_official_source_seed_candidates(eb_target_scope, eb_target_bonds),
      ),
      "official_pdf_seeds": Json::array(
        eb_official_pdf_seed_candidates(eb_target_scope, eb_target_bonds),
      ),
    },
    "analysis": {
      "method_page": method_path,
      "source_schema": "schemas/pdf-source.schema.md",
      "result_schema": "schemas/analysis-result.schema.md",
      "output_contract": if pattern_id == "exchangeable-bond-evidence-watch" {
        "moondesk.exchangeable_bond_tracking.xlsx.v1"
      } else {
        "moontown.pdf_evidence_watch.result.v1"
      },
      "source_registry_path": "wiki/sources/README.md",
      "findings_path": "wiki/findings/README.md",
      "review_path": "wiki/reviews/pdf-watch-review.md",
      "skills": json_from_string_array(skills),
      "notify_on": json_from_string_array(notify_on),
    },
    "targets": {
      "kind": if pattern_id == "exchangeable-bond-evidence-watch" {
        "exchangeable-bond"
      } else {
        "generic-pdf-evidence"
      },
      "target_scope": if pattern_id == "exchangeable-bond-evidence-watch" {
        eb_target_scope
      } else {
        "generic"
      },
      "active_universe_default": pattern_id ==
      "exchangeable-bond-evidence-watch" &&
      eb_target_scope == "active_universe",
      "discovery_mode": if pattern_id == "exchangeable-bond-evidence-watch" &&
        eb_target_scope == "active_universe" {
        "dynamic_official_source_search"
      } else {
        "configured_target_source_adapter"
      },
      "target_count": eb_target_bonds.length(),
      "bonds": Json::array(eb_target_bonds),
      "multi_target_supported": pattern_id == "exchangeable-bond-evidence-watch",
      "portfolio_supported": pattern_id == "exchangeable-bond-evidence-watch",
      "official_source_seeds": Json::array(
        eb_official_source_seed_candidates(eb_target_scope, eb_target_bonds),
      ),
      "official_pdf_seeds": Json::array(
        eb_official_pdf_seed_candidates(eb_target_scope, eb_target_bonds),
      ),
    },
    "moondesk": {
      "create_mode": "pattern-builder",
      "editable_files": json_from_string_array([
        "book.json", "wiki/methods/my-analysis-method.md", "skills/pdf-watch/SKILL.md",
        "skills/pdf-analysis/SKILL.md", "skills/tool-watch/SKILL.md", "skills/tool-build/SKILL.md",
        "wiki/methods/analysis-method.md",
      ]),
      "output_files": json_from_string_array(
        book_pattern_output_files(pattern_id),
      ),
      "skill_pack": json_from_string_array(skills),
      "template_publish_mode": pdf_watch_moontown_publish_mode(pattern_id),
    },
    "workflow": json_from_string_array([
      "watch websites", "discover relevant PDFs", "download PDFs", "extract full text",
      "normalize/source-screen", "run analysis method", "compare against existing book baseline",
      "update wiki/report only if new knowledge appears", "notify operator",
    ]),
  }
}

///|
fn pdf_watch_standing_goal(
  book_id~ : String,
  topic~ : String,
  pattern_id~ : String,
  purpose~ : String,
  cadence~ : Int,
  source_policy~ : String,
  daemon_tick~ : Int,
) -> Json {
  let title = if pattern_id == "exchangeable-bond-evidence-watch" {
    "Watch \{topic} EB disclosures"
  } else {
    "Watch \{topic} PDFs"
  }
  {
    "id": pdf_watch_goal_id(book_id),
    "title": title,
    "target_book_id": book_id,
    "cadence_ticks": cadence,
    "next_due_tick": daemon_tick,
    "last_run_tick": Json::null(),
    "enabled": true,
    "source_policy": source_policy,
    "quality_threshold": 85,
    "prompt": pdf_watch_goal_prompt(pattern_id, topic, purpose),
  }
}

///|
fn pdf_watch_goal_id(book_id : String) -> String {
  "watch-\{book_id}-pdfs"
}

///|
fn pdf_watch_operator_config_relative_path() -> String {
  "raw/inbox/pdf-evidence-watch-config.json"
}

///|
fn pdf_watch_base_type_selection_relative_path() -> String {
  "raw/analysis-runs/base-type-selection.json"
}

///|
fn pdf_watch_operator_config_json(book_json : Json) -> Json {
  let watch = json_object_field_or_empty(book_json, "watch")
  let analysis = json_object_field_or_empty(book_json, "analysis")
  {
    "id": json_string(book_json, "id", default=""),
    "type": "research-book",
    "specialization": json_string(
      book_json,
      "specialization",
      default="pdf-evidence-watch",
    ),
    "watch": {
      "cadence_minutes": json_int(watch, "cadence_minutes", default=30),
      "source_policy": json_string(watch, "source_policy", default="web-first"),
      "websites": json_from_string_array(
        json_string_array_items(watch, "websites"),
      ),
      "file_types": json_from_string_array(
        json_string_array_items(watch, "file_types"),
      ),
      "dedupe_by": json_from_string_array(
        json_string_array_items(watch, "dedupe_by"),
      ),
      "target_scope": json_first_string(
        watch,
        ["target_scope", "eb_target_scope"],
        default=json_string(
          json_object_field_or_empty(book_json, "targets"),
          "target_scope",
          default="",
        ),
      ),
      "active_universe_default": json_bool(
        watch,
        "active_universe_default",
        default=json_bool(
          json_object_field_or_empty(book_json, "targets"),
          "active_universe_default",
          default=false,
        ),
      ),
      "discovery_mode": json_string(
        watch,
        "discovery_mode",
        default="configured_target_source_adapter",
      ),
      "official_source_seeds": Json::array(
        json_array_items(watch, "official_source_seeds"),
      ),
      "official_pdf_seeds": Json::array(
        json_array_items(watch, "official_pdf_seeds"),
      ),
    },
    "analysis": {
      "method_page": json_string(
        analysis,
        "method_page",
        default="wiki/methods/my-analysis-method.md",
      ),
      "notify_on": json_from_string_array(
        json_string_array_items(analysis, "notify_on"),
      ),
    },
    "skill_pack": json_from_string_array(
      json_string_array_items(analysis, "skills"),
    ),
    "pattern_components": json_object_field_or_empty(
      book_json, "pattern_components",
    ),
  }
}

///|
fn pdf_watch_base_type_selection_json(book_json : Json) -> Json {
  let pattern_id = pdf_watch_pattern_id_from_book_json(book_json)
  let book_id = json_string(book_json, "id", default="")
  let book_provenance = json_object_field_or_empty(
    book_json, "base_type_provenance",
  )
  let provenance = if pdf_watch_base_type_provenance_valid(book_provenance) {
    book_provenance
  } else {
    pdf_watch_base_type_provenance_json()
  }
  let base_type = json_string(provenance, "base_type", default="research-book")
  {
    "kind": "moondesk-base-type-selection",
    "selection_version": "1",
    "book_id": book_id,
    "base_type": base_type,
    "pattern_id": pattern_id,
    "selected_by": "Moondesk",
    "selected_from": "GET /api/books/base-types",
    "base_type_owner": "MoonBook",
    "handoff_target": "Moontown",
    "build_contract": "research-book + source adapter + extractor + analysis skill + standing watch",
    "selected_from_catalog": true,
    "supported_pattern": true,
    "base_type_provenance": provenance,
    "required_roots": json_from_string_array(
      book_base_type_required_roots(base_type),
    ),
    "template_registry_refs": json_from_string_array(
      json_string_array_items(provenance, "template_registry_refs"),
    ),
    "moonbook_layout_refs": json_from_string_array(
      json_string_array_items(provenance, "moonbook_layout_refs"),
    ),
    "verified": pdf_watch_base_type_provenance_valid(provenance),
  }
}

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
  eb_target_scope? : String = "",
  eb_target_fields? : Json = eb_target_fields_from_payload(Json::object({})),
  eb_target_bonds? : Array[Json] = [],
) -> Bool {
  let eb_target_scope = infer_eb_target_scope(
    eb_target_scope, eb_target_fields, eb_target_bonds,
  )
  let eb_target_bonds = eb_effective_target_bonds(
    eb_target_scope, eb_target_fields, eb_target_bonds,
  )
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
    eb_tool_watch_skill_markdown(topic),
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "skills/tool-build/SKILL.md"),
    eb_tool_build_skill_markdown(topic),
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
  if pattern_id == "exchangeable-bond-evidence-watch" {
    @fsx.write_to_file(
      @pathx.join(book_root, "skills/eb-credit-compliance/SKILL.md"),
      eb_credit_compliance_skill_markdown(topic),
      create=0o644,
    )
    @fsx.write_to_file(
      @pathx.join(book_root, "schemas/eb-tracking-output.schema.md"),
      eb_tracking_output_schema_markdown(),
      create=0o644,
    )
    @fsx.write_to_file(
      @pathx.join(book_root, "book/outputs/README.md"),
      eb_outputs_readme_markdown(book_id),
      create=0o644,
    )
    @fsx.write_to_file(
      @pathx.join(book_root, "moonclaw.jobs.json"),
      eb_moonclaw_profile_json().stringify(indent=2) + "\n",
      create=0o644,
    )
    @fsx.write_to_file(
      @pathx.join(book_root, "raw/inbox/eb-tracking-request.json"),
      eb_tracking_request_json(
        book_id,
        topic,
        websites,
        target_scope=eb_target_scope,
        target_fields=eb_target_fields,
        target_bonds=eb_target_bonds,
      ).stringify(indent=2) +
      "\n",
      create=0o644,
    )
    @fsx.write_to_file(
      @pathx.join(book_root, "raw/inbox/eb-standing-watch-dispatch.json"),
      eb_standing_watch_dispatch_json(
        book_id,
        topic,
        websites,
        target_scope=eb_target_scope,
        target_fields=eb_target_fields,
        target_bonds=eb_target_bonds,
      ).stringify(indent=2) +
      "\n",
      create=0o644,
    )
    @fsx.write_to_file(
      @pathx.join(book_root, "raw/bootstrap/EB_WATCH_CONTRACT.md"),
      eb_watch_contract_markdown(topic),
      create=0o644,
    )
    @fsx.write_to_file(
      @pathx.join(book_root, eb_operator_prompt_relative_path()),
      eb_operator_prompt_markdown(topic, book_id),
      create=0o644,
    )
    @fsx.write_to_file(
      @pathx.join(book_root, "raw/bootstrap/eb_discover_pdf_candidates.py"),
      eb_discover_pdf_candidates_script(),
      create=0o755,
    )
    @fsx.write_to_file(
      @pathx.join(book_root, "raw/bootstrap/eb_extract_pdf_text.py"),
      eb_extract_pdf_text_script(),
      create=0o755,
    )
    @fsx.write_to_file(
      @pathx.join(book_root, "raw/bootstrap/eb_package_workbook.py"),
      eb_package_workbook_script(),
      create=0o755,
    )
    @fsx.write_to_file(
      @pathx.join(book_root, "wiki/tools/tool-spec.md"),
      [
        "# EB Evidence Dashboard Tool Spec", "", "- Template: `app-tool-book`", "- Tool id: `eb-evidence-dashboard`",
        "- Inputs: official source candidates, downloaded PDFs/HTML source pages, extracted text, AI lifecycle analysis.",
        "- Outputs: `book/outputs/EB追踪_<债券代码>_<债券简称>_<YYYYMMDD>.xlsx`, `book/site/generated/tool.html`, `tool-manifest.json`.",
        "- Quality rule: every announcement row links to an official source URL and includes source-backed extracted text evidence.",
        "",
      ].join("\n"),
      create=0o644,
    )
    @fsx.write_to_file(
      @pathx.join(book_root, "tool-manifest.json"),
      eb_toolbook_manifest_seed_json(book_id).stringify(indent=2) + "\n",
      create=0o644,
    )
    @fsx.write_to_file(
      @pathx.join(book_root, "app/index.html"),
      "<!doctype html><meta charset=\"utf-8\"><title>EB Evidence Dashboard</title><p>Run the EB evidence watch to generate the dashboard.</p>",
      create=0o644,
    )
    @fsx.write_to_file(
      @pathx.join(book_root, "book/site/generated/tool.html"),
      "<!doctype html><meta charset=\"utf-8\"><title>EB Evidence Dashboard</title><p>Run the EB evidence watch to generate the dashboard.</p>",
      create=0o644,
    )
    @fsx.write_to_file(
      @pathx.join(book_root, eb_moonclaw_proposal_packet_relative_path()),
      eb_moonclaw_proposal_packet_json(
        book_root,
        book_id,
        topic,
        websites,
        target_scope=eb_target_scope,
        target_fields=eb_target_fields,
        target_bonds=eb_target_bonds,
      ).stringify(indent=2) +
      "\n",
      create=0o644,
    )
    write_bytes_file(
      @pathx.join(book_root, eb_output_template_relative_path()),
      eb_tracking_template_xlsx_bytes(),
      create=0o644,
    )
    let output_template_path = @pathx.join(
      book_root,
      eb_output_template_relative_path(),
    )
    @fsx.write_to_file(
      @pathx.join(
        book_root,
        eb_output_manifest_relative_path(eb_output_template_relative_path()),
      ),
      eb_tracking_output_manifest_json(
        book_id~,
        run_id="template",
        bond_code="[债券代码]",
        bond_short_name="[债券简称]",
        as_of="[YYYYMMDD]",
        output_relative=eb_output_template_relative_path(),
        source_screen_relative="",
        accepted_by_bookkeeper=false,
        sample_run=false,
        xlsx_sha256=eb_file_sha256(output_template_path),
      ).stringify(indent=2) +
      "\n",
      create=0o644,
    )
    @fsx.write_to_file(
      @pathx.join(
        book_root,
        eb_output_workbook_validation_relative_path(
          eb_output_template_relative_path(),
        ),
      ),
      eb_tracking_workbook_validation_json(
        book_id~,
        run_id="template",
        output_relative=eb_output_template_relative_path(),
        sample_run=true,
        xlsx_sha256=eb_file_sha256(output_template_path),
      ).stringify(indent=2) +
      "\n",
      create=0o644,
    )
    @fsx.write_to_file(
      @pathx.join(book_root, eb_output_validation_relative_path()),
      eb_output_validation(book_root, book_id).stringify(indent=2) + "\n",
      create=0o644,
    )
    @fsx.write_to_file(
      @pathx.join(book_root, eb_prompt_contract_receipt_relative_path()),
      eb_prompt_contract_verification(book_root, book_id).stringify(indent=2) +
      "\n",
      create=0o644,
    )
    @fsx.write_to_file(
      @pathx.join(book_root, eb_expected_output_contract_relative_path()),
      eb_expected_output_contract_json(book_id).stringify(indent=2) + "\n",
      create=0o644,
    )
    @fsx.write_to_file(
      @pathx.join(book_root, "raw/analysis-runs/eb-contract-verification.json"),
      book_contract_verification("", book_root, book_id, pattern_id).stringify(
        indent=2,
      ) +
      "\n",
      create=0o644,
    )
  }
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

///|
async fn refresh_eb_runtime_artifacts(
  root : String,
  book_root : String,
  book_id : String,
) -> Json {
  let book_json = read_json_file_or_object(@pathx.join(book_root, "book.json"))
  let request = read_json_file_or_object(
    @pathx.join(book_root, "raw/inbox/eb-tracking-request.json"),
  )
  let pattern_id = pdf_watch_pattern_id_from_book_json(book_json)
  if pattern_id != "exchangeable-bond-evidence-watch" {
    return {
      "kind": "eb-runtime-refresh",
      "ok": false,
      "status": "unsupported_pattern",
      "book_id": book_id,
      "pattern_id": pattern_id,
      "changed": false,
      "refreshed_paths": json_from_string_array([]),
      "message": "Book is not an EB evidence watch book.",
    }
  }
  let title = json_string(book_json, "title", default="")
  let topic = json_first_string(
    request,
    ["topic"],
    default=topic_from_book_title(title, pattern_id, book_id),
  )
  let watch = json_object_field_or_empty(book_json, "watch")
  let mut websites = json_string_array_items(watch, "websites")
  if websites.length() == 0 {
    websites = json_string_array_items(request, "watch_websites")
  }
  if websites.length() == 0 {
    websites = eb_default_source_websites()
  }
  let purpose = trimmed_payload_text(
    json_string(book_json, "purpose", default=""),
    default=default_book_pattern_purpose(pattern_id, topic),
  )
  let cadence = positive_or_default(
    json_int(watch, "cadence_minutes", default=30),
    30,
  )
  let source_policy = trimmed_payload_text(
    json_string(watch, "source_policy", default=""),
    default="web-first",
  )
  let previous_refresh = read_json_file_or_object(
    @pathx.join(book_root, "raw/analysis-runs/eb-runtime-refresh.json"),
  )
  let previous_changed_at = json_string(
    previous_refresh,
    "latest_changed_at",
    default=if json_bool(previous_refresh, "changed", default=false) {
      json_string(previous_refresh, "recorded_at", default="")
    } else {
      ""
    },
  )
  let targets = eb_production_targets_from_book(book_root)
  let target_scope = eb_target_scope_from_book(book_root)
  let target_fields = effective_eb_target_fields(
    eb_target_fields_from_json(
      json_object_field_or_empty(request, "target_fields"),
    ),
    targets,
  )
  let refreshed_paths : Array[String] = []
  let changed_paths : Array[String] = []
  refresh_generated_text_file(
    book_root,
    "moonclaw.jobs.json",
    eb_moonclaw_profile_json().stringify(indent=2) + "\n",
    refreshed_paths,
    changed_paths,
  )
  refresh_generated_text_file(
    book_root,
    "raw/inbox/eb-tracking-request.json",
    eb_tracking_request_json(
      book_id,
      topic,
      websites,
      target_scope~,
      target_fields~,
      target_bonds=targets,
    ).stringify(indent=2) +
    "\n",
    refreshed_paths,
    changed_paths,
  )
  refresh_generated_text_file(
    book_root,
    "raw/inbox/eb-standing-watch-dispatch.json",
    eb_standing_watch_dispatch_json(
      book_id,
      topic,
      websites,
      target_scope~,
      target_fields~,
      target_bonds=targets,
    ).stringify(indent=2) +
    "\n",
    refreshed_paths,
    changed_paths,
  )
  refresh_generated_text_file(
    book_root,
    pdf_watch_base_type_selection_relative_path(),
    pdf_watch_base_type_selection_json(book_json).stringify(indent=2) + "\n",
    refreshed_paths,
    changed_paths,
  )
  refresh_generated_text_file(
    book_root,
    "raw/bootstrap/EB_WATCH_CONTRACT.md",
    eb_watch_contract_markdown(topic),
    refreshed_paths,
    changed_paths,
  )
  refresh_generated_text_file(
    book_root,
    eb_operator_prompt_relative_path(),
    eb_operator_prompt_markdown(topic, book_id),
    refreshed_paths,
    changed_paths,
  )
  refresh_generated_text_file(
    book_root,
    "raw/bootstrap/eb_discover_pdf_candidates.py",
    eb_discover_pdf_candidates_script(),
    refreshed_paths,
    changed_paths,
  )
  refresh_generated_text_file(
    book_root,
    "raw/bootstrap/eb_extract_pdf_text.py",
    eb_extract_pdf_text_script(),
    refreshed_paths,
    changed_paths,
  )
  refresh_generated_text_file(
    book_root,
    "raw/bootstrap/eb_package_workbook.py",
    eb_package_workbook_script(),
    refreshed_paths,
    changed_paths,
  )
  refresh_generated_text_file(
    book_root,
    "wiki/tools/tool-spec.md",
    [
      "# EB Evidence Dashboard Tool Spec", "", "- Template: `app-tool-book`", "- Tool id: `eb-evidence-dashboard`",
      "- Inputs: official source candidates, downloaded PDFs/HTML source pages, extracted text, AI lifecycle analysis.",
      "- Outputs: `book/outputs/EB追踪_<债券代码>_<债券简称>_<YYYYMMDD>.xlsx`, `book/site/generated/tool.html`, `tool-manifest.json`.",
      "- Quality rule: every announcement row links to an official source URL and includes source-backed extracted text evidence.",
      "",
    ].join("\n"),
    refreshed_paths,
    changed_paths,
  )
  refresh_generated_text_file(
    book_root,
    "skills/tool-watch/SKILL.md",
    eb_tool_watch_skill_markdown(topic),
    refreshed_paths,
    changed_paths,
  )
  refresh_generated_text_file(
    book_root,
    "skills/tool-build/SKILL.md",
    eb_tool_build_skill_markdown(topic),
    refreshed_paths,
    changed_paths,
  )
  refresh_generated_text_file(
    book_root,
    "tool-manifest.json",
    eb_toolbook_manifest_seed_json(book_id).stringify(indent=2) + "\n",
    refreshed_paths,
    changed_paths,
  )
  refresh_generated_text_file(
    book_root, "app/index.html", "<!doctype html><meta charset=\"utf-8\"><title>EB Evidence Dashboard</title><p>Run the EB evidence watch to generate the dashboard.</p>",
    refreshed_paths, changed_paths,
  )
  refresh_generated_text_file(
    book_root, "book/site/generated/tool.html", "<!doctype html><meta charset=\"utf-8\"><title>EB Evidence Dashboard</title><p>Run the EB evidence watch to generate the dashboard.</p>",
    refreshed_paths, changed_paths,
  )
  refresh_generated_text_file(
    book_root,
    "schemas/eb-tracking-output.schema.md",
    eb_tracking_output_schema_markdown(),
    refreshed_paths,
    changed_paths,
  )
  refresh_generated_text_file(
    book_root,
    "wiki/evidence-matrix.md",
    pdf_watch_evidence_matrix_markdown(
      "exchangeable-bond-evidence-watch", topic,
    ),
    refreshed_paths,
    changed_paths,
  )
  let existing_method = read_text_file_or_empty(
    @pathx.join(book_root, "wiki/methods/my-analysis-method.md"),
  )
  let refreshed_method = analysis_method_for_pattern(
    "exchangeable-bond-evidence-watch", topic, existing_method,
  )
  refresh_generated_text_file(
    book_root,
    "wiki/methods/my-analysis-method.md",
    refreshed_method + "\n",
    refreshed_paths,
    changed_paths,
  )
  refresh_generated_text_file(
    book_root,
    "wiki/methods/analysis-method.md",
    refreshed_method + "\n",
    refreshed_paths,
    changed_paths,
  )
  refresh_generated_text_file(
    book_root,
    eb_moonclaw_proposal_packet_relative_path(),
    eb_moonclaw_proposal_packet_json(
      book_root,
      book_id,
      topic,
      websites,
      target_scope~,
      target_fields~,
      target_bonds=targets,
    ).stringify(indent=2) +
    "\n",
    refreshed_paths,
    changed_paths,
  )
  refresh_generated_text_file(
    book_root,
    eb_prompt_contract_receipt_relative_path(),
    eb_prompt_contract_verification(book_root, book_id).stringify(indent=2) +
    "\n",
    refreshed_paths,
    changed_paths,
  )
  refresh_generated_text_file(
    book_root,
    eb_expected_output_contract_relative_path(),
    eb_expected_output_contract_json(book_id).stringify(indent=2) + "\n",
    refreshed_paths,
    changed_paths,
  )
  if root != "" {
    let daemon = read_json_file_or_object(town_daemon_path(root))
    let receipt = read_json_file_or_object(
      @pathx.join(
        book_root,
        pdf_watch_moontown_standing_goal_receipt_relative_path(),
      ),
    )
    let daemon_tick = json_int(
      receipt,
      "next_due_tick",
      default=json_int(daemon, "tick_sequence", default=0),
    )
    let goal = pdf_watch_standing_goal(
      book_id~,
      topic~,
      pattern_id~,
      purpose~,
      cadence~,
      source_policy~,
      daemon_tick~,
    )
    let previous_publish = read_text_file_or_empty(
      @pathx.join(book_root, pdf_watch_moontown_publish_receipt_relative_path()),
    )
    let previous_standing_registration = read_text_file_or_empty(
      @pathx.join(
        book_root,
        pdf_watch_moontown_standing_goal_receipt_relative_path(),
      ),
    )
    ignore(
      write_moontown_book_template_publish(
        root~,
        book_root~,
        book_id~,
        topic~,
        pattern_id~,
        purpose~,
        cadence~,
        websites~,
        method_body=refreshed_method,
        skill_pack=default_skill_pack_for_pattern(pattern_id),
        goal~,
      ),
    )
    ignore(
      write_moontown_standing_goal_registration(
        root~,
        book_root~,
        book_id~,
        pattern_id~,
        goal~,
      ),
    )
    let publish_relative = pdf_watch_moontown_publish_receipt_relative_path()
    let standing_relative = pdf_watch_moontown_standing_goal_receipt_relative_path()
    let next_publish = read_text_file_or_empty(
      @pathx.join(book_root, publish_relative),
    )
    let next_standing_registration = read_text_file_or_empty(
      @pathx.join(book_root, standing_relative),
    )
    refreshed_paths.push(publish_relative)
    if previous_publish != next_publish {
      changed_paths.push(publish_relative)
    }
    refreshed_paths.push(standing_relative)
    if previous_standing_registration != next_standing_registration {
      changed_paths.push(standing_relative)
    }
  }
  let recorded_at = @async.now().to_string()
  let latest_changed_at = if changed_paths.length() > 0 {
    recorded_at
  } else {
    previous_changed_at
  }
  let receipt : Json = {
    "kind": "eb-runtime-refresh",
    "ok": true,
    "status": if changed_paths.length() > 0 {
      "refreshed"
    } else {
      "already_current"
    },
    "book_id": book_id,
    "pattern_id": pattern_id,
    "changed": changed_paths.length() > 0,
    "topic": topic,
    "websites": json_from_string_array(websites),
    "target_count": targets.length(),
    "refreshed_paths": json_from_string_array(refreshed_paths),
    "changed_paths": json_from_string_array(changed_paths),
    "latest_changed_at": latest_changed_at,
    "recorded_at": recorded_at,
  }
  @fsx.write_to_file(
    @pathx.join(book_root, "raw/analysis-runs/eb-runtime-refresh.json"),
    receipt.stringify(indent=2) + "\n",
    create=0o644,
  )
  receipt
}
