///|
fn runtime_lane_is_proof(lane : String) -> Bool {
  match lane {
    "tool" | "diff" | "test" | "artifact" | "review" => true
    _ => false
  }
}

///|
fn runtime_string_array_contains(items : Array[String], value : String) -> Bool {
  for item in items {
    if item == value {
      return true
    }
  }
  false
}

///|
fn runtime_receipt_statuses(receipts : Array[Json]) -> Map[String, String] {
  let statuses : Map[String, String] = {}
  for receipt in receipts {
    let command_id = rq_json_string(receipt, "command_id", default="")
    if command_id != "" {
      statuses[command_id] = rq_json_string(
        receipt,
        "status",
        default="recorded",
      )
    }
  }
  statuses
}

///|
fn runtime_latest_receipts(receipts : Array[Json]) -> Map[String, Json] {
  let latest : Map[String, Json] = {}
  for receipt in receipts {
    let command_id = rq_json_string(receipt, "command_id", default="")
    if command_id != "" {
      latest[command_id] = receipt
    }
  }
  latest
}

///|
fn runtime_session_command_failed(session : Json, command_id : String) -> Bool {
  if command_id == "" {
    return false
  }
  let mut failed = false
  for event in rq_json_array_items(session, "mooncode_command_events") {
    let packet = rq_json_object_field_or_empty(event, "command_packet")
    if rq_json_string(packet, "command_id", default="") == command_id &&
      rq_json_string(event, "status", default="") == "failed" {
      failed = true
    }
  }
  failed
}

///|
fn runtime_owner_record() -> Json {
  {
    "ui": "moondesk",
    "runtime": "moonclaw",
    "extractable_component": "mooncode",
  }
}

///|
fn rq_json_with_missing_string(
  object : Json,
  field : String,
  value : String,
) -> Json {
  match rq_json_object_field(object, field) {
    Some(_) => object
    None => rq_json_with_field(object, field, value.to_json())
  }
}

///|
fn rq_json_with_missing_bool(
  object : Json,
  field : String,
  value : Bool,
) -> Json {
  match rq_json_object_field(object, field) {
    Some(_) => object
    None => rq_json_with_field(object, field, value.to_json())
  }
}

///|
fn rq_json_with_missing_json(
  object : Json,
  field : String,
  value : Json,
) -> Json {
  match rq_json_object_field(object, field) {
    Some(_) => object
    None => rq_json_with_field(object, field, value)
  }
}

///|
fn rq_json_with_field(object : Json, field : String, value : Json) -> Json {
  match object {
    Json::Object(fields) => {
      let next : Map[String, Json] = {}
      for item in fields {
        next[item.0] = item.1
      }
      next[field] = value
      Json::object(next)
    }
    _ => object
  }
}

///|
fn runtime_safe_id(value : String, fallback~ : String) -> String {
  let trimmed = value.trim().to_owned()
  if trimmed == "" ||
    trimmed == "." ||
    trimmed == ".." ||
    trimmed.contains("/") ||
    trimmed.contains("\\") ||
    trimmed.contains(":") ||
    trimmed.length() > 160 {
    fallback
  } else {
    trimmed
  }
}

///|
fn rq_json_object_field(json : Json, key : String) -> Json? {
  match json {
    Json::Object(object) => object.get(key)
    _ => None
  }
}

///|
fn rq_json_object_field_or_empty(json : Json, key : String) -> Json {
  match rq_json_object_field(json, key) {
    Some(value) => value
    None => Json::object({})
  }
}

///|
fn rq_json_array_items(json : Json, key : String) -> Array[Json] {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(Json::Array(items)) => items
        _ => []
      }
    _ => []
  }
}

///|
fn rq_json_string_array_items(json : Json, key : String) -> Array[String] {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(value) => @json.from_json(value) catch { _ => [] }
        _ => []
      }
    _ => []
  }
}

///|
fn rq_json_string(json : Json, key : String, default~ : String) -> String {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(Json::String(value)) => value
        _ => default
      }
    _ => default
  }
}

///|
fn rq_json_bool(json : Json, key : String, default~ : Bool) -> Bool {
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
fn rq_json_int(json : Json, key : String, default~ : Int) -> Int {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(value) => @json.from_json(value) catch { _ => default }
        _ => default
      }
    _ => default
  }
}
