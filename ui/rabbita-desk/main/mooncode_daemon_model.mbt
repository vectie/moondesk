///|
struct MoonClawDaemonStatus {
  running : Bool
  port : Int
  pid : Int
  info_path : String
  moonclaw_root : String
  message : String
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
