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
          let server = @moonwiki.Server::new(options.host, options.port) catch {
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
    Object(object) =>
      match object.get(key) {
        Some(String(value)) => value
        _ => default
      }
    _ => default
  }
}

///|
fn config_int(json : Json, key : String, default~ : Int) -> Int {
  match json {
    Object(object) =>
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
    Object(object) =>
      match object.get(key) {
        Some(value) => @json.from_json(value) catch { _ => default }
        None => default
      }
    _ => default
  }
}
