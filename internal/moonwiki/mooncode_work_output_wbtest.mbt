///|
fn output_test_descriptor() -> Json {
  {
    "state": "ready",
    "session_id": "S",
    "workspace": { "id": "W", "root_path": "/book" },
    "original_command": { "command_id": "C0" },
    "original_result": {
      "command_id": "C0",
      "output_refs": [
        { "command_id": "C0", "path": "result/a.md", "evidence_id": "E0" },
      ],
    },
    "continuations": [
      {
        "command_id": "C1",
        "admission": "accepted",
        "input_status": "verified",
        "source": { "original_command_id": "C0", "session_id": "S" },
        "output_refs": [
          { "command_id": "C1", "path": "result/a.md", "evidence_id": "E1" },
        ],
      },
    ],
  }
}

///|
test "output reference projection separates original and followup even with identical paths" {
  for (command, evidence) in [("C0", "E0"), ("C1", "E1")] {
    let hint : Json = {
      "command_id": command,
      "path": "result/a.md",
      "evidence_id": evidence,
    }
    let result = mooncode_work_output_projection(output_test_descriptor(), hint)
    assert_eq(mooncode_output_text(result, "state"), "ready")
    assert_eq(mooncode_output_text(result, "command_id"), command)
    assert_eq(
      mooncode_output_text(result, "content_scope"),
      "current_workspace_bytes",
    )
    assert_eq(
      mooncode_work_output_projection(output_test_descriptor(), hint),
      result,
    )
  }
}

///|
test "output reference rejects unrelated commands forged refs and path escapes" {
  for
    (command, path, evidence) in [
      ("C2", "result/a.md", "E1"),
      ("C0", "result/a.md", "E1"),
      ("C1", "result/a.md", "E0"),
      ("C1", "other.md", "E1"),
      ("C1", "../secret", "E1"),
      ("C1", "/secret", "E1"),
      ("C1", "a\\b", "E1"),
      ("C1", "a/./b", "E1"),
      ("C1", "a//b", "E1"),
      ("C1", "result/a.md", ""),
    ] {
    assert_eq(
      mooncode_output_text(
        mooncode_work_output_projection(output_test_descriptor(), {
          "command_id": command,
          "path": path,
          "evidence_id": evidence,
        }),
        "state",
      ),
      "unavailable",
    )
  }
}

///|
test "output missing native evidence and invalid continuation inputs never become ready" {
  let original = output_test_descriptor()
  let hint : Json = {
    "command_id": "C1",
    "path": "result/a.md",
    "evidence_id": "E1",
  }
  guard original is Object(fields) else { fail("fixture") }
  for key in ["admission", "input_status", "source"] {
    let records = mooncode_output_items(original, "continuations")
    guard records[0] is Object(record) else { fail("fixture") }
    let changed = record.copy()
    changed[key] = Json::null()
    let modified = fields.copy()
    modified["continuations"] = [Json::object(changed)].to_json()
    assert_eq(
      mooncode_output_text(
        mooncode_work_output_projection(Json::object(modified), hint),
        "state",
      ),
      "unavailable",
    )
  }
  let unavailable = fields.copy()
  unavailable["state"] = "runtime_unavailable".to_json()
  assert_eq(
    mooncode_output_text(
      mooncode_work_output_projection(Json::object(unavailable), hint),
      "state",
    ),
    "unavailable",
  )
  assert_eq(
    mooncode_work_output_projection(original, Json::null()),
    Json::null(),
  )
}
