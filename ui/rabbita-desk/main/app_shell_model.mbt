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
  PackHome
  Desk
  MoonWiki
  MoonCode
  RequestsWorkspace
  RunsWorkspace
  ReviewWorkspace
  PublishWorkspace
  MoonFlow
} derive(Eq)

///|
enum MoonBookAction {
  Chat
  StartTask
} derive(Eq)

///|
enum PendingMarkdownNavigation {
  NoPendingMarkdownNavigation
  PendingWorkspaceMode(WorkspaceMode)
  PendingActivity(Activity)
  PendingWorkspace(String)
  PendingMoonBookAction(String, MoonBookAction)
  PendingWorkFile(String)
  PendingWorkSearch(String, String)
  PendingWorkReturn
  PendingWorkThread(String, String, String, String)
  PendingPath(String)
  PendingDirectory(String)
  PendingQuickPath(String)
  PendingDeskQuickPath(String, String)
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
