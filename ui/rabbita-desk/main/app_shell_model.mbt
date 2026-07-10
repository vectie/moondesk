///|
enum Activity {
  Files
  Search
  Inbox
  Town
  Runs
  Settings
} derive(Eq)

///|
enum WorkspaceMode {
  Desk
  MoonWiki
  MoonCode
} derive(Eq)

///|
enum PendingMarkdownNavigation {
  NoPendingMarkdownNavigation
  PendingWorkspaceMode(WorkspaceMode)
  PendingActivity(Activity)
  PendingWorkspace(String)
  PendingPath(String)
  PendingDirectory(String)
  PendingQuickPath(String)
  PendingSearchHit(String, String)
} derive(Eq)

///|
struct ActivityButton {
  key : Activity
  label : String
}

///|
struct PreviewTab {
  title : String
  path : String
  renderer : @desk.PreviewRenderer
}
