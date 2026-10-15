///|
let document_calendar_write_mutex : @async.Mutex = Mutex()

///|
fn document_calendar_path(workspace_root : String) -> String {
  moonsuite_product_artifact_for_workspace_root(
    workspace_root, "moondesk", "calendar/events.v1.json",
  )
}

///|
fn document_calendar_event(
  payload : Json,
  now : String,
) -> Result[Json, String] {
  let workspace_id = json_string(payload, "workspace_id", default="")
  let title = json_string(payload, "title", default="").trim().to_owned()
  let starts_at = json_int(payload, "starts_at", default=0)
  let ends_at = json_int(payload, "ends_at", default=0)
  let recurrence = json_string(payload, "recurrence", default="once")
  if title == "" ||
    starts_at <= 0 ||
    ends_at <= starts_at ||
    !["once", "daily", "weekdays", "weekly"].contains(recurrence) {
    return Err("Enter a title and an end time after the start time")
  }
  let requested_id = json_string(payload, "id", default="")
  let id = if requested_id == "" {
    @desk.stable_id("calendar-event", workspace_id + ":" + title + ":" + now)
  } else {
    requested_id
  }
  Ok({
    "id": id,
    "workspace_id": workspace_id,
    "title": title,
    "description": json_string(payload, "description", default=""),
    "starts_at": starts_at,
    "ends_at": ends_at,
    "timezone": json_string(payload, "timezone", default="UTC"),
    "recurrence": recurrence,
    "remind_minutes": json_int(payload, "remind_minutes", default=15),
    "document_path": json_string(payload, "document_path", default=""),
    "updated_at": now,
  })
}

///|
async fn handle_document_calendar(
  workspace_root : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let workspace_id = decode_query_value(
    query_value(request_path, "workspace_id").unwrap_or(""),
  )
  if workspace_id == "" || find_workspace(workspace_root, workspace_id) is None {
    send_api_error(
      conn, method_, 404, "Not Found", "Choose a MoonBook for its calendar",
    )
    return
  }
  send_json(conn, method_, {
    "contract": "moondesk.book-calendar.v1",
    "workspace_id": workspace_id,
    "events": Json::array(
      read_json_array_file(document_calendar_path(workspace_root)).filter(item => {
        json_string(item, "workspace_id", default="") == workspace_id
      }),
    ),
  })
}

///|
async fn handle_save_document_calendar(
  workspace_root : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let payload = match read_json_body(body) {
    Some(value) => value
    None => {
      send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
      return
    }
  }
  let workspace_id = json_string(payload, "workspace_id", default="")
  if workspace_id == "" || find_workspace(workspace_root, workspace_id) is None {
    send_api_error(
      conn, method_, 404, "Not Found", "Choose a MoonBook for its calendar",
    )
    return
  }
  document_calendar_write_mutex.acquire()
  defer document_calendar_write_mutex.release()
  let path = document_calendar_path(workspace_root)
  let records = read_json_array_file(path)
  let next = if json_string(payload, "action", default="save") == "delete" {
    records.filter(record => {
      !(json_string(record, "workspace_id", default="") == workspace_id &&
      json_string(record, "id", default="") ==
      json_string(payload, "id", default=""))
    })
  } else {
    match document_calendar_event(payload, @async.now().to_string()) {
      Ok(event) => upsert_record_by_id(records, event)
      Err(error) => {
        send_api_error(conn, method_, 400, "Bad Request", error)
        return
      }
    }
  }
  write_preference_records(path, next)
  send_json(conn, method_, {
    "contract": "moondesk.book-calendar.v1",
    "workspace_id": workspace_id,
    "events": Json::array(
      next.filter(record => {
        json_string(record, "workspace_id", default="") == workspace_id
      }),
    ),
  })
}
