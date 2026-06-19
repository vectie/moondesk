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
struct TagRecord {
  id : String
  workspace_id : String
  path : String
  tag : String
  created_at : String
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

