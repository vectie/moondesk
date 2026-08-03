///|
async fn handle_town_messages(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let root = workspace_context(workspace_root).suite_root
  let results_root = @pathx.join(moontown_product_root(root), "book-results")
  let messages : Array[Json] = []
  let names = read_directory_names(results_root, include_hidden=false)
  let start = if names.length() > 40 { names.length() - 40 } else { 0 }
  let mut index = start
  while index < names.length() {
    let name = names[index]
    index += 1
    if !name.has_suffix(".json") {
      continue
    }
    messages.push({
      "id": @desk.stable_id("message", name),
      "path": "book-results/" + name,
      "title": name,
      "kind": "book-result",
    })
  }
  send_json(conn, method_, Json::array(messages))
}

///|
async fn handle_town_requests(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let owner_rows = match
    moontown_owner_get_json(workspace_root, "/api/operator-requests") {
    Ok(Array(rows)) => rows
    Ok(_) => {
      send_api_error(
        conn, method_, 502, "Bad Gateway", "MoonTown returned an invalid request ledger",
      )
      return
    }
    Err(error) => {
      send_api_error(conn, method_, 503, "Service Unavailable", error)
      return
    }
  }
  let requests : Array[Json] = []
  let start = if owner_rows.length() > 80 {
    owner_rows.length() - 80
  } else {
    0
  }
  let mut index = start
  while index < owner_rows.length() {
    let record = owner_rows[index]
    index += 1
    let id = json_string(record, "id", default="owner-request")
    requests.push({
      "id": id,
      "status": json_string(record, "status", default="accepted"),
      "path": "moontown.api.v1:/api/operator-requests#" + id,
      "request": town_request_payload_from_record(record, id),
    })
  }
  send_json(conn, method_, Json::array(requests))
}

///|
fn town_request_listing_record(record : Json, name : String) -> Json {
  let path = json_string(
    record,
    "path",
    default=town_moondesk_request_relative_path(name),
  )
  let request = match record {
    Object(object) =>
      match object.get("request") {
        Some(value) =>
          town_request_payload_from_existing_request(value, record, name)
        None => town_request_payload_from_record(record, name)
      }
    _ => town_request_payload_from_record(record, name)
  }
  {
    "id": json_string(record, "id", default=@desk.stable_id("request", name)),
    "status": json_string(record, "status", default="staged"),
    "path": path,
    "request": request,
    "kind": json_string(record, "kind", default="moondesk-request"),
    "book_id": json_string(record, "book_id", default=""),
  }
}

///|
fn town_request_payload_from_existing_request(
  request : Json,
  record : Json,
  name : String,
) -> Json {
  {
    "title": json_first_string(
      request,
      ["title", "summary", "book_id", "id"],
      default=json_first_string(
        record,
        ["title", "summary", "book_id", "id"],
        default=name,
      ),
    ),
    "prompt": json_first_string(
      request,
      ["prompt", "purpose", "summary", "body"],
      default=json_first_string(
        record,
        ["prompt", "purpose", "summary"],
        default="",
      ),
    ),
    "kind": json_string(
      request,
      "kind",
      default=json_string(record, "kind", default="moondesk-request"),
    ),
    "book_id": json_string(
      request,
      "book_id",
      default=json_string(record, "book_id", default=""),
    ),
    "pattern_id": json_string(
      request,
      "pattern_id",
      default=json_string(record, "pattern_id", default=""),
    ),
    "target_book_id": json_string(
      request,
      "target_book_id",
      default=json_string(record, "target_book_id", default=""),
    ),
    "context_entries": town_request_context_entries(request, record),
  }
}

///|
fn town_request_payload_from_record(record : Json, name : String) -> Json {
  let title = json_first_string(
    record,
    ["title", "summary", "book_id", "id"],
    default=name,
  )
  {
    "title": title,
    "prompt": json_first_string(
      record,
      ["prompt", "purpose", "summary"],
      default="",
    ),
    "kind": json_string(record, "kind", default="moondesk-request"),
    "book_id": json_string(record, "book_id", default=""),
    "pattern_id": json_string(record, "pattern_id", default=""),
    "target_book_id": json_string(record, "target_book_id", default=""),
    "context_entries": town_request_context_entries(record, record),
  }
}

///|
fn town_request_context_entries(primary : Json, fallback : Json) -> Json {
  let paths = json_string_array_items(primary, "context_entries")
  let source = if paths.length() == 0 {
    json_string_array_items(fallback, "context_entries")
  } else {
    paths
  }
  let values : Array[Json] = []
  for path in source {
    values.push(path.to_json())
  }
  Json::array(values)
}

///|
async fn handle_town_request(
  workspace_root : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let payload = match read_json_body(body) {
    Some(json) => json
    None => {
      send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
      return
    }
  }
  let receipt = match
    moontown_owner_post_json(
      workspace_root,
      "/api/operator-requests",
      moontown_owner_watch_payload(payload),
    ) {
    Ok(value) => value
    Err(error) => {
      send_api_error(conn, method_, 503, "Service Unavailable", error)
      return
    }
  }
  let id = json_string(receipt, "request_id", default="")
  if id == "" {
    send_api_error(
      conn, method_, 502, "Bad Gateway", "MoonTown accepted no versioned request identity",
    )
    return
  }
  let record : Json = {
    "id": id,
    "status": json_string(receipt, "status", default="accepted"),
    "path": "moontown.api.v1:/api/operator-requests#" + id,
    "request": payload,
  }
  send_json(conn, method_, record)
}
