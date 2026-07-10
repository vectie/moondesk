///|
enum MoonCodeSessionEffect {
  MoonCodeFetchDaemon
  MoonCodeFetchSessions(String)
  MoonCodeFetchSelectedSession
  MoonCodeFetchSession(String)
  MoonCodeScheduleFastPoll(Int)
  MoonCodeSchedulePoll(Int)
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
    MoonCodeFetchSelectedSession =>
      fetch_selected_mooncode_session_cmd(dispatch, model)
    MoonCodeFetchSession(session_id) =>
      fetch_mooncode_session_cmd(dispatch, session_id)
    MoonCodeScheduleFastPoll(generation) =>
      schedule_mooncode_fast_poll(dispatch, generation)
    MoonCodeSchedulePoll(generation) =>
      schedule_mooncode_poll(dispatch, generation)
    MoonCodeSyncShell => sync_shell_cmd(MoonCode, model.activity)
  }
}

///|
fn mooncode_user_submit_effects(
  model : Model,
  generation : Int,
) -> Array[MoonCodeSessionEffect] {
  let effects : Array[MoonCodeSessionEffect] = []
  if model.selected_mooncode_session_id == "" {
    effects.push(MoonCodeFetchSessions(""))
  } else {
    effects.push(MoonCodeFetchSelectedSession)
  }
  effects.push(MoonCodeScheduleFastPoll(generation))
  effects.push(MoonCodeSyncShell)
  effects
}

///|
fn mooncode_after_user_submit_cmd(
  dispatch : Dispatch[Msg],
  model : Model,
  primary : @rabbita.Cmd,
  generation : Int,
) -> @rabbita.Cmd {
  mooncode_session_effects_with_primary_cmd(
    dispatch,
    model,
    @rabbita.batch([primary, clear_mooncode_composer_cmd()]),
    mooncode_user_submit_effects(model, generation),
  )
}

///|
fn mooncode_session_mutation_effects(
  _model : Model,
  session_id : String,
) -> Array[MoonCodeSessionEffect] {
  let effects : Array[MoonCodeSessionEffect] = []
  if session_id != "" {
    effects.push(MoonCodeFetchSession(session_id))
  }
  effects.push(MoonCodeSyncShell)
  effects
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
      mooncode_session_mutation_effects(model, session_id),
    ),
    sync_mooncode_context_cmd(model.selected_workspace_id, session_id),
    clear_mooncode_composer_cmd(),
  ])
}

///|
fn mooncode_poll_effects(
  model : Model,
  generation : Int,
) -> Array[MoonCodeSessionEffect] {
  let effects : Array[MoonCodeSessionEffect] = []
  if mooncode_should_fast_poll(model) {
    if model.selected_mooncode_session_id == "" {
      effects.push(MoonCodeFetchSessions(""))
    } else {
      effects.push(MoonCodeFetchSelectedSession)
    }
    effects.push(MoonCodeScheduleFastPoll(generation))
  } else {
    effects.push(MoonCodeFetchDaemon)
    effects.push(MoonCodeFetchSessions(""))
    effects.push(MoonCodeFetchSelectedSession)
    effects.push(MoonCodeSchedulePoll(generation))
  }
  effects
}

///|
fn mooncode_poll_cmd(
  dispatch : Dispatch[Msg],
  model : Model,
  generation : Int,
) -> @rabbita.Cmd {
  mooncode_session_effects_cmd(
    dispatch,
    model,
    mooncode_poll_effects(model, generation),
  )
}

///|
fn mooncode_should_fast_poll(model : Model) -> Bool {
  if model.selected_mooncode_session_id == "" {
    return mooncode_optimistic_rows_have_session(
      model.mooncode_optimistic_rows,
      mooncode_draft_session_id(model),
    )
  }
  mooncode_selected_session_has_inflight_state(
    model,
    model.selected_mooncode_session_id,
  )
}

///|
fn mooncode_selected_session_effects(
  session_id : String,
) -> Array[MoonCodeSessionEffect] {
  [MoonCodeFetchSession(session_id)]
}

///|
fn mooncode_selected_session_cmd(
  dispatch : Dispatch[Msg],
  model : Model,
  session_id : String,
) -> @rabbita.Cmd {
  mooncode_session_effects_cmd(
    dispatch,
    model,
    mooncode_selected_session_effects(session_id),
  )
}
