///|
struct ServeOptions {
  workspace_root : String
  ui_dir : String
  host : String
  port : Int
} derive(Show)

///|
priv struct BundleOptions {
  workspace_root : String
  ui_dir : String
  out_dir : String
  host : String
  port : Int
}

///|
fn default_serve_options() -> ServeOptions {
  {
    workspace_root: "..",
    ui_dir: "ui/rabbita-desk/dist",
    host: "127.0.0.1",
    port: 4188,
  }
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
  Some(options)
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
  Some(options)
}

///|
async fn run_serve(args : Array[String]) -> Unit {
  let options = match parse_serve_args(args) {
    Some(options) => options
    None => {
      print_usage()
      return
    }
  }
  let server = @httpserve.Server::new(options.host, options.port) catch {
    _ => {
      println("failed to bind \{options.host}:\{options.port}")
      return
    }
  }
  println("Moondesk serving \{options.ui_dir}")
  println("Workspace root: \{options.workspace_root}")
  println("Open http://\{options.host}:\{server.port()}/")
  server.serve_desk(options.ui_dir, options.workspace_root)
}

///|
async fn run_bundle(args : Array[String]) -> Unit {
  let options = match parse_bundle_args(args) {
    Some(options) => options
    None => {
      print_usage()
      return
    }
  }
  let repo_root = @env.current_dir().unwrap_or(".")
  let out_dir = @pathx.normalize(options.out_dir)
  let app_root = @pathx.join(out_dir, "Moondesk.app")
  let contents = @pathx.join(app_root, "Contents")
  let macos = @pathx.join(contents, "MacOS")
  let resources = @pathx.join(contents, "Resources")
  @fsx.make_directory(macos, recursive=true, exists_ok=true) catch {
    error => {
      println("bundle failed: \{error}")
      return
    }
  }
  @fsx.make_directory(resources, recursive=true, exists_ok=true) catch {
    error => {
      println("bundle failed: \{error}")
      return
    }
  }
  let launcher = @pathx.join(macos, "moondesk")
  let script = "#!/bin/sh\n" +
    "cd \{shell_quote(repo_root)}\n" +
    "exec moon run cmd/main -- desktop \{shell_quote(options.workspace_root)} --ui \{shell_quote(options.ui_dir)} --host \{shell_quote(options.host)} --port \{options.port}\n"
  @fsx.write_to_file(launcher, script, create=0o755) catch {
    error => {
      println("bundle failed: \{error}")
      return
    }
  }
  ignore(@process.run("chmod", ["+x", launcher]) catch { _ => -1 })
  @fsx.write_to_file(
    @pathx.join(contents, "Info.plist"),
    info_plist(),
    create=0o644,
  ) catch {
    error => {
      println("bundle failed: \{error}")
      return
    }
  }
  @fsx.write_to_file(
    @pathx.join(resources, "README.txt"),
    "Moondesk.app launches the pure MoonBit desktop host and serves \{options.ui_dir} for \{options.workspace_root}.\n",
    create=0o644,
  ) catch {
    error => {
      println("bundle failed: \{error}")
      return
    }
  }
  println("Created \{app_root}")
}

///|
fn shell_quote(value : String) -> String {
  "'" + value.replace_all(old="'", new="'\"'\"'").to_string() + "'"
}

///|
fn info_plist() -> String {
  (
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    #|<plist version="1.0">
    #|<dict>
    #|  <key>CFBundleName</key>
    #|  <string>Moondesk</string>
    #|  <key>CFBundleDisplayName</key>
    #|  <string>Moondesk</string>
    #|  <key>CFBundleIdentifier</key>
    #|  <string>app.vectie.moondesk</string>
    #|  <key>CFBundleVersion</key>
    #|  <string>0.1.0</string>
    #|  <key>CFBundleShortVersionString</key>
    #|  <string>0.1.0</string>
    #|  <key>CFBundleExecutable</key>
    #|  <string>moondesk</string>
    #|  <key>CFBundlePackageType</key>
    #|  <string>APPL</string>
    #|</dict>
    #|</plist>
  )
}

///|
fn run_doctor(args : Array[String]) -> Unit {
  let root = match args {
    [root] => root
    _ => ".."
  }
  let config = @host.default_config(root)
  println("Moondesk doctor")
  println("configured root: \{config.roots[0].path}")
  println("ui package: ui/rabbita-desk")
  println("host mode: scoped local reads and inbox writes only")
}

///|
fn print_usage() -> Unit {
  println(
    (
      #|Moondesk
      #|
      #|Usage:
      #|  moon run cmd/main -- doctor [root]
      #|  moon run cmd/main -- serve [root] [--ui ui/rabbita-desk/dist] [--host 127.0.0.1] [--port 4188]
      #|  moon run cmd/main -- desktop [root] [--ui ui/rabbita-desk/dist] [--host 127.0.0.1] [--port 4188]
      #|  moon run cmd/main -- bundle [root] [--ui ui/rabbita-desk/dist] [--out dist] [--host 127.0.0.1] [--port 4199]
      #|
      #|Build the UI first with:
      #|  npm --prefix ui/rabbita-desk run build
    ),
  )
}

///|
async fn main {
  let args = @env.args()
  match args[1:] {
    ["serve", .. rest] => run_serve(rest.to_array())
    ["desktop", .. rest] => run_serve(rest.to_array())
    ["bundle", .. rest] => run_bundle(rest.to_array())
    ["doctor", .. rest] => run_doctor(rest.to_array())
    _ => print_usage()
  }
}
