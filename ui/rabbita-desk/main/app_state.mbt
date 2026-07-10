///|
fn initial_activity() -> Activity {
  activity_from_slug(browser_initial_activity())
}

///|
fn initial_workspace_mode() -> WorkspaceMode {
  match browser_initial_activity() {
    "code" | "mooncode" => MoonCode
    "desk" | "" => Desk
    _ => MoonWiki
  }
}

///|
fn initial_mooncode_runtime_mode() -> String {
  match browser_initial_mooncode_runtime_mode() {
    "manual" => "manual"
    "off" => "manual"
    _ => "auto"
  }
}

///|
fn activity_from_slug(slug : String) -> Activity {
  match slug {
    "library" | "files" => Files
    "desk" => Files
    "search" => Search
    "inbox" => Inbox
    "activity" | "town" => Town
    "review" | "runs" => Runs
    "more" | "settings" => Settings
    _ => Files
  }
}

///|
fn activity_slug(activity : Activity) -> String {
  match activity {
    Files => "library"
    Search => "search"
    Inbox => "inbox"
    Town => "activity"
    Runs => "review"
    Settings => "more"
  }
}

///|
fn workspace_mode_summary(mode : WorkspaceMode) -> String {
  match mode {
    Desk => "Desk workspace"
    MoonWiki => "Wiki workspace"
    MoonCode => "Code workspace"
  }
}

///|
fn workspace_mode_for_activity(activity : Activity) -> WorkspaceMode {
  ignore(activity)
  MoonWiki
}

///|
fn activities() -> Array[ActivityButton] {
  [
    { key: Files, label: "Library" },
    { key: Search, label: "Search" },
    { key: Inbox, label: "Inbox" },
    { key: Town, label: "Activity" },
    { key: Runs, label: "Review" },
    { key: Settings, label: "More" },
  ]
}

///|
