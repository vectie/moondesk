///|
async fn run_release(args : Array[String]) -> Bool {
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
          return false
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
      return false
    }
  }
  let repo_root = @pathx.normalize(@env.current_dir().unwrap_or("."))
  let out_dir = absolute_path(parsed.out_dir, repo_root)
  if @fsx.exists(out_dir) {
    let entries = @fsx.list_directory(out_dir) catch {
      error => {
        println("release failed: could not inspect output directory: \{error}")
        return false
      }
    }
    if !entries.is_empty() {
      println(
        "release failed: output directory is not empty; refusing overwrite: \{out_dir}",
      )
      return false
    }
  }
  if !run_bundle(bundle_args) {
    println("release failed: bundle prerequisite did not complete")
    return false
  }
  let parsed = {
    ..parsed,
    workspace_root: resolve_user_workspace_root(
      parsed.workspace_root,
      repo_root,
    ),
    ui_dir: absolute_path(parsed.ui_dir, repo_root),
    out_dir,
    lepusa_root: absolute_path(parsed.lepusa_root, repo_root),
  }
  let app_root = bundle_app_root(parsed)
  let archive_path = bundle_archive_path(parsed)
  let runtime_manifest_path = bundle_runtime_manifest_path(parsed)
  let dmg_path = @pathx.join(out_dir, release_dmg_file_name(parsed.version))
  let update_manifest_path = @pathx.join(out_dir, "updates.json")
  if !@fsx.exists(app_root) {
    println("release failed: app bundle was not created")
    return false
  }
  let signed = verify_codesign(app_root)
  let dmg_created = if create_dmg {
    create_release_dmg(app_root, dmg_path)
  } else {
    false
  }
  if create_dmg && !dmg_created {
    println("release failed: requested DMG was not created")
    return false
  }
  let mut notarized = false
  if notary_profile != "" {
    if !signed {
      println("release failed: notarization requires a valid signed app")
      return false
    }
    let notary_code = @process.run("xcrun", [
      "notarytool", "submit", archive_path, "--keychain-profile", notary_profile,
      "--wait",
    ]) catch {
      _ => -1
    }
    if notary_code != 0 {
      println("release failed: notarytool exited with \{notary_code}")
      return false
    } else {
      notarized = true
      if staple {
        let staple_code = @process.run("xcrun", ["stapler", "staple", app_root]) catch {
          _ => -1
        }
        if staple_code != 0 {
          println("release failed: stapler exited with \{staple_code}")
          return false
        }
      }
    }
  } else if notary_profile == "" {
    println(
      "release ready: add --notary-profile <profile> to submit the archive with xcrun notarytool",
    )
  }
  let archive_sha256 = file_sha256(archive_path)
  let runtime_manifest_sha256 = file_sha256(runtime_manifest_path)
  let dmg_sha256 = if dmg_created { file_sha256(dmg_path) } else { "" }
  let problems = release_artifact_problems(
    app_exists=@fsx.exists(app_root),
    archive_exists=@fsx.exists(archive_path),
    archive_sha256~,
    runtime_manifest_exists=@fsx.exists(runtime_manifest_path),
    runtime_manifest_sha256~,
    dmg_requested=create_dmg,
    dmg_created~,
    dmg_sha256~,
    signing_required=!parsed.skip_sign,
    signed~,
    notarization_requested=notary_profile != "",
    notarized~,
  )
  if !problems.is_empty() {
    for problem in problems {
      println("release failed: \{problem}")
    }
    return false
  }
  let manifest = release_manifest_json(
    parsed,
    app_root,
    archive_path,
    dmg_path,
    update_manifest_path,
    archive_sha256,
    runtime_manifest_sha256,
    dmg_sha256,
    notary_profile_supplied=notary_profile != "",
    signed~,
    dmg_created~,
    notarized~,
  )
  let release_manifest_path = @pathx.join(out_dir, "release-manifest.json")
  if !write_release_json(release_manifest_path, manifest) {
    return false
  }
  if !write_release_json(
      update_manifest_path,
      update_manifest_json(
        parsed,
        archive_path,
        dmg_path,
        archive_sha256,
        runtime_manifest_sha256,
        dmg_sha256,
        dmg_created~,
        notarized~,
      ),
    ) {
    return false
  }
  if !@fsx.exists(release_manifest_path) || !@fsx.exists(update_manifest_path) {
    println("release failed: public release metadata was not created")
    return false
  }
  println(
    "release complete: \{app_root} (\{bundle_shell_policy()}, signed=\{signed}, notarized=\{notarized}, dmg=\{dmg_created})",
  )
  true
}

///|
fn release_dmg_file_name(version : String) -> String {
  "moondesk-\{version}-macos-arm64.dmg"
}

///|
fn release_manifest_json(
  options : BundleOptions,
  app_root : String,
  archive_path : String,
  dmg_path : String,
  update_manifest_path : String,
  archive_sha256 : String,
  runtime_manifest_sha256 : String,
  dmg_sha256 : String,
  notary_profile_supplied~ : Bool,
  signed~ : Bool,
  dmg_created~ : Bool,
  notarized~ : Bool,
) -> Json {
  let app = bundle_path_leaf(app_root)
  {
    "kind": "moondesk-release-manifest.v1",
    "app": app,
    "app_name": app,
    "archive": bundle_path_leaf(archive_path),
    "archive_sha256": archive_sha256,
    "runtime_manifest": release_runtime_manifest_relative_path(app),
    "runtime_manifest_sha256": runtime_manifest_sha256,
    "dmg": if dmg_created {
      bundle_path_leaf(dmg_path)
    } else {
      ""
    },
    "dmg_created": dmg_created,
    "dmg_sha256": if dmg_created {
      dmg_sha256
    } else {
      ""
    },
    "update_manifest": bundle_path_leaf(update_manifest_path),
    "release_notes": "RELEASE_NOTES.md",
    "serve_host": options.host,
    "version": options.version,
    "channel": options.channel,
    "distribution_mode": "self-contained-local-app",
    "shell_policy": bundle_shell_policy(),
    "native_host": bundle_native_host_name(),
    "native_window": bundle_has_native_window(),
    "signed": signed,
    "notary_profile_supplied": notary_profile_supplied,
    "notarized": notarized,
    "installer": if dmg_created {
      "dmg"
    } else {
      "zip"
    },
  }
}

