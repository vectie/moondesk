///|
fn string_array_json(items : Array[String]) -> Json {
  @mooncore.string_array_json(items)
}

///|
fn json_array_items(json : Json, key : String) -> Array[Json] {
  @mooncore.json_array_items(json, key)
}

///|
fn json_string(json : Json, key : String, default~ : String) -> String {
  @mooncore.json_string(json, key, default~)
}

///|
fn json_bool(json : Json, key : String, default~ : Bool) -> Bool {
  @mooncore.json_bool(json, key, default~)
}

///|
fn session_runtime_session_id(session : Json) -> String {
  let runtime_id = json_string(
    session,
    "mooncode_runtime_session_id",
    default="",
  )
  if runtime_id != "" {
    runtime_id
  } else {
    json_string(session, "id", default="")
  }
}
