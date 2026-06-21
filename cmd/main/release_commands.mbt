///|
async fn run_release(args : Array[String]) -> Unit {
  let bundle_args : Array[String] = []
  let mut notary_profile = ""
  let mut staple = true
  let mut create_dmg = true
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
      "--no-dmg" => {
        create_dmg = false
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
  let parsed = {
    ..parsed,
    workspace_root: absolute_path(parsed.workspace_root, repo_root),
    ui_dir: absolute_path(parsed.ui_dir, repo_root),
    out_dir,
    lepusa_root: absolute_path(parsed.lepusa_root, repo_root),
  }
  let app_root = bundle_app_root(parsed)
  let archive_path = bundle_archive_path(parsed)
  let runtime_manifest_path = bundle_runtime_manifest_path(parsed)
  let dmg_path = @pathx.join(out_dir, "Moondesk-\{parsed.version}.dmg")
  let update_manifest_path = @pathx.join(out_dir, "updates.json")
  if !@fsx.exists(app_root) {
    println("release failed: app bundle was not created")
    return
  }
  let signed = verify_codesign(app_root)
  let dmg_created = if create_dmg {
    create_release_dmg(app_root, dmg_path)
  } else {
    false
  }
  let mut notarized = false
  if notary_profile != "" && @fsx.exists(archive_path) {
    let notary_code = @process.run("xcrun", [
      "notarytool", "submit", archive_path, "--keychain-profile", notary_profile,
      "--wait",
    ]) catch {
      _ => -1
    }
    if notary_code != 0 {
      println("release warning: notarytool exited with \{notary_code}")
    } else {
      notarized = true
      if staple {
        let staple_code = @process.run("xcrun", ["stapler", "staple", app_root]) catch {
          _ => -1
        }
        if staple_code != 0 {
          println("release warning: stapler exited with \{staple_code}")
          notarized = false
        }
      }
    }
  } else if notary_profile == "" {
    println(
      "release ready: add --notary-profile <profile> to submit the archive with xcrun notarytool",
    )
  } else {
    println(
      "release warning: archive not found at \{archive_path}; notarization skipped",
    )
  }
  let manifest = release_manifest_json(
    parsed,
    app_root,
    archive_path,
    runtime_manifest_path,
    dmg_path,
    update_manifest_path,
    notary_profile,
    signed~,
    dmg_created~,
    notarized~,
  )
  @fsx.write_to_file(
    @pathx.join(out_dir, "release-manifest.json"),
    manifest.stringify(indent=2) + "\n",
    create=0o644,
  ) catch {
    error => println("release warning: could not write manifest: \{error}")
  }
  @fsx.write_to_file(
    update_manifest_path,
    update_manifest_json(
      parsed,
      archive_path,
      runtime_manifest_path,
      dmg_path,
      dmg_created~,
      notarized~,
    ).stringify(indent=2) +
    "\n",
    create=0o644,
  ) catch {
    error =>
      println("release warning: could not write update manifest: \{error}")
  }
  println(
    "release complete: \{app_root} (\{bundle_shell_policy()}, signed=\{signed}, notarized=\{notarized}, dmg=\{dmg_created})",
  )
}

///|
async fn release_manifest_json(
  options : BundleOptions,
  app_root : String,
  archive_path : String,
  runtime_manifest_path : String,
  dmg_path : String,
  update_manifest_path : String,
  notary_profile : String,
  signed~ : Bool,
  dmg_created~ : Bool,
  notarized~ : Bool,
) -> Json {
  {
    "app": app_root,
    "app_name": bundle_path_leaf(app_root),
    "archive": archive_path,
    "archive_sha256": file_sha256(archive_path),
    "runtime_manifest": runtime_manifest_path,
    "runtime_manifest_sha256": file_sha256(runtime_manifest_path),
    "dmg": dmg_path,
    "dmg_created": dmg_created,
    "dmg_sha256": file_sha256(dmg_path),
    "update_manifest": update_manifest_path,
    "workspace_root": options.workspace_root,
    "ui_dir": options.ui_dir,
    "lepusa_root": options.lepusa_root,
    "host": options.host,
    "port": options.port,
    "version": options.version,
    "channel": options.channel,
    "distribution_mode": "self-contained-local-app",
    "shell_policy": bundle_shell_policy(),
    "native_host": bundle_native_host_name(),
    "native_window": bundle_has_native_window(),
    "sign_identity": options.sign_identity,
    "signed": signed,
    "notary_profile": notary_profile,
    "notarized": notarized,
    "installer": if dmg_created {
      "dmg"
    } else {
      "zip"
    },
  }
}

///|
async fn update_manifest_json(
  options : BundleOptions,
  archive_path : String,
  runtime_manifest_path : String,
  dmg_path : String,
  dmg_created~ : Bool,
  notarized~ : Bool,
) -> Json {
  let artifacts : Array[Json] = []
  artifacts.push({
    "kind": "zip",
    "path": archive_path,
    "sha256": file_sha256(archive_path),
  })
  artifacts.push({
    "kind": "runtime-manifest",
    "path": runtime_manifest_path,
    "sha256": file_sha256(runtime_manifest_path),
  })
  if dmg_created {
    artifacts.push({
      "kind": "dmg",
      "path": dmg_path,
      "sha256": file_sha256(dmg_path),
    })
  }
  {
    "name": "Moondesk",
    "version": options.version,
    "channel": options.channel,
    "shell_policy": bundle_shell_policy(),
    "native_host": bundle_native_host_name(),
    "native_window": bundle_has_native_window(),
    "notarized": notarized,
    "artifacts": Json::array(artifacts),
    "install": {
      "macos": "Open the DMG or unzip the app bundle, then drag it to Applications.",
      "daemon": "Use the in-app daemon panel to install or remove the Moontown LaunchAgent.",
    },
  }
}

///|
async fn verify_codesign(app_root : String) -> Bool {
  (@process.run("codesign", ["--verify", "--deep", "--strict", app_root]) catch {
    _ => -1
  }) ==
  0
}

///|
async fn create_release_dmg(app_root : String, dmg_path : String) -> Bool {
  @fs.remove(dmg_path) catch {
    _ => ()
  }
  let code = @process.run("hdiutil", [
    "create", "-volname", "Moondesk", "-srcfolder", app_root, "-ov", "-format", "UDZO",
    dmg_path,
  ]) catch {
    _ => -1
  }
  if code != 0 {
    println("release warning: hdiutil exited with \{code}")
  }
  code == 0
}

///|
async fn file_sha256(path : String) -> String {
  if !@fsx.exists(path) {
    return ""
  }
  let output = @process.collect_output("shasum", ["-a", "256", path]) catch {
    _ => return ""
  }
  if output.0 != 0 {
    return ""
  }
  let text = (output.1.text() catch { _ => "" }).trim().to_owned()
  match text.find(" ") {
    Some(index) => text[:index].to_owned()
    None => text
  }
}
