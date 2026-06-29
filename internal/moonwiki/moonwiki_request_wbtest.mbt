///|
test "resolve request path rejects traversal" {
  assert_true(
    resolve_request_path("/tmp/moondesk", "/")
    is Some("/tmp/moondesk/index.html"),
  )
  assert_true(resolve_request_path("/tmp/moondesk", "/../secret") is None)
}

///|
test "api path helpers handle queries and traversal" {
  assert_eq(
    strip_query("/api/workspaces/book/entries?path=wiki"),
    "/api/workspaces/book/entries",
  )
  assert_true(
    query_value("/api?path=wiki%2Findex.md&other=1", "path")
    is Some("wiki%2Findex.md"),
  )
  assert_eq(encode_query_value("/tmp/moon book"), "%2Ftmp%2Fmoon%20book")
  assert_eq(
    decode_query_value(encode_query_value("/tmp/moon book")),
    "/tmp/moon book",
  )
  assert_eq(decode_query_value("wiki%2Findex.md"), "wiki/index.md")
  assert_eq(
    decode_query_value("wiki%2Fsources%2Freport.md"),
    "wiki/sources/report.md",
  )
  assert_true(path_segments("/api/workspaces") == ["api", "workspaces"])
  assert_true(
    clean_relative_path("wiki/../raw/README.md") is Some("raw/README.md"),
  )
  assert_true(clean_relative_path("../secret") is None)
  assert_true(clean_relative_path("/tmp/secret") is None)
}

///|
async test "workspace discovery ignores plain folders" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-plain-folder-wbtest-" + @async.now().to_string(),
  )
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  let workspaces = discover_workspaces(root)
  assert_eq(workspaces.length(), 0)
}

///|
async test "workspace discovery only exposes town roots and moonbooks" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-town-root-wbtest-" + @async.now().to_string(),
  )
  @fsx.make_directory(
    @pathx.join(root, ".moontown"),
    recursive=true,
    exists_ok=true,
  )
  let town_workspaces = discover_workspaces(root)
  assert_eq(town_workspaces.length(), 1)
  assert_true(town_workspaces[0].kind is TownRoot)

  let book_root = @pathx.join(root, ".moontown/books/research-demo")
  @fsx.make_directory(book_root, recursive=true, exists_ok=true)
  let book_workspaces = discover_workspaces(root)
  assert_eq(book_workspaces.length(), 1)
  assert_eq(book_workspaces[0].name, "research-demo")
  assert_true(book_workspaces[0].kind is MoonBook)
}

///|
async test "workspace entries expose virtual filesystem metadata" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-entry-metadata-wbtest-" + @async.now().to_string(),
  )
  let wiki_root = @pathx.join(root, "wiki")
  @fsx.make_directory(wiki_root, recursive=true, exists_ok=true)
  @fsx.write_to_file(@pathx.join(wiki_root, "index.md"), "hello desk\n")
  @fsx.make_directory(@pathx.join(wiki_root, "sources"), recursive=true)
  let workspace = @desk.workspace(
    id="book-demo",
    name="Demo",
    root_path=root,
    kind=MoonBook,
  )
  let entries = list_workspace_entries(workspace, "wiki", wiki_root)
  let index = find_test_entry(entries, "wiki/index.md")
  match index {
    Some(entry) => {
      assert_true(entry.size_bytes is Some(11))
      match entry.modified_at {
        Some(value) => assert_true(value.contains("T"))
        None => fail("missing modified_at")
      }
      assert_true(entry.readable)
      assert_false(entry.writable)
    }
    None => fail("missing index.md entry")
  }
  let sources = find_test_entry(entries, "wiki/sources")
  match sources {
    Some(entry) => {
      assert_true(entry.kind is Directory)
      assert_true(entry.size_bytes is None)
      assert_true(entry.modified_at is Some(_))
    }
    None => fail("missing sources directory entry")
  }
}

