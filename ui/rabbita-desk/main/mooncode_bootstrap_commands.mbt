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
