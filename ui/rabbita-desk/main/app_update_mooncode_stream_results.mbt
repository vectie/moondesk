///|
fn update_mooncode_stream_results(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    LoadedMoonCodeStream(session_id, Ok(stream)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        let stream_events = if session_id == model.mooncode_stream_session_id {
          mooncode_merge_stream_events(
            model.mooncode_stream_events,
            stream.events,
          )
        } else {
          mooncode_merge_stream_events([], stream.events)
        }
        let mooncode_conversation_rows = mooncode_hydrate_conversation_from_events(
          model.mooncode_conversation_rows,
          session_id,
          stream.events,
        )
        (
          @rabbita.batch([
            save_mooncode_stream_checkpoint_cmd(
              dispatch,
              session_id,
              stream.next_since,
            ),
            if mooncode_stream_should_fast_poll(model, session_id, stream) {
              schedule_mooncode_fast_poll(dispatch)
            } else {
              @rabbita.none
            },
          ]),
          {
            ..model,
            mooncode_stream_session_id: session_id,
            mooncode_stream_cursor: stream.next_since,
            mooncode_stream_events: stream_events,
            mooncode_conversation_rows,
            mooncode_pending_prompts: mooncode_clear_acknowledged_pending_prompts(
              model.mooncode_pending_prompts,
              session_id,
              stream_events,
            ),
            mooncode_stream_status: "live tail / \{stream.stream_source} / \{stream.stream} +\{stream.emitted_count} event(s), cursor \{stream.next_since}",
            mooncode_stream_checkpoint_session_id: session_id,
            mooncode_stream_checkpoint_status: if stream.next_since > 0 {
              "saving checkpoint \{stream.next_since}"
            } else {
              "checkpoint idle"
            },
          },
        )
      }
    LoadedMoonCodeStream(session_id, Err(error)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_stream_session_id: session_id,
            mooncode_stream_status: error,
          },
        )
      }
    SavedMoonCodeStreamCheckpoint(session_id, Ok(state)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_stream_checkpoint_session_id: session_id,
            mooncode_stream_checkpoint_status: "\{state.consumer_id} checkpoint \{state.next_since} / latest \{state.latest_sequence}",
          },
        )
      }
    SavedMoonCodeStreamCheckpoint(session_id, Err(error)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_stream_checkpoint_session_id: session_id,
            mooncode_stream_checkpoint_status: "checkpoint failed: \{error}",
          },
        )
      }
    LoadedMoonCodeRuntimeEventSink(session_id, Ok(sink)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        let service_status = if sink.runtime_service.status == "idle" {
          ""
        } else {
          " / service " + sink.runtime_service.status
        }
        let mooncode_conversation_rows = mooncode_hydrate_conversation_from_events(
          model.mooncode_conversation_rows,
          session_id,
          sink.events,
        )
        let should_start_service = mooncode_runtime_sink_should_start_service(
          model, session_id, sink,
        )
        (
          if should_start_service {
            @rabbita.batch([
              start_mooncode_runtime_service_cmd(dispatch, session_id),
              schedule_mooncode_fast_poll(dispatch),
            ])
          } else {
            @rabbita.none
          },
          {
            ..model,
            mooncode_runtime_event_sink_session_id: session_id,
            mooncode_runtime_event_sink: Some(sink),
            mooncode_conversation_rows,
            mooncode_pending_prompts: mooncode_clear_acknowledged_pending_prompts(
              model.mooncode_pending_prompts,
              session_id,
              sink.events,
            ),
            mooncode_runtime_event_sink_status: if should_start_service {
              "starting runtime service"
            } else {
              "\{sink.event_count} runtime event(s)\{service_status}"
            },
          },
        )
      }
    LoadedMoonCodeRuntimeEventSink(session_id, Err(error)) =>
      if session_id != model.selected_mooncode_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_runtime_event_sink_session_id: session_id,
            mooncode_runtime_event_sink: None,
            mooncode_runtime_event_sink_status: error,
          },
        )
      }
    _ => (@rabbita.none, model)
  }
}

