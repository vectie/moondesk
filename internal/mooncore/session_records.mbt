///|
pub fn session_with_field(session : Json, key : String, value : Json) -> Json {
  let object : Map[String, Json] = {}
  match session {
    Object(fields) =>
      for existing_key, existing_value in fields {
        object[existing_key] = existing_value
      }
    _ => ()
  }
  object[key] = value
  Json::object(object)
}

///|
pub fn session_response_defaults(
  session : Json,
  default_title~ : String,
) -> Json {
  let workspace_root = json_string(session, "workspace_root", default="")
  let next = session_with_default_field(
    session,
    "cwd",
    workspace_root.to_json(),
  )
  let next = session_with_default_field(next, "model", "".to_json())
  let next = session_with_default_field(next, "port", (0).to_json())
  let next = session_with_default_field(next, "web_search", false.to_json())
  let next = session_with_default_field(next, "queued_count", (0).to_json())
  let next = session_with_default_field(next, "title", default_title.to_json())
  let next = session_with_default_field(next, "created_at", "".to_json())
  let next = session_with_default_field(next, "updated_at", "".to_json())
  let next = session_with_default_field(next, "last_message", "".to_json())
  session_with_default_field(next, "transcript", Json::array([]))
}

///|
pub fn transcript_message_record(
  id_prefix~ : String,
  role~ : String,
  content~ : String,
  status~ : String,
  created_at~ : String,
) -> Json {
  transcript_message_record_with_id(
    id=@desk.stable_id(id_prefix, role + ":" + content + ":" + created_at),
    role~,
    content~,
    status~,
    created_at~,
  )
}

///|
pub fn transcript_message_record_with_id(
  id~ : String,
  role~ : String,
  content~ : String,
  status~ : String,
  created_at~ : String,
) -> Json {
  {
    "id": id,
    "role": role,
    "content": trim_for_record(content),
    "status": status,
    "created_at": created_at,
  }
}

///|
pub fn append_transcript_message(
  session : Json,
  id_prefix~ : String,
  role~ : String,
  content~ : String,
  status~ : String,
  created_at? : String = @async.now().to_string(),
) -> Json {
  let messages = json_array_items(session, "transcript")
  messages.push(
    transcript_message_record(id_prefix~, role~, content~, status~, created_at~),
  )
  let next = session_with_field(session, "transcript", Json::array(messages))
  session_with_field(next, "updated_at", created_at.to_json())
}

///|
fn session_with_default_field(
  session : Json,
  key : String,
  value : Json,
) -> Json {
  match json_object_field(session, key) {
    Some(_) => session
    None => session_with_field(session, key, value)
  }
}

///|
fn trim_for_record(text : String) -> String {
  let text = text.trim().to_owned()
  if text.length() > 4000 {
    text[:4000].to_owned()
  } else {
    text
  }
}
