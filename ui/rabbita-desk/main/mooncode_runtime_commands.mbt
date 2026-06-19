///|
fn fetch_mooncode_runtime_event_sink_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.get(
    "/api/mooncode/sessions/\{encode_component(session_id)}/runtime-events",
    expect=Json(fn(result) {
      dispatch(LoadedMoonCodeRuntimeEventSink(session_id, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode runtime event sink")
      }
    }),
  )
}

///|
fn fetch_mooncode_runtime_handoff_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.get(
    "/api/mooncode/sessions/\{encode_component(session_id)}/runtime-handoff",
    expect=Json(fn(result) {
      dispatch(LoadedMoonCodeRuntimeHandoff(session_id, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode runtime handoff")
      }
    }),
  )
}

///|
fn fetch_mooncode_runtime_evidence_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.get(
    "/api/mooncode/sessions/\{encode_component(session_id)}/runtime-evidence",
    expect=Json(fn(result) {
      dispatch(LoadedMoonCodeRuntimeEvidence(session_id, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode runtime evidence")
      }
    }),
  )
}

///|
fn fetch_mooncode_command_queue_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.get(
    "/api/mooncode/sessions/\{encode_component(session_id)}/commands",
    expect=Json(fn(result) {
      dispatch(LoadedMoonCodeCommandQueue(session_id, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode command queue")
      }
    }),
  )
}

///|
fn fetch_mooncode_runtime_command_feed_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.get(
    "/api/mooncode/sessions/\{encode_component(session_id)}/runtime-commands",
    expect=Json(fn(result) {
      dispatch(LoadedMoonCodeRuntimeCommandFeed(session_id, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode runtime command feed")
      }
    }),
  )
}

///|
fn fetch_mooncode_runtime_replay_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.get(
    "/api/mooncode/sessions/\{encode_component(session_id)}/runtime-replay",
    expect=Json(fn(result) {
      dispatch(LoadedMoonCodeRuntimeReplay(session_id, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode runtime replay state")
      }
    }),
  )
}

///|
fn fetch_mooncode_command_preflight_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
  action : String,
  context_path : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.get(
    "/api/mooncode/sessions/\{encode_component(session_id)}/preflight?action=\{encode_component(action)}&context_path=\{encode_component(context_path)}",
    expect=Json(fn(result) {
      dispatch(LoadedMoonCodeCommandPreflight(session_id, action, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode command preflight")
      }
    }),
  )
}

///|
fn fetch_mooncode_preflight_matrix_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
  context_path : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @rabbita.batch([
    fetch_mooncode_command_preflight_cmd(
      dispatch, session_id, "run_tests", context_path,
    ),
    fetch_mooncode_command_preflight_cmd(
      dispatch, session_id, "run_build", context_path,
    ),
    fetch_mooncode_command_preflight_cmd(
      dispatch, session_id, "run_eval", context_path,
    ),
    fetch_mooncode_command_preflight_cmd(
      dispatch, session_id, "package", context_path,
    ),
    fetch_mooncode_command_preflight_cmd(
      dispatch, session_id, "commit", context_path,
    ),
    fetch_mooncode_command_preflight_cmd(
      dispatch, session_id, "accept", context_path,
    ),
    fetch_mooncode_command_preflight_cmd(
      dispatch, session_id, "apply_patch", context_path,
    ),
    fetch_mooncode_command_preflight_cmd(
      dispatch, session_id, "revert_patch", context_path,
    ),
  ])
}

///|
fn fetch_mooncode_runtime_dispatch_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.get(
    "/api/mooncode/sessions/\{encode_component(session_id)}/runtime-dispatch",
    expect=Json(fn(result) {
      dispatch(LoadedMoonCodeRuntimeDispatch(session_id, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode runtime dispatch state")
      }
    }),
  )
}

///|
fn fetch_mooncode_runtime_claim_state_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.get(
    "/api/mooncode/sessions/\{encode_component(session_id)}/runtime-claim",
    expect=Json(fn(result) {
      dispatch(LoadedMoonCodeRuntimeClaimState(session_id, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode runtime claim state")
      }
    }),
  )
}

///|
fn claim_mooncode_runtime_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
  force : Bool,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.post(
    "/api/mooncode/sessions/\{encode_component(session_id)}/runtime-claim",
    Json({
      "consumer_id": "moondesk-ui-inspector",
      "max_count": 1,
      "force": force,
    }),
    expect=Json(fn(result) {
      dispatch(ClaimedMoonCodeRuntime(session_id, force, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode runtime claim response")
      }
    }),
  )
}

///|
fn run_mooncode_runtime_loop_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.post(
    "/api/mooncode/sessions/\{encode_component(session_id)}/runtime-supervisor",
    Json({
      "consumer_id": "moondesk-ui-runtime-loop",
      "max_turns": 8,
      "live_wait_ms": 5000,
      "poll_ms": 250,
    }),
    expect=Json(fn(result) {
      dispatch(RanMoonCodeRuntimeLoop(session_id, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode native runtime loop response")
      }
    }),
  )
}

///|
fn start_mooncode_runtime_service_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.post(
    "/api/mooncode/sessions/\{encode_component(session_id)}/runtime-service",
    Json({
      "consumer_id": "moondesk-ui-runtime-service",
      "max_turns": 8,
      "live_wait_ms": 5000,
      "poll_ms": 250,
    }),
    expect=Json(fn(result) {
      dispatch(StartedMoonCodeRuntimeService(session_id, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode native runtime service response")
      }
    }),
  )
}

///|
fn ack_mooncode_runtime_command_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
  command_id : String,
  status : String,
) -> @rabbita.Cmd {
  if session_id == "" || command_id == "" {
    return @rabbita.none
  }
  @http.post(
    "/api/mooncode/sessions/\{encode_component(session_id)}/runtime-replay",
    Json({
      "consumer_id": "moondesk-ui-inspector",
      "command_id": command_id,
      "status": status,
      "detail": "Moondesk UI inspector recorded runtime \{status} for \{command_id}.",
    }),
    expect=Json(fn(result) {
      dispatch(AckedMoonCodeRuntimeCommand(session_id, command_id, status, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode runtime replay acknowledgement")
      }
    }),
  )
}