///|
fn update_manifest_json(
  options : BundleOptions,
  archive_path : String,
  dmg_path : String,
  archive_sha256 : String,
  runtime_manifest_sha256 : String,
  dmg_sha256 : String,
  dmg_created~ : Bool,
  notarized~ : Bool,
) -> Json {
  let app = bundle_path_leaf(bundle_app_root(options))
  let artifacts : Array[Json] = []
  artifacts.push({
    "kind": "zip",
    "path": bundle_path_leaf(archive_path),
    "sha256": archive_sha256,
  })
  artifacts.push({
    "kind": "runtime-manifest",
    "path": release_runtime_manifest_relative_path(app),
    "sha256": runtime_manifest_sha256,
  })
  if dmg_created {
    artifacts.push({
      "kind": "dmg",
      "path": bundle_path_leaf(dmg_path),
      "sha256": dmg_sha256,
    })
  }
  {
    "kind": "moondesk-update-manifest.v1",
    "name": "MoonDesk",
    "version": options.version,
    "channel": options.channel,
    "shell_policy": bundle_shell_policy(),
    "native_host": bundle_native_host_name(),
    "native_window": bundle_has_native_window(),
    "notarized": notarized,
    "release_notes": "RELEASE_NOTES.md",
    "artifacts": Json::array(artifacts),
    "install": {
      "macos": "Open the DMG or unzip the app bundle, then drag it to Applications.",
      "daemon": "Use the in-app daemon panel to install or remove the MoonTown LaunchAgent.",
    },
  }
}

///|
fn release_runtime_manifest_relative_path(app : String) -> String {
  app + "/Contents/Resources/lepusa/runtime.json"
}

///|
fn release_sha256_present(value : String) -> Bool {
  if value.length() != 64 {
    return false
  }
  for char in value {
    if !((char >= '0' && char <= '9') || (char >= 'a' && char <= 'f')) {
      return false
    }
  }
  true
}

///|
fn release_artifact_problems(
  app_exists~ : Bool,
  archive_exists~ : Bool,
  archive_sha256~ : String,
  runtime_manifest_exists~ : Bool,
  runtime_manifest_sha256~ : String,
  dmg_requested~ : Bool,
  dmg_created~ : Bool,
  dmg_sha256~ : String,
  signing_required~ : Bool,
  signed~ : Bool,
  notarization_requested~ : Bool,
  notarized~ : Bool,
) -> Array[String] {
  let problems : Array[String] = []
  if !app_exists {
    problems.push("app bundle is missing")
  }
  if !archive_exists {
    problems.push("zip archive is missing")
  } else if !release_sha256_present(archive_sha256) {
    problems.push("zip archive SHA-256 is missing or invalid")
  }
  if !runtime_manifest_exists {
    problems.push("runtime manifest is missing")
  } else if !release_sha256_present(runtime_manifest_sha256) {
    problems.push("runtime manifest SHA-256 is missing or invalid")
  }
  if dmg_requested && !dmg_created {
    problems.push("requested DMG is missing")
  } else if dmg_created && !release_sha256_present(dmg_sha256) {
    problems.push("DMG SHA-256 is missing or invalid")
  }
  if signing_required && !signed {
    problems.push("required code signature is invalid")
  }
  if notarization_requested && !notarized {
    problems.push("requested notarization did not complete")
  }
  problems
}

///|
async fn write_release_json(path : String, value : Json) -> Bool {
  @fsx.write_to_file(path, value.stringify(indent=2) + "\n", create=0o644) catch {
    error => {
      println("release failed: could not write \{path}: \{error}")
      return false
    }
  }
  true
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
  let staging = release_dmg_staging_dir(dmg_path)
  @fs.rmdir(staging, recursive=true) catch {
    _ => ()
  }
  @fsx.make_directory(staging, recursive=true, exists_ok=true) catch {
    error => {
      println("release warning: could not create DMG staging: \{error}")
      return false
    }
  }
  let staged_app = @pathx.join(staging, bundle_path_leaf(app_root))
  let copy_code = @process.run("ditto", [app_root, staged_app]) catch {
    _ => -1
  }
  if copy_code != 0 {
    println("release warning: ditto exited with \{copy_code}")
    @fs.rmdir(staging, recursive=true) catch {
      _ => ()
    }
    return false
  }
  @fs.symlink(
    target="/Applications",
    @pathx.join(staging, "Applications"),
    force_symlink=true,
  ) catch {
    error => {
      println("release warning: could not add Applications shortcut: \{error}")
      @fs.rmdir(staging, recursive=true) catch {
        _ => ()
      }
      return false
    }
  }
  let code = @process.run("hdiutil", [
    "create", "-volname", "MoonDesk", "-srcfolder", staging, "-ov", "-format", "UDZO",
    dmg_path,
  ]) catch {
    _ => -1
  }
  @fs.rmdir(staging, recursive=true) catch {
    _ => ()
  }
  if code != 0 {
    println("release warning: hdiutil exited with \{code}")
  }
  code == 0
}

///|
fn release_dmg_staging_dir(dmg_path : String) -> String {
  dmg_path + ".staging"
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
