///|
struct MoonClawDaemonStatus {
  running : Bool
  port : Int
  message : String
  service_configured : Bool
} derive(FromJson)

///|
struct MoonClawModel {
  name : String
} derive(FromJson)

///|
struct MoonClawModelsResult {
  ok : Bool
  daemon : MoonClawDaemonStatus
  models : Array[MoonClawModel]
} derive(FromJson)