///|
async test "moonbook root entries project canonical virtual sections" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-virtual-root-wbtest-" + @async.now().to_string(),
  )
  @fsx.make_directory(@pathx.join(root, "wiki/history"), recursive=true)
  @fsx.make_directory(@pathx.join(root, "raw"), recursive=true)
  @fsx.make_directory(@pathx.join(root, "book/site/generated"), recursive=true)
  @fsx.write_to_file(@pathx.join(root, "book.json"), "{\"name\":\"Demo\"}\n")
  let workspace = @desk.workspace(
    id="book-demo",
    name="Demo",
    root_path=root,
    kind=MoonBook,
  )
  let entries = list_workspace_entries(workspace, "", root)
  assert_eq(entries[0].path, "wiki")
  assert_eq(entries[0].display_name, "Wiki")
  assert_true(entries[0].source_layer is Wiki)
  assert_eq(entries[1].path, "raw")
  assert_eq(entries[1].display_name, "Raw Evidence")
  assert_true(entries[1].source_layer is RawEvidence)
  assert_true(find_test_entry(entries, "wiki/history") is Some(_))
  assert_true(find_test_entry(entries, "book/site/generated") is Some(_))
  assert_true(find_test_entry(entries, "book.json") is Some(_))
  assert_true(find_test_entry(entries, "book") is None)
}

///|
fn find_test_entry(
  entries : Array[@desk.DeskFileEntry],
  path : String,
) -> @desk.DeskFileEntry? {
  for entry in entries {
    if entry.path == path {
      return Some(entry)
    }
  }
  None
}

///|
test "request body helpers handle optional strings" {
  let payload : Json = { "title": "Draft", "path": "inbox/draft.md" }
  assert_eq(json_string(payload, "title", default="Fallback"), "Draft")
  assert_true(json_string_opt(payload, "path") is Some("inbox/draft.md"))
  assert_true(json_string_opt(payload, "missing") is None)
}

///|
test "moondesk health payload exposes readiness contract" {
  assert_eq(moondesk_health_path(), "/__moondesk_health")
  let health = moondesk_health_json("ui/rabbita-desk/dist", "../books")
  assert_true(json_bool(health, "ok", default=false))
  assert_eq(json_string(health, "service", default=""), "moondesk")
  assert_true(
    json_string(health, "ui_root", default="").contains("ui/rabbita-desk/dist"),
  )
  assert_true(
    json_string(health, "workspace_root", default="").contains("books"),
  )
}

///|
test "town request listing normalizes book-pattern handoff records" {
  let record : Json = {
    "id": "request-publish-research-policy-watch",
    "kind": "book-pattern-publish",
    "status": "ready-for-moontown",
    "book_id": "research-policy-watch",
    "title": "Policy Reports PDF Evidence Watch",
    "pattern_id": "pdf-evidence-watch",
    "purpose": "Standing research-book for official-source discovery.",
  }
  let listing = town_request_listing_record(
    record, "research-policy-watch.json",
  )
  assert_eq(
    json_string(listing, "id", default=""),
    "request-publish-research-policy-watch",
  )
  assert_eq(json_string(listing, "status", default=""), "ready-for-moontown")
  assert_eq(
    json_string(listing, "path", default=""),
    ".moontown/moondesk-requests/research-policy-watch.json",
  )
  let request = json_object_field_or_empty(listing, "request")
  assert_eq(
    json_string(request, "title", default=""),
    "Policy Reports PDF Evidence Watch",
  )
  assert_eq(
    json_string(request, "book_id", default=""),
    "research-policy-watch",
  )
  assert_eq(
    json_string(request, "pattern_id", default=""),
    "pdf-evidence-watch",
  )
}

///|
fn parse_moonclaw_json_output_for_test(text : String) -> Json {
  let parsed = @json.parse(text) catch { _ => Json::object({}) }
  if json_string(parsed, "proposal_id", default="") != "" {
    return parsed
  }
  let lines = text.split("\n").to_array()
  let mut index = lines.length()
  while index > 0 {
    index -= 1
    let line = lines[index].to_owned().trim().to_owned()
    if line == "{" || line.contains("\"proposal_id\"") {
      let candidate_lines : Array[String] = []
      let mut cursor = index
      while cursor < lines.length() {
        candidate_lines.push(lines[cursor].to_owned())
        cursor += 1
      }
      let candidate = candidate_lines.join("\n").trim().to_owned()
      let candidate_json = @json.parse(candidate) catch {
        _ => Json::object({})
      }
      if json_string(candidate_json, "proposal_id", default="") != "" {
        return candidate_json
      }
    }
  }
  Json::object({})
}

