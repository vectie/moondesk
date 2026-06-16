///|
fn summary_json_object_field(json : Json, key : String) -> Json? {
  match json {
    Object(map) => map.get(key)
    _ => None
  }
}

///|
fn summary_json_object_field_or_empty(json : Json, key : String) -> Json {
  match summary_json_object_field(json, key) {
    Some(value) => value
    None => Json::object({})
  }
}

///|
fn summary_json_int(json : Json, key : String, default~ : Int) -> Int {
  match summary_json_object_field(json, key) {
    Some(Json::Number(value, ..)) => value.to_int()
    Some(Json::String(value)) => @string.parse_int(value) catch { _ => default }
    _ => default
  }
}
