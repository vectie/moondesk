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
          mooncode_merge_stream_events(model.mooncode_stream_events, stream.events)
        } else {
          mooncode_merge_stream_events([], stream.events)
        }
        (
          save_mooncode_stream_checkpoint_cmd(
            dispatch, session_id, stream.next_since,
          ),
          {
            ..model,
            mooncode_stream_session_id: session_id,
            mooncode_stream_cursor: stream.next_since,
            mooncode_stream_events: stream_events,
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
        (
          @rabbita.none,
          {
            ..model,
            mooncode_runtime_event_sink_session_id: session_id,
            mooncode_runtime_event_sink: Some(sink),
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
