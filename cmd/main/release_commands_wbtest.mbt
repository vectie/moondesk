///|
async test "release manifest describes lepusa runtime artifact" {
  let options = {
    ..default_bundle_options(),
    workspace_root: "/repo/books",
    ui_dir: "/repo/moondesk/ui",
    out_dir: "/tmp/release",
    lepusa_root: "/repo/lepusa",
    version: "1.2.3",
    channel: "nightly",
  }
  let manifest = release_manifest_json(
    options,
    "/tmp/release/MoonDesk.app",
    "/tmp/release/MoonDesk.app.zip",
    "/tmp/release/MoonDesk.app/Contents/Resources/lepusa/runtime.json",
    "/tmp/release/moondesk-1.2.3-macos-arm64.dmg",
    "/tmp/release/updates.json",
    "",
    signed=false,
    dmg_created=false,
    notarized=false,
  )
  let text = manifest.stringify()
  assert_true(text.contains("\"app_name\":\"MoonDesk.app\""))
  assert_true(text.contains("\"native_host\":\"lepusa\""))
  assert_true(text.contains("\"native_window\":true"))
  assert_true(text.contains("\"runtime_manifest\""))
  assert_true(text.contains("\"lepusa_root\":\"/repo/lepusa\""))
  assert_true(text.contains("\"workspace_root\":\"/repo/books\""))
}

///|
async test "update manifest includes runtime manifest artifact" {
  let options = {
    ..default_bundle_options(),
    out_dir: "/tmp/release",
    version: "1.2.3",
  }
  let manifest = update_manifest_json(
    options,
    "/tmp/release/MoonDesk.app.zip",
    "/tmp/release/MoonDesk.app/Contents/Resources/lepusa/runtime.json",
    "/tmp/release/moondesk-1.2.3-macos-arm64.dmg",
    dmg_created=false,
    notarized=false,
  )
  let text = manifest.stringify()
  assert_true(text.contains("\"native_host\":\"lepusa\""))
  assert_true(text.contains("\"native_window\":true"))
  assert_true(text.contains("\"kind\":\"runtime-manifest\""))
  assert_true(text.contains("Contents/Resources/lepusa/runtime.json"))
}

///|
test "release DMG name includes platform and architecture" {
  assert_eq(release_dmg_file_name("0.1.0"), "moondesk-0.1.0-macos-arm64.dmg")
  assert_eq(
    release_dmg_staging_dir("/tmp/moondesk-0.1.0-macos-arm64.dmg"),
    "/tmp/moondesk-0.1.0-macos-arm64.dmg.staging",
  )
}