///|
fn mooncode_runtime_sink_should_start_service(
  model : Model,
  session_id : String,
  sink : MoonCodeRuntimeEventSink,
) -> Bool {
  let has_unstarted_prompt = mooncode_events_have_unstarted_prompt_command(
    sink.events,
  )
  let has_pending_prompt = mooncode_session_has_pending_prompt(
    model, session_id,
  )
  let has_open_local_prompt = mooncode_conversation_has_open_user_turn(
    model.mooncode_conversation_rows,
    session_id,
  )
  if !has_unstarted_prompt && !has_pending_prompt && !has_open_local_prompt {
    return false
  }
  if sink.runtime_service.status != "idle" &&
    !mooncode_events_have_unstarted_prompt_after_latest_service_start(
      sink.events,
    ) {
    return false
  }
  if model.mooncode_runtime_event_sink_status == "starting runtime service" &&
    !mooncode_runtime_sink_has_new_events(model, session_id, sink) {
    return false
  }
  true
}

///|
fn mooncode_runtime_sink_has_new_events(
  model : Model,
  session_id : String,
  sink : MoonCodeRuntimeEventSink,
) -> Bool {
  if model.mooncode_runtime_event_sink_session_id != session_id {
    return true
  }
  match model.mooncode_runtime_event_sink {
    Some(previous) =>
      sink.event_count > previous.event_count ||
      sink.events.length() > previous.events.length()
    None => true
  }
}

///|
fn mooncode_events_have_unstarted_prompt_command(
  events : Array[MoonCodeEvent],
) -> Bool {
  let prompt_command_ids : Array[String] = []
  let mut has_unkeyed_prompt = false
  for event in events {
    if mooncode_event_is_command_prompt_like(event) {
      let command_id = mooncode_event_command_id(event)
      if command_id == "" {
        has_unkeyed_prompt = true
      } else if !prompt_command_ids.contains(command_id) {
        prompt_command_ids.push(command_id)
      }
    }
  }
  if has_unkeyed_prompt && prompt_command_ids.length() == 0 {
    return true
  }
  for command_id in prompt_command_ids {
    if !mooncode_events_have_runtime_progress_for_command(events, command_id) {
      return true
    }
  }
  false
}

///|
fn mooncode_events_have_unstarted_prompt_after_latest_service_start(
  events : Array[MoonCodeEvent],
) -> Bool {
  let latest_started_at = mooncode_latest_runtime_service_started_at(events)
  if latest_started_at == "" {
    return false
  }
  for event in events {
    if mooncode_event_is_command_prompt_like(event) &&
      mooncode_timestamp_after(event.created_at, latest_started_at) {
      let command_id = mooncode_event_command_id(event)
      if command_id == "" {
        return true
      }
      if !mooncode_events_have_runtime_progress_for_command(events, command_id) {
        return true
      }
    }
  }
  false
}

///|
fn mooncode_latest_runtime_service_started_at(
  events : Array[MoonCodeEvent],
) -> String {
  let mut latest = ""
  for event in events {
    if event.kind == "runtime.service_started" &&
      (latest == "" || mooncode_timestamp_after(event.created_at, latest)) {
      latest = event.created_at
    }
  }
  latest
}

///|
fn mooncode_timestamp_after(left : String, right : String) -> Bool {
  let left = left.trim().to_owned()
  let right = right.trim().to_owned()
  if left == "" || right == "" {
    return false
  }
  if mooncode_timestamp_is_digits(left) &&
    mooncode_timestamp_is_digits(right) &&
    left.length() != right.length() {
    return left.length() > right.length()
  }
  left.compare(right) > 0
}

///|
fn mooncode_timestamp_is_digits(value : String) -> Bool {
  if value == "" {
    return false
  }
  for ch in value {
    if ch < '0' || ch > '9' {
      return false
    }
  }
  true
}

///|
fn mooncode_events_have_runtime_progress_for_command(
  events : Array[MoonCodeEvent],
  command_id : String,
) -> Bool {
  if command_id == "" {
    return false
  }
  for event in events {
    if mooncode_event_command_id(event) == command_id &&
      !mooncode_event_is_command_prompt_like(event) {
      return true
    }
  }
  false
}

///|
fn mooncode_stream_should_fast_poll(
  model : Model,
  session_id : String,
  stream : MoonCodeStreamPoll,
) -> Bool {
  if session_id != model.selected_mooncode_session_id {
    return false
  }
  mooncode_session_has_pending_prompt(model, session_id) ||
  stream.emitted_count > 0 ||
  mooncode_selected_session_is_active(model, session_id)
}

///|
fn mooncode_selected_session_is_active(
  model : Model,
  session_id : String,
) -> Bool {
  for session in model.mooncode_sessions {
    if session.id == session_id {
      return session.status == "queued" ||
        session.status == "running" ||
        session.queued_count > 0
    }
  }
  false
}
