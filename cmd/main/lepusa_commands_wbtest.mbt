///|
fn assert_string_array_eq(
  actual : Array[String],
  expected : Array[String],
) -> Unit raise {
  assert_eq(actual.length(), expected.length())
  for index = 0; index < expected.length(); index = index + 1 {
    assert_eq(actual[index], expected[index])
  }
}

///|
test "lepusa integration args default to strict-free macos verify" {
  let parsed = parse_lepusa_integration_args([])
  assert_true(parsed is Some(_))
  let options = parsed.unwrap()
  assert_eq(options.command, "verify")
  assert_eq(options.target, "macos")
  assert_eq(options.lepusa_root, ".mooncakes/vectie/lepusa")
  assert_eq(options.project, "desktop/lepusa/moondesk/lepusa.json")
  assert_eq(options.out_dir, "_build/lepusa/moondesk")
  assert_eq(options.manifest_path, "")
  assert_eq(options.asset_url, "lepusa://packaged/main/index.html")
  assert_eq(options.workspace_root, default_workspace_root())
  assert_eq(options.ui_dir, "")
  assert_eq(options.serve_port, 4398)
  assert_eq(options.strict, false)
  assert_string_array_eq(
    lepusa_integration_process_args(
      options, "/repo/desktop/lepusa/moondesk/lepusa.json", "/repo/_build/lepusa/moondesk",
      "/repo/_build/lepusa/moondesk/moondesk.app/Contents/Resources/lepusa/runtime.json",
    ),
    [
      "run", "cmd/main", "--target", "native", "--", "verify", "macos", "--project",
      "/repo/desktop/lepusa/moondesk/lepusa.json",
    ],
  )
}

///|
test "lepusa integration args accept strict verify with custom roots" {
  let parsed = parse_lepusa_integration_args([
    "verify", "linux", "--strict", "--lepusa", "/tmp/lepusa", "--project", "/tmp/app/lepusa.json",
  ])
  assert_true(parsed is Some(_))
  let options = parsed.unwrap()
  assert_eq(options.command, "verify")
  assert_eq(options.target, "linux")
  assert_eq(options.lepusa_root, "/tmp/lepusa")
  assert_eq(options.project, "/tmp/app/lepusa.json")
  assert_eq(options.strict, true)
  assert_string_array_eq(
    lepusa_integration_process_args(
      options, "/tmp/app/lepusa.json", "/tmp/moondesk-build", "/tmp/moondesk-build/moondesk/lepusa/runtime.json",
    ),
    [
      "run", "cmd/main", "--target", "native", "--", "verify", "linux", "--strict",
      "--project", "/tmp/app/lepusa.json",
    ],
  )
}

///|
test "lepusa integration launch maps to Lepusa run launch mode" {
  let parsed = parse_lepusa_integration_args(["launch", "macos"])
  assert_true(parsed is Some(_))
  assert_string_array_eq(
    lepusa_integration_process_args(
      parsed.unwrap(),
      "/tmp/moondesk/lepusa.json",
      "/tmp/moondesk-build",
      "/tmp/moondesk-build/moondesk.app/Contents/Resources/lepusa/runtime.json",
    ),
    [
      "run", "cmd/main", "--target", "native", "--", "run", "macos", "--launch",
      "--project", "/tmp/moondesk/lepusa.json",
    ],
  )
}

///|
test "lepusa integration doctor skips project arguments" {
  let parsed = parse_lepusa_integration_args(["doctor", "windows", "--strict"])
  assert_true(parsed is Some(_))
  assert_eq(parsed.unwrap().strict, true)
  assert_string_array_eq(
    lepusa_integration_process_args(
      parsed.unwrap(),
      "/ignored/lepusa.json",
      "/tmp/moondesk-build",
      "/tmp/moondesk-build/moondesk/lepusa/runtime.json",
    ),
    ["run", "cmd/main", "--target", "native", "--", "doctor", "windows"],
  )
}

