///|
struct ServeOptions {
  workspace_root : String
  ui_dir : String
  host : String
  port : Int
  open_browser : Bool
}

///|
priv struct BundleOptions {
  workspace_root : String
  ui_dir : String
  out_dir : String
  host : String
  port : Int
  sign_identity : String
  version : String
  channel : String
  lepusa_root : String
  archive : Bool
  skip_sign : Bool
}

///|
fn default_serve_options() -> ServeOptions {
  {
    workspace_root: default_workspace_root(),
    ui_dir: "ui/rabbita-desk/dist",
    host: "127.0.0.1",
    port: 4188,
    open_browser: false,
  }
}

///|
fn default_workspace_root() -> String {
  default_workspace_root_from_env(
    @sys.get_env_var("MOONDESK_WORKSPACE_ROOT").unwrap_or(""),
  )
}

///|
fn default_workspace_root_from_env(override_root : String) -> String {
  let override_root = override_root.trim().to_owned()
  if override_root != "" {
    return @pathx.normalize(override_root)
  }
  ""
}

///|
fn default_bundle_options() -> BundleOptions {
  let serve = default_serve_options()
  {
    workspace_root: serve.workspace_root,
    ui_dir: serve.ui_dir,
    out_dir: "dist",
    host: serve.host,
    port: 4199,
    sign_identity: "-",
    version: "0.1.0",
    channel: "local",
    lepusa_root: ".mooncakes/vectie/lepusa",
    archive: true,
    skip_sign: false,
  }
}

///|
fn parse_serve_args(args : Array[String]) -> ServeOptions? {
  let mut options = default_serve_options()
  let mut index = 0
  let mut seen_root = false
  while index < args.length() {
    match args[index] {
      "--root" =>
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
      "--host" =>
        if index + 1 < args.length() {
          options = { ..options, host: args[index + 1] }
          index += 2
        } else {
          return None
        }
      "--port" =>
        if index + 1 < args.length() {
          let port = @string.parse_int(args[index + 1]) catch {
            _ => return None
          }
          options = { ..options, port, }
          index += 2
        } else {
          return None
        }
      "--open" => {
        options = { ..options, open_browser: true }
        index += 1
      }
      "--no-open" => {
        options = { ..options, open_browser: false }
        index += 1
      }
      value =>
        if !seen_root && !value.has_prefix("-") {
          options = { ..options, workspace_root: value }
          seen_root = true
          index += 1
        } else {
          return None
        }
    }
  }
  if options.workspace_root.trim() == "" {
    None
  } else {
    Some(options)
  }
}

///|
fn parse_bundle_args(args : Array[String]) -> BundleOptions? {
  let mut options = default_bundle_options()
  let mut index = 0
  let mut seen_root = false
  while index < args.length() {
    match args[index] {
      "--root" =>
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
      "--out" =>
        if index + 1 < args.length() {
          options = { ..options, out_dir: args[index + 1] }
          index += 2
        } else {
          return None
        }
      "--host" =>
        if index + 1 < args.length() {
          options = { ..options, host: args[index + 1] }
          index += 2
        } else {
          return None
        }
      "--port" =>
        if index + 1 < args.length() {
          let port = @string.parse_int(args[index + 1]) catch {
            _ => return None
          }
          options = { ..options, port, }
          index += 2
        } else {
          return None
        }
      "--sign-identity" =>
        if index + 1 < args.length() {
          options = { ..options, sign_identity: args[index + 1] }
          index += 2
        } else {
          return None
        }
      "--version" =>
        if index + 1 < args.length() {
          options = { ..options, version: args[index + 1] }
          index += 2
        } else {
          return None
        }
      "--channel" =>
        if index + 1 < args.length() {
          options = { ..options, channel: args[index + 1] }
          index += 2
        } else {
          return None
        }
      "--lepusa" =>
        if index + 1 < args.length() {
          options = { ..options, lepusa_root: args[index + 1] }
          index += 2
        } else {
          return None
        }
      "--skip-sign" => {
        options = { ..options, skip_sign: true }
        index += 1
      }
      "--no-archive" => {
        options = { ..options, archive: false }
        index += 1
      }
      value =>
        if !seen_root && !value.has_prefix("-") {
          options = { ..options, workspace_root: value }
          seen_root = true
          index += 1
        } else {
          return None
        }
    }
  }
  if options.workspace_root.trim() == "" {
    None
  } else {
    Some(options)
  }
}

///|
fn absolute_path(path : String, base : String) -> String {
  if @pathx.is_absolute(path) {
    @pathx.normalize(path)
  } else {
    @pathx.join(base, path)
  }
}
