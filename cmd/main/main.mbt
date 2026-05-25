///|
struct ServeOptions {
  workspace_root : String
  ui_dir : String
  host : String
  port : Int
  open_browser : Bool
} derive(Show)

///|
priv struct BundleOptions {
  workspace_root : String
  ui_dir : String
  out_dir : String
  host : String
  port : Int
  sign_identity : String
  archive : Bool
  skip_sign : Bool
}

///|
fn default_serve_options() -> ServeOptions {
  {
    workspace_root: "..",
    ui_dir: "ui/rabbita-desk/dist",
    host: "127.0.0.1",
    port: 4188,
    open_browser: false,
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
    sign_identity: "-",
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
      "--sign-identity" =>
        if index + 1 < args.length() {
          options = { ..options, sign_identity: args[index + 1] }
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
  serve_with_options(options, label="serving")
}

///|
async fn run_desktop(args : Array[String]) -> Unit {
  let options = match parse_serve_args(args) {
    Some(options) => { ..options, open_browser: true }
    None => {
      print_usage()
      return
    }
  }
  serve_with_options(options, label="desktop")
}

///|
async fn serve_with_options(options : ServeOptions, label~ : String) -> Unit {
  let server = @httpserve.Server::new(options.host, options.port) catch {
    _ => {
      println("failed to bind \{options.host}:\{options.port}")
      return
    }
  }
  println("Moondesk \{label} \{options.ui_dir}")
  println("Workspace root: \{options.workspace_root}")
  let url = "http://\{options.host}:\{server.port()}/"
  println("Open \{url}")
  if options.open_browser {
    open_browser_url(url)
  }
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
  let repo_root = @pathx.normalize(@env.current_dir().unwrap_or("."))
  let options = {
    ..options,
    workspace_root: absolute_path(options.workspace_root, repo_root),
    ui_dir: absolute_path(options.ui_dir, repo_root),
    out_dir: absolute_path(options.out_dir, repo_root),
  }
  let out_dir = options.out_dir
  let app_root = @pathx.join(out_dir, "Moondesk.app")
  let contents = @pathx.join(app_root, "Contents")
  let macos = @pathx.join(contents, "MacOS")
  let resources = @pathx.join(contents, "Resources")
  let bundled_ui = @pathx.join(resources, "ui")
  @fs.rmdir(app_root, recursive=true) catch {
    _ => ()
  }
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
  @fsx.make_directory(bundled_ui, recursive=true, exists_ok=true) catch {
    error => {
      println("bundle failed: \{error}")
      return
    }
  }
  let build_code = @process.run(
    "moon",
    ["build", "--target", "native"],
    cwd=repo_root,
  ) catch {
    error => {
      println("bundle failed: could not build native executable: \{error}")
      return
    }
  }
  if build_code != 0 {
    println(
      "bundle failed: moon build --target native exited with \{build_code}",
    )
    return
  }
  let launcher = @pathx.join(macos, "moondesk")
  let binary = @pathx.join(
    repo_root, "_build/native/debug/build/cmd/main/main.exe",
  )
  let binary_data = @fs.read_file(binary) catch {
    error => {
      println("bundle failed: could not read native executable: \{error}")
      return
    }
  }
  @fs.write_file(launcher, binary_data, create=0o755, truncate=true) catch {
    error => {
      println("bundle failed: could not copy native executable: \{error}")
      return
    }
  }
  @fs.chmod(launcher, 0o755) catch {
    _ => ()
  }
  let copy_code = @process.run("cp", ["-R", options.ui_dir + "/.", bundled_ui]) catch {
    error => {
      println("bundle failed: could not copy UI resources: \{error}")
      return
    }
  }
  if copy_code != 0 {
    println("bundle failed: UI resource copy exited with \{copy_code}")
    return
  }
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
    @pathx.join(resources, "moondesk-config.json"),
    bundle_config_json(options).stringify(indent=2) + "\n",
    create=0o644,
  ) catch {
    error => {
      println("bundle failed: \{error}")
      return
    }
  }
  @fsx.write_to_file(
    @pathx.join(resources, "README.txt"),
    "Moondesk.app contains a native MoonBit host executable and bundled Rabbita UI resources. It serves \{options.workspace_root} on \{options.host}:\{options.port}.\n",
    create=0o644,
  ) catch {
    error => {
      println("bundle failed: \{error}")
      return
    }
  }
  if !options.skip_sign {
    let sign_code = @process.run("codesign", [
      "--force",
      "--deep",
      "--sign",
      options.sign_identity,
      app_root,
    ]) catch {
      _ => -1
    }
    if sign_code != 0 {
      println("bundle warning: codesign failed with \{sign_code}")
    }
  }
  if options.archive {
    let archive_path = @pathx.join(out_dir, "Moondesk.app.zip")
    @fs.remove(archive_path) catch {
      _ => ()
    }
    let archive_code = @process.run("ditto", [
      "-c", "-k", "--keepParent", app_root, archive_path,
    ]) catch {
      _ => -1
    }
    if archive_code != 0 {
      println("bundle warning: archive creation failed with \{archive_code}")
    }
  }
  println("Created \{app_root}")
}

///|
async fn run_release(args : Array[String]) -> Unit {
  let bundle_args : Array[String] = []
  let mut notary_profile = ""
  let mut staple = true
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "--notary-profile" =>
        if index + 1 < args.length() {
          notary_profile = args[index + 1]
          index += 2
        } else {
          print_usage()
          return
        }
      "--no-staple" => {
        staple = false
        index += 1
      }
      value => {
        bundle_args.push(value)
        index += 1
      }
    }
  }
  let parsed = match parse_bundle_args(bundle_args) {
    Some(options) => options
    None => {
      print_usage()
      return
    }
  }
  run_bundle(bundle_args)
  let repo_root = @pathx.normalize(@env.current_dir().unwrap_or("."))
  let out_dir = absolute_path(parsed.out_dir, repo_root)
  let app_root = @pathx.join(out_dir, "Moondesk.app")
  let archive_path = @pathx.join(out_dir, "Moondesk.app.zip")
  if !@fsx.exists(app_root) {
    println("release failed: app bundle was not created")
    return
  }
  @fsx.write_to_file(
    @pathx.join(out_dir, "release-manifest.json"),
    release_manifest_json(parsed, app_root, archive_path, notary_profile).stringify(
      indent=2,
    ) +
    "\n",
    create=0o644,
  ) catch {
    error => println("release warning: could not write manifest: \{error}")
  }
  if notary_profile == "" {
    println(
      "release ready: add --notary-profile <profile> to submit the archive with xcrun notarytool",
    )
    return
  }
  if !@fsx.exists(archive_path) {
    println(
      "release warning: archive not found at \{archive_path}; notarization skipped",
    )
    return
  }
  let notary_code = @process.run("xcrun", [
    "notarytool", "submit", archive_path, "--keychain-profile", notary_profile, "--wait",
  ]) catch {
    _ => -1
  }
  if notary_code != 0 {
    println("release warning: notarytool exited with \{notary_code}")
    return
  }
  if staple {
    let staple_code = @process.run("xcrun", ["stapler", "staple", app_root]) catch {
      _ => -1
    }
    if staple_code != 0 {
      println("release warning: stapler exited with \{staple_code}")
      return
    }
  }
  println("release notarized: \{app_root}")
}