///|
test "lepusa integration build writes the configured output directory" {
  let parsed = parse_lepusa_integration_args([
    "build", "macos", "--out", "/tmp/moondesk-build",
  ])
  assert_true(parsed is Some(_))
  let options = parsed.unwrap()
  assert_eq(options.command, "build")
  assert_eq(options.target, "macos")
  assert_eq(options.out_dir, "/tmp/moondesk-build")
  assert_string_array_eq(
    lepusa_integration_process_args(
      options, "/repo/desktop/lepusa/moondesk/lepusa.json", "/tmp/moondesk-build",
      "/tmp/moondesk-build/moondesk.app/Contents/Resources/lepusa/runtime.json",
    ),
    [
      "run", "cmd/main", "--target", "native", "--", "build", "macos", "/tmp/moondesk-build",
      "--project", "/repo/desktop/lepusa/moondesk/lepusa.json",
    ],
  )
}

///|
test "lepusa integration bundle commands build the runtime first" {
  assert_true(lepusa_integration_command_builds_runtime("build"))
  assert_true(lepusa_integration_command_builds_runtime("bundle-write"))
  assert_true(lepusa_integration_command_builds_runtime("smoke"))
  assert_true(lepusa_integration_command_builds_runtime("live-smoke"))
  assert_true(lepusa_integration_command_builds_runtime("live-build"))
  assert_true(lepusa_integration_command_builds_runtime("live-session"))
  assert_true(lepusa_integration_command_builds_runtime("live-launch"))
  assert_false(lepusa_integration_command_builds_runtime("bundle-check"))
  assert_false(lepusa_integration_command_builds_runtime("live-bundle-check"))
  assert_false(lepusa_integration_command_builds_runtime("verify"))
  assert_false(lepusa_integration_command_builds_runtime("runtime-launch"))
}

///|
test "lepusa integration live commands use generated localhost project" {
  assert_true(lepusa_integration_command_uses_live_project("live-smoke"))
  assert_true(lepusa_integration_command_uses_live_project("live-build"))
  assert_true(lepusa_integration_command_uses_live_project("live-session"))
  assert_true(lepusa_integration_command_uses_live_project("live-launch"))
  assert_true(lepusa_integration_command_uses_live_project("live-bundle-check"))
  assert_false(lepusa_integration_command_uses_live_project("smoke"))
  assert_false(lepusa_integration_command_uses_live_project("build"))
}

///|
test "lepusa integration bundle paths describe standalone app artifacts" {
  let macos = lepusa_integration_bundle_paths("macos", "/tmp/out")
  assert_eq(macos.app_root, "/tmp/out/moondesk.app")
  assert_eq(macos.launcher, "/tmp/out/moondesk.app/Contents/MacOS/moondesk")
  assert_eq(
    macos.runtime_executable,
    "/tmp/out/moondesk.app/Contents/MacOS/lepusa-runtime",
  )
  assert_eq(
    macos.manifest,
    "/tmp/out/moondesk.app/Contents/Resources/lepusa/runtime.json",
  )
  assert_eq(
    macos.entrypoint,
    "/tmp/out/moondesk.app/Contents/Resources/lepusa/assets/main/index.html",
  )
  let linux = lepusa_integration_bundle_paths("linux", "/tmp/out")
  assert_eq(linux.launcher, "/tmp/out/moondesk/moondesk")
  assert_eq(linux.runtime_executable, "/tmp/out/moondesk/lepusa-runtime")
  let windows = lepusa_integration_bundle_paths("windows", "/tmp/out")
  assert_eq(windows.launcher, "/tmp/out/moondesk/moondesk.cmd")
  assert_eq(windows.runtime_executable, "/tmp/out/moondesk/lepusa-runtime.exe")
}

///|
test "lepusa integration uses the runtime built for release" {
  assert_eq(
    lepusa_runtime_build_output("/tmp/lepusa"),
    "/tmp/lepusa/_build/native/release/build/cmd/runtime/runtime.exe",
  )
}

