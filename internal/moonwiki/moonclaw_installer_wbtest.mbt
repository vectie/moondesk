///|
test "moonclaw release asset selects exact platform" {
  let manifest : Json = {
    "assets": [
      {
        "platform": "macos",
        "architecture": "arm64",
        "name": "moonclaw-0.1.2-macos-arm64.tar.gz",
      },
      {
        "platform": "linux",
        "architecture": "x86_64",
        "name": "moonclaw-0.1.2-linux-x86_64.tar.gz",
      },
    ],
  }
  let selected = moonclaw_release_asset(manifest, "macos", "arm64").unwrap()
  assert_eq(
    json_string(selected, "name", default=""),
    "moonclaw-0.1.2-macos-arm64.tar.gz",
  )
  assert_true(moonclaw_release_asset(manifest, "macos", "x86_64") is None)
}

///|
test "moonclaw release declarations reject unsafe paths and checksums" {
  assert_true(
    moonclaw_release_segment_valid("moonclaw-0.1.2-macos-arm64.tar.gz"),
  )
  assert_false(moonclaw_release_segment_valid("../moonclaw.tar.gz"))
  assert_false(moonclaw_release_segment_valid("moonclaw/asset.tar.gz"))
  assert_true(
    moonclaw_release_checksum_valid(
      "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
    ),
  )
  assert_false(moonclaw_release_checksum_valid("not-a-checksum"))
}
