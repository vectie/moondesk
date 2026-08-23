///|
fn sandbox_receipt_fixture() -> Json {
  {
    "backend": "MicroVm",
    "enforcement": "Enforced",
    "cleanup_verified": true,
    "unverified_limits": [],
    "approval_digest": "a".repeat(64),
    "command_digest": "b".repeat(64),
    "profile_digest": "c".repeat(64),
    "changed_paths": ["src/main.mbt", "old.txt"],
    "changes": [
      {
        "relative_path": "src/main.mbt",
        "change": "Modified",
        "before": {
          "relative_path": "src/main.mbt",
          "kind": "RegularFile",
          "size_bytes": 10,
          "fingerprint": "d".repeat(64),
        },
        "after": {
          "relative_path": "src/main.mbt",
          "kind": "RegularFile",
          "size_bytes": 12,
          "fingerprint": "e".repeat(64),
        },
      },
      {
        "relative_path": "old.txt",
        "change": "Removed",
        "before": {
          "relative_path": "old.txt",
          "kind": "RegularFile",
          "size_bytes": 4,
          "fingerprint": "f".repeat(64),
        },
        "after": null,
      },
    ],
    "artifacts": ["reports/check.json"],
    "retention_id": "retention-1",
    "network": "Deny",
    "limits": {
      "wall_clock_ms": 60000,
      "cpu_seconds": 20,
      "memory_mib": 512,
      "disk_mib": 256,
      "processes": 32,
      "output_bytes": 1000000,
    },
  }
}

///|
test "sandbox evidence exposes only sanitized receipt and promotable files" {
  let receipt = decode_mooncode_sandbox_receipt(sandbox_receipt_fixture()).unwrap()
  assert_eq(receipt.backend, "MicroVm")
  assert_eq(receipt.network, "Deny")
  assert_eq(receipt.changes.length(), 2)
  assert_true(receipt.changes[0].promotable)
  assert_false(receipt.changes[1].promotable)
  assert_true(receipt.promotion_ready())
  assert_eq(receipt.review_key(), "retention-1:" + "b".repeat(64))
  assert_eq(receipt.artifacts, ["reports/check.json"])
}

///|
test "sandbox evidence rejects paths, mismatched inventory, digests, and unrestricted network" {
  for
    mutation in [
      fn(fields : Map[String, Json]) {
        fields["changed_paths"] = ["../host-secret"]
      },
      fn(fields : Map[String, Json]) {
        fields["approval_digest"] = "not-a-digest"
      },
      fn(fields : Map[String, Json]) { fields["network"] = "Unrestricted" },
    ] {
    guard sandbox_receipt_fixture() is Object(fields) else {
      fail("expected fixture object")
    }
    mutation(fields)
    assert_true(decode_mooncode_sandbox_receipt(Json::object(fields)) is Err(_))
  }
}

///|
test "work decoding marks malformed sandbox receipts as invalid and non-promotable" {
  let payload : Json = {
    "item_id": "work",
    "status": "done",
    "steps": [
      {
        "item_id": "tool",
        "command_id": "command",
        "summary": "sandbox result",
        "evidence": {
          "kind": "tool",
          "sandbox_evidence": {
            "backend": "MicroVm",
            "enforcement": "Enforced",
            "retention_id": "/private/secret",
          },
        },
      },
    ],
  }
  let work = decode_work_codec(payload, "session", "command").unwrap().value
  assert_eq(work.evidence.length(), 1)
  assert_true(work.evidence[0].sandbox_receipt is None)
  assert_true(work.evidence[0].sandbox_receipt_invalid)
}

///|
test "empty projected sandbox evidence remains absent instead of alarming" {
  let payload : Json = {
    "item_id": "work",
    "status": "done",
    "steps": [
      {
        "item_id": "ordinary-tool",
        "command_id": "command",
        "summary": "ordinary result",
        "evidence": { "kind": "tool", "sandbox_evidence": {} },
      },
    ],
  }
  let work = decode_work_codec(payload, "session", "command").unwrap().value
  assert_eq(work.evidence.length(), 1)
  assert_true(work.evidence[0].sandbox_receipt is None)
  assert_false(work.evidence[0].sandbox_receipt_invalid)
}