///|
test "moonclaw json parser tolerates log-prefixed pretty json" {
  let parsed = parse_moonclaw_json_output_for_test(
    "{\"level\":\"Info\",\"msg\":\"started\"}\n" +
    "{\n  \"proposal_id\": \"proposal-1\",\n  \"run_id\": \"run-1\",\n  \"status\": \"WaitingForInput\"\n}\n",
  )
  assert_eq(json_string(parsed, "proposal_id", default=""), "proposal-1")
  assert_eq(json_string(parsed, "run_id", default=""), "run-1")
  assert_eq(json_string(parsed, "status", default=""), "WaitingForInput")
}

///|
test "import markdown records URL and attachment sidecar" {
  let markdown = import_markdown(
    {
      "url": "https://example.com",
      "note": "keep this",
      "data_url": "data:image/png;base64,abc",
    },
    "url",
    "Example",
  )
  assert_true(markdown.contains("# Example"))
  assert_true(markdown.contains("- URL: https://example.com"))
  assert_true(markdown.contains("keep this"))
  assert_true(markdown.contains(".data-url.txt"))
}

///|
test "calendar escaping keeps ICS text single-line" {
  let escaped = ics_escape("A, B; C\nD")
  assert_eq(escaped, "A\\, B\\; C D")
}

///|
test "standing goal records normalize host payloads" {
  let record = standing_goal_record_from_payload(
    {
      "title": "Track APIs",
      "prompt": "Watch API docs",
      "target_book_id": "research-api",
      "cadence_ticks": "0",
      "review_policy": "accepted_new_knowledge",
      "source_policy": "web-first",
    },
    daemon_tick=42,
  )
  assert_eq(json_string(record, "id", default=""), "watch-track-apis")
  assert_eq(json_int(record, "cadence_ticks", default=0), 1)
  assert_eq(
    json_string(record, "review_policy", default=""),
    "accepted_new_knowledge",
  )
  assert_eq(json_int(record, "next_due_tick", default=0), 42)
}

