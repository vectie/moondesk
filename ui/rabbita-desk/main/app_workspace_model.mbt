///|
struct SavedViewRecord {
  id : String
  title : String
  query : String
  workspace_id : String
  path : String
  created_at : String
  updated_at : String
} derive(FromJson)

///|
struct SearchHit {
  workspace_id : String
  workspace_name : String
  path : String
  title : String
  kind : @desk.EntryKind
  source_layer : @desk.SourceLayer
  snippet : String
} derive(FromJson)

///|
struct CreatedWorkspace {
  workspace_id : String
  book_id : String
  name : String
  path : String
} derive(FromJson)

///|
struct MoonSuiteProduct {
  id : String
  name : String
  status : String
} derive(FromJson)

///|
struct WorkspaceMetadata {
  root_path : String
  suite_root : String
  active_suite_root : String
  library_path : String
  books_root : String
  products : Array[MoonSuiteProduct]
} derive(FromJson)

///|
struct DeskEntryCreated {
  workspace_id : String
  path : String
  directory : String
} derive(FromJson)

///|
struct DeskEntryRenamed {
  workspace_id : String
  path : String
  directory : String
} derive(FromJson)

///|
struct DeskEntryMoved {
  workspace_id : String
  path : String
  directory : String
  moved_count : Int
} derive(FromJson)

///|
struct DeskEntryCopied {
  workspace_id : String
  path : String
  directory : String
  copied_count : Int
} derive(FromJson)

///|
struct DeskEntryTrashed {
  workspace_id : String
  path : String
  directory : String
  trash_path : String
  trashed_count : Int
} derive(FromJson)

///|
struct DeskTrashEntry {
  workspace_id : String
  original_path : String
  trash_path : String
  receipt_path : String
  trashed_at : String
} derive(FromJson)

///|
struct DeskEntryRestored {
  workspace_id : String
  path : String
  directory : String
} derive(FromJson)

///|
struct DeskFilesImported {
  workspace_id : String
  path : String
  directory : String
  imported_count : Int
} derive(FromJson)
