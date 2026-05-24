///|
struct ServeOptions {
  workspace_root : String
  ui_dir : String
  host : String
  port : Int
} derive(Show)

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
          let port = @strconv.parse_int(args[index + 1]) catch {
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
    ["doctor", .. rest] => run_doctor(rest.to_array())
    _ => print_usage()
  }
}
