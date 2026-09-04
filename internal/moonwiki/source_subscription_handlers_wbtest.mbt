///|
test "source subscriptions validate source kind cadence and required fields" {
  assert_true(
    source_subscription_create(
      {
        "workspace_id": "book-one",
        "source_kind": "database",
        "source": "example",
        "title": "Invalid source",
        "cadence": "weekly",
      },
      "2026-09-04T12:00:00Z",
    )
    is Err("invalid_source_subscription"),
  )
  let valid = source_subscription_create(
    {
      "workspace_id": "book-one",
      "source_kind": "website",
      "source": "https://example.org/reports",
      "title": "Public reports",
      "cadence": "weekly",
      "change_rule": "A report changes the accepted revenue outlook",
    },
    "2026-09-04T12:00:00Z",
  ).unwrap()
  assert_eq(json_string(valid, "status", default=""), "needs_setup")
  assert_eq(json_int(valid, "cadence_ticks", default=0), 10_080)
  assert_true(
    json_string(valid, "prompt", default="").contains(
      "Treat new knowledge as proposed",
    ),
  )
}

///|
test "source subscription activation links only the matching workspace goal" {
  let pending = source_subscription_create(
    {
      "workspace_id": "book-one",
      "source_kind": "feed",
      "source": "https://example.org/feed.xml",
      "title": "Research feed",
      "cadence": "daily",
    },
    "2026-09-04T12:00:00Z",
  ).unwrap()
  let id = json_string(pending, "id", default="")
  assert_true(
    source_subscription_activate(
      [pending],
      {
        "id": id,
        "workspace_id": "another-book",
        "standing_goal_id": "goal-one",
      },
      "2026-09-04T12:10:00Z",
    )
    is Err("invalid_source_subscription_activation"),
  )
  let active = source_subscription_activate(
    [pending],
    { "id": id, "workspace_id": "book-one", "standing_goal_id": "goal-one" },
    "2026-09-04T12:10:00Z",
  ).unwrap()
  assert_eq(json_string(active, "status", default=""), "active")
  assert_eq(json_string(active, "standing_goal_id", default=""), "goal-one")
}

///|
async test "source subscriptions persist separately by workspace" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-source-subscription-wbtest-" + @async.now().to_string(),
  )
  assert_true(prepare_moonsuite_workspace_root(root))
  let book = @pathx.join(root, "books/research-subscription")
  @fsx.make_directory(book, recursive=true, exists_ok=true)
  @fsx.write_to_file(
    @pathx.join(book, "book.json"),
    "{\"book_id\":\"research-subscription\",\"title\":\"Subscription Book\"}\n",
    create=0o644,
  )
  let workspace_id = @desk.stable_id("book", "research-subscription")
  let pending = apply_source_subscription(
    root,
    {
      "workspace_id": workspace_id,
      "source_kind": "repository",
      "source": "https://example.org/project.git",
      "title": "Project releases",
      "cadence": "weekly",
      "change_rule": "A release changes a supported workflow",
    },
    "2026-09-04T12:00:00Z",
  ).unwrap()
  let active = apply_source_subscription(
    root,
    {
      "action": "activate",
      "workspace_id": workspace_id,
      "id": json_string(pending, "id", default=""),
      "standing_goal_id": "standing-release-watch",
    },
    "2026-09-04T12:10:00Z",
  ).unwrap()
  assert_eq(json_string(active, "status", default=""), "active")
  let stored = read_json_array_file(source_subscriptions_path(root))
  assert_eq(stored.length(), 1)
  assert_eq(
    json_string(stored[0], "standing_goal_id", default=""),
    "standing-release-watch",
  )
}
