///|
struct WorkspaceTerminal {
  id : String
  root : String
  directory : String
  handle : @terminal.Session
  mut title : String
}

///|
let workspace_terminals : Map[String, WorkspaceTerminal] = {}

///|
let workspace_terminal_sequence : Ref[Int32] = { val: 0, }

///|
fn WorkspaceTerminal::to_json(self : WorkspaceTerminal) -> Json {
  {
    "id": self.id,
    "title": self.title,
    "directory": self.directory,
    "status": self.handle.status(),
  }
}

///|
async fn handle_workspace_terminals(
  workspace_root : String,
  workspace_id : String,
  session_id : String?,
  request_path : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let workspace = match find_workspace(workspace_root, workspace_id) {
    Some(workspace) => workspace
    None => {
      send_api_error(
        conn, method_, 404, "Not Found", "Choose a Book to open a terminal",
      )
      return
    }
  }
  if method_ is Get {
    match session_id {
      None => {
        let items : Array[Json] = []
        for terminal in workspace_terminals.values() {
          if terminal.root == workspace.root_path {
            items.push(terminal.to_json())
          }
        }
        send_json(conn, method_, { "sessions": items })
      }
      Some(id) => {
        guard workspace_terminals.get(id) is Some(terminal) &&
          terminal.root == workspace.root_path else {
          send_api_error(conn, method_, 404, "Not Found", "Terminal closed")
          return
        }
        let after = @string.parse_int64(
          query_value(request_path, "after").unwrap_or("0"),
        ) catch {
          _ => 0
        }
        let (output, start, next) = terminal.handle.read(after)
        send_json(conn, method_, {
          "output": @base64.encode(output),
          "start": start,
          "next": next,
          "status": terminal.handle.status(),
        })
      }
    }
    return
  }
  guard method_ is Post else {
    send_method_not_allowed_with_methods(conn, method_, ["GET", "POST"])
    return
  }
  guard read_json_body(body) is Some(payload) else {
    send_api_error(
      conn, method_, 400, "Bad Request", "Invalid terminal request",
    )
    return
  }
  match session_id {
    None => {
      let relative = json_string(payload, "directory", default="")
      guard resolve_workspace_existing_path(workspace.root_path, relative)
        is Some((directory, _)) &&
        is_directory(directory) else {
        send_api_error(
          conn, method_, 400, "Bad Request", "Choose a folder in this Book",
        )
        return
      }
      let handle = @terminal.Session::open(
        directory,
        columns=json_int(payload, "columns", default=100),
        rows=json_int(payload, "rows", default=30),
      ) catch {
        _ => {
          send_api_error(
            conn, method_, 500, "Terminal unavailable", "The shell could not start in this folder",
          )
          return
        }
      }
      workspace_terminal_sequence.val += 1
      let id = @desk.stable_id(
        "terminal",
        workspace.root_path +
        @async.now().to_string() +
        "-\{workspace_terminal_sequence.val}",
      )
      let terminal : WorkspaceTerminal = {
        id,
        root: workspace.root_path,
        directory: relative,
        handle,
        title: json_string(
          payload,
          "title",
          default="Terminal \{workspace_terminal_sequence.val}",
        ),
      }
      workspace_terminals[id] = terminal
      send_json(conn, method_, terminal.to_json())
    }
    Some(id) => {
      guard workspace_terminals.get(id) is Some(terminal) &&
        terminal.root == workspace.root_path else {
        send_api_error(conn, method_, 404, "Not Found", "Terminal closed")
        return
      }
      let action = json_string(payload, "action", default="input")
      match action {
        "input" => {
          let input = @encoding/utf8.encode(
            json_string(payload, "data", default=""),
          )
          let mut offset = 0
          while offset < input.length() {
            let count = terminal.handle.write(input[offset:].to_owned())
            if count < 0 {
              send_api_error(
                conn, method_, 409, "Terminal exited", "This shell has exited. Open a new terminal.",
              )
              return
            }
            offset += count
            if count == 0 {
              @async.sleep(10)
            }
          }
        }
        "resize" =>
          ignore(
            terminal.handle.resize(
              json_int(payload, "columns", default=100),
              json_int(payload, "rows", default=30),
            ),
          )
        "interrupt" => ignore(terminal.handle.write(b"\x03"))
        "rename" =>
          terminal.title = json_string(payload, "title", default=terminal.title)
        "close" => {
          terminal.handle.close()
          workspace_terminals.remove(id)
        }
        _ => {
          send_api_error(
            conn, method_, 400, "Bad Request", "Unknown terminal action",
          )
          return
        }
      }
      send_json(conn, method_, terminal.to_json())
    }
  }
}
