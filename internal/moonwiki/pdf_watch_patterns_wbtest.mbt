///|
async test "book pattern discovery reads Moontown template registry" {
  let root = "/tmp/moondesk-template-registry-wbtest"
  let template_root = @pathx.join(root, "templates/books/pdf-evidence-watch")
  let tool_template_root = @pathx.join(root, "templates/books/app-tool-book")
  @fsx.make_directory(template_root, recursive=true, exists_ok=true)
  @fsx.make_directory(tool_template_root, recursive=true, exists_ok=true)
  @fsx.write_to_file(
    @pathx.join(root, "templates/books/templates.json"),
    (
      {
        "templates": [
          {
            "template_id": "pdf-evidence-watch",
            "book_type": "research-book",
            "specialization": "pdf-evidence-watch",
            "title": "Registry PDF Evidence Watch",
            "purpose": "Loaded from the local Moontown registry.",
            "root": "templates/books/pdf-evidence-watch",
            "install_example": "templates/books/pdf-evidence-watch/install.example.json",
            "install_command": "moon run cmd/main -- books template install pdf-evidence-watch <config.json>",
            "status_command": "moon run cmd/main -- books pdf-watch status <book-id>",
            "required_paths": [
              "book.json", "skills/pdf-watch/SKILL.md", "skills/pdf-analysis/SKILL.md",
            ],
            "editable_files": [
              "skills/pdf-watch/SKILL.md", "skills/pdf-analysis/SKILL.md",
            ],
          },
          {
            "template_id": "app-tool-book",
            "book_type": "toolbook",
            "specialization": "app-tool-book",
            "title": "Registry App ToolBook",
            "purpose": "Loaded from the current Moontown app toolbook registry.",
            "root": "templates/books/app-tool-book",
            "install_example": "templates/books/app-tool-book/install.example.json",
            "install_command": "moon run cmd/main -- books template install app-tool-book <config.json>",
            "status_command": "moon run cmd/main -- books app-tool status <book-id>",
            "required_paths": [
              "book.json", "app/tool.js", "skills/tool-watch/SKILL.md",
            ],
            "editable_files": ["skills/tool-watch/SKILL.md", "app/tool.js"],
          },
        ],
      } : Json).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(template_root, "install.example.json"),
    (
      {
        "book_id": "research-registry-pdf-watch",
        "title": "Registry PDF Watch",
        "purpose": "Registry-loaded install example.",
        "websites": ["https://registry.example/reports"],
        "analysis_method": "",
        "analysis_method_path": "analysis-method.example.md",
        "cadence_ticks": 17,
        "workspace_root": "",
      } : Json).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(tool_template_root, "install.example.json"),
    (
      {
        "book_id": "tool-registry-app",
        "title": "Registry App Tool",
        "purpose": "Registry-loaded toolbook install example.",
        "websites": ["https://registry.example/tools"],
        "analysis_method": "",
        "cadence_ticks": 11,
        "workspace_root": "",
      } : Json).stringify(indent=2) +
    "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(template_root, "book.json"),
    "{ }\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(tool_template_root, "book.json"),
    "{ }\n",
    create=0o644,
  )
  @fsx.make_directory(
    @pathx.join(template_root, "skills/pdf-watch"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(
    @pathx.join(template_root, "skills/pdf-analysis"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    @pathx.join(template_root, "skills/pdf-watch/SKILL.md"),
    "---\nname: pdf-watch\n---\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(template_root, "skills/pdf-analysis/SKILL.md"),
    "---\nname: pdf-analysis\n---\n",
    create=0o644,
  )
  @fsx.make_directory(
    @pathx.join(tool_template_root, "skills/tool-watch"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(
    @pathx.join(tool_template_root, "app"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    @pathx.join(tool_template_root, "skills/tool-watch/SKILL.md"),
    "---\nname: tool-watch\n---\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(tool_template_root, "app/tool.js"),
    "export function render() {}\n",
    create=0o644,
  )
  let patterns = book_pattern_records_for_workspace(root)
  assert_eq(patterns.length(), 3)
  let pdf = match json_record_by_id(patterns, "pdf-evidence-watch") {
    Some(record) => record
    None => fail("expected registry PDF pattern")
  }
  assert_eq(
    json_string(pdf, "title", default=""),
    "Registry PDF Evidence Watch",
  )
  assert_eq(json_int(pdf, "default_cadence_minutes", default=0), 17)
  assert_eq(json_string_array_items(pdf, "default_websites"), [
    "https://registry.example/reports",
  ])
  assert_eq(json_string_array_items(pdf, "skills"), [
    "pdf-watch", "pdf-analysis",
  ])
  let tool_pattern = match json_record_by_id(patterns, "app-tool-book") {
    Some(record) => record
    None => fail("expected registry app toolbook pattern")
  }
  assert_eq(json_string(tool_pattern, "base_type", default=""), "toolbook")
  assert_eq(
    json_string(tool_pattern, "title", default=""),
    "Registry App ToolBook",
  )
  assert_eq(json_int(tool_pattern, "default_cadence_minutes", default=0), 11)
  assert_eq(json_string_array_items(tool_pattern, "skills"), ["tool-watch"])
  let base_types = book_base_type_records_for_workspace(root)
  assert_eq(base_types.length(), 2)
  let base = match json_record_by_id(base_types, "research-book") {
    Some(record) => record
    None => fail("expected research-book base")
  }
  assert_true(
    json_string_array_items(base, "supported_patterns").contains(
      "pdf-evidence-watch",
    ),
  )
  assert_true(
    json_string_array_items(base, "supported_patterns").contains(
      "exchangeable-bond-evidence-watch",
    ),
  )
  assert_eq(
    json_string(base, "source", default=""),
    "moontown-template-registry + moonbook-layout",
  )
  assert_true(
    json_string_array_items(base, "moonbook_layout_refs").contains(
      "../moonbook/docs/CLI_AND_LAYOUT.md",
    ),
  )
  assert_true(
    json_string_array_items(base, "template_registry_refs").contains(
      "../moontown/templates/books/templates.json",
    ),
  )
  let tool_base = match json_record_by_id(base_types, "toolbook") {
    Some(record) => record
    None => fail("expected toolbook base")
  }
  assert_eq(json_string(tool_base, "title", default=""), "ToolBook")
  assert_true(
    json_string_array_items(tool_base, "supported_patterns").contains(
      "app-tool-book",
    ),
  )
  assert_true(
    json_string_array_items(tool_base, "required_roots").contains("app/"),
  )
  assert_true(
    json_string_array_items(tool_base, "template_registry_refs").contains(
      @pathx.join(root, "templates/books/app-tool-book/book.json"),
    ),
  )
  let status = book_template_registry_status(root)
  assert_true(json_bool(status, "ready", default=false))
  assert_eq(json_int(status, "template_count", default=0), 2)
  assert_eq(json_int(status, "missing_count", default=-1), 0)
}

///|
test "custom EB analysis method is preserved and completed with required contract" {
  let short = "# My EB Method\n\nFocus on official PDFs."
  let materialized = analysis_method_for_pattern(
    "exchangeable-bond-evidence-watch", "Exchangeable Bond Credit Compliance", short,
  )
  assert_true(materialized.contains(short))
  assert_true(materialized.contains("Moondesk Required EB Output Contract"))
  assert_true(materialized.contains("公告追踪主表"))
  assert_true(materialized.contains("关键指标监控表"))
  assert_true(
    materialized.contains(
      "EB追踪_[债券代码]_[债券简称]_[YYYYMMDD].xlsx",
    ),
  )
  assert_true(materialized.contains("未检索到"))
  assert_true(materialized.contains("sse.com.cn"))
  assert_true(materialized.contains("shclearing.com.cn"))
  assert_true(eb_analysis_method_contract_ready(materialized))
  let complete = default_eb_analysis_method("Complete EB")
  assert_eq(
    analysis_method_for_pattern(
      "exchangeable-bond-evidence-watch", "Complete EB", complete,
    ),
    complete,
  )
  assert_eq(
    analysis_method_for_pattern("pdf-evidence-watch", "Policy", short),
    short,
  )
}
