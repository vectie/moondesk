///|
test "desktop api route builder encodes path segments and query values" {
  assert_eq(
    @core.desktop_api_url(["api", "workspaces", "book demo/#one", "entries"], query=[
      ("path", "docs/read me?#1"),
    ]),
    "/api/workspaces/book%20demo%2F%23one/entries?path=docs%2Fread%20me%3F%231",
  )
  assert_eq(
    @core.desktop_api_query([("workspace", "book demo"), ("query", "a/b")]),
    "workspace=book%20demo&query=a%2Fb",
  )
  assert_eq(
    @core.url_path("book/site #1/index.html"),
    "book/site%20%231/index.html",
  )
}

///|
test "workspace desktop routes live in core boundary" {
  assert_eq(@core.workspaces_url(), "/api/workspaces")
  assert_eq(@core.workspace_metadata_url(), "/api/workspaces/metadata")
  assert_eq(@core.workspace_import_url(), "/api/workspaces/import")
  assert_eq(
    @core.workspace_endpoint_url("book demo", "trash"),
    "/api/workspaces/book%20demo/trash",
  )
  assert_eq(
    @core.workspace_entries_url(
      "book-demo", "docs with spaces/encoded # name.md",
    ),
    "/api/workspaces/book-demo/entries?path=docs%20with%20spaces%2Fencoded%20%23%20name.md",
  )
  assert_eq(
    @core.workspace_preview_url("book-demo", "raw/data?set%.json"),
    "/api/workspaces/book-demo/preview?path=raw%2Fdata%3Fset%25.json",
  )
  assert_eq(
    @core.workspace_raw_url("book-demo", "images/logo #1.png"),
    "/api/workspaces/book-demo/raw?path=images%2Flogo%20%231.png",
  )
  assert_eq(
    @core.workspace_file_url(
      "book-demo", "book/site/generated/assets/site #1.css",
    ),
    "/api/workspaces/book-demo/file/book/site/generated/assets/site%20%231.css",
  )
  assert_eq(
    @core.workspace_site_url("book demo", "assets/site #1.css"),
    "/api/workspaces/book%20demo/site/assets/site%20%231.css",
  )
}

///|
test "product and system desktop routes live in core boundary" {
  assert_eq(@core.desktop_capabilities_url(), "/api/desktop/capabilities")
  assert_eq(@core.moonclaw_endpoint_url("daemon"), "/api/moonclaw/daemon")
  assert_eq(
    @core.moonclaw_run_artifacts_route(),
    "/api/moonclaw/runs/<run-id>/artifacts",
  )
  assert_eq(
    @core.moonclaw_workspace_url("runs", "book demo/#one"),
    "/api/moonclaw/runs?workspace=book%20demo%2F%23one",
  )
  assert_eq(
    @core.review_items_url("book demo/#one"),
    "/api/review/items?workspace=book%20demo%2F%23one",
  )
  assert_eq(@core.review_decision_url(), "/api/review/items/decision")
  assert_eq(@core.search_url("moon suite"), "/api/search?query=moon%20suite")
  assert_eq(@core.town_endpoint_url("daemon/status"), "/api/town/daemon/status")
  assert_eq(@core.town_calendar_url(), "/api/town/calendar.ics")
  assert_eq(@core.preferences_views_url(), "/api/preferences/views")
  assert_eq(
    @core.books_endpoint_url("app-tool-portable/all"),
    "/api/books/app-tool-portable/all",
  )
}

///|
test "desktop api route contracts own active backend method policy" {
  let endpoints = @core.desktop_api_required_endpoints()
  assert_true(endpoints.length() > 40)
  assert_eq(endpoints.length(), @core.desktop_api_route_contracts().length())
  assert_true(endpoints.contains(@core.desktop_capabilities_route()))
  assert_true(endpoints.contains(@core.workspace_action_route("entries")))
  assert_true(endpoints.contains(@core.workspace_file_route()))
  assert_true(endpoints.contains(@core.town_route("dispatch")))
  assert_false(endpoints.contains(@core.town_route("control")))
  assert_eq(
    @core.desktop_api_route_allowed_methods(@core.workspaces_route()).join(", "),
    "GET, HEAD, POST",
  )
  assert_eq(
    @core.desktop_api_route_allowed_methods(@core.desktop_capabilities_route()).join(
      ", ",
    ),
    "GET, HEAD",
  )
  assert_eq(
    @core.desktop_api_route_allowed_methods(
      @core.workspace_action_route("trash"),
    ).join(", "),
    "GET, HEAD, POST",
  )
  assert_eq(
    @core.desktop_api_route_allowed_methods(@core.town_route("dispatch")).join(
      ", ",
    ),
    "POST",
  )
  assert_eq(
    @core.desktop_api_route_allowed_methods(@core.books_route("from-pattern")).join(
      ", ",
    ),
    "POST",
  )
  assert_true(
    @core.desktop_api_route_accepts_method(
      @core.preferences_views_route(),
      "HEAD",
    ),
  )
  assert_false(
    @core.desktop_api_route_accepts_method(@core.town_route("control"), "POST"),
  )
}

