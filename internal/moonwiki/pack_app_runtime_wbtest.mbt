///|
test "pack app runtime accepts a matching installed app" {
  let record = pack_app_runtime_record(
    { "pack_id": "sample", "version": "1.2.3" },
    {
      "id": "sample",
      "display_name": "Sample Pack",
      "kind": "DomainPack",
      "app_area": {
        "id": "operations.sample",
        "category": "operations",
        "label": "Operations",
      },
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
  assert_eq(json_string(record, "area_id", default=""), "operations.sample")
  assert_eq(json_string(record, "area_category", default=""), "operations")
  assert_eq(json_string(record, "area_label", default=""), "Operations")
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
      "contract": "moonsuite.pack-app-runtime.v1",
      "pack_id": "other",
      "app_url": "http://127.0.0.1:4300/app",
      "service_url": "http://127.0.0.1:4300",
    })
    is None,
  )
  assert_true(
    pack_app_runtime_record({ "pack_id": "sample" }, manifest, {
      "contract": "moonsuite.pack-app-runtime.v1",
      "pack_id": "sample",
      "app_url": "javascript:alert(1)",
      "service_url": "http://127.0.0.1:4300",
    })
    is None,
  )
  assert_true(
    pack_app_runtime_record({ "pack_id": "sample" }, manifest, {
      "contract": "moonsuite.pack-app-runtime.v1",
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
test "pack app runtime pins the contract and app URL to the declared route" {
  let active : Json = { "pack_id": "sample" }
  let manifest : Json = {
    "id": "sample",
    "app_entrypoints": [{ "id": "app", "path": "/apps/sample" }],
  }
  assert_true(
    pack_app_runtime_record(active, manifest, {
      "contract": "moonsuite.pack-app-runtime.v2",
      "pack_id": "sample",
      "app_url": "http://127.0.0.1:4300/apps/sample",
      "service_url": "http://127.0.0.1:4300",
    })
    is None,
  )
  assert_true(
    pack_app_runtime_record(active, manifest, {
      "contract": "moonsuite.pack-app-runtime.v1",
      "pack_id": "sample",
      "app_url": "http://localhost:4300/apps/sample",
      "service_url": "http://127.0.0.1:4300",
    })
    is None,
  )
  assert_true(
    pack_app_runtime_record(active, manifest, {
      "contract": "moonsuite.pack-app-runtime.v1",
      "pack_id": "sample",
      "app_url": "http://127.0.0.1:4300/admin",
      "service_url": "http://127.0.0.1:4300",
    })
    is None,
  )
}

///|
test "pack app runtime rejects traversal and ambiguous identifiers" {
  assert_true(is_safe_pack_id("mooncast"))
  assert_true(is_safe_pack_id("research_pack-2"))
  assert_false(is_safe_pack_id("../mooncast"))
  assert_false(is_safe_pack_id("Mooncast"))
  assert_false(is_safe_pack_id("mooncast%2fadmin"))
  assert_true(is_safe_pack_route_path("/apps/mooncast/studio"))
  assert_true(is_safe_pack_route_path("/assets/main.js"))
  assert_false(is_safe_pack_route_path("//attacker.invalid/app"))
  assert_false(is_safe_pack_route_path("/apps//admin"))
  assert_false(is_safe_pack_route_path("/apps/../admin"))
  assert_false(is_safe_pack_route_path("/apps/%2e%2e/admin"))
  assert_false(is_safe_pack_route_path("/apps/moon cast"))
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
  assert_eq(json_string(record, "area_id", default="missing"), "")
}

///|
test "pack catalog projects a generic manifest-declared app area" {
  let record = pack_app_catalog_record(
    { "pack_id": "sample", "version": "1.2.0" },
    {
      "id": "sample",
      "display_name": "Sample Pack",
      "app_area": {
        "id": "finance.research",
        "category": "finance",
        "label": "Finance",
      },
      "app_entrypoints": [
        { "id": "studio", "path": "/apps/sample", "audience": "operator" },
      ],
    },
    None,
  )
  guard record is Some(record) else { fail("expected installed pack") }
  assert_eq(json_string(record, "area_id", default=""), "finance.research")
  assert_eq(json_string(record, "area_category", default=""), "finance")
  assert_eq(json_string(record, "area_label", default=""), "Finance")
}

///|
test "pack catalog rejects malformed declared app areas" {
  let active : Json = { "pack_id": "sample" }
  assert_true(
    pack_app_catalog_record(
      active,
      {
        "id": "sample",
        "app_area": "finance",
        "app_entrypoints": [{ "id": "app", "path": "/apps/sample" }],
      },
      None,
    )
    is None,
  )
  assert_true(
    pack_app_catalog_record(
      active,
      {
        "id": "sample",
        "app_area": { "id": "finance.sample", "category": "finance" },
        "app_entrypoints": [{ "id": "app", "path": "/apps/sample" }],
      },
      None,
    )
    is None,
  )
  assert_true(
    pack_app_catalog_record(
      active,
      {
        "id": "sample",
        "app_area": {
          "id": "../finance",
          "category": "finance",
          "label": "Finance",
        },
        "app_entrypoints": [{ "id": "app", "path": "/apps/sample" }],
      },
      None,
    )
    is None,
  )
  assert_true(
    pack_app_catalog_record(
      active,
      {
        "id": "sample",
        "app_area": {
          "id": "finance.sample",
          "category": "Finance",
          "label": "Finance",
        },
        "app_entrypoints": [{ "id": "app", "path": "/apps/sample" }],
      },
      None,
    )
    is None,
  )
}

///|
async test "installed pack app area artifact survives manifest projection" {
  let root = "/tmp/moondesk-pack-app-area-wbtest-" +
    @desk.stable_id("pack-app-area", @async.now().to_string())
  @fsx.make_directory(@pathx.join(root, "apps"), recursive=true, exists_ok=true)
  @fsx.write_to_file(
    @pathx.join(root, "apps/app-area.json"),
    (
      {
        "contract": "moonsuite.pack-app-area.v1",
        "app_area": {
          "id": "finance.sample",
          "category": "finance",
          "label": "Finance",
        },
      } : Json).stringify() +
    "\n",
    create=0o644,
  )
  let manifest : Json = {
    "id": "sample",
    "evaluations": [
      {
        "id": "moondesk-app-area",
        "version": "1.0.0",
        "path": "apps/app-area.json",
      },
    ],
    "app_entrypoints": [{ "id": "app", "path": "/apps/sample" }],
  }
  let (valid, area) = resolve_installed_pack_app_area(root, manifest)
  assert_true(valid)
  guard area is Some(area) else { fail("expected installed app area") }
  let record = pack_app_catalog_record_resolved(
    { "pack_id": "sample", "version": "1.0.0" },
    manifest,
    None,
    Some(area),
  )
  guard record is Some(record) else { fail("expected catalog record") }
  assert_eq(json_string(record, "area_id", default=""), "finance.sample")
  assert_eq(json_string(record, "area_category", default=""), "finance")
  assert_eq(json_string(record, "area_label", default=""), "Finance")
  @fs.rmdir(root, recursive=true)
}

///|
async test "installed pack app area artifact fails closed" {
  let root = "/tmp/moondesk-pack-app-area-invalid-wbtest-" +
    @desk.stable_id("pack-app-area-invalid", @async.now().to_string())
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  let traversal_manifest : Json = {
    "evaluations": [
      {
        "id": "moondesk-app-area",
        "version": "1.0.0",
        "path": "../outside.json",
      },
    ],
  }
  let (unsafe_valid, _) = resolve_installed_pack_app_area(
    root, traversal_manifest,
  )
  assert_false(unsafe_valid)
  assert_false(is_safe_installed_pack_artifact_path("apps/\narea.json"))

  @fsx.write_to_file(
    @pathx.join(root, "app-area.json"),
    (
      {
        "contract": "moonsuite.pack-app-area.v2",
        "app_area": {
          "id": "finance.sample",
          "category": "finance",
          "label": "Finance",
        },
      } : Json).stringify() +
    "\n",
    create=0o644,
  )
  let wrong_contract : Json = {
    "evaluations": [
      { "id": "moondesk-app-area", "version": "1.0.0", "path": "app-area.json" },
    ],
  }
  let (contract_valid, _) = resolve_installed_pack_app_area(
    root, wrong_contract,
  )
  assert_false(contract_valid)
  @fs.rmdir(root, recursive=true)
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
