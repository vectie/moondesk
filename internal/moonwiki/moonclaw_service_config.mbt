///|
fn moonclaw_service_config_path(root : String) -> String {
  moonsuite_product_service_path(root, "moonclaw")
}

///|
async fn moonclaw_service_config(root : String) -> Json {
  read_json_file_or_object(moonclaw_service_config_path(root))
}

///|
fn moonclaw_service_config_has_legacy_execution(
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
async fn moonclaw_service_descriptor(root : String, action : String) -> Json {
  let config = moonclaw_service_config(root)
  let version = json_string(config, "version", default="")
  let legacy_execution_rejected = moonclaw_service_config_has_legacy_execution(
    config, action,
  )
  let managed_config = json_string(config, "kind", default="") ==
    "moondesk-moonclaw-service.v1" &&
    moonclaw_release_segment_valid(version)
  let install_dir = if managed_config {
    @pathx.join(moonclaw_runtime_root(), "moonclaw/" + version)
  } else {
    ""
  }
  let managed_binary = if install_dir == "" {
    ""
  } else {
    @pathx.join(install_dir, "bin/moonclaw")
  }
  let managed_install = !legacy_execution_rejected &&
    moonclaw_managed_service_matches(
      version,
      managed_binary,
      managed_binary,
      @fsx.exists(managed_binary),
    )
  let repair_available = managed_config &&
    (legacy_execution_rejected || !managed_install)
  let command = if managed_install { managed_binary } else { "" }
  let args = if managed_install && action == "daemon" {
    ["daemon", "--port", "0", "--serve", root]
  } else {
    []
  }
  let cwd = if managed_install { install_dir } else { root }
  let integrity = service_configuration_integrity(command, cwd)
  {
    "configured": managed_install,
    "configuration_present": managed_config || legacy_execution_rejected,
    "configuration_valid": !repair_available &&
    json_bool(integrity, "valid", default=false),
    "configuration_reason": if legacy_execution_rejected {
      "legacy-workspace-execution-config-rejected"
    } else if repair_available {
      "stale-managed-service-config"
    } else {
      json_string(integrity, "reason", default="not-configured")
    },
    "kind": "moondesk-moonclaw-service.v1",
    "action": action,
    "command": command,
    "args": json_from_string_array(args),
    "cwd": cwd,
    "version": version,
    "managed_config": managed_config,
    "managed_install": managed_install,
    "repair_available": repair_available,
    "legacy_execution_rejected": legacy_execution_rejected,
    "config_path": moonclaw_service_config_path(root),
    "source": if legacy_execution_rejected {
      "legacy-rejected"
    } else if repair_available {
      "stale-managed"
    } else if managed_install {
      "managed-binding"
    } else {
      "missing"
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
fn moonclaw_managed_service_matches(
  version : String,
  command : String,
  managed_binary : String,
  binary_exists : Bool,
) -> Bool {
  version != "" && command == managed_binary && binary_exists
}
