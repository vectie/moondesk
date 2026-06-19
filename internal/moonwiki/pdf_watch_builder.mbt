///|
async fn create_pdf_watch_book_dirs(book_root : String) -> Bool {
  let dirs = [
    "", "raw", "raw/bootstrap", "raw/inbox", "raw/pdfs", "raw/html", "raw/extracted",
    "raw/analysis-runs", "wiki", "wiki/sources", "wiki/findings", "wiki/methods",
    "wiki/reports", "wiki/tools", "wiki/reviews", "wiki/history", "skills", "skills/pdf-watch",
    "skills/pdf-analysis", "skills/tool-watch", "skills/tool-build", "schemas", "moonclaw-packets",
    "app", "book", "book/outputs", "book/site", "book/site/generated", "site", "site/generated",
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
  ignore(pattern_id)
  default_pdf_analysis_method(topic)
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
  ignore(pattern_id)
  ignore(topic)
  requested
}

///|
fn default_book_pattern_purpose(pattern_id : String, topic : String) -> String {
  ignore(pattern_id)
  "Standing MoonBook workspace for \{topic} PDF discovery, download, extraction, method-specific analysis, durable findings, and operator notification when accepted new knowledge appears."
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
  skill_pack~ : Array[String],
) -> Json {
  let skills = if skill_pack.length() == 0 {
    default_skill_pack_for_pattern(pattern_id)
  } else {
    skill_pack
  }
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
      "enabled": true,
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
      "runtime_control": "Moontown",
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
      "target_scope": "generic",
      "discovery_mode": "configured_target_source_adapter",
    },
    "analysis": {
      "method_page": method_path,
      "source_schema": "schemas/pdf-source.schema.md",
      "result_schema": "schemas/analysis-result.schema.md",
      "output_contract": "moontown.pdf_evidence_watch.result.v1",
      "source_registry_path": "wiki/sources/README.md",
      "findings_path": "wiki/findings/README.md",
      "review_path": "wiki/reviews/pdf-watch-review.md",
      "skills": json_from_string_array(skills),
      "notify_on": json_from_string_array(notify_on),
    },
    "targets": {
      "kind": "generic-pdf-evidence",
      "target_scope": "generic",
      "discovery_mode": "configured_target_source_adapter",
      "target_count": 0,
      "multi_target_supported": false,
      "portfolio_supported": false,
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
  ignore(pattern_id)
  let title = "Watch \{topic} PDFs"
  {
    "id": pdf_watch_goal_id(book_id),
    "title": title,
    "target_book_id": book_id,
    "cadence_ticks": cadence,
    "next_due_tick": daemon_tick,
    "last_run_tick": Json::null(),
    "enabled": true,
    "source_policy": source_policy,
    "review_policy": "accepted_new_knowledge",
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
        ["target_scope"],
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
