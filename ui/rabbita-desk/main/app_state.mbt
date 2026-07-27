///|
fn initial_activity() -> Activity {
  activity_from_slug(browser_initial_activity())
}

///|
fn initial_workspace_mode() -> WorkspaceMode {
  workspace_mode_from_initial_activity(browser_initial_activity())
}

///|
fn workspace_mode_from_initial_activity(activity : String) -> WorkspaceMode {
  match activity {
    "packs" => PackHome
    "code" | "mooncode" => MoonCode
    "requests" => RequestsWorkspace
    "runs" => RunsWorkspace
    "review" => ReviewWorkspace
    "publish" => PublishWorkspace
    "flow" | "moonflow" => MoonFlow
    "desk" | "home" | "" => Desk
    "activity" | "town" => RequestsWorkspace
    "pages" | "library" | "files" | "wiki" | "more" | "settings" => MoonWiki
    _ => MoonWiki
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
  workspace_mode_label(mode) + " workspace"
}

///|
fn workspace_mode_for_activity(activity : Activity) -> WorkspaceMode {
  ignore(activity)
  MoonWiki
}

///|
fn activities() -> Array[ActivityButton] {
  [Files, Search, Inbox, Settings].map(key => {
    key,
    label: activity_title(key),
  })
}

///|
