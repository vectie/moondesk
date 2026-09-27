///|
struct MoonCodeSchedule {
  id : String
  book_id : String
  book_root : String
  session_id : String
  prompt : String
  model : String
  interval_seconds : Int
  enabled : Bool
  next_due_at : Int64
  pending_command_id : String
  last_command_id : String
  last_status : String
  last_finished_at : Int64
} derive(FromJson)

///|
struct MoonCodeScheduleState {
  schema : String
  revision : Int
  schedules : Array[MoonCodeSchedule]
} derive(FromJson)

///|
fn mooncode_schedule_id_valid(id : String) -> Bool {
  id != "" &&
  id.length() <= 64 &&
  id.all(ch => (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9') || ch == '-')
}

///|
fn mooncode_schedule_state_valid(state : MoonCodeScheduleState) -> Bool {
  state.schema == "moontown.code-schedules.v1" &&
  state.revision >= 0 &&
  state.schedules.all(schedule => {
    schedule.id != "" &&
    schedule.book_id != "" &&
    schedule.session_id != "" &&
    schedule.interval_seconds >= 60
  })
}

///|
fn mooncode_schedule_mutation_error(error : String, creating : Bool) -> String {
  if error.contains("already exists") {
    "This schedule ID already exists. Choose another ID."
  } else if error.contains("registered MoonBook") {
    "This MoonBook is unavailable. Refresh the workspace and retry."
  } else if error.contains("HTTP 400") || error.contains("valid schedule ID") {
    "Enter a valid schedule ID, Code task, model, and cadence."
  } else if error.contains("HTTP 404") || error.contains("no longer available") {
    "This schedule is no longer available. Refresh the list."
  } else if error.contains("HTTP 409") {
    if creating {
      "This schedule ID may already exist, or its MoonBook is unavailable. Check the ID and refresh."
    } else {
      "MoonTown could not change this schedule. Refresh and retry."
    }
  } else if error.contains("HTTP 503") ||
    error.contains("TypeError") ||
    error.contains("could not save") {
    "MoonTown is unavailable. Your draft is safe; retry when it reconnects."
  } else {
    "MoonTown is unavailable. Your draft is safe; retry when it reconnects."
  }
}

///|
fn mooncode_schedule_mutation_payload_error(
  payload : Json,
  creating : Bool,
) -> String {
  let detail = match payload {
    Object(fields) =>
      match fields.get("error") {
        Some(String(value)) => value
        _ => ""
      }
    _ => ""
  }
  if detail == "" {
    "MoonTown returned an unreadable schedule receipt. Your draft is safe; retry after refreshing."
  } else {
    mooncode_schedule_mutation_error(detail, creating)
  }
}

///|
fn mooncode_schedule_error_key(error : String) -> String {
  match error {
    "Choose a MoonBook and model, then enter a schedule ID, prompt, and cadence in minutes." =>
      "code.schedule_setup_required"
    "Enter a valid schedule ID, Code task, model, and cadence." =>
      "code.schedule_invalid"
    "This schedule ID already exists. Choose another ID." =>
      "code.schedule_duplicate"
    "This MoonBook is unavailable. Refresh the workspace and retry." =>
      "code.schedule_book_missing"
    "This schedule is no longer available. Refresh the list." =>
      "code.schedule_gone"
    "This schedule ID may already exist, or its MoonBook is unavailable. Check the ID and refresh." =>
      "code.schedule_conflict"
    "MoonTown could not change this schedule. Refresh and retry." =>
      "code.schedule_change_failed"
    "MoonTown is unavailable. Your draft is safe; retry when it reconnects." =>
      "code.schedule_unavailable"
    "MoonTown is not configured. Start its owner service, then refresh MoonDesk." =>
      "code.schedule_owner_setup"
    "MoonTown returned an unreadable schedule receipt. Your draft is safe; retry after refreshing." =>
      "code.schedule_unreadable"
    _ => ""
  }
}

///|
fn fetch_mooncode_schedules_cmd(
  dispatch : Dispatch[Msg],
  workspace_id : String,
  generation : Int,
) -> @rabbita.Cmd {
  @http.get(@desk.desktop_api_url(["api", "mooncode", "schedules"])).expect_text(result => {
      let decoded : Result[MoonCodeScheduleState, String] = match result {
        Ok(body) => mooncode_schedule_decode_response(body)
        Err(error) => Err(error.to_string())
      }
      dispatch(LoadedMoonCodeSchedules(workspace_id, generation, decoded))
    },
  )
}

///|
fn mooncode_schedule_decode_response(
  body : String,
) -> Result[MoonCodeScheduleState, String] {
  let payload = @json.parse(body) catch {
    _ => return Err("Code schedules response is unreadable")
  }
  if !json_field_bool(payload, "ok", default=true) {
    if json_field_string(payload, "message", default="").contains(
        "MoonTown is not configured",
      ) {
      return Err(
        "MoonTown is not configured. Start its owner service, then refresh MoonDesk.",
      )
    }
    return Err(
      "MoonTown is unavailable. Your draft is safe; retry when it reconnects.",
    )
  }
  let state : MoonCodeScheduleState = @json.from_json(payload) catch {
    _ => return Err("Code schedules response is unreadable")
  }
  Ok(state)
}

///|
fn mutate_mooncode_schedule_cmd(
  dispatch : Dispatch[Msg],
  workspace_id : String,
  body : Json,
  creating : Bool,
) -> @rabbita.Cmd {
  @http.post(@desk.desktop_api_url(["api", "mooncode", "schedules"]))
  .with_json(body)
  .expect_json(result => {
    let decoded : Result[MoonCodeScheduleState, String] = match result {
      Ok(payload) =>
        Ok(@json.from_json(payload)) catch {
          _ => Err(mooncode_schedule_mutation_payload_error(payload, creating))
        }
      Err(error) =>
        Err(mooncode_schedule_mutation_error(error.to_string(), creating))
    }
    dispatch(SavedMoonCodeSchedule(workspace_id, creating, decoded))
  })
}
