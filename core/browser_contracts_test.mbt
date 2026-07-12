///|
test "opaque preview scope is local, ephemeral, and evidence capable" {
  let scope = @core.opaque_local_browser_scope(
    session_id="browser-book-demo-r7",
    workspace_id="book-demo",
    book_revision="book-r7",
    code_revision="code-a91",
  )
  assert_true(scope.origin_class is OpaqueLocalPreview)
  assert_true(scope.network_policy is LocalAssetsOnly)
  assert_true(scope.storage_lifetime is Ephemeral)
  assert_true(scope.permitted_effects.contains("capture_screenshot"))
  assert_eq(scope.download_root, "")
  assert_eq(scope.upload_sources.length(), 0)
}

///|
test "local preview path rejects traversal and unrelated workspace content" {
  assert_true(
    @core.browser_local_preview_path_allowed("book/site/generated/index.html"),
  )
  assert_true(
    @core.browser_local_preview_path_allowed(
      "book/site/generated/assets/app.js",
    ),
  )
  for
    path in [
      "", "/book/site/generated/index.html", "book/site/generated/../../wiki/index.md",
      "book/site/generated\\..\\wiki\\index.md", "wiki/index.md", "file:/etc/passwd",
    ] {
    assert_false(@core.browser_local_preview_path_allowed(path))
  }
}

///|
test "external schemes require fresh authority" {
  for
    target in [
      "https://example.com", "http://127.0.0.1:9000", "//example.com/path", "mailto:user@example.com",
      "file:///tmp/private", "data:text/html,test", "blob:null/opaque",
    ] {
    assert_true(@core.browser_external_navigation_requires_authority(target))
  }
  assert_false(
    @core.browser_external_navigation_requires_authority("assets/app.js"),
  )
}

///|
test "action receipt inputs remain scoped and secret safe" {
  let scope = @core.opaque_local_browser_scope(
    session_id="browser-book-demo-r7",
    workspace_id="book-demo",
    code_revision="code-a91",
  )
  let action = @core.browser_action(
    action_id="action-1",
    session_id="browser-book-demo-r7",
    actor=@core.User,
    operation=@core.TypeText,
    target="label=Search",
    value_redacted="[redacted]",
    expected_observation="results visible",
    code_revision="code-a91",
    created_at="2026-07-13T00:00:00Z",
  )
  assert_true(@core.browser_action_matches_scope(action, scope))
  assert_false(
    @core.browser_action_matches_scope(
      @core.browser_action(
        action_id="action-1",
        session_id="other-session",
        actor=@core.User,
        operation=@core.TypeText,
        target="label=Search",
        value_redacted="[redacted]",
        code_revision="code-a91",
      ),
      scope,
    ),
  )
  assert_false(
    @core.browser_action_matches_scope(
      @core.browser_action(
        action_id="action-1",
        session_id="browser-book-demo-r7",
        actor=@core.User,
        operation=@core.TypeText,
        target="label=Search",
        value_redacted="a-secret",
        code_revision="code-a91",
      ),
      scope,
    ),
  )
}
