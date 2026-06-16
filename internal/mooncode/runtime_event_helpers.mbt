///|
fn runtime_with_field(base : Json, key : String, value : Json) -> Json {
  match base {
    Json::Object(fields) => {
      let next : Map[String, Json] = {}
      for item in fields {
        next[item.0] = item.1
      }
      next[key] = value
      Json::object(next)
    }
    _ => base
  }
}

///|
fn runtime_json_object_field(json : Json, key : String) -> Json? {
  match json {
    Json::Object(fields) => fields.get(key)
    _ => None
  }
}

///|
fn runtime_json_object_field_or_empty(json : Json, key : String) -> Json {
  match runtime_json_object_field(json, key) {
    Some(value) => value
    None => Json::object({})
  }
}

///|
fn runtime_json_array_items(json : Json, key : String) -> Array[Json] {
  match runtime_json_object_field(json, key) {
    Some(Json::Array(values)) => values
    _ => []
  }
}

///|
fn runtime_first_string(
  json : Json,
  keys : Array[String],
  default~ : String,
) -> String {
  for key in keys {
    let value = runtime_json_string(json, key, default="")
    if value != "" {
      return value
    }
  }
  default
}

///|
fn runtime_json_string(json : Json, key : String, default~ : String) -> String {
  match runtime_json_object_field(json, key) {
    Some(Json::String(value)) => value
    Some(value) => value.stringify()
    None => default
  }
}

///|
fn runtime_json_int(json : Json, key : String, default~ : Int) -> Int {
  match runtime_json_object_field(json, key) {
    Some(Json::Number(value, ..)) => value.to_int()
    Some(Json::String(value)) => @string.parse_int(value) catch { _ => default }
    _ => default
  }
}

///|
fn runtime_trimmed_text(value : String, fallback~ : String) -> String {
  let trimmed = value.trim().to_owned()
  if trimmed == "" {
    fallback
  } else {
    trimmed
  }
}
