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
  run_lepusa_integration(args)
  if @fsx.exists(generated_app_root) {
    @fs.rename(generated_app_root, app_root, replace=true) catch {
      error => {
        println("bundle failed: could not name app MoonDesk.app: \{error}")
        return
      }
    }
  }
  if !@fsx.exists(app_root) {
    println("bundle failed: Lepusa app bundle was not created at \{app_root}")
    return
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
    let archive_path = bundle_archive_path(options)
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
