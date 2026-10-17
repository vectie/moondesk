///|
/// Exact prepared response from the synthetic real-MoonBook CLI acceptance fixture.
/// This embedded wire contract has no runtime dependency on the capture directory.
fn portable_book_actual_wire_fixture() -> Json {
  let wire =
    #|{
    #|  "workspace_id": "book-export-fixture",
    #|  "expected_library": "/tmp/desk-agent-export/acceptance/books",
    #|  "export_id": "0123456789abcdef0123456789abcdef",
    #|  "path": "book/agents/desk-0123456789abcdef0123456789abcdef/package.moonbook-agent",
    #|  "inspection": {
    #|    "contract": "moonbook.agent_bundle.v1",
    #|    "agent_id": "moondesk-agent-export-.816.363a3d8b",
    #|    "version": "1.0.0",
    #|    "book_revision": "sha256:fa6342b13df359aa1b201dfaf47c3266be00d95ab0febfbfd6dc146b99ab9c82",
    #|    "bundle_digest": "sha256:e61b138509352c782f3751b79cd77bdb6436ae7deabf087005b7affd17a111cc",
    #|    "file_count": 10,
    #|    "total_bytes": 525984,
    #|    "files": [
    #|      {
    #|        "path": "USER.md",
    #|        "role": "preference",
    #|        "digest": "sha256:24f1c6bcf15801c5d12ca319da4cc7a6a9acd300385c988591a26e1c1f261f4d",
    #|        "size_bytes": 51,
    #|        "review_status": "accepted",
    #|        "sensitivity": "user-private"
    #|      },
    #|      {
    #|        "path": "IDENTITY.md",
    #|        "role": "identity",
    #|        "digest": "sha256:1fd6b3c6f7a0351cca273dd35ca4c942656076fd7483bd2d28cdffc54c153e6e",
    #|        "size_bytes": 50,
    #|        "review_status": "accepted",
    #|        "sensitivity": "book-exportable"
    #|      },
    #|      {
    #|        "path": "keeper/USER.md",
    #|        "role": "preference",
    #|        "digest": "sha256:3508842cc80a7fdab2394112ee316a193e7babc51e0b260f8e9a50db5f778be7",
    #|        "size_bytes": 118,
    #|        "review_status": "accepted",
    #|        "sensitivity": "user-private"
    #|      },
    #|      {
    #|        "path": "keeper/MEMORY.md",
    #|        "role": "memory",
    #|        "digest": "sha256:91b23a04479a31a19b67c56ceba294ec51f1d35482cbedd8722cfbe2d0bf73ad",
    #|        "size_bytes": 125,
    #|        "review_status": "accepted",
    #|        "sensitivity": "book-exportable"
    #|      },
    #|      {
    #|        "path": "keeper/POLICY.md",
    #|        "role": "policy",
    #|        "digest": "sha256:9d514cd9fb9b22fb3377d9e6204f43544f500895740f711c39cf624aa022cbdd",
    #|        "size_bytes": 266,
    #|        "review_status": "accepted",
    #|        "sensitivity": "book-exportable"
    #|      },
    #|      {
    #|        "path": "wiki/sources/example.md",
    #|        "role": "knowledge",
    #|        "digest": "sha256:07b65742558b067690f4be43501878ffc8cd0c555f05d500a3c711e1c204be78",
    #|        "size_bytes": 327,
    #|        "review_status": "accepted",
    #|        "sensitivity": "book-exportable"
    #|      },
    #|      {
    #|        "path": "wiki/concepts/accepted.md",
    #|        "role": "knowledge",
    #|        "digest": "sha256:bce9d3c3e1ff18d39ab0f8781c99029a9bfa02ea85f4e8a8e441065d5948773c",
    #|        "size_bytes": 236,
    #|        "review_status": "accepted",
    #|        "sensitivity": "book-exportable"
    #|      },
    #|      {
    #|        "path": "memory/procedures/accepted.md",
    #|        "role": "procedure",
    #|        "digest": "sha256:128841cb73e315d8afcf8929d53dcb153e70a77d50e8c11ac7e487078d0f386b",
    #|        "size_bytes": 80,
    #|        "review_status": "accepted",
    #|        "sensitivity": "book-exportable"
    #|      },
    #|      {
    #|        "path": "portable/outputs.manifest.v1.json",
    #|        "role": "artifact",
    #|        "digest": "sha256:480431064260b5f18f1b539afbec248732127061ebcd74b9aafd68377c394900",
    #|        "size_bytes": 443,
    #|        "review_status": "accepted",
    #|        "sensitivity": "book-exportable"
    #|      },
    #|      {
    #|        "path": "portable/outputs/output-0/result.bin",
    #|        "role": "artifact",
    #|        "digest": "sha256:55854a6b13148e4237a428566701ec6655e85b94bc36395a1d02c7e9f9cceacf",
    #|        "size_bytes": 524288,
    #|        "review_status": "accepted",
    #|        "sensitivity": "book-exportable"
    #|      }
    #|    ],
    #|    "exclusions": [
    #|      {
    #|        "path": "memory/procedures/candidate.md",
    #|        "reason": "content is not accepted for agent activation"
    #|      }
    #|    ],
    #|    "compatibility": {
    #|      "moonclaw_contract": "moonclaw-task-stream.v2",
    #|      "moonfort_contract": "moonfort-artifact.v1",
    #|      "moontown_contract": "moontown-standing-goal.v1",
    #|      "moongate_contract": "moongate-route.v1",
    #|      "required_capabilities": [
    #|        "workspace.read",
    #|        "workspace.relative-paths",
    #|        "artifact.typed-location",
    #|        "sandbox.required-for-executable-artifacts"
    #|      ],
    #|      "dependency_locks": [
    #|        {
    #|          "component": "moonclaw",
    #|          "contract": "moonclaw-task-stream.v2",
    #|          "version_range": ">=2 <3",
    #|          "required": true,
    #|          "capabilities": [
    #|            "durable-turns",
    #|            "general-agent",
    #|            "typed-fragments"
    #|          ],
    #|          "migration": "Upgrade the task-stream adapter before activation.",
    #|          "lock_digest": "sha256:1aeb3c1ca704a11c6a004d06087ba2b5a43f397c7f9cdea5c67a987c2bdecb28"
    #|        },
    #|        {
    #|          "component": "moonfort",
    #|          "contract": "moonfort-artifact.v1",
    #|          "version_range": ">=1 <2",
    #|          "required": true,
    #|          "capabilities": [
    #|            "artifact-receipts",
    #|            "explicit-promotion",
    #|            "isolated-execution"
    #|          ],
    #|          "migration": "Re-run capability trials in a compatible sandbox.",
    #|          "lock_digest": "sha256:e951a6884eb38d636f97e1a2a6060d765be2762f8c5c06462908e0f239bec08f"
    #|        },
    #|        {
    #|          "component": "moontown",
    #|          "contract": "moontown-standing-goal.v1",
    #|          "version_range": ">=1 <2",
    #|          "required": false,
    #|          "capabilities": [
    #|            "leases",
    #|            "standing-goals",
    #|            "result-delivery"
    #|          ],
    #|          "migration": "Import watch intent disabled until a compatible scheduler is available.",
    #|          "lock_digest": "sha256:53918166ec27048146d8aac61d510c3591777551662ffc0914a417bbe6fa4278"
    #|        },
    #|        {
    #|          "component": "moongate",
    #|          "contract": "moongate-route.v1",
    #|          "version_range": ">=1 <2",
    #|          "required": true,
    #|          "capabilities": [
    #|            "cost-metrics",
    #|            "model-routing",
    #|            "token-metrics",
    #|            "latency-metrics"
    #|          ],
    #|          "migration": "Re-evaluate adopted capabilities on a compatible route.",
    #|          "lock_digest": "sha256:ce1d1739d4bb3bb441f0e6e37293cfb654163240b9420a82e5022e39beafe0dc"
    #|        }
    #|      ]
    #|    },
    #|    "export_policy": {
    #|      "accepted_knowledge_only": true,
    #|      "include_working_memory": false,
    #|      "include_runtime_state": false,
    #|      "include_credentials": false,
    #|      "relative_paths_only": true
    #|    },
    #|    "memory_policy": {
    #|      "contract": "moonbook.memory_policy.v1",
    #|      "active_entry_limit": 12,
    #|      "preference_entry_limit": 10,
    #|      "working_entry_limit": 7,
    #|      "active_character_limit": 1800,
    #|      "preference_character_limit": 1400,
    #|      "working_character_limit": 2400
    #|    },
    #|    "memory_metrics": {
    #|      "admitted": 4,
    #|      "rejected": 1,
    #|      "deduplicated": 0,
    #|      "expired": 0,
    #|      "promoted": 1,
    #|      "exported": 4
    #|    }
    #|  },
    #|  "verification": {
    #|    "ok": true,
    #|    "agent_id": "moondesk-agent-export-.816.363a3d8b",
    #|    "version": "1.0.0",
    #|    "bundle_digest": "sha256:e61b138509352c782f3751b79cd77bdb6436ae7deabf087005b7affd17a111cc",
    #|    "checked_file_count": 10,
    #|    "issues": []
    #|  },
    #|  "source": {
    #|    "contract": "moonbook.portable_source.v1",
    #|    "bundle_contract": "moonbook.agent_bundle.v1",
    #|    "agent_id": "moondesk-agent-export-.816.363a3d8b",
    #|    "agent_version": "1.0.0",
    #|    "book_revision": "sha256:fa6342b13df359aa1b201dfaf47c3266be00d95ab0febfbfd6dc146b99ab9c82",
    #|    "bundle_digest": "sha256:e61b138509352c782f3751b79cd77bdb6436ae7deabf087005b7affd17a111cc",
    #|    "package_filename": "package.moonbook-agent",
    #|    "package_size_bytes": 707957,
    #|    "package_sha256": "sha256:7de70a86fa3bb888d1c5db2ec868334f4f24bf57fb9c32c02083e30ca635c6c0",
    #|    "file_count": 10,
    #|    "total_decoded_bytes": 525984,
    #|    "outputs_manifest_path": "portable/outputs.manifest.v1.json",
    #|    "outputs_manifest_digest": "sha256:480431064260b5f18f1b539afbec248732127061ebcd74b9aafd68377c394900",
    #|    "included_output_count": 1,
    #|    "reference_only_count": 0,
    #|    "transport": "local_file"
    #|  }
    #|}
  try! @json.parse(wire)
}

