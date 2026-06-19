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
fn moonstat_startup_ready_message(base_url : String) -> String {
  "Moonstat available at \{base_url}; usage/statistics panels enabled"
}

///|
fn moonstat_startup_unavailable_message(
  base_url : String,
  error : String,
) -> String {
  "Moonstat unavailable at \{base_url}; continuing as standalone Moondesk: \{error}"
}

///|
async fn print_moonstat_startup_status() -> Unit {
  let client = @moonstat.discover()
  match client.health() {
    Ok(_) => println(moonstat_startup_ready_message(client.base_url()))
    Err(error) =>
      println(moonstat_startup_unavailable_message(client.base_url(), error))
  }
}

///|
async fn serve_with_options(options : ServeOptions, label~ : String) -> Unit {
  let server = @moonwiki.Server::new(options.host, options.port) catch {
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
  print_moonstat_startup_status()
  server.serve_desk(options.ui_dir, options.workspace_root)
}

///|
async fn open_browser_url(url : String) -> Unit {
  let mac = @process.run("open", [url]) catch { _ => -1 }
  if mac == 0 {
    return
  }
  ignore(@process.run("xdg-open", [url]) catch { _ => -1 })
}
