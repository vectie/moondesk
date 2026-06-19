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
  let command = first_non_empty([
    json_string(section, "command", default=""),
    json_string(config, action + "_command", default=""),
  ])
  let args = first_non_empty_array([
    json_string_array_items(section, "args"),
    json_string_array_items(config, action + "_args"),
  ])
  let cwd = first_non_empty([
    json_string(section, "cwd", default=""),
    json_string(config, action + "_cwd", default=""),
    json_string(config, "cwd", default=""),
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
    "display": if command == "" {
      ""
    } else if args.length() == 0 {
      command
    } else {
      command + " " + args.join(" ")
    },
  }
}
