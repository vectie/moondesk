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
