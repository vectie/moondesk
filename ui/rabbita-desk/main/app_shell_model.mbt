///|
enum Activity {
  Explorer
  Search
  Inbox
  MoonCode
  Town
  Runs
  Settings
} derive(Eq)

///|
enum WorkspaceMode {
  MoonWiki
  MoonCode
} derive(Eq)

///|
struct ActivityButton {
  key : Activity
  icon : String
  label : String
}

///|
enum DrawerTab {
  DrawerRequests
  DrawerMessages
  DrawerRuns
  DrawerMoonCode
  DrawerRecent
} derive(Eq)

///|
struct DrawerTabButton {
  key : DrawerTab
  label : String
}

///|
struct PreviewTab {
  title : String
  path : String
  renderer : @desk.PreviewRenderer
}

