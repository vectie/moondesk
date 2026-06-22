///|
fn fetch_moonclaw_daemon_cmd(dispatch : (Msg) -> @rabbita.Cmd) -> @rabbita.Cmd {
  @http.get(
    "/api/moonclaw/daemon",
    expect=Json(fn(result) { dispatch(LoadedMoonClawDaemon(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonClaw daemon status")
      }
    }),
  )
}

///|
fn fetch_moonclaw_models_cmd(dispatch : (Msg) -> @rabbita.Cmd) -> @rabbita.Cmd {
  @http.get(
    "/api/moonclaw/models",
    expect=Json(fn(result) { dispatch(LoadedMoonClawModels(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonClaw model listing")
      }
    }),
  )
}
