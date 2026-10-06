///|
/// Browser projection only. Town owns all native targets, credentials, and writes.
priv struct TownNativeWorkStatus {
  id : String
  kind : String
  book_id : String
  criterion_id : String
  state : String
  control_state : String
  blocked_reason : String
  blocker_help : String
  session_id : String
  command_id : String
  engineering_status : String
  output : String
  generation : Int
  observed_at_ms : UInt64
  retry_after_ms : UInt64
} derive(FromJson, ToJson)

///|
priv enum TownNativeWorkRoute {
  SavedList
  SavedDetail(String)
  Mutation(String, String)
}

///|
fn town_native_work_schema() -> String {
  "moontown.native-work.status.v1"
}

///|
fn town_native_work_nonnegative_int(value : Json) -> Int? {
  guard value is Number(number, ..) && number >= 0 && number <= 2147483647.0 else {
    return None
  }
  let integer = number.to_int()
  if integer.to_double() == number {
    Some(integer)
  } else {
    None
  }
}

///|
fn town_native_work_id_valid(id : String) -> Bool {
  id.length() == 42 &&
  id.has_prefix("town-work-") &&
  id[10:].iter().all(ch => ch is ('0'..='9' | 'a'..='f'))
}

///|
/// Do not normalize separators or decode an owner-generated identifier.
fn town_native_work_route(
  path : String,
) -> Result[TownNativeWorkRoute, (Int, String)] {
  match strip_query(path).split("/").to_array() {
    ["", "api", "town", "native-work"] => Ok(SavedList)
    ["", "api", "town", "native-work", id] =>
      if town_native_work_id_valid(id.to_owned()) {
        Ok(SavedDetail(id.to_owned()))
      } else {
        Err((400, "Invalid Town work ID"))
      }
    ["", "api", "town", "native-work", id, action] =>
      if !town_native_work_id_valid(id.to_owned()) {
        Err((400, "Invalid Town work ID"))
      } else if action is ("refresh" | "cancel" | "sync") {
        Ok(Mutation(id.to_owned(), action.to_owned()))
      } else {
        Err((404, "Unknown Town work action"))
      }
    _ => Err((404, "Unknown Town work route"))
  }
}

///|
fn town_native_work_allowed_methods(
  route : TownNativeWorkRoute,
) -> Array[String] {
  match route {
    SavedList | SavedDetail(_) => ["GET"]
    Mutation(_, _) => ["POST"]
  }
}

///|
fn town_native_work_revision_body(bytes : Bytes) -> Result[Json, (Int, String)] {
  if bytes.length() > 4096 {
    return Err((413, "Town work request exceeds the 4 KiB limit"))
  }
  let text = @encoding/utf8.decode(bytes) catch {
    _ => return Err((400, "Invalid UTF-8 JSON body"))
  }
  let payload = @json.parse(text) catch {
    _ => return Err((400, "Invalid JSON body"))
  }
  guard payload is Object(fields) &&
    fields.length() == 1 &&
    fields.get("expected_revision") is Some(value) else {
    return Err((400, "Body must contain only expected_revision"))
  }
  // With this one-key scalar schema a comma always means an extra or repeated
  // field. JSON parsing otherwise collapses duplicate object keys.
  if text.contains(",") {
    return Err((400, "Body must contain expected_revision exactly once"))
  }
  guard town_native_work_nonnegative_int(value) is Some(revision) else {
    return Err((400, "expected_revision must be a nonnegative integer"))
  }
  Ok({ "expected_revision": revision })
}

///|
fn town_native_work_capability(contract : Json) -> Bool {
  guard contract
    is {
      "schema": String("moontown.api.v1"),
      "nativeWorkStatusSchema": String(schema),
      "endpoints": Array(endpoints),
      ..
    } &&
    schema == town_native_work_schema() else {
    return false
  }
  for
    (method_, path) in [
      ("GET", "/api/native-work"),
      ("GET", "/api/native-work/{id}"),
      ("POST", "/api/native-work/{id}/refresh"),
      ("POST", "/api/native-work/{id}/cancel"),
      ("POST", "/api/native-work/{id}/sync"),
    ] {
    if !endpoints.any(endpoint => {
        json_string(endpoint, "method", default="") == method_ &&
        json_string(endpoint, "path", default="") == path
      }) {
      return false
    }
  }
  true
}

