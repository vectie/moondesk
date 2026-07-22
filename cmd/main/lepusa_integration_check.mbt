///|
async fn run_lepusa_integration_live_bundle_check(
  options : LepusaIntegrationOptions,
  out_dir : String,
  manifest_path : String,
) -> Bool {
  let problems = lepusa_integration_live_bundle_problems(
    options, out_dir, manifest_path,
  )
  if problems.is_empty() {
    println("lepusa live bundle-check \{options.target}: ok")
    true
  } else {
    for problem in problems {
      println("lepusa live bundle-check failed: \{problem}")
    }
    false
  }
}

///|
async fn lepusa_integration_live_bundle_problems(
  options : LepusaIntegrationOptions,
  out_dir : String,
  manifest_path : String,
) -> Array[String] {
  let paths = lepusa_integration_bundle_paths(options.target, out_dir)
  let problems : Array[String] = []
  lepusa_integration_require_file(
    paths.platform_metadata,
    "platform metadata",
    problems,
  )
  lepusa_integration_require_file(paths.launcher, "launcher", problems)
  lepusa_integration_require_file(
    paths.runtime_executable,
    "bundled Lepusa runtime",
    problems,
  )
  lepusa_integration_require_file(
    lepusa_integration_sidecar_path(options.target, out_dir),
    "MoonDesk sidecar",
    problems,
  )
  lepusa_integration_require_file(paths.manifest, "runtime manifest", problems)
  lepusa_integration_require_file(
    paths.entrypoint,
    "bundled Rabbita entrypoint",
    problems,
  )
  if @pathx.normalize(manifest_path) != @pathx.normalize(paths.manifest) {
    problems.push(
      "manifest path mismatch: expected \{paths.manifest}, got \{manifest_path}",
    )
  }
  let manifest = @fs.read_file(paths.manifest).text() catch { _ => "" }
  if manifest == "" {
    problems.push("runtime manifest is empty or unreadable: \{paths.manifest}")
  } else {
    if !manifest.contains("\"localServices\"") {
      problems.push("runtime manifest does not include local service metadata")
    }
    if !manifest.contains(
        "\"readinessUrl\":\"http://127.0.0.1:\{options.serve_port}\{@moonwiki.moondesk_health_path()}\"",
      ) {
      problems.push(
        "runtime manifest does not include expected readiness URL for port \{options.serve_port}",
      )
    }
    if !manifest.contains("moondesk-sidecar") || !manifest.contains("\"serve\"") {
      problems.push(
        "runtime manifest does not include bundled MoonDesk sidecar serve command",
      )
    }
    if !manifest.contains(
        "\"command\":[\"moondesk-sidecar\",\"serve\",\"--ui\",\"lepusa/assets/main\"",
      ) {
      problems.push(
        "runtime manifest does not launch sidecar with the bundled UI",
      )
    }
  }
  let launcher = @fs.read_file(paths.launcher).text() catch { _ => "" }
  if launcher == "" {
    problems.push("launcher is empty or unreadable: \{paths.launcher}")
  } else if !lepusa_integration_launcher_uses_bundled_runtime(
      options.target,
      launcher,
    ) {
    problems.push(
      "launcher does not prefer bundled Lepusa runtime: \{paths.launcher}",
    )
  }
  problems
}

///|
async fn run_lepusa_integration_bundle_check(
  options : LepusaIntegrationOptions,
  out_dir : String,
  manifest_path : String,
) -> Bool {
  let problems = lepusa_integration_bundle_problems(
    options, out_dir, manifest_path,
  )
  if problems.is_empty() {
    println("lepusa bundle-check \{options.target}: ok")
    true
  } else {
    for problem in problems {
      println("lepusa bundle-check failed: \{problem}")
    }
    false
  }
}

