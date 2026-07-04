///|
enum MoonCodeSessionEffect {
  MoonCodeFetchDaemon
  MoonCodeFetchSessions(String)
  MoonCodeFetchSelectedStream
  MoonCodeFetchStream(String, Int)
  MoonCodeStartRuntimeService(String)
  MoonCodeScheduleFastPoll
  MoonCodeSchedulePoll
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
    MoonCodeFetchSessions(workspace_id) =>
      fetch_mooncode_sessions_cmd(dispatch, workspace_id)
    MoonCodeFetchSelectedStream =>
      fetch_selected_mooncode_stream_cmd(dispatch, model)
    MoonCodeFetchStream(session_id, since) =>
      fetch_mooncode_stream_cmd(dispatch, session_id, since)
    MoonCodeStartRuntimeService(session_id) =>
      start_mooncode_runtime_service_cmd(dispatch, session_id)
    MoonCodeScheduleFastPoll => schedule_mooncode_fast_poll(dispatch)
    MoonCodeSchedulePoll => schedule_mooncode_poll(dispatch)
    MoonCodeSyncShell => sync_shell_cmd(MoonCode, model.activity)
  }
}

///|
fn mooncode_user_submit_effects() -> Array[MoonCodeSessionEffect] {
  [MoonCodeScheduleFastPoll, MoonCodeSchedulePoll, MoonCodeSyncShell]
}

///|
fn mooncode_after_user_submit_cmd(
  dispatch : Dispatch[Msg],
  model : Model,
  primary : @rabbita.Cmd,
) -> @rabbita.Cmd {
  mooncode_session_effects_with_primary_cmd(
    dispatch, model, primary, mooncode_user_submit_effects(),
  )
}

///|
fn mooncode_session_mutation_effects(
  model : Model,
  session_id : String,
) -> Array[MoonCodeSessionEffect] {
  let effects : Array[MoonCodeSessionEffect] = []
  if model.mooncode_runtime_mode != "manual" {
    effects.push(MoonCodeStartRuntimeService(session_id))
  }
  effects.push(MoonCodeFetchSessions(model.selected_workspace_id))
  effects.push(MoonCodeFetchStream(session_id, 0))
  effects.push(MoonCodeScheduleFastPoll)
  effects.push(MoonCodeSchedulePoll)
  effects.push(MoonCodeSyncShell)
  effects
}

///|
fn mooncode_after_session_mutation_cmd(
  dispatch : Dispatch[Msg],
  model : Model,
  session_id : String,
) -> @rabbita.Cmd {
  mooncode_session_effects_cmd(
    dispatch, model, mooncode_session_mutation_effects(model, session_id),
  )
}

///|
fn mooncode_runtime_started_effects(
  model : Model,
  session_id : String,
) -> Array[MoonCodeSessionEffect] {
  [
    MoonCodeFetchSessions(model.selected_workspace_id),
    MoonCodeFetchStream(session_id, 0),
    MoonCodeScheduleFastPoll,
    MoonCodeSchedulePoll,
  ]
}

///|
fn mooncode_after_runtime_started_cmd(
  dispatch : Dispatch[Msg],
  model : Model,
  session_id : String,
) -> @rabbita.Cmd {
  mooncode_session_effects_cmd(
    dispatch, model, mooncode_runtime_started_effects(model, session_id),
  )
}

///|
fn mooncode_runtime_failed_effects(
  model : Model,
  session_id : String,
) -> Array[MoonCodeSessionEffect] {
  [
    MoonCodeFetchSessions(model.selected_workspace_id),
    MoonCodeFetchStream(session_id, 0),
    MoonCodeSchedulePoll,
  ]
}

///|
fn mooncode_after_runtime_failed_cmd(
  dispatch : Dispatch[Msg],
  model : Model,
  session_id : String,
) -> @rabbita.Cmd {
  mooncode_session_effects_cmd(
    dispatch, model, mooncode_runtime_failed_effects(model, session_id),
  )
}

///|
fn mooncode_poll_effects(model : Model) -> Array[MoonCodeSessionEffect] {
  [
    MoonCodeFetchDaemon,
    MoonCodeFetchSessions(model.selected_workspace_id),
    MoonCodeFetchSelectedStream,
    MoonCodeSchedulePoll,
  ]
}

///|
fn mooncode_poll_cmd(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Cmd {
  mooncode_session_effects_cmd(dispatch, model, mooncode_poll_effects(model))
}

///|
fn mooncode_selected_session_effects(
  session_id : String,
) -> Array[MoonCodeSessionEffect] {
  [MoonCodeFetchStream(session_id, 0)]
}

///|
fn mooncode_selected_session_cmd(
  dispatch : Dispatch[Msg],
  model : Model,
  session_id : String,
) -> @rabbita.Cmd {
  mooncode_session_effects_cmd(
    dispatch, model, mooncode_selected_session_effects(session_id),
  )
}
