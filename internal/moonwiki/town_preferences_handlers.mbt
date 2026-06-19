///|
async fn handle_saved_views(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  send_json(
    conn,
    method_,
    Json::array(read_json_array_file(saved_views_path(workspace_root))),
  )
}

///|
async fn handle_save_view(
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
  let title = json_string(payload, "title", default="Saved view")
  let id = json_string(payload, "id", default=@desk.stable_id("view", title))
  let record : Json = {
    "id": id,
    "title": title,
    "query": json_string(payload, "query", default=""),
    "workspace_id": json_string(payload, "workspace_id", default=""),
    "path": json_string(payload, "path", default=""),
    "created_at": json_string(
      payload,
      "created_at",
      default=@async.now().to_string(),
    ),
    "updated_at": @async.now().to_string(),
  }
  let path = saved_views_path(workspace_root)
  write_preference_records(
    path,
    upsert_record_by_id(read_json_array_file(path), record),
  ) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not save view",
      )
      return
    }
  }
  send_json(conn, method_, record)
}

///|
async fn handle_tags(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  send_json(
    conn,
    method_,
    Json::array(read_json_array_file(tags_path(workspace_root))),
  )
}

///|
async fn handle_save_tag(
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
  let workspace_id = json_string(payload, "workspace_id", default="")
  let path_value = json_string(payload, "path", default="")
  let tag = json_string(payload, "tag", default="")
  if workspace_id == "" || path_value == "" || tag == "" {
    send_api_error(
      conn, method_, 400, "Bad Request", "workspace_id, path, and tag are required",
    )
    return
  }
  let record : Json = {
    "id": @desk.stable_id("tag", workspace_id + ":" + path_value + ":" + tag),
    "workspace_id": workspace_id,
    "path": path_value,
    "tag": tag,
    "created_at": @async.now().to_string(),
  }
  let path = tags_path(workspace_root)
  write_preference_records(
    path,
    upsert_record_by_id(read_json_array_file(path), record),
  ) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not save tag",
      )
      return
    }
  }
  send_json(conn, method_, record)
}
