///|
fn fetch_mooncode_sessions_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  workspace_id : String,
) -> @rabbita.Cmd {
  let query = if workspace_id == "" {
    ""
  } else {
    "?workspace=\{encode_component(workspace_id)}"
  }
  @http.get(
    "/api/mooncode/sessions\{query}",
    expect=Json(fn(result) { dispatch(LoadedMoonCodeSessions(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode session listing")
      }
    }),
  )
}

///|
fn fetch_mooncode_stream_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
  since : Int,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  let expect : @http.Expecting[@rabbita.Cmd, Unit] = Text(fn(result) {
      let decoded : Result[MoonCodeStreamPoll, String] = match result {
        Ok(text) => parse_mooncode_stream_text(text)
        Err(error) => Err(error)
      }
      dispatch(LoadedMoonCodeStream(session_id, decoded))
    })
  @http.get(
    "/api/mooncode/sessions/\{encode_component(session_id)}/stream?format=jsonl&since=\{since}&live=true&timeout_ms=1000&poll_ms=100",
    expect~,
  )
}

///|
fn save_mooncode_stream_checkpoint_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
  next_since : Int,
) -> @rabbita.Cmd {
  if session_id == "" || next_since <= 0 {
    return @rabbita.none
  }
  @http.post(
    "/api/mooncode/sessions/\{encode_component(session_id)}/stream-state",
    Json({
      "consumer_id": "moondesk-ui",
      "last_seen_sequence": next_since,
    }),
    expect=Json(
      fn(result) { dispatch(SavedMoonCodeStreamCheckpoint(session_id, result)) },
      json => {
        Ok(@json.from_json(json)) catch {
          _ => Err("Could not save MoonCode stream checkpoint")
        }
      },
    ),
  )
}

///|
fn fetch_mooncode_change_set_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.get(
    "/api/mooncode/sessions/\{encode_component(session_id)}/change-set",
    expect=Json(fn(result) {
      dispatch(LoadedMoonCodeChangeSet(session_id, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode change set")
      }
    }),
  )
}

///|
fn fetch_mooncode_eval_report_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.get(
    "/api/mooncode/sessions/\{encode_component(session_id)}/eval-report",
    expect=Json(fn(result) {
      dispatch(LoadedMoonCodeEvalReport(session_id, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode eval report")
      }
    }),
  )
}

///|
fn fetch_mooncode_patch_set_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.get(
    "/api/mooncode/sessions/\{encode_component(session_id)}/patch-set",
    expect=Json(fn(result) {
      dispatch(LoadedMoonCodePatchSet(session_id, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode patch set")
      }
    }),
  )
}

///|
fn fetch_mooncode_test_runs_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.get(
    "/api/mooncode/sessions/\{encode_component(session_id)}/test-runs",
    expect=Json(fn(result) {
      dispatch(LoadedMoonCodeTestRuns(session_id, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode test runs")
      }
    }),
  )
}

///|
fn fetch_mooncode_package_candidates_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.get(
    "/api/mooncode/sessions/\{encode_component(session_id)}/package-candidates",
    expect=Json(fn(result) {
      dispatch(LoadedMoonCodePackageCandidates(session_id, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode package candidates")
      }
    }),
  )
}

///|
fn fetch_mooncode_action_plan_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.get(
    "/api/mooncode/sessions/\{encode_component(session_id)}/action-plan",
    expect=Json(fn(result) {
      dispatch(LoadedMoonCodeActionPlan(session_id, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode action plan")
      }
    }),
  )
}

///|
fn fetch_mooncode_readiness_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.get(
    "/api/mooncode/sessions/\{encode_component(session_id)}/readiness",
    expect=Json(fn(result) {
      dispatch(LoadedMoonCodeReadiness(session_id, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode readiness")
      }
    }),
  )
}

