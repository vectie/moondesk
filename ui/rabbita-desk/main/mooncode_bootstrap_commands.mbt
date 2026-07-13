///|
fn fetch_moonclaw_daemon_cmd(dispatch : Dispatch[Msg]) -> @rabbita.Cmd {
  @http.get(@desk.moonclaw_endpoint_url("daemon")).expect_json(result => {
    dispatch(
      LoadedMoonClawDaemon(
        http_result(result, "Invalid MoonClaw daemon status"),
      ),
    )
  })
}

///|
fn fetch_moonclaw_models_cmd(dispatch : Dispatch[Msg]) -> @rabbita.Cmd {
  @http.get(@desk.moonclaw_endpoint_url("models")).expect_json(result => {
    dispatch(
      LoadedMoonClawModels(
        http_result(result, "Invalid MoonClaw model listing"),
      ),
    )
  })
}

///|
fn manage_moonclaw_cmd(
  dispatch : Dispatch[Msg],
  action : String,
) -> @rabbita.Cmd {
  @http.post(@desk.moonclaw_endpoint_url("daemon/" + action))
  .with_json(Json::object({}))
  .expect_json(result => {
    dispatch(ManagedMoonClaw(http_result(result, "Could not start MoonClaw")))
  })
}
