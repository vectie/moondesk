///|
let document_room_write_mutex : @async.Mutex = Mutex()

///|
fn document_rooms_path(workspace_root : String) -> String {
  moonsuite_product_artifact_for_workspace_root(
    workspace_root, "moondesk", "collaboration/workspace-rooms.v1.json",
  )
}

///|
fn document_room_snapshot(
  records : Array[Json],
  workspace_id : String,
  channel : String,
  now : Int32,
) -> Json {
  let matching = records.filter(record => {
    json_string(record, "workspace_id", default="") == workspace_id
  })
  let channels = matching.filter(record => {
    json_string(record, "kind", default="") == "channel"
  })
  let messages = matching.filter(record => {
    json_string(record, "kind", default="") == "message" &&
    json_string(record, "channel", default="general") == channel
  })
  let presence = matching.filter(record => {
    json_string(record, "kind", default="") == "presence" &&
    json_string(record, "channel", default="general") == channel &&
    json_int(record, "last_seen", default=0) >= now - 45
  })
  {
    "contract": "moondesk.workspace-room.v1",
    "workspace_id": workspace_id,
    "channel": channel,
    "channels": Json::array(
      [{ "id": "general", "title": "General", "kind": "channel" }, ..channels],
    ),
    "messages": Json::array(messages),
    "presence": Json::array(presence),
  }
}

///|
async fn handle_document_room(
  workspace_root : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let workspace_id = decode_query_value(
    query_value(request_path, "workspace_id").unwrap_or(""),
  )
  let channel = decode_query_value(
    query_value(request_path, "channel").unwrap_or("general"),
  )
  if workspace_id == "" || find_workspace(workspace_root, workspace_id) is None {
    send_api_error(
      conn, method_, 404, "Not Found", "Choose a MoonBook to open its shared room",
    )
    return
  }
  send_json(
    conn,
    method_,
    document_room_snapshot(
      read_json_array_file(document_rooms_path(workspace_root)),
      workspace_id,
      channel,
      (@env.now() / 1000UL).to_int(),
    ),
  )
}

///|
fn document_room_reaction(
  message : Json,
  actor_id : String,
  reaction : String,
) -> Json {
  let existing : Array[Json] = match message {
    Object(fields) =>
      match fields.get("reactions") {
        Some(Array(items)) => items
        _ => []
      }
    _ => []
  }
  let selected = existing.any(item => {
    json_string(item, "actor_id", default="") == actor_id &&
    json_string(item, "reaction", default="") == reaction
  })
  let next : Array[Json] = if selected {
    existing.filter(item => {
      !(json_string(item, "actor_id", default="") == actor_id &&
      json_string(item, "reaction", default="") == reaction)
    })
  } else {
    [..existing, { "actor_id": actor_id, "reaction": reaction }]
  }
  @mooncore.session_with_field(message, "reactions", Json::array(next))
}

///|
async fn handle_save_document_room(
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
  let channel = json_string(payload, "channel", default="general")
  let action = json_string(payload, "action", default="message")
  let actor_id = json_string(payload, "actor_id", default="").trim().to_owned()
  let author = json_string(payload, "author", default="").trim().to_owned()
  if workspace_id == "" || find_workspace(workspace_root, workspace_id) is None {
    send_api_error(
      conn, method_, 404, "Not Found", "Choose a MoonBook to open its shared room",
    )
    return
  }
  if actor_id == "" || author == "" {
    send_api_error(
      conn, method_, 400, "Bad Request", "Enter your display name before joining",
    )
    return
  }
  document_room_write_mutex.acquire()
  defer document_room_write_mutex.release()
  let path = document_rooms_path(workspace_root)
  let records = read_json_array_file(path)
  let now = (@env.now() / 1000UL).to_int()
  let mut next = records.filter(record => {
    json_string(record, "kind", default="") != "presence" ||
    json_int(record, "last_seen", default=0) >= now - 45
  })
  match action {
    "presence" => {
      let id = @desk.stable_id("room-presence", workspace_id + ":" + actor_id)
      next = upsert_record_by_id(next, {
        "id": id,
        "kind": "presence",
        "workspace_id": workspace_id,
        "channel": channel,
        "actor_id": actor_id,
        "author": author,
        "typing": json_bool(payload, "typing", default=false),
        "last_seen": now,
      })
    }
    "create-channel" => {
      let title = json_string(payload, "title", default="").trim().to_owned()
      if title == "" {
        send_api_error(
          conn, method_, 400, "Bad Request", "Enter a channel name",
        )
        return
      }
      let id = @desk.stable_id("room-channel", workspace_id + ":" + title)
      next = upsert_record_by_id(next, {
        "id": id,
        "kind": "channel",
        "workspace_id": workspace_id,
        "title": title,
        "created_at": @async.now().to_string(),
      })
    }
    "message" => {
      let text = json_string(payload, "text", default="").trim().to_owned()
      let client_id = json_string(payload, "client_id", default="")
        .trim()
        .to_owned()
      if text == "" || client_id == "" {
        send_api_error(
          conn, method_, 400, "Bad Request", "Write a message before sending",
        )
        return
      }
      let id = @desk.stable_id(
        "room-message",
        workspace_id + ":" + actor_id + ":" + client_id,
      )
      if !next.any(record => json_string(record, "id", default="") == id) {
        next.push({
          "id": id,
          "kind": "message",
          "workspace_id": workspace_id,
          "channel": channel,
          "actor_id": actor_id,
          "author": author,
          "text": text,
          "reply_to": json_string(payload, "reply_to", default=""),
          "document_path": json_string(payload, "document_path", default=""),
          "reactions": Json::array([]),
          "created_at": @async.now().to_string(),
        })
      }
    }
    "react" => {
      let id = json_string(payload, "message_id", default="")
      let reaction = json_string(payload, "reaction", default="")
      if !["agree", "thanks", "question"].contains(reaction) {
        send_api_error(conn, method_, 400, "Bad Request", "Choose a reaction")
        return
      }
      next = next.map(record => {
        if json_string(record, "id", default="") == id &&
          json_string(record, "workspace_id", default="") == workspace_id &&
          json_string(record, "kind", default="") == "message" {
          document_room_reaction(record, actor_id, reaction)
        } else {
          record
        }
      })
    }
    _ => {
      send_api_error(conn, method_, 400, "Bad Request", "Unknown room action")
      return
    }
  }
  write_preference_records(path, next)
  send_json(
    conn,
    method_,
    document_room_snapshot(next, workspace_id, channel, now),
  )
}
