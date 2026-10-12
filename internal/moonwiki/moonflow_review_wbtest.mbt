///|
fn review_test_principal(id : String, kind? : String = "human") -> Json {
  {
    "contract_id": "moonsuite.principal-ref.v1",
    "principal_id": id,
    "kind": kind,
    "issuer": "synthetic-review-host",
    "subject": id,
  }
}

///|
test "review host mapping uses exact authenticated account Book and existing independent human membership" {
  let principal = review_test_principal("reviewer")
  let account : Json = {
    "account_id": "account-reviewer",
    "subject_ref": "subject-reviewer",
    "state": "Active",
  }
  let binding : Json = {
    "account_id": "account-reviewer",
    "subject_ref": "subject-reviewer",
    "workspace_id": "book",
    "principal": principal,
  }
  let mapping : Json = {
    "contract_id": "moondesk.review-principal-map.v1",
    "identity_endpoint": "http://127.0.0.1:48939",
    "bindings": [binding],
  }
  assert_eq(
    moonflow_review_mapped_principal(
      mapping, "http://127.0.0.1:48939", account, "book",
    ),
    principal,
  )
  for
    (endpoint, selected, identity) in [
      ("http://other", "book", account),
      ("http://127.0.0.1:48939", "other-book", account),
      (
        "http://127.0.0.1:48939",
        "book",
        ({ "account_id": "claimed", "subject_ref": "subject-reviewer" } : Json),
      ),
    ] {
    assert_true(
      try {
        ignore(
          moonflow_review_mapped_principal(
            mapping, endpoint, identity, selected,
          ),
        )
        false
      } catch {
        _ => true
      },
    )
  }
  let review : Json = {
    "assigned_reviewer": principal,
    "submitted_by": review_test_principal("submitter"),
  }
  let member : Json = {
    "principal": principal,
    "status": "active",
    "roles": ["reviewer"],
  }
  let snapshot : Json = { "payload": { "memberships": [member] } }
  assert_true(moonflow_review_authorized(snapshot, review, principal))
  assert_false(
    moonflow_review_authorized(snapshot, review, review_test_principal("other")),
  )
  assert_false(
    moonflow_review_authorized(
      snapshot,
      review,
      review_test_principal("reviewer", kind="service"),
    ),
  )
  assert_false(
    moonflow_review_authorized(
      { "payload": { "memberships": [] } },
      review,
      principal,
    ),
  )
  assert_false(
    moonflow_review_authorized(
      snapshot,
      { "assigned_reviewer": principal, "submitted_by": principal },
      principal,
    ),
  )
  for
    bad in [
      (
        { "principal": principal, "status": "suspended", "roles": ["reviewer"] } :
        Json),
      ({ "principal": principal, "status": "active", "roles": ["owner"] } : Json),
    ] {
    assert_false(
      moonflow_review_authorized(
        { "payload": { "memberships": [bad] } },
        review,
        principal,
      ),
    )
  }
}

///|
test "review payload is exact bounded and excludes browser identity commands and grants" {
  let payload : Json = {
    "identity": {
      "workspace_id": "book",
      "run_id": "run",
      "work_item_id": "item",
      "attempt_id": "attempt",
      "result_id": "result",
      "action_id": "action",
      "artifact_index": 1,
    },
    "sha256": "sha256:" + "a".repeat(64),
    "record_digest": "sha256:" + "b".repeat(64),
    "review_id": "review",
    "expected_head": "sha256:" + "c".repeat(64),
    "mutation_id": "mutation",
    "action": "approved",
    "notes": "Exact artifact inspected",
  }
  assert_true(moonflow_review_request_valid(payload))
  for
    key in [
      "actor", "roles", "principal", "executable", "args", "grant", "membership",
      "evidence_ref", "recorded_at",
    ] {
    let injected = @json.parse(payload.stringify())
    if injected is Object(fields) {
      fields[key] = "browser-claim"
    }
    assert_false(moonflow_review_request_valid(injected), msg=key)
  }
  for
    (key, value) in [
      ("notes", ""),
      ("notes", "x".repeat(16385)),
      ("action", "review-outcome"),
      ("action", "accept"),
      ("action", "add-member"),
      ("mutation_id", "../escape"),
    ] {
    let changed = @json.parse(payload.stringify())
    if changed is Object(fields) {
      fields[key] = value.to_json()
    }
    assert_false(moonflow_review_request_valid(changed))
  }
}
