///|
/// Stable user-facing vocabulary for existing workspace routing modes.
fn workspace_mode_label(mode : WorkspaceMode) -> String {
  match mode {
    PackHome => "Packs"
    Desk => "Home"
    MoonWiki => "Pages"
    MoonCode => "Code"
    RequestsWorkspace => "Requests"
    RunsWorkspace => "Runs"
    ReviewWorkspace => "Review"
    PublishWorkspace => "Publish"
    MoonFlow => "Flow"
  }
}

///|
/// Stable user-facing vocabulary for existing activities.
fn activity_label(activity : Activity) -> String {
  match activity {
    Files => "Pages"
    Search => "Search"
    Inbox => "Inbox"
    Town => "Requests"
    Runs => "Review"
    Settings => "Settings"
  }
}

///|
/// A workspace title derived without changing routing identity.
fn workspace_mode_title(mode : WorkspaceMode) -> String {
  workspace_mode_label(mode)
}

///|
/// An activity title derived without changing routing identity.
fn activity_title(activity : Activity) -> String {
  activity_label(activity)
}
