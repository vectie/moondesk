///|
test "workspace modes use stable user-facing labels and summaries" {
  assert_eq(workspace_mode_label(Desk), "Desk")
  assert_eq(workspace_mode_label(MoonWiki), "Wiki")
  assert_eq(workspace_mode_label(MoonCode), "Code")
  assert_eq(workspace_mode_label(RequestsWorkspace), "Requests")
  assert_eq(workspace_mode_label(RunsWorkspace), "Runs")
  assert_eq(workspace_mode_label(ReviewWorkspace), "Review")
  assert_eq(workspace_mode_label(PublishWorkspace), "Publish")
  assert_eq(workspace_mode_label(MoonFlow), "Flow")
  assert_eq(workspace_mode_label(PackHome), "Packs")
  assert_eq(workspace_mode_summary(Desk), "Desk workspace")
  assert_eq(workspace_mode_summary(MoonWiki), "Wiki workspace")
  assert_eq(workspace_mode_summary(MoonCode), "Code workspace")
}

///|
test "activities use stable user-facing labels" {
  assert_eq(activity_label(Files), "Pages")
  assert_eq(activity_label(Search), "Search")
  assert_eq(activity_label(Inbox), "Inbox")
  assert_eq(activity_label(Town), "Requests")
  assert_eq(activity_label(Runs), "Review")
  assert_eq(activity_label(Settings), "Settings")
  let labels = activities().map(item => item.label)
  assert_eq(labels.length(), 4)
  assert_eq(labels[0], "Pages")
  assert_eq(labels[1], "Search")
  assert_eq(labels[2], "Inbox")
  assert_eq(labels[3], "Settings")
}

///|
test "current and legacy navigation slugs remain compatible" {
  assert_true(workspace_mode_from_initial_activity("home") is Desk)
  assert_true(workspace_mode_from_initial_activity("desk") is Desk)
  assert_true(workspace_mode_from_initial_activity("code") is MoonCode)
  assert_true(workspace_mode_from_initial_activity("mooncode") is MoonCode)
  assert_true(
    workspace_mode_from_initial_activity("requests") is RequestsWorkspace,
  )
  assert_true(workspace_mode_from_initial_activity("runs") is RunsWorkspace)
  assert_true(workspace_mode_from_initial_activity("review") is ReviewWorkspace)
  assert_true(
    workspace_mode_from_initial_activity("publish") is PublishWorkspace,
  )
  assert_true(
    workspace_mode_from_initial_activity("activity") is RequestsWorkspace,
  )
  assert_true(workspace_mode_from_initial_activity("town") is RequestsWorkspace)
  assert_true(workspace_mode_from_initial_activity("flow") is MoonFlow)
  assert_true(workspace_mode_from_initial_activity("moonflow") is MoonFlow)
  assert_true(activity_from_slug("activity") is Town)
  assert_true(activity_from_slug("town") is Town)
  assert_true(activity_from_slug("review") is Runs)
  assert_true(activity_from_slug("runs") is Runs)
  assert_true(activity_from_slug("settings") is Settings)
  assert_true(activity_from_slug("more") is Settings)
  assert_eq(activity_slug(Town), "activity")
  assert_eq(activity_slug(Runs), "review")
  assert_eq(activity_slug(Settings), "more")
}

///|
test "palette high-level navigation uses user vocabulary" {
  let home = palette_commands_for_mode(Desk).map(command => command.0)
  assert_true(home.contains("Open Desk"))
  assert_true(home.contains("Open Wiki"))
  assert_true(home.contains("Open Code"))
  assert_false(home.contains("Browse Home"))
  assert_false(home.contains("Open in Wiki"))
  let pages = palette_commands_for_mode(MoonWiki).map(command => command.0)
  assert_true(pages.contains("Open Wiki"))
  assert_true(pages.contains("Open Pages"))
  assert_true(pages.contains("Open Requests"))
  assert_true(pages.contains("Open Settings"))
  let code = palette_commands_for_mode(MoonCode).map(command => command.0)
  assert_true(code.contains("Submit Request"))
  assert_false(code.contains("Submit to Town"))
}
