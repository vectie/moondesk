///|
pub fn town_service_config_path(root : String) -> String {
  moonsuite_product_service_path(root, "moontown")
}

///|
async fn town_service_config(root : String) -> Json {
  read_json_file_or_object(town_service_config_path(root))
}

///|
pub async fn town_service_descriptor(root : String, action : String) -> Json {
  let config = town_service_config(root)
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
    "kind": "moondesk-town-service.v1",
    "action": action,
    "command": command,
    "args": json_from_string_array(args),
    "cwd": cwd,
    "config_path": town_service_config_path(root),
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
fn first_non_empty(values : Array[String]) -> String {
  for value in values {
    let trimmed = value.trim().to_owned()
    if trimmed != "" {
      return trimmed
    }
  }
  ""
}

///|
fn first_non_empty_array(values : Array[Array[String]]) -> Array[String] {
  for value in values {
    if value.length() > 0 {
      return value
    }
  }
  []
}
