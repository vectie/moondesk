///|
fn parse_lepusa_integration_args(
  args : Array[String],
) -> LepusaIntegrationOptions? {
  let mut options = default_lepusa_integration_options()
  let mut index = 0
  let mut seen_command = false
  let mut seen_target = false
  let mut seen_asset = false
  while index < args.length() {
    match args[index] {
      "--lepusa" =>
        if index + 1 < args.length() {
          options = { ..options, lepusa_root: args[index + 1] }
          index += 2
        } else {
          return None
        }
      "--project" =>
        if index + 1 < args.length() {
          options = { ..options, project: args[index + 1] }
          index += 2
        } else {
          return None
        }
      "--out" =>
        if index + 1 < args.length() {
          options = { ..options, out_dir: args[index + 1] }
          index += 2
        } else {
          return None
        }
      "--manifest" =>
        if index + 1 < args.length() {
          options = { ..options, manifest_path: args[index + 1] }
          index += 2
        } else {
          return None
        }
      "--asset" =>
        if index + 1 < args.length() {
          options = { ..options, asset_url: args[index + 1] }
          index += 2
        } else {
          return None
        }
      "--workspace-root" =>
        if index + 1 < args.length() {
          options = { ..options, workspace_root: args[index + 1] }
          index += 2
        } else {
          return None
        }
      "--ui" =>
        if index + 1 < args.length() {
          options = { ..options, ui_dir: args[index + 1] }
          index += 2
        } else {
          return None
        }
      "--serve-port" =>
        if index + 1 < args.length() {
          let serve_port = @string.parse_int(args[index + 1]) catch {
            _ => return None
          }
          options = { ..options, serve_port, }
          index += 2
        } else {
          return None
        }
      "--strict" => {
        options = { ..options, strict: true }
        index += 1
      }
      value =>
        if !value.has_prefix("-") && !seen_command {
          if !lepusa_integration_command_supported(value) {
            return None
          }
          options = { ..options, command: value }
          seen_command = true
          index += 1
        } else if lepusa_integration_command_uses_asset(options.command) &&
          !value.has_prefix("-") &&
          !seen_asset {
          options = { ..options, asset_url: value }
          seen_asset = true
          index += 1
        } else if !value.has_prefix("-") && !seen_target {
          if !lepusa_integration_target_supported(value) {
            return None
          }
          options = { ..options, target: value }
          seen_target = true
          index += 1
        } else {
          return None
        }
    }
  }
  if lepusa_integration_command_uses_live_project(options.command) &&
    options.workspace_root.trim() == "" {
    None
  } else {
    Some(options)
  }
}

///|
fn lepusa_integration_command_supported(command : String) -> Bool {
  match command {
    "verify"
    | "run"
    | "launch"
    | "launch-session"
    | "bundle-plan"
    | "bundle-write"
    | "build"
    | "smoke"
    | "live-smoke"
    | "live-build"
    | "live-session"
    | "live-launch"
    | "live-bundle-check"
    | "bundle-check"
    | "asset"
    | "runtime-session"
    | "runtime-launch"
    | "runtime-asset"
    | "doctor" => true
    _ => false
  }
}

///|
fn lepusa_integration_command_uses_live_project(command : String) -> Bool {
  command == "live-smoke" ||
  command == "live-build" ||
  command == "live-session" ||
  command == "live-launch" ||
  command == "live-bundle-check"
}

///|
fn lepusa_integration_command_uses_asset(command : String) -> Bool {
  command == "asset" || command == "runtime-asset"
}

///|
fn lepusa_integration_command_uses_runtime(command : String) -> Bool {
  command == "runtime-session" ||
  command == "runtime-launch" ||
  command == "runtime-asset"
}

///|
fn lepusa_integration_command_builds_runtime(command : String) -> Bool {
  command == "build" ||
  command == "bundle-write" ||
  command == "smoke" ||
  command == "live-smoke" ||
  command == "live-build" ||
  command == "live-session" ||
  command == "live-launch"
}

///|
fn lepusa_integration_target_supported(target : String) -> Bool {
  match target {
    "macos" | "windows" | "linux" => true
    _ => false
  }
}
