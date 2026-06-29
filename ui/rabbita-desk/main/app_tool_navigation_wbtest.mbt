///|
test "portable app-tool navigation chooses only standalone-ready books" {
  let result : Json = {
    "books": [
      {
        "book_id": "external-warning-tool",
        "status": "portable_with_api_warnings",
        "operatable_without_moondesk_api": false,
        "auto_open_allowed": false,
      },
      {
        "book_id": "external-standalone-tool",
        "status": "portable_ready",
        "operatable_without_moondesk_api": true,
        "auto_open_allowed": true,
      },
    ],
  }
  assert_eq(
    first_standalone_app_tool_book_id(result),
    "external-standalone-tool",
  )
}

///|
test "portable app-tool navigation does not choose warning-only books" {
  let result : Json = {
    "books": [
      {
        "book_id": "external-warning-tool",
        "status": "portable_with_api_warnings",
        "operatable_without_moondesk_api": false,
        "auto_open_allowed": false,
      },
    ],
  }
  assert_eq(first_standalone_app_tool_book_id(result), "")
}

///|
test "book pattern builder keeps generic shell state" {
  let model = init_model()
  assert_eq(model.selected_book_pattern_id, "pdf-evidence-watch")
  assert_false(book_pattern_creator_supported(model))
  let pdf_pattern : BookPatternRecord = {
    id: "pdf-evidence-watch",
    title: "PDF Evidence Watch",
    base_type: "research-book",
    description: "Watch source PDFs.",
    output: "wiki findings",
    default_topic: "policy reports",
    default_cadence_minutes: 30,
    default_source_policy: "web-first",
    standing_watch: true,
    creation_backend: "builtin-pdf-evidence-watch",
    default_websites: ["https://example.org/reports"],
    skills: ["pdf-watch", "pdf-analysis"],
  }
  let external_pattern : BookPatternRecord = {
    id: "external-pack",
    title: "External Pack",
    base_type: "research-book",
    description: "Installed by an external pack.",
    output: "external",
    default_topic: "external",
    default_cadence_minutes: 60,
    default_source_policy: "web-first",
    standing_watch: true,
    creation_backend: "",
    default_websites: [],
    skills: [],
  }
  let loaded = { ..model, book_patterns: [pdf_pattern, external_pattern] }
  let supported = apply_selected_book_pattern(loaded, "pdf-evidence-watch")
  assert_eq(supported.selected_book_pattern_id, "pdf-evidence-watch")
  assert_eq(supported.book_pattern_topic, "policy reports")
  assert_true(book_pattern_creator_supported(supported))
  let unsupported = apply_selected_book_pattern(loaded, "external-pack")
  assert_eq(unsupported.selected_book_pattern_id, "external-pack")
  assert_false(book_pattern_creator_supported(unsupported))
  assert_true(unsupported.book_pattern_status.contains("creation backend"))
}