///|
test "lepusa integration launcher check requires bundled runtime preference" {
  assert_true(
    lepusa_integration_launcher_uses_bundled_runtime(
      "macos", "RUNTIME=\"$APP_DIR/MacOS/lepusa-runtime\"\ntrap cleanup INT TERM HUP\n\"$RUNTIME\" launch --manifest\nRUNTIME_PID=$!\nwait \"$RUNTIME_PID\"",
    ),
  )
  assert_false(
    lepusa_integration_launcher_uses_bundled_runtime(
      "macos", "exec lepusa-runtime launch --manifest",
    ),
  )
  assert_true(
    lepusa_integration_launcher_uses_bundled_runtime(
      "linux", "RUNTIME=\"$APP_DIR/lepusa-runtime\"\ntrap cleanup INT TERM HUP\n\"$RUNTIME\" launch --manifest\nRUNTIME_PID=$!\nwait \"$RUNTIME_PID\"",
    ),
  )
  assert_true(
    lepusa_integration_launcher_uses_bundled_runtime(
      "windows", "set \"RUNTIME=%APP_DIR%lepusa-runtime.exe\"\n\"%RUNTIME%\" launch --manifest",
    ),
  )
}

///|
test "lepusa integration smoke runs verify bundle and runtime checks" {
  let parsed = parse_lepusa_integration_args([
    "smoke", "macos", "--strict", "--out", "/tmp/moondesk-build", "--asset", "lepusa://packaged/main/app.css",
  ])
  assert_true(parsed is Some(_))
  let options = parsed.unwrap()
  assert_eq(options.command, "smoke")
  assert_eq(options.target, "macos")
  assert_eq(options.strict, true)
  assert_eq(options.asset_url, "lepusa://packaged/main/app.css")
  let steps = lepusa_integration_smoke_steps(
    options, "/repo/desktop/lepusa/moondesk/lepusa.json", "/tmp/moondesk-build",
    "/tmp/moondesk-build/moondesk.app/Contents/Resources/lepusa/runtime.json",
  )
  assert_eq(steps.length(), 4)
  assert_eq(steps[0].name, "verify")
  assert_string_array_eq(steps[0].args, [
    "run", "cmd/main", "--target", "native", "--", "verify", "macos", "--strict",
    "--project", "/repo/desktop/lepusa/moondesk/lepusa.json",
  ])
  assert_eq(steps[1].name, "bundle-write")
  assert_string_array_eq(steps[1].args, [
    "run", "cmd/main", "--target", "native", "--", "bundle-write", "macos", "/tmp/moondesk-build",
    "--project", "/repo/desktop/lepusa/moondesk/lepusa.json",
  ])
  assert_eq(steps[2].name, "runtime-session")
  assert_string_array_eq(steps[2].args, [
    "run", "cmd/runtime", "--target", "native", "--", "launch-session", "--manifest",
    "/tmp/moondesk-build/moondesk.app/Contents/Resources/lepusa/runtime.json",
  ])
  assert_eq(steps[3].name, "runtime-asset")
  assert_string_array_eq(steps[3].args, [
    "run", "cmd/runtime", "--target", "native", "--", "asset", "lepusa://packaged/main/app.css",
    "--manifest", "/tmp/moondesk-build/moondesk.app/Contents/Resources/lepusa/runtime.json",
  ])
}

///|
async test "lepusa integration live project uses localhost sidecar service" {
  let parsed = parse_lepusa_integration_args([
    "live-smoke", "macos", "--strict", "--workspace-root", "/tmp/moondesk-suite",
    "--serve-port", "4512",
  ])
  assert_true(parsed is Some(_))
  let options = parsed.unwrap()
  assert_eq(options.command, "live-smoke")
  assert_eq(options.serve_port, 4512)
  let project_path = lepusa_integration_live_project_path("/tmp/moondesk-live")
  assert_eq(project_path, "/tmp/moondesk-live/live-project/lepusa.json")
  let options = lepusa_integration_resolve_live_paths(options, "/repo/moondesk")
  let manifest = lepusa_integration_live_project_json(options, "/repo/moondesk").stringify()
  assert_true(manifest.contains("\"localhost\""))
  assert_true(manifest.contains("\"port\":4512"))
  assert_true(manifest.contains("\"readinessPath\":\"/__moondesk_health\""))
  assert_true(
    manifest.contains(
      "\"/repo/moondesk/_build/native/release/build/cmd/main/main.exe\"",
    ),
  )
  assert_false(manifest.contains("\"-C\""))
  assert_false(manifest.contains("\"/tmp/moondesk-suite\""))
  assert_false(manifest.contains("\"/repo/moondesk\",\"--ui\""))
  assert_true(manifest.contains("\"serve\""))
  assert_true(manifest.contains("\"lepusa/assets/main\""))
  assert_true(manifest.contains("\"/repo/moondesk/ui/rabbita-desk/dist\""))
  assert_true(manifest.contains("\"/repo/moondesk/assets/moondesk.icns\""))
  assert_true(manifest.contains("\"identity\":\"-\""))
  assert_true(manifest.contains("\"localhost\""))
  assert_true(manifest.contains("\"serviceDiscovery\""))
}

