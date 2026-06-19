///|
pub fn json_object_field(json : Json, key : String) -> Json? {
  match json {
    Object(object) => object.get(key)
    _ => None
  }
}

///|
pub fn string_array_json(items : Array[String]) -> Json {
  Json::array([ for item in items => Json::string(item) ])
}

///|
pub fn json_array_items(json : Json, key : String) -> Array[Json] {
  match json_object_field(json, key) {
    Some(Array(items)) => items
    _ => []
  }
}

///|
pub fn json_string(json : Json, key : String, default~ : String) -> String {
  match json_object_field(json, key) {
    Some(String(value)) => value
    _ => default
  }
}

///|
pub fn json_string_opt(json : Json, key : String) -> String? {
  match json_object_field(json, key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}

///|
pub fn json_first_string(
  json : Json,
  keys : Array[String],
  default~ : String,
) -> String {
  for key in keys {
    let value = json_string(json, key, default="")
    if value != "" {
      return value
    }
  }
  default
}

///|
pub fn json_int(json : Json, key : String, default~ : Int) -> Int {
  match json_object_field(json, key) {
    Some(value) =>
      @json.from_json(value) catch {
        _ =>
          match value {
            String(text) => @string.parse_int(text) catch { _ => default }
            _ => default
          }
      }
    None => default
  }
}

///|
pub fn json_bool(json : Json, key : String, default~ : Bool) -> Bool {
  match json_object_field(json, key) {
    Some(value) => @json.from_json(value) catch { _ => default }
    None => default
  }
}
