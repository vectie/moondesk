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
  let host_binary = @pathx.join(macos, "moondesk-host")
  let binary = @pathx.join(
    repo_root, "_build/native/debug/build/cmd/main/main.exe",
  )
  let binary_data = @fs.read_file(binary) catch {
    error => {
      println("bundle failed: could not read native executable: \{error}")
      return
    }
  }
  let native_window = bundle_uses_native_window(options)
  let runtime_binary = if native_window { host_binary } else { launcher }
  @fs.write_file(runtime_binary, binary_data, create=0o755, truncate=true) catch {
    error => {
      println("bundle failed: could not copy native executable: \{error}")
      return
    }
  }
  @fs.chmod(runtime_binary, 0o755) catch {
    _ => ()
  }
  if native_window {
    let launcher_source_path = @pathx.join(out_dir, "MoondeskLauncher.m")
    @fsx.write_to_file(
      launcher_source_path,
      native_launcher_source(),
      create=0o644,
    ) catch {
      error => {
        println(
          "bundle failed: could not write native launcher source: \{error}",
        )
        return
      }
    }
    let compile_code = @process.run("clang", [
      "-fobjc-arc", "-framework", "Cocoa", "-framework", "WebKit", launcher_source_path,
      "-o", launcher,
    ]) catch {
      error => {
        println("bundle failed: could not compile native launcher: \{error}")
        return
      }
    }
    if compile_code != 0 {
      println(
        "bundle failed: native launcher compile exited with \{compile_code}",
      )
      return
    }
    @fs.remove(launcher_source_path) catch {
      _ => ()
    }
    @fs.chmod(launcher, 0o755) catch {
      _ => ()
    }
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
    info_plist(options.version, native_window),
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
    "Moondesk.app contains a native MoonBit host executable, bundled Rabbita UI resources, and the \{options.shell_policy} desktop shell. It serves \{options.workspace_root} on \{options.host}:\{options.port}.\n",
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
