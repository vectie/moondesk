///|
test "pack app runtime accepts a matching installed app" {
  let record = pack_app_runtime_record(
    { "pack_id": "sample", "version": "1.2.3" },
    {
      "id": "sample",
      "display_name": "Sample Pack",
      "kind": "DomainPack",
      "app_entrypoints": [
        { "id": "studio", "path": "/apps/sample/studio", "audience": "operator" },
      ],
    },
    {
      "contract": "moonsuite.pack-app-runtime.v1",
      "pack_id": "sample",
      "app_url": "http://127.0.0.1:4300/apps/sample/studio",
      "service_url": "http://127.0.0.1:4300",
    },
  )
  guard record is Some(record) else {
    fail("expected a configured pack app")
  }
  assert_eq(json_string(record, "pack_id", default=""), "sample")
  assert_eq(json_string(record, "entrypoint_id", default=""), "studio")
  assert_eq(
    json_string(record, "app_url", default=""),
    "http://127.0.0.1:4300/apps/sample/studio",
  )
  assert_eq(
    json_string(record, "launch_url", default=""),
    "/pack-apps/sample/",
  )
}

///|
test "pack app runtime rejects mismatched ids and unsafe URLs" {
  let manifest : Json = {
    "id": "sample",
    "app_entrypoints": [{ "id": "app", "path": "/app" }],
  }
  assert_true(
    pack_app_runtime_record(
      { "pack_id": "sample" },
      manifest,
      {
        "pack_id": "other",
        "app_url": "http://127.0.0.1:4300/app",
        "service_url": "http://127.0.0.1:4300",
      },
    ) is None,
  )
  assert_true(
    pack_app_runtime_record(
      { "pack_id": "sample" },
      manifest,
      {
        "pack_id": "sample",
        "app_url": "javascript:alert(1)",
        "service_url": "http://127.0.0.1:4300",
      },
    ) is None,
  )
  assert_true(
    pack_app_runtime_record(
      { "pack_id": "sample" },
      manifest,
      {
        "pack_id": "sample",
        "app_url": "http://127.0.0.1:4300/app",
        "service_url": "http://169.254.169.254:80",
      },
    ) is None,
  )
  assert_false(
    is_safe_local_pack_service_url(
      "http://127.0.0.1:4300@attacker.invalid",
    ),
  )
  assert_false(
    is_safe_local_pack_service_url("http://127.0.0.1:4300/private"),
  )
}
