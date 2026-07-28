///|
#warnings("-alert_unstable")
fn render_accessibility_test_html(html : @rabbita.Html) -> String {
  @rabbita.render_to_string(@rabbita.static_cell(html))
}

///|
fn assert_polite_atomic_status(markup : String, test_id : String) -> Unit raise {
  assert_true(markup.contains("data-testid=\"\{test_id}\""))
  assert_true(markup.contains("role=\"status\""))
  assert_true(markup.contains("aria-live=\"polite\""))
  assert_true(markup.contains("aria-atomic=\"true\""))
  assert_false(markup.contains("aria-live=\"assertive\""))
}

///|
#warnings("-alert_unstable")
test "every destination owns one skip target and one named main landmark" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let book = @desk.workspace(
    id="book-alpha",
    name="Research Alpha",
    root_path="/tmp/books/research-alpha",
    kind=MoonBook,
  )
  for
    mode in [
      PackHome,
      Desk,
      MoonCode,
      RequestsWorkspace,
      RunsWorkspace,
      ReviewWorkspace,
      PublishWorkspace,
      MoonFlow,
      MoonWiki,
    ] {
    let markup = render_accessibility_test_html(
      render_app(dispatch, {
        ..init_model(),
        workspace_mode: mode,
        selected_workspace_id: "book-alpha",
        workspaces: [book],
      }),
    )
    let main_parts : Array[StringView] = markup.split("<main").collect()
    assert_eq(main_parts.length(), 2)
    assert_true(main_parts[1].contains("<h1"))
    assert_eq(markup.split(" id=\"moondesk-main-content\"").length(), 2)
    assert_eq(markup.split("data-testid=\"skip-to-main\"").length(), 2)
    assert_true(markup.contains("href=\"#moondesk-main-content\""))
    assert_true(markup.contains("tabindex=\"-1\""))
    assert_true(
      markup.contains("aria-label=\"\{workspace_mode_label(mode)} workspace\""),
    )
    assert_true(markup.contains("Skip to main content"))
    assert_true(markup.contains("data-testid=\"destination-announcement\""))
    assert_true(
      markup.contains(
        "\{workspace_mode_label(mode)} destination. Selected book: Research Alpha.",
      ),
    )
  }
}

///|
#warnings("-alert_unstable")
test "Home complementary landmarks have distinct names" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let markup = render_accessibility_test_html(
    render_app(dispatch, {
      ..init_model(),
      workspace_mode: Desk,
      selected_workspace_id: "book-alpha",
      workspaces: [
        @desk.workspace(
          id="book-alpha",
          name="Research Alpha",
          root_path="/tmp/books/research-alpha",
          kind=MoonBook,
        ),
      ],
    }),
  )
  assert_eq(markup.split("aria-label=\"MoonBook library\"").length(), 2)
  assert_eq(markup.split("aria-label=\"Selection details\"").length(), 2)
}

///|
#warnings("-alert_unstable")
test "Pages and Code complementary landmarks have distinct names" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let pages = render_accessibility_test_html(
    render_app(dispatch, {
      ..init_model(),
      workspace_mode: MoonWiki,
      selected_workspace_id: "book-alpha",
      workspaces: [
        @desk.workspace(
          id="book-alpha",
          name="Research Alpha",
          root_path="/tmp/books/research-alpha",
          kind=MoonBook,
        ),
      ],
    }),
  )
  assert_eq(pages.split("aria-label=\"Pages activities\"").length(), 2)
  assert_eq(pages.split("aria-label=\"Page browser\"").length(), 2)
  let code = render_accessibility_test_html(
    render_app(dispatch, { ..init_model(), workspace_mode: MoonCode }),
  )
  assert_eq(code.split("aria-label=\"Code sessions\"").length(), 2)
}

///|
test "preview tabs keep a name when no path is selected" {
  assert_eq(
    preview_tab_accessible_name({
      title: "",
      path: "",
      renderer: DirectoryListing,
    }),
    "Current preview, directory",
  )
  assert_eq(
    preview_tab_accessible_name({
      title: "Inbox",
      path: "wiki/inbox.md",
      renderer: Markdown,
    }),
    "Inbox, markdown",
  )
}

