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
  "MoonGate available at \{base_url}; usage/statistics panels enabled"
}

///|
fn moonstat_startup_unavailable_message(
  base_url : String,
  error : String,
) -> String {
  "MoonGate unavailable at \{base_url}; continuing as standalone MoonDesk: \{error}"
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
  let resolution = serve_workspace_root_resolution(options.workspace_root)
  let workspace_root = resolution.workspace_root
  if resolution.redirected {
    println(workspace_root_guard_message(resolution))
  }
  if !prepare_moondesk_workspace_root(workspace_root) {
    println("failed to prepare workspace root: \{workspace_root}")
    return
  }
  let server = @moonwiki.Server::new(options.host, options.port) catch {
    error => {
      println("failed to bind \{options.host}:\{options.port}: \{error}")
      return
    }
  }
  println("MoonDesk \{label} \{options.ui_dir}")
  println("Workspace root: \{workspace_root}")
  let url = "http://\{options.host}:\{server.port()}/"
  println("Open \{url}")
  if options.open_browser {
    open_browser_url(url)
  }
  print_moonstat_startup_status()
  server.serve_desk(options.ui_dir, workspace_root)
}

///|
async fn serve_workspace_root_resolution(
  workspace_root : String,
) -> WorkspaceRootResolution {
  resolve_user_workspace_root_resolution(
    workspace_root,
    current_workspace_directory(),
  )
}

///|
struct WorkspaceRootResolution {
  requested_root : String
  workspace_root : String
  redirected : Bool
}

///|
async fn resolve_user_workspace_root(
  workspace_root : String,
  repo_root : String,
) -> String {
  resolve_user_workspace_root_resolution(workspace_root, repo_root).workspace_root
}

///|
async fn resolve_user_workspace_root_resolution(
  workspace_root : String,
  repo_root : String,
) -> WorkspaceRootResolution {
  resolve_user_workspace_root_with_default(
    workspace_root,
    repo_root,
    default_workspace_root(),
    @sys.get_env_var("HOME").unwrap_or(""),
  )
}

///|
async fn resolve_user_workspace_root_with_default(
  workspace_root : String,
  repo_root : String,
  fallback_root : String,
  home_root : String,
) -> WorkspaceRootResolution {
  let requested_root = absolute_path(workspace_root, repo_root)
  if workspace_root_looks_like_source_checkout(requested_root) {
    let workspace_root = source_checkout_fallback_workspace_root(
      fallback_root, repo_root, home_root,
    )
    return { requested_root, workspace_root, redirected: true }
  }
  { requested_root, workspace_root: requested_root, redirected: false }
}

///|
async fn workspace_root_looks_like_source_checkout(root : String) -> Bool {
  @fs.exists(@pathx.join(root, "moon.mod")) ||
  @fs.exists(@pathx.join(root, "moon.mod.json")) ||
  @fs.exists(@pathx.join(root, ".git"))
}

///|
async fn source_checkout_fallback_workspace_root(
  fallback_root : String,
  repo_root : String,
  home_root : String,
) -> String {
  let fallback_root = if fallback_root.trim() == "" {
    default_moonsuite_workspace_root_from_home(home_root)
  } else {
    fallback_root
  }
  let fallback_root = absolute_path(fallback_root, repo_root)
  if workspace_root_looks_like_source_checkout(fallback_root) {
    return absolute_path(
      default_moonsuite_workspace_root_from_home(home_root),
      repo_root,
    )
  }
  fallback_root
}

///|
fn workspace_root_guard_message(resolution : WorkspaceRootResolution) -> String {
  "MoonDesk workspace guard: requested root \{resolution.requested_root} " +
  "looks like a source checkout; using \{resolution.workspace_root} from " +
  "MOONDESK_WORKSPACE_ROOT or ~/moonsuite."
}

///|
fn current_workspace_directory() -> String {
  @pathx.normalize(@env.current_dir().unwrap_or("."))
}

///|
async fn prepare_moondesk_workspace_root(workspace_root : String) -> Bool {
  @moonwiki.prepare_moonsuite_workspace_root(workspace_root)
}

///|
async fn open_browser_url(url : String) -> Unit {
  let mac = @process.run("open", [url]) catch { _ => -1 }
  if mac == 0 {
    return
  }
  ignore(@process.run("xdg-open", [url]) catch { _ => -1 })
}
