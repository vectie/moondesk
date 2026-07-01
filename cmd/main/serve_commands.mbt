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
  let requested_workspace_root = options.workspace_root
  let workspace_root = serve_workspace_root(requested_workspace_root)
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
  println("Moondesk \{label} \{options.ui_dir}")
  println("Workspace root: \{workspace_root}")
  let warning = workspace_root_source_checkout_warning(
    requested_workspace_root,
    effective_root=workspace_root,
  )
  if warning != "" {
    @stdio.stderr.write(warning + "\n")
  }
  let url = "http://\{options.host}:\{server.port()}/"
  println("Open \{url}")
  if options.open_browser {
    open_browser_url(url)
  }
  print_moonstat_startup_status()
  server.serve_desk(options.ui_dir, workspace_root)
}

///|
async fn serve_workspace_root(workspace_root : String) -> String {
  resolve_user_workspace_root(workspace_root, current_workspace_directory())
}

///|
async fn resolve_user_workspace_root(
  workspace_root : String,
  repo_root : String,
) -> String {
  let root = absolute_path(workspace_root, repo_root)
  if workspace_root_is_source_checkout(root) {
    source_checkout_safe_workspace_root(
      root,
      configured_root=default_workspace_root(),
      home=@sys.get_env_var("HOME").unwrap_or(""),
      user_profile=@sys.get_env_var("USERPROFILE").unwrap_or(""),
      cwd=repo_root,
    )
  } else {
    root
  }
}

///|
fn current_workspace_directory() -> String {
  @pathx.normalize(@env.current_dir().unwrap_or("."))
}

///|
async fn source_checkout_safe_workspace_root(
  source_root : String,
  configured_root~ : String,
  home~ : String,
  user_profile~ : String,
  cwd~ : String,
) -> String {
  let root = absolute_path(source_root, cwd)
  match
    safe_source_checkout_workspace_root_candidate(root, configured_root, cwd~) {
    Some(candidate) => return candidate
    None => ()
  }
  let home_root = default_workspace_root_from_env("", home, user_profile)
  match safe_source_checkout_workspace_root_candidate(root, home_root, cwd~) {
    Some(candidate) => return candidate
    None => ()
  }
  @pathx.join(@pathx.dirname(root).to_owned(), "moondesk-workspace")
}

///|
async fn safe_source_checkout_workspace_root_candidate(
  source_root : String,
  candidate_root : String,
  cwd~ : String,
) -> String? {
  let trimmed = candidate_root.trim().to_owned()
  if trimmed == "" {
    return None
  }
  let candidate = absolute_path(trimmed, cwd)
  if workspace_root_contains_path(source_root, candidate) ||
    workspace_root_is_source_checkout(candidate) {
    None
  } else {
    Some(candidate)
  }
}

///|
fn workspace_root_contains_path(root : String, candidate : String) -> Bool {
  let root = @pathx.normalize(root)
  let candidate = @pathx.normalize(candidate)
  candidate == root || candidate.has_prefix(root + "/")
}

///|
async fn workspace_root_is_source_checkout(workspace_root : String) -> Bool {
  let root = @pathx.normalize(workspace_root)
  @fs.exists(@pathx.join(root, "moon.mod")) ||
  @fs.exists(@pathx.join(root, "moon.mod.json"))
}

///|
async fn workspace_root_source_checkout_warning(
  workspace_root : String,
  effective_root~ : String,
) -> String {
  let root = absolute_path(workspace_root, current_workspace_directory())
  if workspace_root_is_source_checkout(root) {
    "Warning: requested workspace root looks like a MoonBit source checkout. Using dedicated user workspace root instead: \{effective_root}. Set MOONDESK_WORKSPACE_ROOT or --root to a dedicated moondesk-workspace directory outside source checkouts for user MoonBooks."
  } else {
    ""
  }
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
