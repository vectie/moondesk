///|
fn fetch_mooncode_tool_approvals_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.get(
    "/api/mooncode/sessions/\{encode_component(session_id)}/tool-approvals",
    expect=Json(fn(result) {
      dispatch(LoadedMoonCodeToolApprovals(session_id, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode tool approvals")
      }
    }),
  )
}

///|
fn mooncode_tool_authorization_probe_payload(
  selected_path : String,
  tool_id : String,
) -> Json {
  let path = if selected_path == "" { "wiki/index.md" } else { selected_path }
  match tool_id {
    "read" => {
      "tool_call_id": "moondesk-ui-probe-read",
      "tool_name": "read",
      "path": path,
      "arguments": "{\"path\":\"\{path}\"}",
    }
    "write" => {
      "tool_call_id": "moondesk-ui-probe-write",
      "tool_name": "write",
      "path": path,
      "arguments": "{\"path\":\"\{path}\",\"content\":\"MoonCode authorization probe\"}",
    }
    "shell" => {
      "tool_call_id": "moondesk-ui-probe-shell",
      "tool_name": "shell",
      "command": "moon check",
      "arguments": "{\"cmd\":[\"moon\",\"check\"]}",
    }
    _ => {
      "tool_call_id": "moondesk-ui-probe-\{tool_id}",
      "tool_name": tool_id,
      "path": path,
      "arguments": "{\"path\":\"\{path}\"}",
    }
  }
}

///|
fn probe_mooncode_tool_authorization_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
  selected_path : String,
  tool_id : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.post(
    "/api/mooncode/sessions/\{encode_component(session_id)}/tool-authorization",
    Json(
      mooncode_tool_authorization_probe_payload(selected_path, tool_id),
    ),
    expect=Json(fn(result) {
      dispatch(LoadedMoonCodeToolAuthorization(session_id, tool_id, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode tool authorization")
      }
    }),
  )
}

