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
  @mooncore.json_object_field(json, key).unwrap_or(Json::object({}))
}

///|
fn command_json_string_array_items(json : Json, key : String) -> Array[String] {
  match json {
    Object(object) =>
      match object.get(key) {
        Some(Array(values)) => {
          let result : Array[String] = []
          for value in values {
            match value {
              String(item) => result.push(item)
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
  Json::array(@mooncore.json_array_items(json, key))
}

///|
fn command_json_array_length(json : Json, key : String) -> Int {
  @mooncore.json_array_items(json, key).length()
}

///|
fn command_json_int(json : Json, key : String, default~ : Int) -> Int {
  @mooncore.json_int(json, key, default~)
}
