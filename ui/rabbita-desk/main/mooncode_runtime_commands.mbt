///|
fn fetch_mooncode_runtime_event_sink_cmd(
  dispatch : Dispatch[Msg],
  session_id : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.get(
    "/api/mooncode/sessions/\{encode_component(session_id)}/runtime-events",
  ).expect_json(result => {
    dispatch(
      LoadedMoonCodeRuntimeEventSink(
        session_id,
        http_result(result, "Invalid MoonCode runtime event sink"),
      ),
    )
  })
}

///|
fn start_mooncode_runtime_service_cmd(
  dispatch : Dispatch[Msg],
  session_id : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  let body : Json = {
    "consumer_id": "moondesk-ui-runtime-service",
    "live_wait_ms": 5000,
    "poll_ms": 250,
  }
  @http.post(
    "/api/mooncode/sessions/\{encode_component(session_id)}/runtime-service",
  )
  .with_json(body)
  .expect_json(result => {
    dispatch(
      StartedMoonCodeRuntimeService(
        session_id,
        http_result(result, "Could not start MoonCode runtime service"),
      ),
    )
  })
}
