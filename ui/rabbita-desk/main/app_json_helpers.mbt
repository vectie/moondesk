///|
fn json_string_array(items : Array[String]) -> Json {
  let values : Array[Json] = []
  for item in items {
    values.push(item.to_json())
  }
  Json::array(values)
}

///|
fn json_field(json : Json, key : String) -> Json? {
  match json {
    Object(object) => object.get(key)
    _ => None
  }
}

///|
fn json_string_value(json : Json, key : String, default~ : String) -> String {
  match json_field(json, key) {
    Some(value) =>
      @json.from_json(value) catch {
        _ => default
      }
    None => default
  }
}

///|
fn json_int_value(json : Json, key : String, default~ : Int) -> Int {
  match json_field(json, key) {
    Some(value) =>
      @json.from_json(value) catch {
        _ => default
      }
    None => default
  }
}
