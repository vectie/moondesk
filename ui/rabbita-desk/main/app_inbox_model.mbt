///|
struct InboxCreated {
  ok : Bool
  workspace_id : String
  path : String
} derive(FromJson)

///|
struct MarkdownEditResult {
  workspace_id : String
  path : String
} derive(FromJson)

///|
struct InboxImportResult {
  ok : Bool
  workspace_id : String
  path : String
  kind : String
  data_path : String
} derive(FromJson)

///|
struct LocalImportFile {
  id : String
  name : String
  relative_path : String?
  media_type : String
  content : String
  source : String
} derive(FromJson)

///|
struct BrowserLocalImportBatch {
  ok : Bool
  files : Array[LocalImportFile]
  error : String?
} derive(FromJson)
