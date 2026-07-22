///|
fn moonclaw_service_config_path(root : String) -> String {
  moonsuite_product_service_path(root, "moonclaw")
}

///|
async fn moonclaw_service_config(root : String) -> Json {
  read_json_file_or_object(moonclaw_service_config_path(root))
}

///|
async fn moonclaw_service_descriptor(root : String, action : String) -> Json {
  let config = moonclaw_service_config(root)
  let version = json_string(config, "version", default="")
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
    moonclaw_explicit_checkout_service_descriptor(root, action)
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
  let managed_binary = if version == "" {
    ""
  } else {
    @pathx.join(
      moonclaw_runtime_root(),
      "moonclaw/" + version + "/bin/moonclaw",
    )
  }
  let managed_install = moonclaw_managed_service_matches(
    version,
    command,
    managed_binary,
    @fsx.exists(managed_binary),
  )
  {
    "configured": command != "",
    "kind": "moondesk-moonclaw-service.v1",
    "action": action,
    "command": command,
    "args": json_from_string_array(args),
    "cwd": cwd,
    "version": version,
    "managed_install": managed_install,
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
fn moonclaw_managed_service_matches(
  version : String,
  command : String,
  managed_binary : String,
  binary_exists : Bool,
) -> Bool {
  version != "" && command == managed_binary && binary_exists
}

///|
struct MoonClawCheckoutCandidate {
  path : String
  source : String
} derive(Debug, Eq)

///|
async fn moonclaw_explicit_checkout_service_descriptor(
  root : String,
  action : String,
) -> Json {
  if action != "daemon" {
    return Json::object({})
  }
  let candidates = moonclaw_checkout_candidates(
    @sys.get_env_var("MOONCLAW_ROOT").unwrap_or(""),
  )
  for candidate in candidates {
    if is_directory(candidate.path) &&
      @fsx.exists(@pathx.join(candidate.path, "moon.mod")) {
      return moonclaw_checkout_service_descriptor(
        root,
        candidate.path,
        candidate.source,
      )
    }
  }
  Json::object({})
}

///|
fn moonclaw_checkout_candidates(
  configured_root : String,
) -> Array[MoonClawCheckoutCandidate] {
  let candidates : Array[MoonClawCheckoutCandidate] = []
  push_moonclaw_checkout_candidate(
    candidates, configured_root, "env-moonclaw-root",
  )
  candidates
}

///|
fn push_moonclaw_checkout_candidate(
  candidates : Array[MoonClawCheckoutCandidate],
  path : String,
  source : String,
) -> Unit {
  if path == "" {
    return
  }
  let normalized = @pathx.normalize(path)
  for candidate in candidates {
    if candidate.path == normalized {
      return
    }
  }
  candidates.push({ path: normalized, source })
}

///|
async fn moonclaw_checkout_service_descriptor(
  root : String,
  checkout : String,
  source : String,
) -> Json {
  {
    "command": moonclaw_default_moon_command(),
    "args": json_from_string_array([
      "run", "cmd/main", "--", "daemon", "--port", "0", "--serve", root,
    ]),
    "cwd": checkout,
    "source": source,
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
