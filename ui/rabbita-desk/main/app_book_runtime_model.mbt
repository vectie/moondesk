///|
struct BookPatternCreationResult {
  book_id : String
  workspace_id : String
  standing_goal : Json
  moontown_publish : Json
  readiness : Json
} derive(FromJson)

///|
struct BookPatternRecord {
  id : String
  title : String
  base_type : String
  description : String
  output : String
  default_topic : String
  default_cadence_minutes : Int
  default_source_policy : String
  standing_watch : Bool
  creation_backend : String
  default_websites : Array[String]
  skills : Array[String]
} derive(FromJson)

///|
struct BookBaseTypeRecord {
  id : String
  title : String
  description : String
  owner : String
  source : String
  creation_palette_source : String
  moonbook_layout_refs : Array[String]
  template_registry_refs : Array[String]
  supported_patterns : Array[String]
  required_roots : Array[String]
} derive(FromJson)
