///|
fn initial_activity() -> Activity {
  activity_from_slug(browser_initial_activity())
}

///|
fn activity_from_slug(slug : String) -> Activity {
  match slug {
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
    Explorer => "explorer"
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
    MoonWiki => "read and organize AI-written books"
    MoonCode => "chat with an agent to change book code"
  }
}

///|
fn workspace_mode_for_activity(activity : Activity) -> WorkspaceMode {
  match activity {
    MoonCode => MoonCode
    _ => MoonWiki
  }
}

///|
fn activities() -> Array[ActivityButton] {
  [
    { key: Explorer, icon: "B", label: "Books" },
    { key: Search, icon: "S", label: "Search" },
    { key: Inbox, icon: "N", label: "Notes" },
    { key: MoonCode, icon: "C", label: "Code" },
    { key: Town, icon: "T", label: "Town" },
    { key: Runs, icon: "R", label: "Runs" },
    { key: Settings, icon: "G", label: "Settings" },
  ]
}

///|
