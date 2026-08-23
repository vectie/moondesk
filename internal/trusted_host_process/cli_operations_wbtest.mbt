///|
test "trusted Lepusa target is a closed platform value" {
  assert_true(lepusa_target("macos") is Ok(_))
  assert_true(lepusa_target("linux") is Ok(_))
  assert_true(lepusa_target("windows") is Ok(_))
  assert_true(lepusa_target("darwin") is Err(_))
  assert_true(lepusa_target("macos\n--help") is Err(_))
  assert_true(lepusa_target("macos\u0000linux") is Err(_))
}

///|
test "trusted release values reject controls and remain bounded" {
  assert_true(signing_identity("-") is Ok(_))
  assert_true(
    signing_identity("Developer ID Application: Example; inert") is Ok(_),
  )
  assert_true(signing_identity("identity\n--entitlements") is Err(_))
  assert_true(signing_identity("identity\u0000other") is Err(_))
  assert_true(signing_identity("x".repeat(513)) is Err(_))
  assert_true(notary_profile("release-profile") is Ok(_))
  assert_true(notary_profile("release\r--wait") is Err(_))
  assert_true(notary_profile("x".repeat(256)) is Err(_))
}

///|
test "trusted canonical path shape rejects traversal and option injection" {
  assert_true(safe_canonical_path_shape("/repo/moondesk/MoonDesk.app"))
  assert_false(safe_canonical_path_shape("relative/MoonDesk.app"))
  assert_false(safe_canonical_path_shape("/repo/../etc/passwd"))
  assert_false(safe_canonical_path_shape("/repo/./MoonDesk.app"))
  assert_false(safe_canonical_path_shape("/repo//MoonDesk.app"))
  assert_false(safe_canonical_path_shape("/repo/MoonDesk.app\n--force"))
  assert_false(safe_canonical_path_shape("/repo/MoonDesk.app\u0000.zip"))
}

///|
test "trusted Lepusa operations expose no arbitrary command slot" {
  let target = lepusa_target("macos").unwrap()
  let verify = lepusa_verify(
    target,
    "/repo/desktop/lepusa/moondesk/lepusa.json",
    strict=true,
  ).unwrap()
  debug_inspect(
    verify.args,
    content=(
      #|[
      #|  "run",
      #|  "cmd/main",
      #|  "--target",
      #|  "native",
      #|  "--",
      #|  "verify",
      #|  "macos",
      #|  "--strict",
      #|  "--project",
      #|  "/repo/desktop/lepusa/moondesk/lepusa.json",
      #|]
    ),
  )
  assert_true(
    lepusa_verify(target, "/repo/project.json\n--", strict=false) is Err(_),
  )
  assert_true(
    lepusa_bundle_write(target, "/repo/project.json", "/tmp/out/../escape")
    is Err(_),
  )
}

///|
test "trusted Lepusa asset URLs reject command and control injection" {
  assert_true(
    lepusa_asset("/repo/project.json", "lepusa://packaged/main/index.html")
    is Ok(_),
  )
  assert_true(
    lepusa_asset("/repo/project.json", "file:///etc/passwd") is Err(_),
  )
  assert_true(
    lepusa_asset("/repo/project.json", "https://example.test/a\n--manifest")
    is Err(_),
  )
}

///|
test "trusted process limits are finite" {
  assert_eq(fixed_tool_stream_limit_bytes, 4 * 1024 * 1024)
  assert_true(tool_build_timeout_ms > 0)
  assert_true(tool_build_timeout_ms <= 1_200_000)
  assert_true(lepusa_operation_timeout_ms > 0)
  assert_true(lepusa_operation_timeout_ms <= 600_000)
  assert_true(release_operation_timeout_ms > 0)
  assert_true(release_operation_timeout_ms <= 1_800_000)
}