///|
async fn run_launch_agent(args : Array[String]) -> Unit {
  let mut options = default_serve_options()
  let mut out_path = "dist/app.vectie.moondesk.plist"
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
  let absolute_root = absolute_path(options.workspace_root, repo_root)
  @fsx.make_directory(
    @pathx.dirname(absolute_out).to_string(),
    recursive=true,
    exists_ok=true,
  ) catch {
    error => {
      println("launch-agent failed: \{error}")
      return
    }
  }
  @fsx.write_to_file(
    absolute_out,
    launch_agent_plist(repo_root, absolute_root, options.port),
    create=0o644,
  ) catch {
    error => {
      println("launch-agent failed: \{error}")
      return
    }
  }
  println("Created launch agent template \{absolute_out}")
}

///|
fn release_manifest_json(
  options : BundleOptions,
  app_root : String,
  archive_path : String,
  notary_profile : String,
) -> Json {
  {
    "app": app_root,
    "archive": archive_path,
    "workspace_root": options.workspace_root,
    "ui_dir": options.ui_dir,
    "host": options.host,
    "port": options.port,
    "sign_identity": options.sign_identity,
    "notary_profile": notary_profile,
    "notarized": notary_profile != "",
  }
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
async fn open_browser_url(url : String) -> Unit {
  let mac = @process.run("open", [url]) catch { _ => -1 }
  if mac == 0 {
    return
  }
  ignore(@process.run("xdg-open", [url]) catch { _ => -1 })
}

///|
fn absolute_path(path : String, base : String) -> String {
  if @pathx.is_absolute(path) {
    @pathx.normalize(path)
  } else {
    @pathx.join(base, path)
  }
}

///|
fn bundle_config_json(options : BundleOptions) -> Json {
  {
    "workspace_root": options.workspace_root,
    "ui_dir": "../Resources/ui",
    "host": options.host,
    "port": options.port,
    "open_browser": true,
  }
}

///|
async fn run_app_bundle(args : Array[String]) -> Bool {
  match bundle_resources_dir(args) {
    Some(resources) => {
      let config_path = @pathx.join(resources, "moondesk-config.json")
      let config = Some(@json.parse(@fsx.read_file(config_path))) catch {
        _ => None
      }
      match config {
        Some(json) => {
          let options = {
            workspace_root: config_string(json, "workspace_root", default=".."),
            ui_dir: @pathx.join(resources, "ui"),
            host: config_string(json, "host", default="127.0.0.1"),
            port: config_int(json, "port", default=4199),
            open_browser: config_bool(json, "open_browser", default=true),
          }
          let server = @httpserve.Server::new(options.host, options.port) catch {
            _ => {
              println("failed to bind \{options.host}:\{options.port}")
              return true
            }
          }
          println("Moondesk app serving \{options.ui_dir}")
          println("Workspace root: \{options.workspace_root}")
          let url = "http://\{options.host}:\{server.port()}/"
          println("Open \{url}")
          if options.open_browser {
            open_browser_url(url)
          }
          server.serve_desk(options.ui_dir, options.workspace_root)
          true
        }
        None => false
      }
    }
    None => false
  }
}

///|
async fn bundle_resources_dir(args : Array[String]) -> String? {
  match args.get(0) {
    Some(exe) => {
      let macos = @pathx.dirname(@pathx.normalize(exe))
      let contents = @pathx.dirname(macos)
      let resources = @pathx.join(contents, "Resources")
      if @fsx.exists(@pathx.join(resources, "moondesk-config.json")) {
        Some(resources)
      } else {
        None
      }
    }
    None => None
  }
}

///|
fn config_string(json : Json, key : String, default~ : String) -> String {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(Json::String(value)) => value
        _ => default
      }
    _ => default
  }
}