///|
fn town_native_work_project_item(payload : Json) -> TownNativeWorkStatus? {
  guard payload is { "generation": generation, .. } &&
    town_native_work_nonnegative_int(generation) is Some(_) else {
    return None
  }
  let status : TownNativeWorkStatus = @json.from_json(payload) catch {
    _ => return None
  }
  if !town_native_work_id_valid(status.id) || status.generation < 0 {
    return None
  }
  Some(status)
}

///|
/// Re-encode only the approved DTO fields; never pass through raw owner JSON.
/// Output and owner-redacted diagnostics are deliberately preserved verbatim.
fn town_native_work_project(
  payload : Json,
  route : TownNativeWorkRoute,
) -> Result[Json, (Int, String)] {
  let invalid = (
    503, "MoonTown returned invalid saved work status. Upgrade or restart its owner service, then reload saved status.",
  )
  guard payload is { "schema": String(schema), "revision": revision_json, .. } &&
    schema == town_native_work_schema() else {
    return Err(invalid)
  }
  guard town_native_work_nonnegative_int(revision_json) is Some(revision) else {
    return Err(invalid)
  }
  match route {
    SavedDetail(id) => {
      guard payload is { "item": item, .. } &&
        town_native_work_project_item(item) is Some(status) &&
        status.id == id else {
        return Err(invalid)
      }
      Ok({
        "schema": schema,
        "revision": revision,
        "item": ToJson::to_json(status),
      })
    }
    SavedList | Mutation(_, _) => {
      guard payload is { "items": Array(items), .. } else {
        return Err(invalid)
      }
      let projected : Array[Json] = []
      let ids : Map[String, Bool] = Map([])
      for item in items {
        guard town_native_work_project_item(item) is Some(status) else {
          return Err(invalid)
        }
        if ids.contains(status.id) {
          return Err(invalid)
        }
        ids[status.id] = true
        projected.push(ToJson::to_json(status))
      }
      Ok({
        "schema": schema,
        "revision": revision,
        "items": projected.to_json(),
      })
    }
  }
}

///|
fn town_native_work_owner_error(code : Int) -> (Int, String) {
  match code {
    400 =>
      (
        400, "MoonTown rejected the work request. Reload saved status and inspect the work before trying again.",
      )
    404 => (404, "This saved Town work no longer exists. Reload the work list.")
    409 =>
      (
        409, "Town work changed. Reload saved status, inspect it, and retry explicitly.",
      )
    413 => (413, "Town work request exceeds the owner request limit")
    _ =>
      (
        503, "MoonTown work status is unavailable. Start or repair its owner service, then reload saved status. A failed action may have taken effect; inspect saved status before retrying.",
      )
  }
}

///|
/// The injectable boundary is exercised without opening a listener or reading
/// local configuration. Production binds it to the existing Town owner bridge.
async fn town_native_work_request_with(
  request_path : String,
  method_ : @http.RequestMethod,
  bytes : Bytes,
  exchange : async (String, String, Json?) -> Result[(Int, Json), String],
) -> Result[Json, (Int, String)] {
  let route = match town_native_work_route(request_path) {
    Ok(route) => route
    Err(error) => return Err(error)
  }
  if !town_native_work_allowed_methods(route).contains(
      mooncode_request_method_name(method_),
    ) {
    return Err((405, "Method Not Allowed"))
  }
  let body = match route {
    Mutation(_, _) =>
      match town_native_work_revision_body(bytes) {
        Ok(payload) => Some(payload)
        Err(error) => return Err(error)
      }
    _ => None
  }
  let contract_result = exchange("GET", "/api/contract", None) catch {
    _ => return Err(town_native_work_owner_error(503))
  }
  let contract = match contract_result {
    Ok((200, payload)) => payload
    _ => return Err(town_native_work_owner_error(503))
  }
  if !town_native_work_capability(contract) {
    return Err(
      (
        503, "This MoonTown owner does not support saved native-work controls. Upgrade or restart MoonTown, then reload this section.",
      ),
    )
  }
  let path = match route {
    SavedList => "/api/native-work"
    SavedDetail(id) => "/api/native-work/" + id
    Mutation(id, action) => "/api/native-work/" + id + "/" + action
  }
  let response = exchange(mooncode_request_method_name(method_), path, body) catch {
    _ => return Err(town_native_work_owner_error(503))
  }
  match response {
    Ok((code, payload)) if code >= 200 && code <= 299 =>
      town_native_work_project(payload, route)
    Ok((code, _)) => Err(town_native_work_owner_error(code))
    Err(_) => Err(town_native_work_owner_error(503))
  }
}
