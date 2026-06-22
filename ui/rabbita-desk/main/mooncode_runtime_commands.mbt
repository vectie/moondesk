///|
fn fetch_mooncode_runtime_event_sink_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.get(
    "/api/mooncode/sessions/\{encode_component(session_id)}/runtime-events",
    expect=Json(fn(result) {
      dispatch(LoadedMoonCodeRuntimeEventSink(session_id, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode runtime event sink")
      }
    }),
  )
}
