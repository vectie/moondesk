///|
struct PackAppRecord {
  pack_id : String
  version : String
  display_name : String
  description : String
  kind : String
  launch_url : String
  status : String
  entrypoint_count : Int
  workflow_count : Int
  tool_count : Int
  configuration_message : String
} derive(FromJson)

///|
struct PackAppCatalog {
  app_count : Int
  configured_count : Int
  apps : Array[PackAppRecord]
} derive(FromJson)