///|
test "pdf evidence watch pattern builds reusable book and goal ids" {
  let base_types = book_base_type_records_from_patterns(book_pattern_records())
  assert_eq(base_types.length(), 1)
  assert_eq(json_string(base_types[0], "id", default=""), "research-book")
  assert_true(base_types[0].stringify().contains("pdf-evidence-watch"))
  assert_eq(book_pattern_base_type("pdf-evidence-watch"), "research-book")
  assert_eq(book_pattern_base_type("external-pack"), "")
  assert_true(book_pattern_supported("pdf-evidence-watch"))
  assert_false(book_pattern_supported("external-pack"))
  assert_true(book_pattern_supports_standing_watch("pdf-evidence-watch"))
  assert_false(book_pattern_supports_standing_watch("external-pack"))
  assert_eq(
    book_pattern_creation_backend("pdf-evidence-watch"),
    "builtin-pdf-evidence-watch",
  )
  assert_eq(book_pattern_creation_backend("external-pack"), "")
  assert_true(
    book_pattern_template_registry_refs("pdf-evidence-watch").contains(
      "moontown://templates/books/pdf-evidence-watch/book.json",
    ),
  )
  assert_true(
    default_skill_pack_for_pattern("pdf-evidence-watch") ==
    ["pdf-watch", "pdf-analysis"],
  )
  assert_true(default_skill_pack_for_pattern("external-pack") == [])
  assert_eq(
    normalize_pdf_watch_book_id(
      "research-my-domain-pdf-watch",
      topic="Ignored Topic",
      pattern_id="pdf-evidence-watch",
    ),
    "research-my-domain-pdf-watch",
  )
  let book_id = pdf_watch_book_id(
    "Policy Reports",
    pattern_id="pdf-evidence-watch",
  )
  assert_eq(book_id, "research-policy-reports-pdf-watch")
  let goal = pdf_watch_standing_goal(
    book_id~,
    topic="Policy Reports",
    pattern_id="pdf-evidence-watch",
    purpose="Watch policy reports",
    cadence=30,
    source_policy="web-first",
    daemon_tick=7,
  )
  assert_eq(json_string(goal, "target_book_id", default=""), book_id)
  assert_eq(json_string(goal, "id", default=""), "watch-\{book_id}-pdfs")
  assert_eq(json_int(goal, "cadence_ticks", default=0), 30)
  assert_true(json_string(goal, "prompt", default="").contains("Bookkeeper"))
  let config = pdf_watch_book_json(
    book_id~,
    topic="Policy Reports",
    pattern_id="pdf-evidence-watch",
    purpose="Watch policy reports",
    cadence=30,
    websites=["https://example.org/reports"],
    source_policy="web-first",
    method_path="wiki/methods/analysis-method.md",
    notify_on=["accepted_new_knowledge"],
    skill_pack=["pdf-watch", "pdf-analysis", "source-screening"],
  )
  assert_eq(json_string(config, "type", default=""), "research-book")
  assert_eq(json_string(config, "book_type", default=""), "research-book")
  assert_eq(json_string(config, "pattern", default=""), "pdf-evidence-watch")
  assert_eq(
    json_string(config, "specialization", default=""),
    "pdf-evidence-watch",
  )
  let targets = json_object_field_or_empty(config, "targets")
  assert_eq(json_int(targets, "target_count", default=-1), 0)
  assert_false(json_bool(targets, "multi_target_supported", default=true))
  let watch = json_object_field_or_empty(config, "watch")
  assert_true(json_string_array_items(watch, "file_types") == ["pdf"])
  assert_true(
    json_string_array_items(watch, "notify_on") == ["accepted_new_knowledge"],
  )
  let analysis = json_object_field_or_empty(config, "analysis")
  assert_eq(
    json_string(analysis, "method_page", default=""),
    "wiki/methods/analysis-method.md",
  )
  assert_eq(
    json_string(analysis, "source_schema", default=""),
    "schemas/pdf-source.schema.md",
  )
  assert_true(
    json_string_array_items(analysis, "skills").contains("source-screening"),
  )
  assert_true(
    json_string_array_items(
      json_object_field_or_empty(config, "moondesk"),
      "skill_pack",
    ).contains("pdf-analysis"),
  )
  assert_true(
    pdf_watch_notify_on_from_payload({ "notify_on": ["new_finding"] }) ==
    ["new_finding"],
  )
  assert_true(
    pdf_watch_notify_on_from_payload({ "notify_rule": "changed_conclusion" }) ==
    ["changed_conclusion"],
  )
  let nested_payload : Json = {
    "watch": {
      "cadence_minutes": 45,
      "source_policy": "web-first",
      "websites": ["https://example.org/reports"],
    },
    "analysis": {
      "method_page": "wiki/methods/my-analysis-method.md",
      "notify_on": ["new_finding", "changed_conclusion"],
    },
  }
  assert_true(
    pdf_watch_websites_from_payload(nested_payload) ==
    ["https://example.org/reports"],
  )
  assert_eq(pdf_watch_cadence_from_payload(nested_payload), 45)
  assert_eq(pdf_watch_source_policy_from_payload(nested_payload), "web-first")
  assert_true(
    pdf_watch_notify_on_from_payload(nested_payload) ==
    ["new_finding", "changed_conclusion"],
  )
}

///|
test "book pattern creation requires explicit supported pattern" {
  assert_true(
    book_pattern_id_from_creation_payload({ "pattern_id": "pdf-evidence-watch" })
    is Some("pdf-evidence-watch"),
  )
  assert_true(book_pattern_id_from_creation_payload({}) is None)
  assert_true(
    book_pattern_id_from_creation_payload({ "pattern_id": "external-pack" })
    is None,
  )
}
