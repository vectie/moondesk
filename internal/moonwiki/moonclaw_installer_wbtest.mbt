///|
test "moonclaw release asset selects exact platform" {
  let manifest : Json = {
    "assets": [
      {
        "platform": "macos",
        "architecture": "arm64",
        "name": "moonclaw-0.1.3-macos-arm64.tar.gz",
      },
      {
        "platform": "linux",
        "architecture": "x86_64",
        "name": "moonclaw-0.1.3-linux-x86_64.tar.gz",
      },
    ],
  }
  let selected = moonclaw_release_asset(manifest, "macos", "arm64").unwrap()
  assert_eq(
    json_string(selected, "name", default=""),
    "moonclaw-0.1.3-macos-arm64.tar.gz",
  )
  assert_true(moonclaw_release_asset(manifest, "macos", "x86_64") is None)
}

///|
test "moonclaw release declarations reject unsafe paths and checksums" {
  assert_true(
    moonclaw_release_segment_valid("moonclaw-0.1.3-macos-arm64.tar.gz"),
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

///|
test "moonclaw release URLs temporarily trust only the GitLab HTTP origin" {
  let manifest = "http://gl.vectie.xyz/vectie/moonclaw/-/releases/v0.1.3/downloads/release-manifest-gitlab.json"
  assert_true(moonclaw_release_url_allowed(manifest, manifest))
  assert_true(
    moonclaw_release_url_allowed(
      "http://gl.vectie.xyz/vectie/moonclaw/-/releases/v0.1.3/downloads/moonclaw-0.1.3-macos-arm64.tar.gz",
      manifest,
    ),
  )
  assert_false(
    moonclaw_release_url_allowed(
      "http://example.com/moonclaw-0.1.3-macos-arm64.tar.gz", manifest,
    ),
  )
  assert_false(
    moonclaw_release_url_allowed(
      "http://gl.vectie.xyz.evil.example/moonclaw.tar.gz", manifest,
    ),
  )
  assert_false(
    moonclaw_release_url_allowed(
      "http://gl.vectie.xyz/vectie/moonclaw/-/releases/v0.1.3/downloads/moonclaw-0.1.3-macos-arm64.tar.gz",
      "http://example.com/release-manifest.json",
    ),
  )
  assert_true(
    moonclaw_release_url_allowed(
      "https://github.com/vectie/moonclaw/releases/download/v0.1.3/moonclaw-0.1.3-macos-arm64.tar.gz",
      "https://github.com/vectie/moonclaw/releases/download/v0.1.3/release-manifest.json",
    ),
  )
}
