///|
fn json_string(json : Json, key : String, default~ : String) -> String {
  @mooncore.json_string(json, key, default~)
}

///|
fn json_bool(json : Json, key : String, default~ : Bool) -> Bool {
  @mooncore.json_bool(json, key, default~)
}

///|
fn json_int(json : Json, key : String, default~ : Int) -> Int {
  @mooncore.json_int(json, key, default~)
}

///|
fn json_array_items(json : Json, key : String) -> Array[Json] {
  @mooncore.json_array_items(json, key)
}

///|
fn json_object_field_or_empty(json : Json, key : String) -> Json {
  @mooncore.json_object_field(json, key).unwrap_or(Json::object({}))
}

///|
fn json_string_array_items(json : Json, key : String) -> Array[String] {
  let result : Array[String] = []
  for item in json_array_items(json, key) {
    match item {
      String(value) => result.push(value)
      _ => ()
    }
  }
  result
}

///|
fn string_array_json(items : Array[String]) -> Json {
  @mooncore.string_array_json(items)
}

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
fn json_with_field(base : Json, key : String, value : Json) -> Json {
  @mooncore.session_with_field(base, key, value)
}

///|
fn json_without_field(base : Json, key : String) -> Json {
  match base {
    Object(fields) => {
      let next : Map[String, Json] = {}
      for existing_key, value in fields {
        if existing_key != key {
          next[existing_key] = value
        }
      }
      Json::object(next)
    }
    _ => base
  }
}

///|
pub fn session_with_field(base : Json, key : String, value : Json) -> Json {
  json_with_field(base, key, value)
}
