///|
async fn run_launch_agent(args : Array[String]) -> Unit {
  let mut options = default_serve_options()
  let mut out_path = "dist/app.vectie.moondesk.plist"
  let mut service = "desk"
  let mut index = 0
  let mut seen_root = false
  while index < args.length() {
    match args[index] {
      "--out" =>
        if index + 1 < args.length() {
          out_path = args[index + 1]
          index += 2
        } else {
          print_usage()
          return
        }
      "--service" =>
        if index + 1 < args.length() {
          service = args[index + 1]
          if service != "desk" && service != "town" {
            print_usage()
            return
          }
          index += 2
        } else {
          print_usage()
          return
        }
      "--port" =>
        if index + 1 < args.length() {
          let port = @string.parse_int(args[index + 1]) catch {
            _ => {
              print_usage()
              return
            }
          }
          options = { ..options, port, }
          index += 2
        } else {
          print_usage()
          return
        }
      value =>
        if !seen_root && !value.has_prefix("-") {
          options = { ..options, workspace_root: value }
          seen_root = true
          index += 1
        } else {
          print_usage()
          return
        }
    }
  }
  let repo_root = @pathx.normalize(@env.current_dir().unwrap_or("."))
  let absolute_out = absolute_path(out_path, repo_root)
  let absolute_root = resolve_user_workspace_root(
    options.workspace_root,
    repo_root,
  )
  @fsx.make_directory(
    @pathx.dirname(absolute_out).to_owned(),
    recursive=true,
    exists_ok=true,
  ) catch {
    error => {
      println("launch-agent failed: \{error}")
      return
    }
  }
  let plist = match
    launch_agent_plist_for_service(
      repo_root,
      absolute_root,
      options.port,
      service,
    ) {
    Some(value) => value
    None => {
      println(
        "launch-agent failed: town service is not configured at \{@moonwiki.town_service_config_path(absolute_root)}",
      )
      return
    }
  }
  @fsx.write_to_file(absolute_out, plist, create=0o644) catch {
    error => {
      println("launch-agent failed: \{error}")
      return
    }
  }
  println("Created launch agent template \{absolute_out}")
}

///|
async fn run_install_launch_agent(args : Array[String]) -> Unit {
  let mut options = default_serve_options()
  let mut service = "desk"
  let mut index = 0
  let mut seen_root = false
  while index < args.length() {
    match args[index] {
      "--service" =>
        if index + 1 < args.length() {
          service = args[index + 1]
          if service != "desk" && service != "town" {
            print_usage()
            return
          }
          index += 2
        } else {
          print_usage()
          return
        }
      "--port" =>
        if index + 1 < args.length() {
          let port = @string.parse_int(args[index + 1]) catch {
            _ => {
              print_usage()
              return
            }
          }
          options = { ..options, port, }
          index += 2
        } else {
          print_usage()
          return
        }
      value =>
        if !seen_root && !value.has_prefix("-") {
          options = { ..options, workspace_root: value }
          seen_root = true
          index += 1
        } else {
          print_usage()
          return
        }
    }
  }
  let repo_root = @pathx.normalize(@env.current_dir().unwrap_or("."))
  let absolute_root = resolve_user_workspace_root(
    options.workspace_root,
    repo_root,
  )
  let label = launch_agent_label(service)
  let plist_path = launch_agent_user_path(label)
  @fsx.make_directory(
    @pathx.dirname(plist_path).to_owned(),
    recursive=true,
    exists_ok=true,
  ) catch {
    error => {
      println("install-launch-agent failed: \{error}")
      return
    }
  }
  let plist = match
    launch_agent_plist_for_service(
      repo_root,
      absolute_root,
      options.port,
      service,
    ) {
    Some(value) => value
    None => {
      println(
        "install-launch-agent failed: town service is not configured at \{@moonwiki.town_service_config_path(absolute_root)}",
      )
      return
    }
  }
  @fsx.write_to_file(plist_path, plist, create=0o644) catch {
    error => {
      println("install-launch-agent failed: \{error}")
      return
    }
  }
  ignore(launchctl_unload(label, plist_path))
  let code = launchctl_load(label, plist_path)
  println(
    "install-launch-agent \{service}: \{if code == 0 { "loaded" } else { "written" }} \{plist_path} (launchctl \{code})",
  )
}

///|
async fn run_uninstall_launch_agent(args : Array[String]) -> Unit {
  let service = match args {
    ["--service", value] => value
    [] => "desk"
    _ => {
      print_usage()
      return
    }
  }
  if service != "desk" && service != "town" {
    print_usage()
    return
  }
  let label = launch_agent_label(service)
  let plist_path = launch_agent_user_path(label)
  let code = launchctl_unload(label, plist_path)
  @fs.remove(plist_path) catch {
    _ => ()
  }
  println(
    "uninstall-launch-agent \{service}: removed \{plist_path} (launchctl \{code})",
  )
}

///|
async fn run_launch_agent_status(args : Array[String]) -> Unit {
  let service = match args {
    ["--service", value] => value
    [] => "desk"
    _ => {
      print_usage()
      return
    }
  }
  if service != "desk" && service != "town" {
    print_usage()
    return
  }
  let label = launch_agent_label(service)
  let plist_path = launch_agent_user_path(label)
  let loaded = launchctl_status(label) == 0
  println(
    "\{service} agent installed=\{@fsx.exists(plist_path)} loaded=\{loaded} label=\{label} path=\{plist_path}",
  )
}