///|
test "lepusa integration live project defaults to MoonSuite workspace root" {
  let live_smoke = parse_lepusa_integration_args([
    "live-smoke", "macos", "--serve-port", "4512",
  ])
  assert_true(live_smoke is Some(_))
  assert_eq(live_smoke.unwrap().workspace_root, default_workspace_root())
  let live_build = parse_lepusa_integration_args([
    "live-build", "macos", "--serve-port", "4512",
  ])
  assert_true(live_build is Some(_))
  assert_eq(live_build.unwrap().workspace_root, default_workspace_root())
  let live_session = parse_lepusa_integration_args(["live-session", "macos"])
  assert_true(live_session is Some(_))
  assert_eq(live_session.unwrap().workspace_root, default_workspace_root())
}

///|
async test "lepusa integration live project honors custom workspace and ui paths" {
  let parsed = parse_lepusa_integration_args([
    "live-build", "macos", "--workspace-root", "../books", "--ui", "dist/ui", "--serve-port",
    "4517",
  ])
  assert_true(parsed is Some(_))
  let options = lepusa_integration_resolve_live_paths(
    parsed.unwrap(),
    "/repo/moondesk",
  )
  assert_eq(options.workspace_root, "/repo/books")
  assert_eq(options.ui_dir, "/repo/moondesk/dist/ui")
  let manifest = lepusa_integration_live_project_json(options, "/repo/moondesk").stringify()
  assert_false(manifest.contains("\"/repo/books\""))
  assert_true(manifest.contains("\"/repo/moondesk/dist/ui\""))
  assert_true(manifest.contains("\"lepusa/assets/main\""))
  assert_false(manifest.contains("\"/repo/moondesk/ui/rabbita-desk/dist\""))
}

///|
async test "lepusa integration live project protects source checkout workspace" {
  let repo_root = @pathx.join(
    "/tmp",
    "moondesk-source-root-wbtest-" + @async.now().to_string(),
  )
  @fsx.make_directory(repo_root, recursive=true, exists_ok=true)
  @fsx.write_to_file(@pathx.join(repo_root, "moon.mod"), "name = \"demo\"\n")
  let parsed = parse_lepusa_integration_args([
    "live-build", "macos", "--workspace-root", ".", "--ui", "dist/ui", "--serve-port",
    "4517",
  ])
  assert_true(parsed is Some(_))
  let options = lepusa_integration_resolve_live_paths(
    parsed.unwrap(),
    repo_root,
  )
  assert_eq(options.workspace_root, default_workspace_root())
  let manifest = lepusa_integration_live_project_json(options, repo_root).stringify()
  assert_false(manifest.contains(options.workspace_root))
  assert_false(manifest.contains("\"serve\",\"" + repo_root + "\""))
}

///|
test "lepusa integration live smoke runs generated manifest checks" {
  let parsed = parse_lepusa_integration_args([
    "live-smoke", "linux", "--workspace-root", "/tmp/moondesk-suite", "--serve-port",
    "4513",
  ])
  assert_true(parsed is Some(_))
  let options = parsed.unwrap()
  let steps = lepusa_integration_live_smoke_steps(
    options, "/tmp/out/live-project/lepusa.json", "/tmp/out", "/tmp/out/moondesk/lepusa/runtime.json",
  )
  assert_eq(steps.length(), 3)
  assert_eq(steps[0].name, "verify")
  assert_string_array_eq(steps[0].args, [
    "run", "cmd/main", "--target", "native", "--", "verify", "linux", "--project",
    "/tmp/out/live-project/lepusa.json",
  ])
  assert_eq(steps[1].name, "bundle-write")
  assert_string_array_eq(steps[1].args, [
    "run", "cmd/main", "--target", "native", "--", "bundle-write", "linux", "/tmp/out",
    "--project", "/tmp/out/live-project/lepusa.json",
  ])
  assert_eq(steps[2].name, "runtime-session")
  assert_string_array_eq(steps[2].args, [
    "run", "cmd/runtime", "--target", "native", "--", "launch-session", "--manifest",
    "/tmp/out/moondesk/lepusa/runtime.json",
  ])
}

