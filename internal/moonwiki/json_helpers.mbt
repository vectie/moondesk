///|
fn trimmed_payload_text(text : String, default~ : String) -> String {
  let text = text.trim().to_owned()
  if text == "" {
    default
  } else {
    text
  }
}

///|
fn json_string_array_items(json : Json, key : String) -> Array[String] {
  let values : Array[String] = []
  for item in json_array_items(json, key) {
    match item {
      String(value) => {
        let value = value.trim().to_owned()
        if value != "" {
          values.push(value)
        }
      }
      _ => ()
    }
  }
  values
}

///|
fn json_object_field_or_empty(json : Json, key : String) -> Json {
  match json_object_field(json, key) {
    Some(value) => value
    None => Json::object({})
  }
}

///|
fn json_from_string_array(items : Array[String]) -> Json {
  let values : Array[Json] = []
  for item in items {
    values.push(item.to_json())
  }
  Json::array(values)
}
