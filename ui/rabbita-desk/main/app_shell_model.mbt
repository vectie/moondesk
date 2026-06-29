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
  Desk
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
struct PreviewTab {
  title : String
  path : String
  renderer : @desk.PreviewRenderer
}
