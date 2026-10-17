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
test "pack app proxy assigns HTML and JSON types to nested app routes" {
  let entrypoint = "/apps/moonfish/paiwork"
  assert_eq(
    pack_app_proxy_content_type(entrypoint, entrypoint),
    "text/html; charset=utf-8",
  )
  assert_eq(
    pack_app_proxy_content_type(entrypoint + "/", entrypoint),
    "text/html; charset=utf-8",
  )
  assert_eq(
    pack_app_proxy_content_type(entrypoint + "/api/v1/bootstrap", entrypoint),
    "application/json; charset=utf-8",
  )
  assert_eq(
    pack_app_proxy_content_type(entrypoint + "/style.css", entrypoint),
    "text/css; charset=utf-8",
  )
}

///|
test "pack app proxy keeps query filters and rejects unsafe query text" {
  assert_eq(
    pack_app_proxy_query_suffix(
      "/pack-apps/moonfish/apps/moonfish/paiwork/api/v1/items?limit=10&sort=latest",
    ),
    Some("?limit=10&sort=latest"),
  )
  assert_eq(pack_app_proxy_query_suffix("/pack-apps/moonfish/"), Some(""))
  assert_eq(
    pack_app_proxy_query_suffix("/pack-apps/moonfish/?next=#fragment"),
    None,
  )
  assert_eq(pack_app_proxy_query_suffix("/pack-apps/moonfish/?x=one two"), None)
}

///|
test "pack app proxy forwards explicit octet-stream request bytes" {
  assert_true(pack_app_proxy_binary_body("application/octet-stream"))
  assert_true(pack_app_proxy_binary_body("APPLICATION/OCTET-STREAM"))
  assert_false(pack_app_proxy_binary_body("application/json"))
  assert_false(pack_app_proxy_binary_body("text/plain"))
  assert_false(pack_app_proxy_binary_body(""))
}

///|
async test "pack app proxy bounds binary request bodies" {
  let binary = Bytes::from_array([b'P', b'K', b'\x00', b'\xff'])
  let reader = @io.MemoryReader() <| writer => { writer.write(binary) }
  defer reader.close()
  assert_eq(pack_app_proxy_bounded_body(reader), Some(binary))
  let oversized = Bytes::make(PackAppProxyMaximumBodyBytes + 1, b'x')
  let large_reader = @io.MemoryReader() <| writer => { writer.write(oversized) }
  defer large_reader.close()
  assert_eq(pack_app_proxy_bounded_body(large_reader), None)
}

///|
test "declared pack runtime identity is constrained to the app route" {
  let legacy : Json = {
    "app_entrypoints": [{ "id": "app", "path": "/apps/sample" }],
  }
  assert_eq(
    pack_app_runtime_identity_declaration(legacy),
    (false, true, "", ""),
  )
  let declared : Json = {
    "app_entrypoints": [{ "id": "app", "path": "/apps/sample" }],
    "app_runtime_identity": {
      "contract": "sample.runtime-identity.v1",
      "path": "/apps/sample/api/v1/runtime-identity",
    },
  }
  assert_eq(
    pack_app_runtime_identity_declaration(declared),
    (
      true, true, "/apps/sample/api/v1/runtime-identity", "sample.runtime-identity.v1",
    ),
  )
  let outside : Json = {
    "app_entrypoints": [{ "id": "app", "path": "/apps/sample" }],
    "app_runtime_identity": {
      "contract": "sample.runtime-identity.v1",
      "path": "/private/metadata",
    },
  }
  let (_, outside_valid, _, _) = pack_app_runtime_identity_declaration(outside)
  assert_false(outside_valid)
}

