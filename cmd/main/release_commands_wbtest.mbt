///|
test "release manifest is portable and describes lepusa runtime artifact" {
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
    "/tmp/release/moondesk-1.2.3-macos-arm64.dmg",
    "/tmp/release/updates.json",
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
    "",
    notary_profile_supplied=false,
    signed=false,
    dmg_created=false,
    notarized=false,
  )
  let text = manifest.stringify()
  assert_true(text.contains("\"app_name\":\"MoonDesk.app\""))
  assert_true(text.contains("\"native_host\":\"lepusa\""))
  assert_true(text.contains("\"native_window\":true"))
  assert_true(text.contains("\"runtime_manifest\""))
  assert_true(text.contains("\"archive\":\"MoonDesk.app.zip\""))
  assert_true(
    text.contains(
      "\"runtime_manifest\":\"MoonDesk.app/Contents/Resources/lepusa/runtime.json\"",
    ),
  )
  assert_true(text.contains("\"release_notes\":\"RELEASE_NOTES.md\""))
  assert_true(!text.contains("/tmp/"))
  assert_true(!text.contains("/repo/"))
}

///|
test "update manifest includes only portable release artifacts" {
  let options = {
    ..default_bundle_options(),
    out_dir: "/tmp/release",
    version: "1.2.3",
  }
  let manifest = update_manifest_json(
    options,
    "/tmp/release/MoonDesk.app.zip",
    "/tmp/release/moondesk-1.2.3-macos-arm64.dmg",
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
    "",
    dmg_created=false,
    notarized=false,
  )
  let text = manifest.stringify()
  assert_true(text.contains("\"native_host\":\"lepusa\""))
  assert_true(text.contains("\"native_window\":true"))
  assert_true(text.contains("\"kind\":\"runtime-manifest\""))
  assert_true(text.contains("Contents/Resources/lepusa/runtime.json"))
  assert_true(!text.contains("/tmp/"))
}

///|
test "release prerequisite classification rejects every incomplete artifact" {
  let valid = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  assert_true(
    release_artifact_problems(
      app_exists=true,
      archive_exists=true,
      archive_sha256=valid,
      runtime_manifest_exists=true,
      runtime_manifest_sha256=valid,
      dmg_requested=false,
      dmg_created=false,
      dmg_sha256="",
      signing_required=false,
      signed=false,
      notarization_requested=false,
      notarized=false,
    ).is_empty(),
  )
  let problems = release_artifact_problems(
    app_exists=false,
    archive_exists=true,
    archive_sha256="",
    runtime_manifest_exists=false,
    runtime_manifest_sha256="",
    dmg_requested=true,
    dmg_created=false,
    dmg_sha256="",
    signing_required=true,
    signed=false,
    notarization_requested=true,
    notarized=false,
  )
  assert_eq(problems.length(), 6)
  assert_true(problems.contains("app bundle is missing"))
  assert_true(problems.contains("zip archive SHA-256 is missing or invalid"))
  assert_true(problems.contains("runtime manifest is missing"))
  assert_true(problems.contains("requested DMG is missing"))
  assert_true(problems.contains("required code signature is invalid"))
  assert_true(problems.contains("requested notarization did not complete"))
}

///|
test "release DMG name includes platform and architecture" {
  assert_eq(release_dmg_file_name("0.1.0"), "moondesk-0.1.0-macos-arm64.dmg")
  assert_eq(
    release_dmg_staging_dir("/tmp/moondesk-0.1.0-macos-arm64.dmg"),
    "/tmp/moondesk-0.1.0-macos-arm64.dmg.staging",
  )
}
