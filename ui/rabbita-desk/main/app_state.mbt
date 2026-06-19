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
    MoonWiki => "book/wiki workspace"
    MoonCode => "coding/chat workspace"
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
    { key: Explorer, icon: "F", label: "Explorer" },
    { key: Search, icon: "S", label: "Search" },
    { key: Inbox, icon: "I", label: "Inbox" },
    { key: MoonCode, icon: "C", label: "MoonCode" },
    { key: Town, icon: "T", label: "Town" },
    { key: Runs, icon: "R", label: "Runs" },
    { key: Settings, icon: "G", label: "Settings" },
  ]
}

///|
fn drawer_tabs() -> Array[DrawerTabButton] {
  [
    { key: DrawerRequests, label: "Requests" },
    { key: DrawerMessages, label: "Town Messages" },
    { key: DrawerRuns, label: "Runs" },
    { key: DrawerMoonCode, label: "MoonCode" },
    { key: DrawerRecent, label: "Recent" },
  ]
}
