///|
fn json_string_array(items : Array[String]) -> Json {
  let values : Array[Json] = []
  for item in items {
    values.push(ToJson::to_json(item))
  }
  Json::array(values)
}
