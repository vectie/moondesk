///|
async fn handle_launch_agent(
  workspace_root : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let root = @pathx.normalize(workspace_root)
  let result = if method_ is Get || method_ is Head {
    launch_agent_record(root, action="status", exit_code=0, message="")
  } else {
    let payload = read_json_body(body).unwrap_or(Json::object({}))
    let action = json_string(payload, "action", default="status")
    match action {
      "install" => install_launch_agent(root)
      "uninstall" => uninstall_launch_agent(root)
      "status" =>
        launch_agent_record(root, action="status", exit_code=0, message="")
      _ =>
        launch_agent_record(
          root,
          action~,
          exit_code=-1,
          message="Unsupported LaunchAgent action",
        )
    }
  }
  send_json(conn, method_, result)
}

///|
async fn install_launch_agent(root : String) -> Json {
  let descriptor = town_service_descriptor(root, "daemon")
  if !json_bool(descriptor, "configured", default=false) {
    return launch_agent_record(
      root,
      action="install",
      exit_code=-1,
      message="Moontown daemon service is not configured for this workspace",
    )
  }
  @fsx.make_directory(moondesk_daemon_dir(root), recursive=true, exists_ok=true) catch {
    _ => ()
  }
  let plist_path = launch_agent_plist_path(root)
  @fsx.make_directory(
    @pathx.dirname(plist_path).to_owned(),
    recursive=true,
    exists_ok=true,
  ) catch {
    _ =>
      return launch_agent_record(
        root,
        action="install",
        exit_code=-1,
        message="Could not create LaunchAgents directory",
      )
  }
  @fsx.write_to_file(
    plist_path,
    launch_agent_plist(root, descriptor),
    create=0o644,
  ) catch {
    _ =>
      return launch_agent_record(
        root,
        action="install",
        exit_code=-1,
        message="Could not write LaunchAgent plist",
      )
  }
  ignore(launchctl_bootout(launch_agent_label(), plist_path))
  let code = launchctl_bootstrap(launch_agent_label(), plist_path)
  launch_agent_record(
    root,
    action="install",
    exit_code=code,
    message=if code == 0 {
      "Moontown daemon LaunchAgent installed and loaded"
    } else {
      "LaunchAgent plist written; launchctl bootstrap failed"
    },
  )
}

///|
async fn uninstall_launch_agent(root : String) -> Json {
  let plist_path = launch_agent_plist_path(root)
  let code = launchctl_bootout(launch_agent_label(), plist_path)
  @fs.remove(plist_path) catch {
    _ => ()
  }
  launch_agent_record(
    root,
    action="uninstall",
    exit_code=code,
    message="Moontown daemon LaunchAgent removed",
  )
}

///|
async fn launch_agent_record(
  root : String,
  action~ : String,
  exit_code~ : Int,
  message~ : String,
) -> Json {
  let descriptor = town_service_descriptor(root, "daemon")
  let label = launch_agent_label()
  let plist_path = launch_agent_plist_path(root)
  let installed = @fsx.exists(plist_path)
  let loaded = launch_agent_loaded_status(installed, label)
  {
    "ok": if action == "status" {
      true
    } else {
      exit_code == 0
    },
    "action": action,
    "installed": installed,
    "loaded": loaded,
    "label": label,
    "plist_path": plist_path,
    "command": json_string(descriptor, "display", default=""),
    "cwd": json_string(descriptor, "cwd", default=root),
    "service_configured": json_bool(descriptor, "configured", default=false),
    "service_config_path": json_string(descriptor, "config_path", default=""),
    "exit_code": exit_code,
    "message": if message == "" {
      if installed {
        if loaded {
          "LaunchAgent is installed and loaded"
        } else {
          "LaunchAgent is installed but not loaded"
        }
      } else {
        "LaunchAgent is not installed"
      }
    } else {
      message
    },
  }
}

///|
async fn launch_agent_loaded_status(installed : Bool, label : String) -> Bool {
  if installed {
    launchctl_print(label) == 0
  } else {
    false
  }
}

///|
fn launch_agent_label() -> String {
  "app.vectie.moondesk.moontown"
}

///|
fn user_launch_agents_dir() -> String {
  let home = @sys.get_env_var("HOME").unwrap_or(".")
  @pathx.join(home, "Library/LaunchAgents")
}

///|
fn launch_agent_plist_path(root : String) -> String {
  ignore(root)
  @pathx.join(user_launch_agents_dir(), launch_agent_label() + ".plist")
}

///|
fn launch_agent_plist(root : String, descriptor : Json) -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
  "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n" +
  "<plist version=\"1.0\">\n" +
  "<dict>\n" +
  "  <key>Label</key>\n" +
  "  <string>\{launch_agent_label()}</string>\n" +
  "  <key>WorkingDirectory</key>\n" +
  "  <string>\{xml_escape(json_string(descriptor, "cwd", default=root))}</string>\n" +
  "  <key>ProgramArguments</key>\n" +
  "  <array>\n" +
  launch_agent_program_arguments_xml(descriptor) +
  "  </array>\n" +
  "  <key>RunAtLoad</key>\n" +
  "  <true/>\n" +
  "  <key>KeepAlive</key>\n" +
  "  <true/>\n" +
  "  <key>StandardOutPath</key>\n" +
  "  <string>\{xml_escape(@pathx.join(moondesk_daemon_dir(root), "launch-agent.out.log"))}</string>\n" +
  "  <key>StandardErrorPath</key>\n" +
  "  <string>\{xml_escape(@pathx.join(moondesk_daemon_dir(root), "launch-agent.err.log"))}</string>\n" +
  "</dict>\n" +
  "</plist>\n"
}

///|
fn launch_agent_program_arguments_xml(descriptor : Json) -> String {
  let lines : Array[String] = []
  let command = json_string(descriptor, "command", default="")
  if command != "" {
    lines.push("    <string>\{xml_escape(command)}</string>\n")
  }
  for arg in json_string_array_items(descriptor, "args") {
    lines.push("    <string>\{xml_escape(arg)}</string>\n")
  }
  lines.join("")
}

///|
fn xml_escape(text : String) -> String {
  text
  .replace_all(old="&", new="&amp;")
  .replace_all(old="<", new="&lt;")
  .replace_all(old=">", new="&gt;")
  .replace_all(old="\"", new="&quot;")
  .to_string()
}

///|
async fn launchctl_target(label : String) -> String {
  let uid = current_user_id()
  if uid == "" {
    "gui/0/" + label
  } else {
    "gui/\{uid}/\{label}"
  }
}

///|
async fn launchctl_domain_name() -> String {
  let uid = current_user_id()
  if uid == "" {
    "gui/0"
  } else {
    "gui/\{uid}"
  }
}

///|
async fn current_user_id() -> String {
  let output = @process.collect_output("id", ["-u"]) catch { _ => return "" }
  if output.0 == 0 {
    (output.1.text() catch { _ => "" }).trim().to_owned()
  } else {
    ""
  }
}

///|
async fn launchctl_bootstrap(label : String, plist_path : String) -> Int {
  ignore(label)
  @process.run("launchctl", ["bootstrap", launchctl_domain_name(), plist_path]) catch {
    _ => -1
  }
}

///|
async fn launchctl_bootout(label : String, plist_path : String) -> Int {
  ignore(plist_path)
  @process.run("launchctl", ["bootout", launchctl_target(label)]) catch {
    _ => -1
  }
}

///|
async fn launchctl_print(label : String) -> Int {
  @process.run("launchctl", ["print", launchctl_target(label)]) catch {
    _ => -1
  }
}