///|
test "lepusa integration live build writes generated localhost bundle" {
  let parsed = parse_lepusa_integration_args([
    "live-build", "macos", "--workspace-root", "/tmp/moondesk-suite", "--serve-port",
    "4514", "--out", "/tmp/out",
  ])
  assert_true(parsed is Some(_))
  let options = parsed.unwrap()
  assert_eq(options.command, "live-build")
  assert_eq(options.target, "macos")
  assert_eq(options.serve_port, 4514)
  let steps = lepusa_integration_live_build_steps(
    options, "/tmp/out/live-project/lepusa.json", "/tmp/out", "/tmp/out/moondesk.app/Contents/Resources/lepusa/runtime.json",
  )
  assert_eq(steps.length(), 2)
  assert_eq(steps[0].name, "verify")
  assert_string_array_eq(steps[0].args, [
    "run", "cmd/main", "--target", "native", "--", "verify", "macos", "--project",
    "/tmp/out/live-project/lepusa.json",
  ])
  assert_eq(steps[1].name, "bundle-write")
  assert_string_array_eq(steps[1].args, [
    "run", "cmd/main", "--target", "native", "--", "bundle-write", "macos", "/tmp/out",
    "--project", "/tmp/out/live-project/lepusa.json",
  ])
}

///|
test "lepusa integration live session and launch use generated runtime manifest" {
  let session = parse_lepusa_integration_args([
    "live-session", "linux", "--workspace-root", "/tmp/moondesk-suite", "--out",
    "/tmp/out",
  ]).unwrap()
  let session_steps = lepusa_integration_live_runtime_steps(
    session, "/tmp/out/live-project/lepusa.json", "/tmp/out", "/tmp/out/moondesk/lepusa/runtime.json",
  )
  assert_eq(session_steps.length(), 3)
  assert_eq(session_steps[2].name, "runtime-session")
  assert_string_array_eq(session_steps[2].args, [
    "run", "cmd/runtime", "--target", "native", "--", "launch-session", "--manifest",
    "/tmp/out/moondesk/lepusa/runtime.json",
  ])
  let launch = parse_lepusa_integration_args([
    "live-launch", "macos", "--workspace-root", "/tmp/moondesk-suite", "--out", "/tmp/out",
  ]).unwrap()
  let launch_steps = lepusa_integration_live_runtime_steps(
    launch, "/tmp/out/live-project/lepusa.json", "/tmp/out", "/tmp/out/moondesk.app/Contents/Resources/lepusa/runtime.json",
  )
  assert_eq(launch_steps.length(), 3)
  assert_eq(launch_steps[2].name, "runtime-launch")
  assert_string_array_eq(launch_steps[2].args, [
    "run", "cmd/runtime", "--target", "native", "--", "launch", "--manifest", "/tmp/out/moondesk.app/Contents/Resources/lepusa/runtime.json",
  ])
}

///|
test "lepusa integration asset resolves the packaged entrypoint by default" {
  let parsed = parse_lepusa_integration_args(["asset"])
  assert_true(parsed is Some(_))
  let options = parsed.unwrap()
  assert_eq(options.command, "asset")
  assert_eq(options.asset_url, "lepusa://packaged/main/index.html")
  assert_string_array_eq(
    lepusa_integration_process_args(
      options, "/repo/desktop/lepusa/moondesk/lepusa.json", "/repo/_build/lepusa/moondesk",
      "/repo/_build/lepusa/moondesk/moondesk.app/Contents/Resources/lepusa/runtime.json",
    ),
    [
      "run", "cmd/main", "--target", "native", "--", "asset", "lepusa://packaged/main/index.html",
      "--project", "/repo/desktop/lepusa/moondesk/lepusa.json",
    ],
  )
}

