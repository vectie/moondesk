///|
fn json_field_string(json : Json, key : String, default~ : String) -> String {
  match json {
    Object(object) =>
      match object.get(key) {
        Some(String(value)) => value
        _ => default
      }
    _ => default
  }
}

///|
fn json_field_object_or_self(json : Json, key : String) -> Json {
  match json {
    Object(object) =>
      match object.get(key) {
        Some(value) =>
          match value {
            Object(_) => value
            _ => json
          }
        _ => json
      }
    _ => json
  }
}

///|
fn json_field_bool_label(json : Json, key : String) -> String {
  match json {
    Object(object) =>
      match object.get(key) {
        Some(value) => {
          let parsed : Bool = @json.from_json(value) catch { _ => false }
          if parsed { "true" } else { "false" }
        }
        _ => "false"
      }
    _ => "false"
  }
}

///|
fn json_field_bool(json : Json, key : String, default~ : Bool) -> Bool {
  match json {
    Object(object) =>
      match object.get(key) {
        Some(value) => @json.from_json(value) catch { _ => default }
        _ => default
      }
    _ => default
  }
}

///|
fn json_field_int(json : Json, key : String, default~ : Int) -> Int {
  match json {
    Object(object) =>
      match object.get(key) {
        Some(value) => @json.from_json(value) catch { _ => default }
        _ => default
      }
    _ => default
  }
}

///|
fn json_field_string_array_summary(
  json : Json,
  key : String,
  limit~ : Int = 2,
) -> String {
  let items : Array[String] = []
  match json {
    Object(object) =>
      match object.get(key) {
        Some(Array(values)) =>
          for value in values {
            match value {
              String(text) => if text != "" { items.push(text) }
              _ => ()
            }
          }
        _ => ()
      }
    _ => ()
  }
  if items.length() == 0 {
    "none"
  } else if items.length() <= limit {
    items.join("; ")
  } else {
    items[:limit].join("; ") + " +" + (items.length() - limit).to_string()
  }
}

///|
fn json_field_string_array_items(json : Json, key : String) -> Array[String] {
  let items : Array[String] = []
  match json {
    Object(object) =>
      match object.get(key) {
        Some(Array(values)) =>
          for value in values {
            match value {
              String(text) => if text != "" { items.push(text) }
              _ => ()
            }
          }
        _ => ()
      }
    _ => ()
  }
  items
}

///|
fn json_field_json_array_items(json : Json, key : String) -> Array[Json] {
  let items : Array[Json] = []
  match json {
    Object(object) =>
      match object.get(key) {
        Some(Array(values)) =>
          for value in values {
            items.push(value)
          }
        _ => ()
      }
    _ => ()
  }
  items
}
