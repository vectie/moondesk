///|
test "bundle defaults to lepusa native shell" {
  let options = default_bundle_options()
  assert_eq(options.lepusa_root, "../lepusa")
  assert_eq(bundle_shell_policy(), "lepusa")
  assert_eq(bundle_app_root(options), "dist/moondesk-lepusa.app")
  assert_eq(bundle_archive_path(options), "dist/moondesk-lepusa.app.zip")
}

///|
test "bundle parser rejects stale shell flags" {
  assert_true(parse_bundle_args(["--shell", "lepusa"]) is None)
  assert_true(parse_bundle_args(["--shell", "browser"]) is None)
  assert_true(parse_bundle_args(["--shell"]) is None)
}

///|
test "bundle paths use lepusa app artifacts" {
  let lepusa = default_bundle_options()
  assert_eq(bundle_app_root(lepusa), "dist/moondesk-lepusa.app")
  assert_eq(bundle_archive_path(lepusa), "dist/moondesk-lepusa.app.zip")
  assert_eq(
    bundle_runtime_manifest_path(lepusa),
    "dist/moondesk-lepusa.app/Contents/Resources/lepusa/runtime.json",
  )
}

///|
test "lepusa bundle is a native window bundle" {
  assert_true(bundle_has_native_window())
  assert_eq(bundle_native_host_name(), "lepusa")
}

///|
test "bundle path leaf extracts app bundle name" {
  assert_eq(
    bundle_path_leaf("/tmp/release/moondesk-lepusa.app"),
    "moondesk-lepusa.app",
  )
  assert_eq(bundle_path_leaf("dist/moondesk-lepusa.app"), "moondesk-lepusa.app")
}

///|
test "bundle parser accepts custom lepusa checkout" {
  let parsed = parse_bundle_args([
    "--lepusa", "/tmp/lepusa", "--out", "/tmp/out", "--port", "4520",
  ])
  assert_true(parsed is Some(_))
  let options = parsed.unwrap()
  assert_eq(options.lepusa_root, "/tmp/lepusa")
  assert_eq(options.out_dir, "/tmp/out")
  assert_eq(options.port, 4520)
  assert_true(parse_bundle_args(["--lepusa"]) is None)
}

///|
test "bundle lepusa args include resolved checkout and sidecar paths" {
  let options = {
    ..default_bundle_options(),
    workspace_root: "/repo/books",
    ui_dir: "/repo/moondesk/ui",
    out_dir: "/tmp/out",
    port: 4521,
    lepusa_root: "/repo/lepusa",
  }
  assert_string_array_eq(bundle_lepusa_args(options), [
    "live-build", "macos", "--strict", "--out", "/tmp/out", "--serve-port", "4521",
    "--workspace-root", "/repo/books", "--ui", "/repo/moondesk/ui", "--lepusa", "/repo/lepusa",
  ])
}
