///|
fn manage_mooncode_session_cmd(
  dispatch : Dispatch[Msg],
  session_id : String,
  action : String,
  title? : String = "",
) -> @rabbita.Cmd {
  let body : Json = { "action": action, "title": title }
  @http.post(@desk.mooncode_session_lifecycle_url(session_id))
  .with_json(body)
  .expect_json(result => {
    dispatch(
      ManagedMoonCodeSession(
        http_result(result, "Could not manage MoonCode session"),
      ),
    )
  })
}
