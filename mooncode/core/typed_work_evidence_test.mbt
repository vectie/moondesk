///|
fn typed_evidence_fixture() -> Json {
  {
    "kind": "mooncode-conversation",
    "protocol": "mooncode.v1",
    "contract_id": "moonsuite-conversation.v2",
    "session_id": "session-a",
    "revision": 1,
    "last_sequence": 9,
    "turns": [
      {
        "kind": "mooncode-conversation-turn",
        "turn_id": "turn-package",
        "client_turn_id": "client-package",
        "command_id": "command-package",
        "ordinal": 0,
        "status": "done",
        "user": null,
        "work": {
          "item_id": "work-package",
          "status": "done",
          "summary": "Packaged",
          "steps": [
            {
              "item_id": "other",
              "command_id": "other-command",
              "source_kind": "package_manifest",
              "summary": "stale manifest",
              "evidence": { "kind": "artifact", "path": "stale.json" },
            },
            {
              "item_id": "artifact",
              "command_id": "command-package",
              "source_kind": "artifact",
              "summary": "unrelated output",
              "evidence": { "kind": "artifact", "path": "notes.txt" },
            },
            {
              "item_id": "manifest",
              "command_id": "command-package",
              "source_kind": "package_manifest",
              "summary": "manifest",
              "evidence": { "kind": "artifact", "path": "package.json" },
            },
            {
              "item_id": "test",
              "command_id": "command-package",
              "source_kind": "test_result",
              "summary": "tests",
              "evidence": { "kind": "test", "exit_code": 0, "output": "ok" },
            },
            {
              "item_id": "accept",
              "command_id": "command-package",
              "source_kind": "receipt.accept",
              "summary": "accepted",
              "evidence": { "kind": "artifact" },
            },
            {
              "item_id": "built",
              "command_id": "command-package",
              "source_kind": "runtime.package_built",
              "summary": "built",
              "evidence": { "kind": "artifact", "path": "Demo.app" },
            },
            {
              "item_id": "verified",
              "command_id": "command-package",
              "source_kind": "runtime.package_verified",
              "summary": "verified",
              "evidence": { "kind": "artifact", "path": "Demo.app" },
            },
          ],
          "live": { "summary": "finalizing", "future": true },
          "future_work": true,
        },
        "assistant": {
          "item_id": "assistant",
          "role": "assistant",
          "content": "Ready for review",
          "status": "done",
        },
      },
    ],
  }
}

///|
test "typed package review is exact, ordered, and lossless at the codec boundary" {
  guard @core.decode_mooncode_conversation(typed_evidence_fixture())
    is Supported(conversation) else {
    fail("decode")
  }
  let turn = conversation.turns[0]
  assert_eq(turn.work.evidence.length(), 7)
  assert_true(turn.work.evidence[0].kind is @core.PackageManifest)
  assert_true(turn.work.evidence[1].kind is @core.Artifact)
  let encoded = @core.encode_mooncode_conversation(conversation).stringify()
  assert_true(encoded.contains("\"future_work\":true"))
  assert_true(encoded.contains("\"future\":true"))
  assert_true(encoded.contains("\"stale manifest\""))
}
