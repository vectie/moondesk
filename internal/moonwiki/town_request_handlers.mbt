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
  let root = workspace_context(workspace_root).suite_root
  let requests_root = town_moondesk_requests_root(root)
  let requests : Array[Json] = []
  let names = read_directory_names(requests_root, include_hidden=false)
  let start = if names.length() > 80 { names.length() - 80 } else { 0 }
  let mut index = start
  while index < names.length() {
    let name = names[index]
    index += 1
    if !name.has_suffix(".json") {
      continue
    }
    let absolute = @pathx.join(requests_root, name)
    let record = @json.parse(@fs.read_file(absolute).text()) catch {
      _ => {
        let fallback : Json = {
          "id": @desk.stable_id("request", name),
          "status": "unreadable",
          "path": town_moondesk_request_relative_path(name),
          "request": { "title": name },
        }
        fallback
      }
    }
    requests.push(town_request_listing_record(record, name))
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
  }
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
  let root = workspace_context(workspace_root).suite_root
  let requests_root = town_moondesk_requests_root(root)
  @fsx.make_directory(requests_root, recursive=true, exists_ok=true) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not create request ledger",
      )
      return
    }
  }
  let title = json_string(payload, "title", default="Moondesk request")
  let id = @desk.stable_id("request", title + "-" + @async.now().to_string())
  let file_name = id + ".json"
  let relative = town_moondesk_request_relative_path(file_name)
  let absolute = town_moondesk_request_path(root, file_name)
  let record : Json = {
    "id": id,
    "status": "staged",
    "path": relative,
    "request": payload,
  }
  @fsx.write_to_file(absolute, record.stringify(indent=2) + "\n", create=0o644) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not write request",
      )
      return
    }
  }
  send_json(conn, method_, record)
}
