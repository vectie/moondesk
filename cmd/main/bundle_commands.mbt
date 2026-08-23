///|
async fn run_bundle(args : Array[String]) -> Bool {
  let options = match parse_bundle_args(args) {
    Some(options) => options
    None => {
      print_usage()
      return false
    }
  }
  let repo_root = @pathx.normalize(@env.current_dir().unwrap_or("."))
  let options = {
    ..options,
    workspace_root: resolve_user_workspace_root(
      options.workspace_root,
      repo_root,
    ),
    ui_dir: absolute_path(options.ui_dir, repo_root),
    out_dir: absolute_path(options.out_dir, repo_root),
    lepusa_root: absolute_path(options.lepusa_root, repo_root),
  }
  let app_root = bundle_app_root(options)
  let generated_app_root = bundle_generated_app_root(options)
  @fs.rmdir(app_root, recursive=true) catch {
    _ => ()
  }
  @fs.rmdir(generated_app_root, recursive=true) catch {
    _ => ()
  }
  let args = bundle_lepusa_args(options)
  if !run_lepusa_integration(args) {
    println("bundle failed: native app integration did not complete")
    return false
  }
  if @fsx.exists(generated_app_root) {
    @fs.rename(generated_app_root, app_root, replace=true) catch {
      error => {
        println("bundle failed: could not name app MoonDesk.app: \{error}")
        return false
      }
    }
  }
  if !@fsx.exists(app_root) {
    println("bundle failed: Lepusa app bundle was not created at \{app_root}")
    return false
  }
  if !options.skip_sign {
    let identity = match @trusted_host.signing_identity(options.sign_identity) {
      Ok(identity) => identity
      Err(message) => {
        println("bundle failed: \{message}")
        return false
      }
    }
    let sign_code = @trusted_host.sign_app(identity, app_root)
    if sign_code != 0 {
      println("bundle failed: codesign exited with \{sign_code}")
      return false
    }
  }
  if options.archive {
    let archive_path = bundle_archive_path(options)
    if @fsx.exists(archive_path) {
      @fs.remove(archive_path) catch {
        error => {
          println("bundle failed: could not replace archive: \{error}")
          return false
        }
      }
    }
    let archive_code = @trusted_host.archive_app(app_root, archive_path)
    if archive_code != 0 {
      println("bundle failed: archive creation exited with \{archive_code}")
      return false
    }
    if !@fsx.exists(archive_path) {
      println("bundle failed: archive was not created at \{archive_path}")
      return false
    }
  }
  println("Created \{app_root}")
  true
}

///|
fn bundle_lepusa_args(options : BundleOptions) -> Array[String] {
  [
    "live-build",
    "macos",
    "--strict",
    "--out",
    options.out_dir,
    "--serve-port",
    options.port.to_string(),
    "--workspace-root",
    options.workspace_root,
    "--ui",
    options.ui_dir,
    "--lepusa",
    options.lepusa_root,
  ]
}
