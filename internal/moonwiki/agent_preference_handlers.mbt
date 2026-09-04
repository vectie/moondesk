///|
const AgentPreferenceMaxRecords : Int = 256

///|
const AgentPreferenceMaxDetailChars : Int = 4000

///|
let agent_preference_write_mutex : @async.Mutex = Mutex()

///|
fn agent_preference_previous(records : Array[Json], id : String) -> Json? {
  if id == "" {
    return None
  }
  for record in records {
    if json_string(record, "id", default="") == id {
      return Some(record)
    }
  }
  None
}

///|
fn agent_preference_visible(record : Json, workspace_id : String) -> Bool {
  let scope = json_string(record, "scope", default="workspace")
  scope == "global" ||
  (
    scope == "workspace" &&
    json_string(record, "workspace_id", default="") == workspace_id
  )
}

///|
async fn agent_preferences_for_workspace(
  workspace_root : String,
  workspace_id : String,
) -> Array[Json] {
  read_json_array_file(agent_preferences_path(workspace_root)).filter(record => {
    agent_preference_visible(record, workspace_id)
  })
}

///|
async fn moonclaw_preferences_for_prompt(
  workspace_root : String,
  workspace_id : String,
) -> Json {
  let lines : Array[String] = []
  let ids : Array[Json] = []
  for record in agent_preferences_for_workspace(workspace_root, workspace_id) {
    if json_bool(record, "enabled", default=true) {
      let label = json_string(record, "label", default="Preference")
      let detail = json_string(record, "detail", default="")
      if detail != "" {
        lines.push("- " + label + ": " + detail)
        ids.push(json_string(record, "id", default="").to_json())
        if lines.length() >= 40 {
          break
        }
      }
    }
  }
  {
    "context": lines.join("\n"),
    "count": lines.length(),
    "ids": Json::array(ids),
  }
}

///|
async fn handle_agent_preferences(
  workspace_root : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let workspace_id = decode_query_value(
      query_value(request_path, "workspace_id").unwrap_or(""),
    )
    .trim()
    .to_owned()
  if workspace_id == "" {
    send_api_error(
      conn, method_, 400, "Bad Request", "workspace_id is required",
    )
    return
  }
  send_json(conn, method_, {
    "contract": "moondesk.agent_preferences.v1",
    "workspace_id": workspace_id,
    "preferences": Json::array(
      agent_preferences_for_workspace(workspace_root, workspace_id),
    ),
  })
}

///|
async fn handle_save_agent_preference(
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
    .trim()
    .to_owned()
  let id = json_string(payload, "id", default="").trim().to_owned()
  let action = json_string(payload, "action", default="upsert")
  let path = agent_preferences_path(workspace_root)
  agent_preference_write_mutex.acquire()
  defer agent_preference_write_mutex.release()
  let records = read_json_array_file(path)
  let previous = agent_preference_previous(records, id)
  let previous_revision = match previous {
    Some(record) => json_int(record, "revision", default=0)
    None => 0
  }
  let expected_revision = json_int(
    payload,
    "expected_revision",
    default=previous_revision,
  )
  if expected_revision != previous_revision {
    send_api_json_error(conn, method_, 409, "Conflict", {
      "contract": "moondesk.agent_preference.v1",
      "error": "revision_conflict",
      "message": "The preference changed on another client",
      "preference": previous.unwrap_or(Json::null()),
    })
    return
  }
  if action == "forget" {
    let next = records.filter(record => {
      json_string(record, "id", default="") != id
    })
    write_preference_records(path, next)
    send_json(conn, method_, { "forgotten": true, "id": id })
    return
  }
  let label = json_string(payload, "label", default="").trim().to_owned()
  let detail = json_string(payload, "detail", default="").trim().to_owned()
  let scope = json_string(payload, "scope", default="workspace")
  let kind = json_string(payload, "kind", default="preference")
  if workspace_id == "" ||
    label == "" ||
    detail == "" ||
    detail.length() > AgentPreferenceMaxDetailChars ||
    !["global", "workspace"].contains(scope) ||
    !["preference", "glossary", "name", "convention"].contains(kind) {
    send_api_error(
      conn, method_, 400, "Bad Request", "Preference fields are invalid",
    )
    return
  }
  let stable_id = if id == "" {
    @desk.stable_id(
      "agent-preference",
      scope + ":" + workspace_id + ":" + kind + ":" + label,
    )
  } else {
    id
  }
  let record : Json = {
    "id": stable_id,
    "contract": "moondesk.agent_preference.v1",
    "workspace_id": workspace_id,
    "scope": scope,
    "kind": kind,
    "label": label,
    "detail": detail,
    "enabled": json_bool(payload, "enabled", default=true),
    "revision": previous_revision + 1,
    "updated_at": @async.now().to_string(),
  }
  let next = upsert_record_by_id(records, record)
  while next.length() > AgentPreferenceMaxRecords {
    next.pop() |> ignore
  }
  write_preference_records(path, next)
  send_json(conn, method_, record)
}
