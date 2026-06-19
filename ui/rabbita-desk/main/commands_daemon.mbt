///|
fn dispatch_daemon_cmd(dispatch : (Msg) -> @rabbita.Cmd) -> @rabbita.Cmd {
  @http.post(
    "/api/town/dispatch",
    Json(Json::object({})),
    expect=Json(fn(result) { dispatch(DispatchedDaemon(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Could not dispatch daemon tick")
      }
    }),
  )
}

///|
fn manage_daemon_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  action : String,
) -> @rabbita.Cmd {
  @http.post(
    "/api/town/daemon/\{action}",
    Json(Json::object({})),
    expect=Json(fn(result) { dispatch(ManagedDaemon(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Could not manage daemon lifecycle")
      }
    }),
  )
}

///|
fn set_daemon_supervision_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  enabled : Bool,
) -> @rabbita.Cmd {
  @http.post(
    "/api/town/daemon/supervision",
    Json({ "enabled": enabled }),
    expect=Json(fn(result) { dispatch(ManagedDaemon(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Could not update daemon supervision")
      }
    }),
  )
}

///|
fn manage_launch_agent_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  action : String,
) -> @rabbita.Cmd {
  @http.post(
    "/api/town/daemon/launch-agent",
    Json({ "action": action }),
    expect=Json(fn(result) { dispatch(ManagedLaunchAgent(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Could not update daemon LaunchAgent")
      }
    }),
  )
}

///|
fn reveal_selection_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  model : Model,
) -> @rabbita.Cmd {
  @http.post(
    "/api/workspaces/\{model.selected_workspace_id}/reveal",
    Json({ "path": model.selected_path }),
    expect=Json(fn(result) { dispatch(RevealedSelection(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Could not reveal selection")
      }
    }),
  )
}

