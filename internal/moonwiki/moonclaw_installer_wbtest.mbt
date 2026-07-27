///|
test "moonclaw release asset selects exact platform" {
  let manifest : Json = {
    "assets": [
      {
        "platform": "macos",
        "architecture": "arm64",
        "name": "moonclaw-0.1.4-macos-arm64.tar.gz",
      },
      {
        "platform": "linux",
        "architecture": "x86_64",
        "name": "moonclaw-0.1.4-linux-x86_64.tar.gz",
      },
    ],
  }
  let selected = moonclaw_release_asset(manifest, "macos", "arm64").unwrap()
  assert_eq(
    json_string(selected, "name", default=""),
    "moonclaw-0.1.4-macos-arm64.tar.gz",
  )
  assert_true(moonclaw_release_asset(manifest, "macos", "x86_64") is None)
}

///|
test "platform support is explicit and independent of string validity" {
  let macos = moonclaw_platform_support_from_values("macos", "arm64")
  assert_true(macos.supported)
  assert_eq(macos.platform, "macos")
  assert_eq(macos.architecture, "arm64")
  assert_true(
    moonclaw_platform_support_from_values("linux", "x86_64").supported,
  )
  assert_false(
    moonclaw_platform_support_from_values("unsupported", "x86_64").supported,
  )
  assert_false(
    moonclaw_platform_support_from_values("macos", "unsupported").supported,
  )
  assert_false(
    moonclaw_platform_support_from_values("windows", "x86_64").supported,
  )
  let json = moonclaw_platform_support_json(macos)
  assert_true(json_bool(json, "supported", default=false))
  assert_eq(json_string(json, "platform", default=""), "macos")
  assert_eq(json_string(json, "architecture", default=""), "arm64")
}

///|
async test "unsupported platform installation fails before release lookup" {
  let result = install_moonclaw_release_for_platform(
    "/tmp/moondesk-moonclaw-unsupported-install-wbtest",
    moonclaw_platform_support_from_values("unsupported", "unsupported"),
  )
  assert_false(json_bool(result, "ok", default=true))
  assert_eq(json_string(result, "status", default=""), "platform_unsupported")
  assert_true(
    json_string(result, "message", default="").contains(
      "not supported for unsupported unsupported",
    ),
  )
}

///|
test "moonclaw runtime root follows the packaged app data directory" {
  assert_eq(
    moonclaw_runtime_root_from_environment(
      "", "/tmp/MoonDesk Application Support", "/Users/demo",
    ),
    "/tmp/MoonDesk Application Support/runtimes",
  )
  assert_eq(
    moonclaw_runtime_root_from_environment(
      "/tmp/explicit-runtime", "/tmp/app-data", "/Users/demo",
    ),
    "/tmp/explicit-runtime",
  )
  assert_eq(moonclaw_runtime_root_from_environment("", "", ""), "")
}

///|
test "moonclaw release declarations reject unsafe paths and checksums" {
  assert_true(
    moonclaw_release_segment_valid("moonclaw-0.1.4-macos-arm64.tar.gz"),
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
  let manifest = "http://gl.vectie.xyz/vectie/moonclaw/-/releases/v0.1.4/downloads/release-manifest-gitlab.json"
  assert_true(moonclaw_release_url_allowed(manifest, manifest))
  assert_true(
    moonclaw_release_url_allowed(
      "http://gl.vectie.xyz/vectie/moonclaw/-/releases/v0.1.4/downloads/moonclaw-0.1.4-macos-arm64.tar.gz",
      manifest,
    ),
  )
  assert_false(
    moonclaw_release_url_allowed(
      "http://example.com/moonclaw-0.1.4-macos-arm64.tar.gz", manifest,
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