///|
#warnings("-alert_unstable")
test "portable Book decodes and renders unchanged real pack wire proof" {
  let wire = portable_book_actual_wire_fixture()
  let library = handoff_text(wire, "expected_library")
  let workspace = handoff_text(wire, "workspace_id")
  let id = handoff_text(wire, "export_id")
  guard portable_book_decode_prepared(wire, library, workspace, id)
    is Some(prepared) else {
    fail("Real MoonBook prepared response failed UI validation")
  }
  assert_eq(prepared.inspection.file_count, 10)
  assert_eq(prepared.source.package_size_bytes, 707957)
  assert_eq(prepared.source.total_decoded_bytes, 525984)
  assert_true(
    prepared.inspection.files.any(file => {
      file.path == "portable/outputs/output-0/result.bin" &&
      file.size_bytes == 524288
    }),
  )
  let state = {
    ..portable_book_test_ready(),
    library,
    workspace,
    version: prepared.inspection.version,
    paths: ["outputs/result.bin"],
  }
  let (pending, effect) = reduce_portable_book(state, Prepare(id))
  assert_true(
    effect is PreparePortablePackage(0, 1, _, "1.0.0", ["outputs/result.bin"]),
  )
  let (ready, effect) = reduce_portable_book(pending, Received(0, 1, Ok(wire)))
  assert_true(effect is NoPortableEffect)
  assert_true(ready.prepared is Some(_))
  assert_eq(ready.error, "")
  let html = @rabbita.render_to_string(
    @rabbita.static_cell(render_portable_book_inspection(prepared, true)),
  )
  assert_eq(
    html.split("data-testid=\"portable-book-member\"").count(),
    prepared.inspection.file_count + 1,
  )
  assert_eq(
    html.split("data-testid=\"portable-book-exclusion\"").count(),
    prepared.inspection.exclusions.length() + 1,
  )
  for file in prepared.inspection.files {
    assert_true(html.contains(file.path))
    assert_true(html.contains(file.digest))
    assert_true(html.contains("Role: " + file.role))
    assert_true(html.contains("Review status: " + file.review_status))
    assert_true(html.contains("Sensitivity: " + file.sensitivity))
    assert_true(html.contains("Size: \{file.size_bytes} bytes"))
  }
  assert_true(html.contains("Contains user-private content: 2 member(s)"))
  assert_true(html.contains("memory/procedures/candidate.md"))
  assert_true(html.contains("content is not accepted for agent activation"))
  assert_true(html.contains("707957 bytes"))
  assert_true(html.contains("data-testid=\"portable-book-download\""))
  assert_true(
    html.contains(
      "digest=" + @desk.url_component(prepared.source.package_sha256),
    ),
  )
  assert_true(html.contains("/api/workspaces/" + workspace + "/artifact?"))
}

