///|
fn initial_activity() -> Activity {
  activity_from_slug(browser_initial_activity())
}

///|
fn activity_from_slug(slug : String) -> Activity {
  match slug {
    "desk" => Explorer
    "search" => Search
    "inbox" => Inbox
    "mooncode" => MoonCode
    "town" => Town
    "runs" => Runs
    "settings" => Settings
    _ => Explorer
  }
}

///|
fn activity_slug(activity : Activity) -> String {
  match activity {
    Explorer => "desk"
    Search => "search"
    Inbox => "inbox"
    MoonCode => "mooncode"
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
  match activity {
    MoonCode => MoonCode
    Explorer => Desk
    _ => MoonWiki
  }
}

///|
fn activities() -> Array[ActivityButton] {
  [
    { key: Explorer, icon: "D", label: "Desk" },
    { key: Search, icon: "S", label: "Search" },
    { key: Inbox, icon: "N", label: "Notes" },
    { key: MoonCode, icon: "C", label: "Code" },
    { key: Town, icon: "T", label: "Town" },
    { key: Runs, icon: "R", label: "Runs" },
    { key: Settings, icon: "G", label: "Settings" },
  ]
}

///|