///|
test "lepusa integration runtime session uses the generated bundle manifest" {
  let parsed = parse_lepusa_integration_args(["runtime-session", "macos"])
  assert_true(parsed is Some(_))
  assert_string_array_eq(
    lepusa_integration_process_args(
      parsed.unwrap(),
      "/repo/desktop/lepusa/moondesk/lepusa.json",
      "/repo/_build/lepusa/moondesk",
      "/repo/_build/lepusa/moondesk/moondesk.app/Contents/Resources/lepusa/runtime.json",
    ),
    [
      "run", "cmd/runtime", "--target", "native", "--", "launch-session", "--manifest",
      "/repo/_build/lepusa/moondesk/moondesk.app/Contents/Resources/lepusa/runtime.json",
    ],
  )
}

///|
test "lepusa integration runtime launch opens the generated bundle manifest" {
  let parsed = parse_lepusa_integration_args(["runtime-launch", "macos"])
  assert_true(parsed is Some(_))
  assert_string_array_eq(
    lepusa_integration_process_args(
      parsed.unwrap(),
      "/repo/desktop/lepusa/moondesk/lepusa.json",
      "/repo/_build/lepusa/moondesk",
      "/repo/_build/lepusa/moondesk/moondesk.app/Contents/Resources/lepusa/runtime.json",
    ),
    [
      "run", "cmd/runtime", "--target", "native", "--", "launch", "--manifest", "/repo/_build/lepusa/moondesk/moondesk.app/Contents/Resources/lepusa/runtime.json",
    ],
  )
}

///|
test "lepusa integration runtime asset accepts explicit manifest and url" {
  let parsed = parse_lepusa_integration_args([
    "runtime-asset", "lepusa://packaged/main/app.css", "--manifest", "/tmp/runtime.json",
  ])
  assert_true(parsed is Some(_))
  let options = parsed.unwrap()
  assert_eq(options.asset_url, "lepusa://packaged/main/app.css")
  assert_eq(options.manifest_path, "/tmp/runtime.json")
  assert_string_array_eq(
    lepusa_integration_process_args(
      options, "/repo/desktop/lepusa/moondesk/lepusa.json", "/repo/_build/lepusa/moondesk",
      "/tmp/runtime.json",
    ),
    [
      "run", "cmd/runtime", "--target", "native", "--", "asset", "lepusa://packaged/main/app.css",
      "--manifest", "/tmp/runtime.json",
    ],
  )
}

///|
test "lepusa integration asset accepts an explicit url" {
  let parsed = parse_lepusa_integration_args([
    "asset", "lepusa://packaged/main/app.css",
  ])
  assert_true(parsed is Some(_))
  assert_eq(parsed.unwrap().asset_url, "lepusa://packaged/main/app.css")
}

///|
test "lepusa integration args reject unknown command, target, and missing values" {
  assert_true(parse_lepusa_integration_args(["serve"]) is None)
  assert_true(parse_lepusa_integration_args(["verify", "android"]) is None)
  assert_true(parse_lepusa_integration_args(["verify", "--lepusa"]) is None)
  assert_true(parse_lepusa_integration_args(["verify", "--project"]) is None)
  assert_true(parse_lepusa_integration_args(["verify", "--out"]) is None)
  assert_true(parse_lepusa_integration_args(["verify", "--manifest"]) is None)
  assert_true(parse_lepusa_integration_args(["verify", "--asset"]) is None)
  assert_true(
    parse_lepusa_integration_args(["verify", "--workspace-root"]) is None,
  )
  assert_true(parse_lepusa_integration_args(["verify", "--ui"]) is None)
  assert_true(parse_lepusa_integration_args(["verify", "--serve-port"]) is None)
  assert_true(
    parse_lepusa_integration_args(["verify", "--serve-port", "abc"]) is None,
  )
  assert_true(parse_lepusa_integration_args(["verify", "--unexpected"]) is None)
}
