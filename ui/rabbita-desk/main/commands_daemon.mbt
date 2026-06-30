///|
fn dispatch_daemon_cmd(dispatch : Dispatch[Msg]) -> @rabbita.Cmd {
  @http.post("/api/town/dispatch")
  .with_json(Json::object({}))
  .expect_json(result => {
    dispatch(
      DispatchedDaemon(http_result(result, "Could not dispatch daemon tick")),
    )
  })
}

///|
fn manage_daemon_cmd(dispatch : Dispatch[Msg], action : String) -> @rabbita.Cmd {
  @http.post("/api/town/daemon/\{action}")
  .with_json(Json::object({}))
  .expect_json(result => {
    dispatch(
      ManagedDaemon(http_result(result, "Could not manage daemon lifecycle")),
    )
  })
}

///|
fn set_daemon_supervision_cmd(
  dispatch : Dispatch[Msg],
  enabled : Bool,
) -> @rabbita.Cmd {
  let body : Json = { "enabled": enabled }
  @http.post("/api/town/daemon/supervision")
  .with_json(body)
  .expect_json(result => {
    dispatch(
      ManagedDaemon(http_result(result, "Could not update daemon supervision")),
    )
  })
}

///|
fn manage_launch_agent_cmd(
  dispatch : Dispatch[Msg],
  action : String,
) -> @rabbita.Cmd {
  let body : Json = { "action": action }
  @http.post("/api/town/daemon/launch-agent")
  .with_json(body)
  .expect_json(result => {
    dispatch(
      ManagedLaunchAgent(
        http_result(result, "Could not update daemon LaunchAgent"),
      ),
    )
  })
}

///|
fn reveal_selection_cmd(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Cmd {
  let body : Json = { "path": reveal_target_path(model) }
  @http.post("/api/workspaces/\{model.selected_workspace_id}/reveal")
  .with_json(body)
  .expect_json(result => {
    dispatch(
      RevealedSelection(http_result(result, "Could not reveal selection")),
    )
  })
}

///|
fn reveal_target_path(model : Model) -> String {
  if model.selected_path != "" {
    model.selected_path
  } else {
    model.current_directory
  }
}