///|
test "pack runtime identity rejects a different version or workspace" {
  let workspace_ref = pack_app_workspace_ref("/tmp/sample-workspace")
  let identity : Json = {
    "contract": "sample.runtime-identity.v1",
    "pack_id": "sample",
    "version": "1.2.3",
    "workspace_ref": workspace_ref,
  }
  assert_true(
    pack_app_runtime_identity_matches(
      identity, "sample.runtime-identity.v1", "sample", "1.2.3", workspace_ref,
    ),
  )
  assert_false(
    pack_app_runtime_identity_matches(
      identity, "sample.runtime-identity.v1", "sample", "1.2.4", workspace_ref,
    ),
  )
  assert_false(
    pack_app_runtime_identity_matches(
      identity,
      "sample.runtime-identity.v1",
      "sample",
      "1.2.3",
      pack_app_workspace_ref("/tmp/other-workspace"),
    ),
  )
  assert_false(
    pack_app_runtime_identity_matches(
      identity, "sample.runtime-identity.v2", "sample", "1.2.3", workspace_ref,
    ),
  )
}

///|
async test "pack catalog and proxy reject an identity bound to another workspace" {
  let root = "/tmp/moondesk-pack-runtime-identity-wbtest-" +
    @desk.stable_id("pack-runtime-identity", @async.now().to_string())
  let installed_root = @pathx.join(root, "installed/sample")
  @fsx.make_directory(installed_root, recursive=true, exists_ok=true)
  @fsx.make_directory(active_packs_root(root), recursive=true, exists_ok=true)
  @fsx.make_directory(
    pack_apps_state_root(root),
    recursive=true,
    exists_ok=true,
  )
  let manifest : Json = {
    "id": "sample",
    "version": "1.2.3",
    "app_entrypoints": [{ "id": "app", "path": "/apps/sample" }],
    "app_runtime_identity": {
      "contract": "sample.runtime-identity.v1",
      "path": "/apps/sample/api/v1/runtime-identity",
    },
  }
  @fsx.write_to_file(
    @pathx.join(installed_root, "pack.json"),
    manifest.stringify(),
    create=0o644,
  )
  let active : Json = {
    "pack_id": "sample",
    "version": "1.2.3",
    "installed_root": installed_root,
  }
  @fsx.write_to_file(
    @pathx.join(active_packs_root(root), "sample.json"),
    active.stringify(),
    create=0o644,
  )
  let canonical_root = @fs.realpath(root)
  let identity = Ref(
    (
      {
        "contract": "sample.runtime-identity.v1",
        "pack_id": "sample",
        "version": "1.2.3",
        "workspace_ref": pack_app_workspace_ref(canonical_root),
      } : Json),
  )
  let server = @http.Server::Server(@socket.Addr::parse("127.0.0.1:0"))
  defer server.close()
  @async.with_task_group(group => {
    group.spawn_bg(
      () => {
        server.run_forever(
          (request, _, conn) => send_json(conn, request.meth, identity.val),
          allow_failure=true,
        )
      },
      no_wait=true,
      allow_failure=true,
    )
    @async.sleep(20)
    let service_url = "http://127.0.0.1:\{server.addr.port()}"
    let runtime : Json = {
      "contract": "moonsuite.pack-app-runtime.v1",
      "pack_id": "sample",
      "app_url": service_url + "/apps/sample",
      "service_url": service_url,
    }
    @fsx.write_to_file(
      @pathx.join(pack_apps_state_root(root), "sample.json"),
      runtime.stringify(),
      create=0o644,
    )
    assert_true(configured_pack_app(root, "sample") is Some(_))
    let catalog = installed_pack_apps(root)
    assert_eq(json_int(catalog, "configured_count", default=0), 1)
    identity.val = {
      "contract": "sample.runtime-identity.v1",
      "pack_id": "sample",
      "version": "1.2.4",
      "workspace_ref": pack_app_workspace_ref(canonical_root),
    }
    assert_true(configured_pack_app(root, "sample") is None)
    let wrong_version_catalog = installed_pack_apps(root)
    assert_eq(json_int(wrong_version_catalog, "configured_count", default=0), 0)
    identity.val = {
      "contract": "sample.runtime-identity.v1",
      "pack_id": "sample",
      "version": "1.2.3",
      "workspace_ref": pack_app_workspace_ref("/tmp/another-workspace"),
    }
    assert_true(configured_pack_app(root, "sample") is None)
    let wrong_workspace_catalog = installed_pack_apps(root)
    assert_eq(
      json_int(wrong_workspace_catalog, "configured_count", default=0),
      0,
    )
  })
  @fs.rmdir(root, recursive=true)
}