///|
fn config_int(json : Json, key : String, default~ : Int) -> Int {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(value) => @json.from_json(value) catch { _ => default }
        None => default
      }
    _ => default
  }
}

///|
fn config_bool(json : Json, key : String, default~ : Bool) -> Bool {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(value) => @json.from_json(value) catch { _ => default }
        None => default
      }
    _ => default
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
      #|  moon run cmd/main -- serve [root] [--ui ui/rabbita-desk/dist] [--host 127.0.0.1] [--port 4188] [--open]
      #|  moon run cmd/main -- desktop [root] [--ui ui/rabbita-desk/dist] [--host 127.0.0.1] [--port 4188]
      #|  moon run cmd/main -- bundle [root] [--ui ui/rabbita-desk/dist] [--out dist] [--host 127.0.0.1] [--port 4199] [--sign-identity -] [--skip-sign] [--no-archive]
      #|  moon run cmd/main -- release [root] [bundle options] [--notary-profile keychain-profile] [--no-staple]
      #|  moon run cmd/main -- launch-agent [root] [--out dist/app.vectie.moondesk.plist] [--port 4188]
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
    ["desktop", .. rest] => run_desktop(rest.to_array())
    ["bundle", .. rest] => run_bundle(rest.to_array())
    ["release", .. rest] => run_release(rest.to_array())
    ["launch-agent", .. rest] => run_launch_agent(rest.to_array())
    ["doctor", .. rest] => run_doctor(rest.to_array())
    [] => if !run_app_bundle(args) { print_usage() }
    _ => print_usage()
  }
}
