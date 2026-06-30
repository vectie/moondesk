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
fn activity_from_slug(slug : String) -> Activity {
  match slug {
    "files" => Files
    "desk" => Files
    "search" => Search
    "inbox" => Inbox
    "town" => Town
    "runs" => Runs
    "settings" => Settings
    _ => Files
  }
}

///|
fn activity_slug(activity : Activity) -> String {
  match activity {
    Files => "files"
    Search => "search"
    Inbox => "inbox"
    Town => "town"
    Runs => "runs"
    Settings => "settings"
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
    { key: Files, icon: "F", label: "Files" },
    { key: Search, icon: "S", label: "Search" },
    { key: Inbox, icon: "N", label: "Notes" },
    { key: Town, icon: "T", label: "Town" },
    { key: Runs, icon: "R", label: "Runs" },
    { key: Settings, icon: "G", label: "Settings" },
  ]
}

///|