///|
/// The discovery envelope here is deliberately derived from the unchanged
/// prepared capture; it is not claimed to be a separately captured GET reply.
test "portable Book catalog derived from real prepared wire admits prefixed digest" {
  let wire = portable_book_actual_wire_fixture()
  let library = handoff_text(wire, "expected_library")
  let workspace = handoff_text(wire, "workspace_id")
  let id = handoff_text(wire, "export_id")
  guard portable_book_decode_prepared(wire, library, workspace, id)
    is Some(prepared) else {
    fail("Real MoonBook prepared response failed UI validation")
  }
  let catalog : Json = {
    "workspace_id": workspace,
    "expected_library": library,
    "available": true,
    "message": "Derived from the real prepared wire fixture",
    "exports": [
      {
        "export_id": id,
        "path": prepared.path,
        "version": prepared.inspection.version,
        "package_sha256": prepared.source.package_sha256,
        "package_size_bytes": prepared.source.package_size_bytes,
      },
    ],
  }
  let (loading, _) = reduce_portable_book(
    init_portable_book(),
    BindPortable(true, library, workspace),
  )
  let (loaded, effect) = reduce_portable_book(
    loading,
    Received(1, 1, Ok(catalog)),
  )
  assert_true(effect is NoPortableEffect)
  assert_true(loaded.available)
  assert_eq(loaded.exports.length(), 1)
  assert_eq(loaded.exports[0].package_sha256, prepared.source.package_sha256)
  let (inspecting, effect) = reduce_portable_book(loaded, InspectSaved(id))
  assert_true(effect is InspectPortablePackage(1, 2, _))
  let (inspected, effect) = reduce_portable_book(
    inspecting,
    Received(1, 2, Ok(wire)),
  )
  assert_true(effect is NoPortableEffect)
  assert_true(inspected.prepared is Some(_))
}
