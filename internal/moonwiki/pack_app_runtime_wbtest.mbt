///|
test "pack app runtime accepts a matching installed app" {
  let record = pack_app_runtime_record(
    { "pack_id": "sample", "version": "1.2.3" },
    {
      "id": "sample",
      "display_name": "Sample Pack",
      "kind": "DomainPack",
      "app_entrypoints": [
        {
          "id": "studio",
          "path": "/apps/sample/studio",
          "audience": "operator",
        },
      ],
    },
    {
      "contract": "moonsuite.pack-app-runtime.v1",
      "pack_id": "sample",
      "app_url": "http://127.0.0.1:4300/apps/sample/studio",
      "service_url": "http://127.0.0.1:4300",
    },
  )
  guard record is Some(record) else { fail("expected a configured pack app") }
  assert_eq(json_string(record, "pack_id", default=""), "sample")
  assert_eq(json_string(record, "entrypoint_id", default=""), "studio")
  assert_eq(
    json_string(record, "app_url", default=""),
    "http://127.0.0.1:4300/apps/sample/studio",
  )
  assert_eq(json_string(record, "launch_url", default=""), "/pack-apps/sample/")
}

///|
test "pack app runtime rejects mismatched ids and unsafe URLs" {
  let manifest : Json = {
    "id": "sample",
    "app_entrypoints": [{ "id": "app", "path": "/app" }],
  }
  assert_true(
    pack_app_runtime_record({ "pack_id": "sample" }, manifest, {
      "pack_id": "other",
      "app_url": "http://127.0.0.1:4300/app",
      "service_url": "http://127.0.0.1:4300",
    })
    is None,
  )
  assert_true(
    pack_app_runtime_record({ "pack_id": "sample" }, manifest, {
      "pack_id": "sample",
      "app_url": "javascript:alert(1)",
      "service_url": "http://127.0.0.1:4300",
    })
    is None,
  )
  assert_true(
    pack_app_runtime_record({ "pack_id": "sample" }, manifest, {
      "pack_id": "sample",
      "app_url": "http://127.0.0.1:4300/app",
      "service_url": "http://169.254.169.254:80",
    })
    is None,
  )
  assert_false(
    is_safe_local_pack_service_url("http://127.0.0.1:4300@attacker.invalid"),
  )
  assert_false(is_safe_local_pack_service_url("http://127.0.0.1:4300/private"))
}

///|
test "pack catalog keeps an installed app visible before runtime setup" {
  let record = pack_app_catalog_record(
    { "pack_id": "sample", "version": "1.2.0" },
    {
      "id": "sample",
      "display_name": "Sample Pack",
      "kind": "DomainPack",
      "app_entrypoints": [
        { "id": "studio", "path": "/apps/sample", "audience": "operator" },
      ],
      "workflows": [{ "id": "daily" }],
      "tools": [{ "id": "prepare" }, { "id": "publish" }],
    },
    None,
  )
  guard record is Some(record) else { fail("expected installed pack") }
  assert_eq(json_string(record, "status", default=""), "configuration_required")
  assert_eq(json_int(record, "entrypoint_count", default=0), 1)
  assert_eq(json_int(record, "workflow_count", default=0), 1)
  assert_eq(json_int(record, "tool_count", default=0), 2)
  assert_eq(json_string(record, "launch_url", default="missing"), "")
}

///|
test "pack catalog describes workflow-only packs without inventing an app" {
  let record = pack_app_catalog_record(
    { "pack_id": "research", "version": "0.3.0" },
    {
      "id": "research",
      "display_name": "Research Pack",
      "kind": "DomainPack",
      "app_entrypoints": [],
      "workflows": [{ "id": "watch" }],
      "tools": [],
    },
    None,
  )
  guard record is Some(record) else { fail("expected installed pack") }
  assert_eq(json_string(record, "status", default=""), "workflow_only")
  assert_eq(json_int(record, "entrypoint_count", default=-1), 0)
}