///|
fn launch_agent_plist(
  repo_root : String,
  workspace_root : String,
  port : Int,
) -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
  "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n" +
  "<plist version=\"1.0\">\n" +
  "<dict>\n" +
  "  <key>Label</key>\n" +
  "  <string>app.vectie.moondesk</string>\n" +
  "  <key>WorkingDirectory</key>\n" +
  "  <string>\{xml_escape(repo_root)}</string>\n" +
  "  <key>ProgramArguments</key>\n" +
  "  <array>\n" +
  "    <string>moon</string>\n" +
  "    <string>run</string>\n" +
  "    <string>cmd/main</string>\n" +
  "    <string>--</string>\n" +
  "    <string>serve</string>\n" +
  "    <string>\{xml_escape(workspace_root)}</string>\n" +
  "    <string>--port</string>\n" +
  "    <string>\{port}</string>\n" +
  "    <string>--no-open</string>\n" +
  "  </array>\n" +
  "  <key>RunAtLoad</key>\n" +
  "  <true/>\n" +
  "  <key>KeepAlive</key>\n" +
  "  <true/>\n" +
  "</dict>\n" +
  "</plist>\n"
}

///|
async fn town_daemon_launch_agent_plist(workspace_root : String) -> String? {
  let descriptor = @moonwiki.town_service_descriptor(workspace_root, "daemon")
  if !cmd_json_bool(descriptor, "configured", default=false) {
    return None
  }
  Some(
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
    "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n" +
    "<plist version=\"1.0\">\n" +
    "<dict>\n" +
    "  <key>Label</key>\n" +
    "  <string>app.vectie.moonsuite.town</string>\n" +
    "  <key>WorkingDirectory</key>\n" +
    "  <string>\{xml_escape(cmd_json_string(descriptor, "cwd", default=workspace_root))}</string>\n" +
    "  <key>ProgramArguments</key>\n" +
    "  <array>\n" +
    town_service_program_arguments_xml(descriptor) +
    "  </array>\n" +
    "  <key>RunAtLoad</key>\n" +
    "  <true/>\n" +
    "  <key>KeepAlive</key>\n" +
    "  <true/>\n" +
    "  <key>StandardOutPath</key>\n" +
    "  <string>\{xml_escape(@pathx.join(@moonwiki.moondesk_daemon_dir(workspace_root), "launch-agent.out.log"))}</string>\n" +
    "  <key>StandardErrorPath</key>\n" +
    "  <string>\{xml_escape(@pathx.join(@moonwiki.moondesk_daemon_dir(workspace_root), "launch-agent.err.log"))}</string>\n" +
    "</dict>\n" +
    "</plist>\n",
  )
}

///|
async fn launch_agent_plist_for_service(
  repo_root : String,
  workspace_root : String,
  port : Int,
  service : String,
) -> String? {
  if service == "town" {
    town_daemon_launch_agent_plist(workspace_root)
  } else {
    Some(launch_agent_plist(repo_root, workspace_root, port))
  }
}

///|
fn town_service_program_arguments_xml(descriptor : Json) -> String {
  let lines : Array[String] = []
  let command = cmd_json_string(descriptor, "command", default="")
  if command != "" {
    lines.push("    <string>\{xml_escape(command)}</string>\n")
  }
  for arg in cmd_json_string_array_items(descriptor, "args") {
    lines.push("    <string>\{xml_escape(arg)}</string>\n")
  }
  lines.join("")
}

///|
fn launch_agent_label(service : String) -> String {
  if service == "town" {
    "app.vectie.moonsuite.town"
  } else {
    "app.vectie.moondesk"
  }
}

///|
fn launch_agent_user_path(label : String) -> String {
  let home = @sys.get_env_var("HOME").unwrap_or(
    @env.current_dir().unwrap_or("."),
  )
  @pathx.join(@pathx.join(home, "Library/LaunchAgents"), label + ".plist")
}

///|
async fn current_uid() -> String {
  let output = @process.collect_output("id", ["-u"]) catch { _ => return "" }
  if output.0 == 0 {
    (output.1.text() catch { _ => "" }).trim().to_owned()
  } else {
    ""
  }
}

///|
async fn launchctl_domain() -> String {
  let uid = current_uid()
  if uid == "" {
    "gui/0"
  } else {
    "gui/\{uid}"
  }
}

///|
async fn launchctl_load(label : String, plist_path : String) -> Int {
  ignore(label)
  @process.run("launchctl", ["bootstrap", launchctl_domain(), plist_path]) catch {
    _ => -1
  }
}

///|
async fn launchctl_unload(label : String, plist_path : String) -> Int {
  ignore(plist_path)
  @process.run("launchctl", ["bootout", launchctl_domain() + "/" + label]) catch {
    _ => -1
  }
}

///|
async fn launchctl_status(label : String) -> Int {
  @process.run("launchctl", ["print", launchctl_domain() + "/" + label]) catch {
    _ => -1
  }
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
fn cmd_json_bool(json : Json, key : String, default~ : Bool) -> Bool {
  @mooncore.json_bool(json, key, default~)
}

///|
fn cmd_json_string(json : Json, key : String, default~ : String) -> String {
  @mooncore.json_string(json, key, default~)
}

///|
fn cmd_json_string_array_items(json : Json, key : String) -> Array[String] {
  let values : Array[String] = []
  for item in @mooncore.json_array_items(json, key) {
    match item {
      String(value) =>
        if value.trim() != "" {
          values.push(value.trim().to_owned())
        }
      _ => ()
    }
  }
  values
}
