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
        (
          @rabbita.none,
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
            mooncode_runtime_event_sink_status: "\{sink.event_count} runtime event(s)\{service_status}",
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