///|
#warnings("-alert_unstable")
test "navigation selection and destination announcement share current mode" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    workspace_mode: RunsWorkspace,
    selected_workspace_id: "book-alpha",
    workspaces: [
      @desk.workspace(
        id="book-alpha",
        name="Research Alpha",
        root_path="/tmp/books/research-alpha",
        kind=MoonBook,
      ),
    ],
  }
  let markup = render_accessibility_test_html(render_title_bar(dispatch, model))
  assert_eq(markup.split("role=\"navigation\"").length(), 4)
  assert_eq(markup.split("aria-label=\"Primary destinations\"").length(), 3)
  assert_eq(markup.split("aria-label=\"Wiki sections\"").length(), 2)
  assert_eq(markup.split("aria-current=\"page\"").length(), 4)
  assert_eq(markup.split("aria-pressed=\"true\"").length(), 4)
  assert_eq(markup.split("aria-current=\"false\"").length(), 13)
  assert_eq(markup.split("class=\"mode-button active\"").length(), 3)
  assert_eq(markup.split("class=\"workspace-tab active\"").length(), 2)
  assert_true(markup.contains("data-testid=\"wiki-tab-runs\""))
  assert_true(markup.contains("aria-keyshortcuts=\"Meta+5 Control+5\""))
  assert_true(
    markup.contains("Runs destination. Selected book: Research Alpha."),
  )
  assert_polite_atomic_status(markup, "destination-announcement")
}

///|
#warnings("-alert_unstable")
test "all typed surface announcements are polite atomic and exclude diagnostics" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let raw_error = "PRIVATE_HOST_DIAGNOSTIC_040"
  let desk = render_accessibility_test_html(
    render_desk_entries_state_panel(
      dispatch,
      { ..init_model(), desk_entries_error: raw_error },
      RecoverableError,
    ),
  )
  assert_polite_atomic_status(desk, "desk-entries-state-announcement")
  assert_true(desk.contains(raw_error))
  let preview = render_accessibility_test_html(
    render_preview_state_panel(
      dispatch,
      { ..init_model(), preview_error: raw_error },
      RecoverableError,
    ),
  )
  assert_polite_atomic_status(preview, "preview-state-announcement")
  assert_true(preview.contains(raw_error))
  assert_polite_atomic_status(
    render_accessibility_test_html(render_search_state_panel(RecoverableError)),
    "pages-search-state-announcement",
  )
  let review = render_accessibility_test_html(
    render_review_state(dispatch, {
      ..init_model(),
      review_state: Some(RecoverableError),
      host_status: raw_error,
    }),
  )
  assert_polite_atomic_status(review, "review-state-announcement")
  assert_true(review.contains(raw_error))
  let requests = render_accessibility_test_html(
    render_requests_state(dispatch, {
      ..init_model(),
      requests_state: Some(RecoverableError),
      requests_error: raw_error,
    }),
  )
  assert_polite_atomic_status(requests, "requests-state-announcement")
  assert_true(requests.contains(raw_error))
  let runs = render_accessibility_test_html(
    render_runs_state(dispatch, {
      ..init_model(),
      runs_state: Some(RecoverableError),
      runs_error: raw_error,
    }),
  )
  assert_polite_atomic_status(runs, "runs-state-announcement")
  assert_true(runs.contains(raw_error))
  let publish = render_accessibility_test_html(
    render_publish_state_notice(dispatch, {
      ..init_model(),
      publish_state: Some(RecoverableError),
      publish_error: raw_error,
    }),
  )
  assert_polite_atomic_status(publish, "publish-state-announcement")
  assert_true(publish.contains(raw_error))
  let code = render_accessibility_test_html(
    mooncode_sessions_state_panel(dispatch, {
      ..init_model(),
      mooncode_sessions_state: Some(RecoverableError),
      mooncode_sessions_error: raw_error,
    }),
  )
  assert_polite_atomic_status(code, "mooncode-sessions-state-announcement")
  assert_true(code.contains(raw_error))
  let announcement = render_accessibility_test_html(
    render_polite_state_announcement(
      "safe-announcement", "Something went wrong", "Retry without leaving this book.",
    ),
  )
  assert_polite_atomic_status(announcement, "safe-announcement")
  assert_false(announcement.contains(raw_error))
}
