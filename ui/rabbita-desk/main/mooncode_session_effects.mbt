///|
enum MoonCodeSessionEffect {
  MoonCodeFetchDaemon
  MoonCodeFetchModels
  MoonCodeFetchSessions(String)
  MoonCodeStartWatch
  MoonCodeSyncShell
}

///|
fn mooncode_session_effects_cmd(
  dispatch : Dispatch[Msg],
  model : Model,
  effects : Array[MoonCodeSessionEffect],
) -> @rabbita.Cmd {
  let cmds : Array[@rabbita.Cmd] = []
  for effect in effects {
    cmds.push(mooncode_session_effect_cmd(dispatch, model, effect))
  }
  @rabbita.batch(cmds)
}

///|
fn mooncode_session_effects_with_primary_cmd(
  dispatch : Dispatch[Msg],
  model : Model,
  primary : @rabbita.Cmd,
  effects : Array[MoonCodeSessionEffect],
) -> @rabbita.Cmd {
  let cmds : Array[@rabbita.Cmd] = [primary]
  for effect in effects {
    cmds.push(mooncode_session_effect_cmd(dispatch, model, effect))
  }
  @rabbita.batch(cmds)
}

///|
fn mooncode_session_effect_cmd(
  dispatch : Dispatch[Msg],
  model : Model,
  effect : MoonCodeSessionEffect,
) -> @rabbita.Cmd {
  match effect {
    MoonCodeFetchDaemon => fetch_moonclaw_daemon_cmd(dispatch)
    MoonCodeFetchModels => fetch_moonclaw_models_cmd(dispatch)
    MoonCodeFetchSessions(workspace_id) =>
      fetch_mooncode_sessions_cmd(dispatch, workspace_id)
    MoonCodeStartWatch => mooncode_watch_cmd(dispatch, model)
    MoonCodeSyncShell => sync_shell_cmd(MoonCode, model.activity)
  }
}

///|
fn mooncode_user_submit_effects() -> Array[MoonCodeSessionEffect] {
  [MoonCodeSyncShell]
}

///|
fn mooncode_after_user_submit_cmd(
  dispatch : Dispatch[Msg],
  model : Model,
  primary : @rabbita.Cmd,
) -> @rabbita.Cmd {
  mooncode_session_effects_with_primary_cmd(
    dispatch,
    model,
    @rabbita.batch([primary, clear_mooncode_composer_cmd()]),
    mooncode_user_submit_effects(),
  )
}

///|
fn mooncode_session_mutation_effects() -> Array[MoonCodeSessionEffect] {
  [MoonCodeFetchSessions(""), MoonCodeStartWatch, MoonCodeSyncShell]
}

///|
fn mooncode_after_session_mutation_cmd(
  dispatch : Dispatch[Msg],
  model : Model,
  session_id : String,
) -> @rabbita.Cmd {
  @rabbita.batch([
    mooncode_session_effects_cmd(
      dispatch,
      model,
      mooncode_session_mutation_effects(),
    ),
    sync_mooncode_context_cmd(model.selected_workspace_id, session_id),
    clear_mooncode_composer_cmd(),
  ])
}

///|
fn mooncode_metadata_refresh_effects() -> Array[MoonCodeSessionEffect] {
  [MoonCodeFetchDaemon, MoonCodeFetchModels, MoonCodeFetchSessions("")]
}

///|
fn mooncode_metadata_refresh_cmd(
  dispatch : Dispatch[Msg],
  model : Model,
  _generation : Int,
) -> @rabbita.Cmd {
  mooncode_session_effects_cmd(
    dispatch,
    model,
    mooncode_metadata_refresh_effects(),
  )
}

///|
fn mooncode_selected_session_effects() -> Array[MoonCodeSessionEffect] {
  [MoonCodeStartWatch]
}

///|
fn mooncode_selected_session_cmd(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Cmd {
  mooncode_session_effects_cmd(
    dispatch,
    model,
    mooncode_selected_session_effects(),
  )
}
