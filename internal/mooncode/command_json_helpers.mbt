///|
fn trimmed_or(value : String, fallback~ : String) -> String {
  let trimmed = value.trim().to_owned()
  if trimmed == "" {
    fallback
  } else {
    trimmed
  }
}

///|
fn command_json_object_field_or_empty(json : Json, key : String) -> Json {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(value) => value
        None => Json::object({})
      }
    _ => Json::object({})
  }
}

///|
fn command_json_string_array_items(json : Json, key : String) -> Array[String] {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(Json::Array(values)) => {
          let result : Array[String] = []
          for value in values {
            match value {
              Json::String(item) => result.push(item)
              _ => ()
            }
          }
          result
        }
        _ => []
      }
    _ => []
  }
}

///|
fn command_json_array_field_or_empty(json : Json, key : String) -> Json {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(Json::Array(values)) => Json::array(values)
        _ => Json::array([])
      }
    _ => Json::array([])
  }
}

///|
fn command_json_array_length(json : Json, key : String) -> Int {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(Json::Array(values)) => values.length()
        _ => 0
      }
    _ => 0
  }
}

///|
fn command_json_int(json : Json, key : String, default~ : Int) -> Int {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(value) => @json.from_json(value) catch { _ => default }
        _ => default
      }
    _ => default
  }
}

///|
fn command_string_array_contains(
  items : Array[String],
  needle : String,
) -> Bool {
  for item in items {
    if item == needle {
      return true
    }
  }
  false
}
