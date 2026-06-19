///|
struct InboxCreated {
  ok : Bool
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