///|
async fn lepusa_integration_bundle_problems(
  options : LepusaIntegrationOptions,
  out_dir : String,
  manifest_path : String,
) -> Array[String] {
  let paths = lepusa_integration_bundle_paths(options.target, out_dir)
  let problems : Array[String] = []
  lepusa_integration_require_file(paths.app_root, "app bundle root", problems)
  lepusa_integration_require_file(
    paths.platform_metadata,
    "platform metadata",
    problems,
  )
  lepusa_integration_require_file(paths.launcher, "launcher", problems)
  lepusa_integration_require_file(
    paths.runtime_executable,
    "bundled Lepusa runtime",
    problems,
  )
  lepusa_integration_require_file(
    lepusa_integration_sidecar_path(options.target, out_dir),
    "MoonDesk sidecar",
    problems,
  )
  lepusa_integration_require_file(paths.manifest, "runtime manifest", problems)
  lepusa_integration_require_file(
    paths.entrypoint,
    "packaged entrypoint",
    problems,
  )
  if @pathx.normalize(manifest_path) != @pathx.normalize(paths.manifest) {
    problems.push(
      "manifest path mismatch: expected \{paths.manifest}, got \{manifest_path}",
    )
  }
  let launcher = @fs.read_file(paths.launcher).text() catch { _ => "" }
  if launcher == "" {
    problems.push("launcher is empty or unreadable: \{paths.launcher}")
  } else if !lepusa_integration_launcher_uses_bundled_runtime(
      options.target,
      launcher,
    ) {
    problems.push(
      "launcher does not prefer bundled Lepusa runtime: \{paths.launcher}",
    )
  }
  let runtime = @fs.read_file(paths.runtime_executable).binary() catch {
    _ => []
  }
  if runtime.length() == 0 {
    problems.push(
      "bundled Lepusa runtime is empty or unreadable: \{paths.runtime_executable}",
    )
  }
  problems
}

///|
async fn lepusa_integration_require_file(
  path : String,
  label : String,
  problems : Array[String],
) -> Unit {
  if !@fs.exists(path) {
    problems.push("missing \{label}: \{path}")
  }
}

///|
fn lepusa_integration_bundle_paths(
  target : String,
  out_dir : String,
) -> LepusaIntegrationBundlePaths {
  if target == "macos" {
    let app_root = @pathx.join(out_dir, "moondesk-lepusa.app")
    {
      app_root,
      launcher: @pathx.join(app_root, "Contents/MacOS/moondesk-lepusa"),
      runtime_executable: @pathx.join(app_root, "Contents/MacOS/lepusa-runtime"),
      manifest: @pathx.join(app_root, "Contents/Resources/lepusa/runtime.json"),
      entrypoint: @pathx.join(
        app_root, "Contents/Resources/lepusa/assets/main/index.html",
      ),
      platform_metadata: @pathx.join(app_root, "Contents/Info.plist"),
    }
  } else if target == "windows" {
    let app_root = @pathx.join(out_dir, "moondesk-lepusa")
    {
      app_root,
      launcher: @pathx.join(app_root, "moondesk-lepusa.cmd"),
      runtime_executable: @pathx.join(app_root, "lepusa-runtime.exe"),
      manifest: @pathx.join(app_root, "lepusa/runtime.json"),
      entrypoint: @pathx.join(app_root, "lepusa/assets/main/index.html"),
      platform_metadata: @pathx.join(app_root, "app.manifest.xml"),
    }
  } else {
    let app_root = @pathx.join(out_dir, "moondesk-lepusa")
    {
      app_root,
      launcher: @pathx.join(app_root, "moondesk-lepusa"),
      runtime_executable: @pathx.join(app_root, "lepusa-runtime"),
      manifest: @pathx.join(app_root, "lepusa/runtime.json"),
      entrypoint: @pathx.join(app_root, "lepusa/assets/main/index.html"),
      platform_metadata: @pathx.join(app_root, "moondesk-lepusa.desktop"),
    }
  }
}

///|
fn lepusa_integration_launcher_uses_bundled_runtime(
  target : String,
  launcher : String,
) -> Bool {
  if target == "macos" {
    launcher.contains("RUNTIME=\"$APP_DIR/MacOS/lepusa-runtime\"") &&
    launcher.contains("trap cleanup INT TERM HUP") &&
    launcher.contains("\"$RUNTIME\" launch --manifest") &&
    launcher.contains("RUNTIME_PID=$!") &&
    launcher.contains("wait \"$RUNTIME_PID\"")
  } else if target == "windows" {
    launcher.contains("RUNTIME=%APP_DIR%lepusa-runtime.exe") &&
    launcher.contains("\"%RUNTIME%\" launch --manifest")
  } else {
    launcher.contains("RUNTIME=\"$APP_DIR/lepusa-runtime\"") &&
    launcher.contains("trap cleanup INT TERM HUP") &&
    launcher.contains("\"$RUNTIME\" launch --manifest") &&
    launcher.contains("RUNTIME_PID=$!") &&
    launcher.contains("wait \"$RUNTIME_PID\"")
  }
}