///|
test "desktop portable api support derives from core desktop routes" {
  let snapshot_routes = @core.desktop_portable_api_snapshot_routes()
  assert_eq(snapshot_routes.length(), 4)
  assert_true(snapshot_routes.contains(@core.workspaces_route()))
  assert_true(snapshot_routes.contains(@core.books_route("patterns")))
  assert_true(snapshot_routes.contains(@core.books_route("base-types")))
  assert_true(snapshot_routes.contains(@core.books_route("template-registry")))
  assert_false(snapshot_routes.contains(@core.town_route("dispatch")))

  let content_routes = @core.desktop_portable_api_workspace_content_routes()
  assert_eq(content_routes.length(), 5)
  assert_true(content_routes.contains(@core.workspace_action_route("entries")))
  assert_true(content_routes.contains(@core.workspace_action_route("preview")))
  assert_true(content_routes.contains(@core.workspace_action_route("raw")))
  assert_true(content_routes.contains(@core.workspace_file_route()))
  assert_true(content_routes.contains(@core.workspace_site_route()))

  let supported = @core.desktop_portable_api_supported_route_patterns()
  assert_eq(
    supported.length(),
    snapshot_routes.length() + content_routes.length(),
  )
  assert_true(@core.desktop_portable_api_route_supported("/api/books/patterns"))
  assert_true(@core.desktop_portable_api_route_supported("/api/workspaces/"))
  assert_true(
    @core.desktop_portable_api_route_supported("/api/books/base-types?fresh=1"),
  )
  assert_true(
    @core.desktop_portable_api_route_supported("/api/books/patterns/?fresh=1"),
  )
  assert_true(
    @core.desktop_portable_api_route_supported(
      "/api/workspaces/book-demo/raw?path=book/outputs/report.txt",
    ),
  )
  assert_true(
    @core.desktop_portable_api_route_supported(
      "/api/workspaces/book-demo/preview?path=book/site/generated/index.html",
    ),
  )
  assert_true(
    @core.desktop_portable_api_route_supported(
      "/api/workspaces/book-demo/file/raw/excel/results.xlsx",
    ),
  )
  assert_true(
    @core.desktop_portable_api_route_supported(
      "/api/workspaces/book-demo/site/assets/site.css",
    ),
  )
  assert_false(@core.desktop_portable_api_route_supported("/api/town/progress"))
  assert_false(
    @core.desktop_portable_api_route_supported(
      "/api/workspaces/book-demo/markdown",
    ),
  )
}

///|
test "desktop api capability schema lives in core boundary" {
  let capability = @core.desktop_api_capability_contract()
  assert_eq(capability.component, "moondesk-desktop-api")
  assert_eq(capability.kind, "moondesk-desktop-api-capabilities.v1")
  assert_eq(capability.version, 1)
  assert_eq(
    capability.route_contract_endpoint,
    @core.desktop_capabilities_route(),
  )
  assert_eq(
    capability.required_endpoints.length(),
    @core.desktop_api_required_endpoints().length(),
  )
  assert_eq(
    capability.desktop_route_contracts.length(),
    @core.desktop_api_route_contracts().length(),
  )
  assert_true(
    capability.desktop_route_contracts.contains({
      path: @core.desktop_capabilities_route(),
      methods: ["GET", "HEAD"],
    }),
  )
  assert_true(
    capability.portable_api_snapshot_routes.contains(
      @core.books_route("patterns"),
    ),
  )
  assert_true(
    capability.portable_api_workspace_content_routes.contains(
      @core.workspace_action_route("raw"),
    ),
  )
  assert_eq(
    capability.portable_api_supported_route_patterns.length(),
    capability.portable_api_snapshot_routes.length() +
    capability.portable_api_workspace_content_routes.length(),
  )
  assert_false(
    capability.portable_api_supported_route_patterns.contains(
      @core.town_route("dispatch"),
    ),
  )
}
