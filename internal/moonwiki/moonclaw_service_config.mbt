///|
fn moonclaw_service_config_path(root : String) -> String {
  @pathx.join(moondesk_daemon_dir(root), "moonclaw-service.json")
}

///|
async fn moonclaw_service_config(root : String) -> Json {
  read_json_file_or_object(moonclaw_service_config_path(root))
}

///|
async fn moonclaw_service_descriptor(root : String, action : String) -> Json {
  let config = moonclaw_service_config(root)
  let section = json_object_field_or_empty(config, action)
  let configured_command = first_non_empty([
    json_string(section, "command", default=""),
    json_string(config, action + "_command", default=""),
  ])
  let configured_args = first_non_empty_array([
    json_string_array_items(section, "args"),
    json_string_array_items(config, action + "_args"),
  ])
  let configured_cwd = first_non_empty([
    json_string(section, "cwd", default=""),
    json_string(config, action + "_cwd", default=""),
    json_string(config, "cwd", default=""),
  ])
  let fallback = if configured_command == "" {
    moonclaw_sibling_service_descriptor(root, action)
  } else {
    Json::object({})
  }
  let command = first_non_empty([
    configured_command,
    json_string(fallback, "command", default=""),
  ])
  let args = first_non_empty_array([
    configured_args,
    json_string_array_items(fallback, "args"),
  ])
  let cwd = first_non_empty([
    configured_cwd,
    json_string(fallback, "cwd", default=""),
  ])
  let cwd = if cwd == "" { root } else { cwd }
  {
    "configured": command != "",
    "kind": "moondesk-moonclaw-service.v1",
    "action": action,
    "command": command,
    "args": json_from_string_array(args),
    "cwd": cwd,
    "config_path": moonclaw_service_config_path(root),
    "source": if configured_command != "" {
      "config"
    } else {
      json_string(fallback, "source", default="missing")
    },
    "display": if command == "" {
      ""
    } else if args.length() == 0 {
      command
    } else {
      command + " " + args.join(" ")
    },
  }
}

///|
async fn moonclaw_sibling_service_descriptor(
  root : String,
  action : String,
) -> Json {
  if action != "daemon" {
    return Json::object({})
  }
  let sibling = @pathx.normalize(@pathx.join(root, "../moonclaw"))
  if !is_directory(sibling) || !@fsx.exists(@pathx.join(sibling, "moon.mod")) {
    return Json::object({})
  }
  {
    "command": moonclaw_default_moon_command(),
    "args": json_from_string_array([
      "run", "cmd/main", "--", "daemon", "--port", "0", "--serve", "cmd/daemon",
    ]),
    "cwd": sibling,
    "source": "sibling-checkout",
  }
}

///|
async fn moonclaw_default_moon_command() -> String {
  let home = @sys.get_env_var("HOME").unwrap_or("")
  if home != "" {
    let local_moon = @pathx.join(home, ".moon/bin/moon")
    if @fsx.exists(local_moon) {
      return local_moon
    }
  }
  "moon"
}
