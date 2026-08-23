///|
pub fn town_service_config_path(root : String) -> String {
  moonsuite_product_service_path(root, "moontown")
}

///|
async fn town_service_config(root : String) -> Json {
  read_json_file_or_object(town_service_config_path(root))
}

///|
fn town_service_config_has_legacy_execution(
  config : Json,
  action : String,
) -> Bool {
  let section = json_object_field_or_empty(config, action)
  json_object_field(section, "command") is Some(_) ||
  json_object_field(section, "args") is Some(_) ||
  json_object_field(section, "cwd") is Some(_) ||
  json_object_field(config, action + "_command") is Some(_) ||
  json_object_field(config, action + "_args") is Some(_) ||
  json_object_field(config, action + "_cwd") is Some(_) ||
  json_object_field(config, "cwd") is Some(_)
}

///|
pub async fn town_service_descriptor(root : String, action : String) -> Json {
  let config = town_service_config(root)
  let legacy_execution_rejected = town_service_config_has_legacy_execution(
    config, action,
  )
  {
    "configured": false,
    "configuration_valid": false,
    "configuration_reason": if legacy_execution_rejected {
      "legacy-workspace-execution-config-rejected"
    } else {
      "not-configured"
    },
    "legacy_execution_rejected": legacy_execution_rejected,
    "kind": "moondesk-town-service.v1",
    "action": action,
    "command": "",
    "args": json_from_string_array([]),
    "cwd": root,
    "config_path": town_service_config_path(root),
    "display": "",
  }
}
