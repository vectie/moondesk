///|
struct MoonCodeRuntimeServiceState {
  status : String
} derive(FromJson)

///|
struct MoonCodeRuntimeEventSink {
  event_count : Int
  events : Array[MoonCodeEvent]
  runtime_service : MoonCodeRuntimeServiceState
} derive(FromJson)