///|
test "template catalog digest rejects tampered presentation and ceilings" {
  let zero = "sha256:" +
    "0000000000000000000000000000000000000000000000000000000000000000"
  let unsigned = "{\"catalog_digest\":\"" +
    zero +
    "\",\"title\":\"Original\",\"ceilings\":{\"external_effect\":false}}"
  let digest = "sha256:" +
    @crypto.bytes_to_hex_string(
      @crypto.sha256(@encoding/utf8.encode(unsigned).to_fixedarray()),
    )
  let signed = unsigned.replace(old=zero, new=digest)
  let catalog = @json.parse(signed)
  assert_true(template_catalog_digest_valid(signed, catalog))
  let tampered = signed.replace(old="Original", new="Changed")
  assert_false(template_catalog_digest_valid(tampered, @json.parse(tampered)))
}

///|
test "pack presentation keeps entrypoint safe and appends strict launch context" {
  let record = pack_app_runtime_record(
    { "pack_id": "sample", "version": "1.0.0" },
    {
      "id": "sample",
      "app_presentation": {
        "contract_id": "moonsuite.pack-presentation.v1",
        "icon": "S",
        "surface": "infinite-canvas",
        "primary_action_label": "Open map",
        "launch_query": [{ "key": "seed", "value": "20260727" }],
      },
      "app_entrypoints": [{ "id": "app", "path": "/index.html" }],
    },
    {
      "contract": "moonsuite.pack-app-runtime.v1",
      "pack_id": "sample",
      "app_url": "http://127.0.0.1:4300/index.html",
      "service_url": "http://127.0.0.1:4300",
    },
  )
  guard record is Some(record) else { fail("expected configured app") }
  assert_eq(
    json_string(record, "launch_url", default=""),
    "/pack-apps/sample/?seed=20260727",
  )
  assert_eq(json_string(record, "presentation_icon", default=""), "S")
  assert_true(
    pack_app_runtime_record(
      { "pack_id": "sample" },
      {
        "id": "sample",
        "app_presentation": {
          "contract_id": "moonsuite.pack-presentation.v1",
          "icon": "S",
          "surface": "infinite-canvas",
          "primary_action_label": "Open map",
          "launch_query": [{ "key": "next", "value": "https://bad" }],
        },
        "app_entrypoints": [{ "id": "app", "path": "/index.html" }],
      },
      {
        "contract": "moonsuite.pack-app-runtime.v1",
        "pack_id": "sample",
        "app_url": "http://127.0.0.1:4300/index.html",
        "service_url": "http://127.0.0.1:4300",
      },
    )
    is None,
  )
}

///|
test "pack runtime presentation is used when typed install omits the optional manifest field" {
  let record = pack_app_runtime_record(
    { "pack_id": "sample", "version": "1.0.0" },
    {
      "id": "sample",
      "app_entrypoints": [{ "id": "app", "path": "/index.html" }],
    },
    {
      "contract": "moonsuite.pack-app-runtime.v1",
      "pack_id": "sample",
      "app_url": "http://127.0.0.1:4300/index.html",
      "service_url": "http://127.0.0.1:4300",
      "app_presentation": {
        "contract_id": "moonsuite.pack-presentation.v1",
        "icon": "F",
        "surface": "paiwork",
        "primary_action_label": "Open PaiWork",
      },
    },
  )
  guard record is Some(record) else { fail("expected configured app") }
  assert_eq(json_string(record, "presentation_icon", default=""), "F")
  assert_eq(json_string(record, "presentation_surface", default=""), "paiwork")
  assert_eq(
    json_string(record, "primary_action_label", default=""),
    "Open PaiWork",
  )
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
