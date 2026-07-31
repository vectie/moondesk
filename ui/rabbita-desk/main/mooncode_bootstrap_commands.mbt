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
fn fetch_mooncode_capability_cmd(dispatch : Dispatch[Msg]) -> @rabbita.Cmd {
  @http.get(@desk.desktop_api_url(["api", "mooncode", "capabilities"])).expect_json(result => {
      let state = match result {
        Ok(payload) => mooncode_capability_state(payload)
        Err(error) => CapabilityUnavailable(error.to_string())
      }
      dispatch(LoadedMoonCodeCapability(state))
    },
  )
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
fn fetch_moonclaw_auth_cmd(dispatch : Dispatch[Msg]) -> @rabbita.Cmd {
  @http.get(@desk.moonclaw_endpoint_url("auth/status")).expect_json(result => {
    dispatch(
      LoadedMoonClawAuth(
        http_result(result, "Could not check Code assistance setup"),
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

///|
fn start_moonclaw_auth_cmd(
  dispatch : Dispatch[Msg],
  provider : String,
) -> @rabbita.Cmd {
  if provider == "copilot" {
    @http.post(@desk.moonclaw_endpoint_url("auth/copilot/start"))
    .with_json(Json::object({}))
    .expect_json(result => {
      dispatch(
        StartedMoonClawCopilotAuth(
          http_result(result, "Could not start GitHub Copilot setup"),
        ),
      )
    })
  } else {
    @http.post(@desk.moonclaw_endpoint_url("auth/codex/start"))
    .with_json(Json::object({}))
    .expect_json(result => {
      dispatch(
        StartedMoonClawCodexAuth(
          http_result(result, "Could not start Codex setup"),
        ),
      )
    })
  }
}

///|
fn save_moonclaw_openrouter_key_cmd(
  dispatch : Dispatch[Msg],
  api_key : String,
) -> @rabbita.Cmd {
  let body : Json = { "api_key": api_key }
  @http.post(@desk.moonclaw_endpoint_url("config/openrouter-key"))
  .with_json(body)
  .expect_json(result => {
    dispatch(
      SavedMoonClawOpenRouterKey(
        http_result(result, "Could not save OpenRouter API key"),
      ),
    )
  })
}
