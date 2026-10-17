///|
/// Recovery is a projection only: no input creation, POST, or native resumption.
async fn mooncode_work_with_continuations(
  target : MoonCodeWorkTarget,
  workspace : @desk.DeskWorkspace,
  descriptor : Json,
  claims : Json,
  selected_id : String,
  read : async (String) -> Result[Json, String],
) -> Json {
  let events = mooncode_continuation_read_evidence(
    target,
    workspace.root_path,
    read,
  )
  let ids : Array[String] = []
  for item in mooncode_continuation_claims_items(claims) {
    let command = json_object_field_or_empty(item, "command")
    let lineage = json_object_field_or_empty(
      json_object_field_or_empty(command, "payload"),
      "moonproj_continuation",
    )
    let id = json_string(lineage, "continuation_id", default="")
    if json_string(lineage, "schema", default="") ==
      "moonproj.work-continuation.v1" &&
      json_string(lineage, "original_command_id", default="") ==
      target.command_id &&
      mooncode_continuation_valid_id(id) &&
      !ids.contains(id) {
      ids.push(id)
    }
  }
  if !selected_id.is_empty() && !ids.contains(selected_id) {
    ids.push(selected_id)
  }
  let continuations : Array[Json] = []
  let mut selected = Json::null()
  let mut selected_state = if selected_id.is_empty() {
    "none"
  } else {
    "not_found"
  }
  let mut selected_message = ""
  for id in ids {
    let snapshot = match
      mooncode_continuation_load(
        workspace.root_path,
        id,
        target,
        allow_missing_input=true,
      ) {
      Ok(Some(value)) => value
      Ok(None) => {
        if id == selected_id {
          let native_items = mooncode_continuation_claims_items(claims).filter(item => {
            let lineage = json_object_field_or_empty(
              json_object_field_or_empty(
                json_object_field_or_empty(item, "command"),
                "payload",
              ),
              "moonproj_continuation",
            )
            json_string(lineage, "continuation_id", default="") == id
          })
          if native_items.length() > 1 {
            selected_state = "conflict"
            selected_message = "Multiple native commands use this continuation identity; do not discard or replace it"
            continue
          }
          let native = native_items.get(0)
          if native is Some(item) {
            let item_target = MoonCodeWorkTarget::{
              session_id: target.session_id,
              command_id: json_string(item, "command_id", default=""),
              book_root: target.book_root,
            }
            if mooncode_continuation_item(item_target, workspace, claims)
              is Err(_) {
              selected_state = "conflict"
              selected_message = "Native continuation identity could not be verified"
              continue
            }
            selected_state = "conflict"
            selected_message = "Native work exists for this continuation but its immutable local capture is missing; retain this identity"
            let command = json_object_field_or_empty(item, "command")
            let lineage = json_object_field_or_empty(
              json_object_field_or_empty(command, "payload"),
              "moonproj_continuation",
            )
            if json_string(lineage, "schema", default="") !=
              "moonproj.work-continuation.v1" ||
              json_string(lineage, "original_command_id", default="") !=
              target.command_id {
              selected_message = "This native continuation is attributed to different original work; its missing capture cannot be relabeled"
              continue
            }
            let source : Json = {
              "task_id": json_string(lineage, "task_id", default=""),
              "run_id": json_string(lineage, "run_id", default=""),
              "session_id": target.session_id,
              "original_command_id": json_string(
                lineage,
                "original_command_id",
                default="",
              ),
              "book_root": workspace.root_path,
            }
            let captured : Json = {
              "continuation_id": id,
              "client_turn_id": json_string(
                json_object_field_or_empty(command, "packet"),
                "client_turn_id",
                default="",
              ),
              "command_id": json_string(item, "command_id", default=""),
              "source": source,
              "instruction": json_string(command, "text", default=""),
              "model": json_string(command, "model", default=""),
              "prior_result_command_id": json_string(
                lineage,
                "prior_result_command_id",
                default="",
              ),
              "input": json_object_field_or_empty(lineage, "input"),
              "input_status": "capture_missing",
            }
            selected = mooncode_continuation_response(
              captured,
              Some(item),
              events,
              "accepted",
              message=selected_message,
            )
          } else {
            match
              mooncode_continuation_read_text(
                workspace.root_path,
                mooncode_continuation_path(id, "dispatch.json"),
              ) {
              Ok(None) => ()
              _ => {
                selected_state = "conflict"
                selected_message = "A prior native dispatch may exist but its saved request is missing; retain this identity"
              }
            }
          }
        }
        continue
      }
      Err(error) => {
        if id == selected_id {
          selected_state = "conflict"
          selected_message = error
        }
        continue
      }
    }
    let command_target = MoonCodeWorkTarget::{
      session_id: target.session_id,
      command_id: json_string(snapshot, "command_id", default=""),
      book_root: target.book_root,
    }
    let item = match
      mooncode_continuation_item(command_target, workspace, claims) {
      Ok(value) => value
      Err(_) => {
        if id == selected_id {
          selected_state = "unavailable"
          selected_message = "Native continuation identity could not be reconciled"
        }
        continue
      }
    }
    if item is Some(value) &&
      !mooncode_continuation_native_matches(snapshot, value) {
      if id == selected_id {
        selected_state = "conflict"
        selected_message = "Native continuation does not match immutable captured input"
      }
      continue
    }
    let unobserved = match
      mooncode_continuation_unobserved_admission(workspace.root_path, snapshot) {
      Ok(value) => value
      Err(error) => {
        if id == selected_id {
          selected_state = "conflict"
          selected_message = error
        }
        continue
      }
    }
    let response = mooncode_continuation_response(
      snapshot,
      item,
      events,
      if item is Some(_) {
        "accepted"
      } else {
        unobserved
      },
    )
    continuations.push(response)
    if id == selected_id {
      selected = response
      selected_state = "ready"
    }
  }
  descriptor
  |> mooncode_session_with_field(
    "original_result",
    match mooncode_continuation_item(target, workspace, claims) {
      Ok(Some(item)) => mooncode_continuation_result(item, events)
      _ => Json::null()
    },
  )
  |> mooncode_session_with_field("continuations", Json::array(continuations))
  |> mooncode_session_with_field("continuation", selected)
  |> mooncode_session_with_field(
    "continuation_state",
    ToJson::to_json(selected_state),
  )
  |> mooncode_session_with_field(
    "continuation_message",
    ToJson::to_json(selected_message),
  )
  |> mooncode_session_with_field(
    "pending_guidance",
    Json::array(mooncode_continuation_pending_guidance(target, claims, events)),
  )
  |> mooncode_session_with_field(
    "pending_guidance_state",
    ToJson::to_json(if events is Null { "unavailable" } else { "ready" }),
  )
}

///|
async fn mooncode_work_saved_unavailable(
  target : MoonCodeWorkTarget,
  workspaces : Array[@desk.DeskWorkspace],
  selected_id : String,
  descriptor : Json,
) -> Json {
  if selected_id.is_empty() {
    return descriptor
  }
  let workspace = match mooncode_work_workspace(target, workspaces) {
    Ok(value) => value
    Err(_) => return descriptor
  }
  let snapshot = match
    mooncode_continuation_load(
      workspace.root_path,
      selected_id,
      target,
      allow_missing_input=true,
    ) {
    Ok(Some(value)) => value
    _ =>
      return descriptor
        |> mooncode_session_with_field(
          "continuation_state",
          ToJson::to_json("unavailable"),
        )
  }
  let response = mooncode_continuation_response(
    snapshot,
    None,
    Json::null(),
    "unconfirmed",
    message="Exact saved input is available; native admission cannot currently be reconciled",
  )
  descriptor
  |> mooncode_session_with_field("continuation", response)
  |> mooncode_session_with_field("continuation_state", ToJson::to_json("ready"))
  |> mooncode_session_with_field("continuations", Json::array([response]))
  |> mooncode_session_with_field(
    "pending_guidance_state",
    ToJson::to_json("unavailable"),
  )
}
