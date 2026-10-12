// Generated real CLI projection and event fixtures.

///|
fn owner_cli_ready_projection() -> Json raise {
  @json.parse(
    (
      #|{
      #|  "protocol": "moonflow.run-projection.v3",
      #|  "run_id": "owner-fixture-r1",
      #|  "book_id": "book-selected",
      #|  "declaration_revision": "r1",
      #|  "source_digest": "sha256:fixture-r1",
      #|  "last_sequence": 2,
      #|  "outcome": "ready",
      #|  "runnable_item_ids": [
      #|    "research"
      #|  ],
      #|  "items": [
      #|    {
      #|      "work_item_id": "research",
      #|      "declaration_id": "research",
      #|      "product_id": "moonwiki",
      #|      "requested_authority": "observe",
      #|      "acceptance_criteria": [
      #|        "Evidence is reviewed"
      #|      ],
      #|      "operation": "query-evidence",
      #|      "input_contracts": [
      #|        "fixture.input.v1"
      #|      ],
      #|      "output_contracts": [
      #|        "fixture.output.v1"
      #|      ],
      #|      "required_claim": "research-evidence",
      #|      "input_artifacts": [
      #|        "evidence/input.json"
      #|      ],
      #|      "timeout_ms": 1000,
      #|      "depends_on": [],
      #|      "status": "ready",
      #|      "attempt_count": 0,
      #|      "request_id": "",
      #|      "result_id": "",
      #|      "active_attempt_id": "",
      #|      "idempotency_key": "",
      #|      "external_job_id": "",
      #|      "attempt_status": "",
      #|      "input_digest": "",
      #|      "output_digest": "",
      #|      "error_kind": "",
      #|      "compensable": false,
      #|      "blocker": "",
      #|      "acceptance_review_id": "",
      #|      "acceptance_review_artifact": "",
      #|      "acceptance_reviewer_id": "",
      #|      "artifacts": [],
      #|      "approvals": []
      #|    }
      #|  ],
      #|  "owner_summary": {
      #|    "contract_id": "moonflow.owner-summary.v1",
      #|    "run_id": "owner-fixture-r1",
      #|    "book_id": "book-selected",
      #|    "declaration_revision": "r1",
      #|    "source_digest": "sha256:fixture-r1",
      #|    "last_sequence": 2,
      #|    "last_event_id": "event-2",
      #|    "recorded_at": "2026-10-06T06:00:00Z",
      #|    "outcome": "ready",
      #|    "outcome_label": "Work is ready for governed execution",
      #|    "next_action": "Continue through the existing execution controls",
      #|    "next_role": "run operator",
      #|    "actions": [
      #|      {
      #|        "work_item_id": "research",
      #|        "product_id": "moonwiki",
      #|        "status": "ready",
      #|        "action": "Continue through the existing execution controls",
      #|        "next_role": "run operator",
      #|        "reasons": [
      #|          "Dependencies are accepted; execution remains subject to existing authority checks"
      #|        ],
      #|        "depends_on": []
      #|      }
      #|    ],
      #|    "evidence": [
      #|      {
      #|        "work_item_id": "research",
      #|        "attempt_id": "",
      #|        "result_id": "",
      #|        "output_digest": "",
      #|        "artifacts": [],
      #|        "review_id": "",
      #|        "review_artifact": "",
      #|        "reviewer_id": ""
      #|      }
      #|    ],
      #|    "acceptance_boundary": "Internal work acceptance does not establish customer approval, delivery acceptance or payment"
      #|  },
      #|  "owner_summary_observation": "event-head-matched"
      #|}
    ),
  )
}

///|
fn owner_cli_ready_events() -> Json raise {
  @json.parse(
    (
      #|[
      #|  {
      #|    "sequence": 0,
      #|    "event_id": "event-0",
      #|    "run_id": "owner-fixture-r1",
      #|    "work_item_id": "",
      #|    "kind": "run-created",
      #|    "product_id": "moonwiki",
      #|    "declaration_id": "",
      #|    "book_id": "book-selected",
      #|    "declaration_revision": "r1",
      #|    "source_digest": "sha256:fixture-r1",
      #|    "requested_authority": "observe",
      #|    "acceptance_criteria": [
      #|      "Evidence is reviewed"
      #|    ],
      #|    "operation": "query-evidence",
      #|    "input_contracts": [
      #|      "fixture.input.v1"
      #|    ],
      #|    "output_contracts": [
      #|      "fixture.output.v1"
      #|    ],
      #|    "required_claim": "research-evidence",
      #|    "input_artifacts": [
      #|      "evidence/input.json"
      #|    ],
      #|    "timeout_ms": 1000,
      #|    "request_id": "request-1",
      #|    "result_id": "",
      #|    "attempt_id": "attempt-1",
      #|    "idempotency_key": "key-1",
      #|    "external_job_id": "",
      #|    "attempt_status": "",
      #|    "input_digest": "sha256:input",
      #|    "output_digest": "",
      #|    "output_artifacts": [],
      #|    "error_kind": "",
      #|    "compensable": false,
      #|    "depends_on": [],
      #|    "detail": "query-evidence",
      #|    "artifact_id": "",
      #|    "authority_id": "",
      #|    "recorded_at": "2026-10-06T06:00:00Z"
      #|  },
      #|  {
      #|    "sequence": 1,
      #|    "event_id": "event-1",
      #|    "run_id": "owner-fixture-r1",
      #|    "work_item_id": "research",
      #|    "kind": "item-registered",
      #|    "product_id": "moonwiki",
      #|    "declaration_id": "research",
      #|    "book_id": "book-selected",
      #|    "declaration_revision": "r1",
      #|    "source_digest": "sha256:fixture-r1",
      #|    "requested_authority": "observe",
      #|    "acceptance_criteria": [
      #|      "Evidence is reviewed"
      #|    ],
      #|    "operation": "query-evidence",
      #|    "input_contracts": [
      #|      "fixture.input.v1"
      #|    ],
      #|    "output_contracts": [
      #|      "fixture.output.v1"
      #|    ],
      #|    "required_claim": "research-evidence",
      #|    "input_artifacts": [
      #|      "evidence/input.json"
      #|    ],
      #|    "timeout_ms": 1000,
      #|    "request_id": "request-1",
      #|    "result_id": "",
      #|    "attempt_id": "attempt-1",
      #|    "idempotency_key": "key-1",
      #|    "external_job_id": "",
      #|    "attempt_status": "",
      #|    "input_digest": "sha256:input",
      #|    "output_digest": "",
      #|    "output_artifacts": [],
      #|    "error_kind": "",
      #|    "compensable": false,
      #|    "depends_on": [],
      #|    "detail": "query-evidence",
      #|    "artifact_id": "",
      #|    "authority_id": "",
      #|    "recorded_at": "2026-10-06T06:00:00Z"
      #|  },
      #|  {
      #|    "sequence": 2,
      #|    "event_id": "event-2",
      #|    "run_id": "owner-fixture-r1",
      #|    "work_item_id": "research",
      #|    "kind": "item-ready",
      #|    "product_id": "moonwiki",
      #|    "declaration_id": "research",
      #|    "book_id": "book-selected",
      #|    "declaration_revision": "r1",
      #|    "source_digest": "sha256:fixture-r1",
      #|    "requested_authority": "observe",
      #|    "acceptance_criteria": [
      #|      "Evidence is reviewed"
      #|    ],
      #|    "operation": "query-evidence",
      #|    "input_contracts": [
      #|      "fixture.input.v1"
      #|    ],
      #|    "output_contracts": [
      #|      "fixture.output.v1"
      #|    ],
      #|    "required_claim": "research-evidence",
      #|    "input_artifacts": [
      #|      "evidence/input.json"
      #|    ],
      #|    "timeout_ms": 1000,
      #|    "request_id": "request-1",
      #|    "result_id": "",
      #|    "attempt_id": "attempt-1",
      #|    "idempotency_key": "key-1",
      #|    "external_job_id": "",
      #|    "attempt_status": "",
      #|    "input_digest": "sha256:input",
      #|    "output_digest": "",
      #|    "output_artifacts": [],
      #|    "error_kind": "",
      #|    "compensable": false,
      #|    "depends_on": [],
      #|    "detail": "query-evidence",
      #|    "artifact_id": "",
      #|    "authority_id": "",
      #|    "recorded_at": "2026-10-06T06:00:00Z"
      #|  }
      #|]
    ),
  )
}

///|
fn owner_cli_waiting_projection() -> Json raise {
  @json.parse(
    (
      #|{
      #|  "protocol": "moonflow.run-projection.v3",
      #|  "run_id": "owner-fixture-r1",
      #|  "book_id": "book-selected",
      #|  "declaration_revision": "r1",
      #|  "source_digest": "sha256:fixture-r1",
      #|  "last_sequence": 4,
      #|  "outcome": "waiting",
      #|  "runnable_item_ids": [],
      #|  "items": [
      #|    {
      #|      "work_item_id": "research",
      #|      "declaration_id": "research",
      #|      "product_id": "moonwiki",
      #|      "requested_authority": "observe",
      #|      "acceptance_criteria": [
      #|        "Evidence is reviewed"
      #|      ],
      #|      "operation": "query-evidence",
      #|      "input_contracts": [
      #|        "fixture.input.v1"
      #|      ],
      #|      "output_contracts": [
      #|        "fixture.output.v1"
      #|      ],
      #|      "required_claim": "research-evidence",
      #|      "input_artifacts": [
      #|        "evidence/input.json"
      #|      ],
      #|      "timeout_ms": 1000,
      #|      "depends_on": [],
      #|      "status": "waiting",
      #|      "attempt_count": 1,
      #|      "request_id": "request-1",
      #|      "result_id": "",
      #|      "active_attempt_id": "attempt-1",
      #|      "idempotency_key": "key-1",
      #|      "external_job_id": "",
      #|      "attempt_status": "submitted",
      #|      "input_digest": "sha256:input",
      #|      "output_digest": "",
      #|      "error_kind": "",
      #|      "compensable": false,
      #|      "blocker": "Await source evidence",
      #|      "acceptance_review_id": "",
      #|      "acceptance_review_artifact": "",
      #|      "acceptance_reviewer_id": "",
      #|      "artifacts": [],
      #|      "approvals": []
      #|    }
      #|  ],
      #|  "owner_summary": {
      #|    "contract_id": "moonflow.owner-summary.v1",
      #|    "run_id": "owner-fixture-r1",
      #|    "book_id": "book-selected",
      #|    "declaration_revision": "r1",
      #|    "source_digest": "sha256:fixture-r1",
      #|    "last_sequence": 4,
      #|    "last_event_id": "event-4",
      #|    "recorded_at": "2026-10-06T06:00:00Z",
      #|    "outcome": "waiting",
      #|    "outcome_label": "Work is waiting",
      #|    "next_action": "Resolve the wait or obtain the missing evidence",
      #|    "actions": [
      #|      {
      #|        "work_item_id": "research",
      #|        "product_id": "moonwiki",
      #|        "status": "waiting",
      #|        "action": "Resolve the wait or obtain the missing evidence",
      #|        "reasons": [
      #|          "Await source evidence"
      #|        ],
      #|        "depends_on": []
      #|      }
      #|    ],
      #|    "evidence": [
      #|      {
      #|        "work_item_id": "research",
      #|        "attempt_id": "attempt-1",
      #|        "result_id": "",
      #|        "output_digest": "",
      #|        "artifacts": [],
      #|        "review_id": "",
      #|        "review_artifact": "",
      #|        "reviewer_id": ""
      #|      }
      #|    ],
      #|    "acceptance_boundary": "Internal work acceptance does not establish customer approval, delivery acceptance or payment"
      #|  },
      #|  "owner_summary_observation": "event-head-matched"
      #|}
    ),
  )
}

///|
fn owner_cli_waiting_events() -> Json raise {
  @json.parse(
    (
      #|[
      #|  {
      #|    "sequence": 0,
      #|    "event_id": "event-0",
      #|    "run_id": "owner-fixture-r1",
      #|    "work_item_id": "",
      #|    "kind": "run-created",
      #|    "product_id": "moonwiki",
      #|    "declaration_id": "",
      #|    "book_id": "book-selected",
      #|    "declaration_revision": "r1",
      #|    "source_digest": "sha256:fixture-r1",
      #|    "requested_authority": "observe",
      #|    "acceptance_criteria": [
      #|      "Evidence is reviewed"
      #|    ],
      #|    "operation": "query-evidence",
      #|    "input_contracts": [
      #|      "fixture.input.v1"
      #|    ],
      #|    "output_contracts": [
      #|      "fixture.output.v1"
      #|    ],
      #|    "required_claim": "research-evidence",
      #|    "input_artifacts": [
      #|      "evidence/input.json"
      #|    ],
      #|    "timeout_ms": 1000,
      #|    "request_id": "request-1",
      #|    "result_id": "",
      #|    "attempt_id": "attempt-1",
      #|    "idempotency_key": "key-1",
      #|    "external_job_id": "",
      #|    "attempt_status": "",
      #|    "input_digest": "sha256:input",
      #|    "output_digest": "",
      #|    "output_artifacts": [],
      #|    "error_kind": "",
      #|    "compensable": false,
      #|    "depends_on": [],
      #|    "detail": "query-evidence",
      #|    "artifact_id": "",
      #|    "authority_id": "",
      #|    "recorded_at": "2026-10-06T06:00:00Z"
      #|  },
      #|  {
      #|    "sequence": 1,
      #|    "event_id": "event-1",
      #|    "run_id": "owner-fixture-r1",
      #|    "work_item_id": "research",
      #|    "kind": "item-registered",
      #|    "product_id": "moonwiki",
      #|    "declaration_id": "research",
      #|    "book_id": "book-selected",
      #|    "declaration_revision": "r1",
      #|    "source_digest": "sha256:fixture-r1",
      #|    "requested_authority": "observe",
      #|    "acceptance_criteria": [
      #|      "Evidence is reviewed"
      #|    ],
      #|    "operation": "query-evidence",
      #|    "input_contracts": [
      #|      "fixture.input.v1"
      #|    ],
      #|    "output_contracts": [
      #|      "fixture.output.v1"
      #|    ],
      #|    "required_claim": "research-evidence",
      #|    "input_artifacts": [
      #|      "evidence/input.json"
      #|    ],
      #|    "timeout_ms": 1000,
      #|    "request_id": "request-1",
      #|    "result_id": "",
      #|    "attempt_id": "attempt-1",
      #|    "idempotency_key": "key-1",
      #|    "external_job_id": "",
      #|    "attempt_status": "",
      #|    "input_digest": "sha256:input",
      #|    "output_digest": "",
      #|    "output_artifacts": [],
      #|    "error_kind": "",
      #|    "compensable": false,
      #|    "depends_on": [],
      #|    "detail": "query-evidence",
      #|    "artifact_id": "",
      #|    "authority_id": "",
      #|    "recorded_at": "2026-10-06T06:00:00Z"
      #|  },
      #|  {
      #|    "sequence": 2,
      #|    "event_id": "event-2",
      #|    "run_id": "owner-fixture-r1",
      #|    "work_item_id": "research",
      #|    "kind": "item-ready",
      #|    "product_id": "moonwiki",
      #|    "declaration_id": "research",
      #|    "book_id": "book-selected",
      #|    "declaration_revision": "r1",
      #|    "source_digest": "sha256:fixture-r1",
      #|    "requested_authority": "observe",
      #|    "acceptance_criteria": [
      #|      "Evidence is reviewed"
      #|    ],
      #|    "operation": "query-evidence",
      #|    "input_contracts": [
      #|      "fixture.input.v1"
      #|    ],
      #|    "output_contracts": [
      #|      "fixture.output.v1"
      #|    ],
      #|    "required_claim": "research-evidence",
      #|    "input_artifacts": [
      #|      "evidence/input.json"
      #|    ],
      #|    "timeout_ms": 1000,
      #|    "request_id": "request-1",
      #|    "result_id": "",
      #|    "attempt_id": "attempt-1",
      #|    "idempotency_key": "key-1",
      #|    "external_job_id": "",
      #|    "attempt_status": "",
      #|    "input_digest": "sha256:input",
      #|    "output_digest": "",
      #|    "output_artifacts": [],
      #|    "error_kind": "",
      #|    "compensable": false,
      #|    "depends_on": [],
      #|    "detail": "query-evidence",
      #|    "artifact_id": "",
      #|    "authority_id": "",
      #|    "recorded_at": "2026-10-06T06:00:00Z"
      #|  },
      #|  {
      #|    "sequence": 3,
      #|    "event_id": "event-3",
      #|    "run_id": "owner-fixture-r1",
      #|    "work_item_id": "research",
      #|    "kind": "attempt-submitted",
      #|    "product_id": "moonwiki",
      #|    "declaration_id": "research",
      #|    "book_id": "book-selected",
      #|    "declaration_revision": "r1",
      #|    "source_digest": "sha256:fixture-r1",
      #|    "requested_authority": "observe",
      #|    "acceptance_criteria": [
      #|      "Evidence is reviewed"
      #|    ],
      #|    "operation": "query-evidence",
      #|    "input_contracts": [
      #|      "fixture.input.v1"
      #|    ],
      #|    "output_contracts": [
      #|      "fixture.output.v1"
      #|    ],
      #|    "required_claim": "research-evidence",
      #|    "input_artifacts": [
      #|      "evidence/input.json"
      #|    ],
      #|    "timeout_ms": 1000,
      #|    "request_id": "request-1",
      #|    "result_id": "",
      #|    "attempt_id": "attempt-1",
      #|    "idempotency_key": "key-1",
      #|    "external_job_id": "",
      #|    "attempt_status": "submitted",
      #|    "input_digest": "sha256:input",
      #|    "output_digest": "",
      #|    "output_artifacts": [],
      #|    "error_kind": "",
      #|    "compensable": false,
      #|    "depends_on": [],
      #|    "detail": "query-evidence",
      #|    "artifact_id": "",
      #|    "authority_id": "",
      #|    "recorded_at": "2026-10-06T06:00:00Z"
      #|  },
      #|  {
      #|    "sequence": 4,
      #|    "event_id": "event-4",
      #|    "run_id": "owner-fixture-r1",
      #|    "work_item_id": "research",
      #|    "kind": "item-waiting",
      #|    "product_id": "moonwiki",
      #|    "declaration_id": "research",
      #|    "book_id": "book-selected",
      #|    "declaration_revision": "r1",
      #|    "source_digest": "sha256:fixture-r1",
      #|    "requested_authority": "observe",
      #|    "acceptance_criteria": [
      #|      "Evidence is reviewed"
      #|    ],
      #|    "operation": "query-evidence",
      #|    "input_contracts": [
      #|      "fixture.input.v1"
      #|    ],
      #|    "output_contracts": [
      #|      "fixture.output.v1"
      #|    ],
      #|    "required_claim": "research-evidence",
      #|    "input_artifacts": [
      #|      "evidence/input.json"
      #|    ],
      #|    "timeout_ms": 1000,
      #|    "request_id": "request-1",
      #|    "result_id": "result-1",
      #|    "attempt_id": "attempt-1",
      #|    "idempotency_key": "key-1",
      #|    "external_job_id": "",
      #|    "attempt_status": "",
      #|    "input_digest": "sha256:input",
      #|    "output_digest": "",
      #|    "output_artifacts": [
      #|      "evidence/exact-output.json"
      #|    ],
      #|    "error_kind": "",
      #|    "compensable": false,
      #|    "depends_on": [],
      #|    "detail": "Await source evidence",
      #|    "artifact_id": "",
      #|    "authority_id": "",
      #|    "recorded_at": "2026-10-06T06:00:00Z"
      #|  }
      #|]
    ),
  )
}

///|
fn owner_cli_review_projection() -> Json raise {
  @json.parse(
    (
      #|{
      #|  "protocol": "moonflow.run-projection.v3",
      #|  "run_id": "owner-fixture-r1",
      #|  "book_id": "book-selected",
      #|  "declaration_revision": "r1",
      #|  "source_digest": "sha256:fixture-r1",
      #|  "last_sequence": 4,
      #|  "outcome": "review",
      #|  "runnable_item_ids": [],
      #|  "items": [
      #|    {
      #|      "work_item_id": "research",
      #|      "declaration_id": "research",
      #|      "product_id": "moonwiki",
      #|      "requested_authority": "observe",
      #|      "acceptance_criteria": [
      #|        "Evidence is reviewed"
      #|      ],
      #|      "operation": "query-evidence",
      #|      "input_contracts": [
      #|        "fixture.input.v1"
      #|      ],
      #|      "output_contracts": [
      #|        "fixture.output.v1"
      #|      ],
      #|      "required_claim": "research-evidence",
      #|      "input_artifacts": [
      #|        "evidence/input.json"
      #|      ],
      #|      "timeout_ms": 1000,
      #|      "depends_on": [],
      #|      "status": "review",
      #|      "attempt_count": 1,
      #|      "request_id": "request-1",
      #|      "result_id": "result-1",
      #|      "active_attempt_id": "attempt-1",
      #|      "idempotency_key": "key-1",
      #|      "external_job_id": "",
      #|      "attempt_status": "succeeded",
      #|      "input_digest": "sha256:input",
      #|      "output_digest": "sha256:output",
      #|      "error_kind": "",
      #|      "compensable": false,
      #|      "blocker": "",
      #|      "acceptance_review_id": "",
      #|      "acceptance_review_artifact": "",
      #|      "acceptance_reviewer_id": "",
      #|      "artifacts": [
      #|        "evidence/exact-output.json"
      #|      ],
      #|      "approvals": []
      #|    }
      #|  ],
      #|  "owner_summary": {
      #|    "contract_id": "moonflow.owner-summary.v1",
      #|    "run_id": "owner-fixture-r1",
      #|    "book_id": "book-selected",
      #|    "declaration_revision": "r1",
      #|    "source_digest": "sha256:fixture-r1",
      #|    "last_sequence": 4,
      #|    "last_event_id": "event-4",
      #|    "recorded_at": "2026-10-06T06:00:00Z",
      #|    "outcome": "review",
      #|    "outcome_label": "Output awaits internal review",
      #|    "next_action": "Review the output against the acceptance criteria",
      #|    "next_role": "reviewer",
      #|    "actions": [
      #|      {
      #|        "work_item_id": "research",
      #|        "product_id": "moonwiki",
      #|        "status": "review",
      #|        "action": "Review the output against the acceptance criteria",
      #|        "next_role": "reviewer",
      #|        "reasons": [
      #|          "Internal review is required; execution success is not acceptance"
      #|        ],
      #|        "depends_on": []
      #|      }
      #|    ],
      #|    "evidence": [
      #|      {
      #|        "work_item_id": "research",
      #|        "attempt_id": "attempt-1",
      #|        "result_id": "result-1",
      #|        "output_digest": "sha256:output",
      #|        "artifacts": [
      #|          "evidence/exact-output.json"
      #|        ],
      #|        "review_id": "",
      #|        "review_artifact": "",
      #|        "reviewer_id": ""
      #|      }
      #|    ],
      #|    "acceptance_boundary": "Internal work acceptance does not establish customer approval, delivery acceptance or payment"
      #|  },
      #|  "owner_summary_observation": "event-head-matched"
      #|}
    ),
  )
}

///|
fn owner_cli_review_events() -> Json raise {
  @json.parse(
    (
      #|[
      #|  {
      #|    "sequence": 0,
      #|    "event_id": "event-0",
      #|    "run_id": "owner-fixture-r1",
      #|    "work_item_id": "",
      #|    "kind": "run-created",
      #|    "product_id": "moonwiki",
      #|    "declaration_id": "",
      #|    "book_id": "book-selected",
      #|    "declaration_revision": "r1",
      #|    "source_digest": "sha256:fixture-r1",
      #|    "requested_authority": "observe",
      #|    "acceptance_criteria": [
      #|      "Evidence is reviewed"
      #|    ],
      #|    "operation": "query-evidence",
      #|    "input_contracts": [
      #|      "fixture.input.v1"
      #|    ],
      #|    "output_contracts": [
      #|      "fixture.output.v1"
      #|    ],
      #|    "required_claim": "research-evidence",
      #|    "input_artifacts": [
      #|      "evidence/input.json"
      #|    ],
      #|    "timeout_ms": 1000,
      #|    "request_id": "request-1",
      #|    "result_id": "",
      #|    "attempt_id": "attempt-1",
      #|    "idempotency_key": "key-1",
      #|    "external_job_id": "",
      #|    "attempt_status": "",
      #|    "input_digest": "sha256:input",
      #|    "output_digest": "",
      #|    "output_artifacts": [],
      #|    "error_kind": "",
      #|    "compensable": false,
      #|    "depends_on": [],
      #|    "detail": "query-evidence",
      #|    "artifact_id": "",
      #|    "authority_id": "",
      #|    "recorded_at": "2026-10-06T06:00:00Z"
      #|  },
      #|  {
      #|    "sequence": 1,
      #|    "event_id": "event-1",
      #|    "run_id": "owner-fixture-r1",
      #|    "work_item_id": "research",
      #|    "kind": "item-registered",
      #|    "product_id": "moonwiki",
      #|    "declaration_id": "research",
      #|    "book_id": "book-selected",
      #|    "declaration_revision": "r1",
      #|    "source_digest": "sha256:fixture-r1",
      #|    "requested_authority": "observe",
      #|    "acceptance_criteria": [
      #|      "Evidence is reviewed"
      #|    ],
      #|    "operation": "query-evidence",
      #|    "input_contracts": [
      #|      "fixture.input.v1"
      #|    ],
      #|    "output_contracts": [
      #|      "fixture.output.v1"
      #|    ],
      #|    "required_claim": "research-evidence",
      #|    "input_artifacts": [
      #|      "evidence/input.json"
      #|    ],
      #|    "timeout_ms": 1000,
      #|    "request_id": "request-1",
      #|    "result_id": "",
      #|    "attempt_id": "attempt-1",
      #|    "idempotency_key": "key-1",
      #|    "external_job_id": "",
      #|    "attempt_status": "",
      #|    "input_digest": "sha256:input",
      #|    "output_digest": "",
      #|    "output_artifacts": [],
      #|    "error_kind": "",
      #|    "compensable": false,
      #|    "depends_on": [],
      #|    "detail": "query-evidence",
      #|    "artifact_id": "",
      #|    "authority_id": "",
      #|    "recorded_at": "2026-10-06T06:00:00Z"
      #|  },
      #|  {
      #|    "sequence": 2,
      #|    "event_id": "event-2",
      #|    "run_id": "owner-fixture-r1",
      #|    "work_item_id": "research",
      #|    "kind": "item-ready",
      #|    "product_id": "moonwiki",
      #|    "declaration_id": "research",
      #|    "book_id": "book-selected",
      #|    "declaration_revision": "r1",
      #|    "source_digest": "sha256:fixture-r1",
      #|    "requested_authority": "observe",
      #|    "acceptance_criteria": [
      #|      "Evidence is reviewed"
      #|    ],
      #|    "operation": "query-evidence",
      #|    "input_contracts": [
      #|      "fixture.input.v1"
      #|    ],
      #|    "output_contracts": [
      #|      "fixture.output.v1"
      #|    ],
      #|    "required_claim": "research-evidence",
      #|    "input_artifacts": [
      #|      "evidence/input.json"
      #|    ],
      #|    "timeout_ms": 1000,
      #|    "request_id": "request-1",
      #|    "result_id": "",
      #|    "attempt_id": "attempt-1",
      #|    "idempotency_key": "key-1",
      #|    "external_job_id": "",
      #|    "attempt_status": "",
      #|    "input_digest": "sha256:input",
      #|    "output_digest": "",
      #|    "output_artifacts": [],
      #|    "error_kind": "",
      #|    "compensable": false,
      #|    "depends_on": [],
      #|    "detail": "query-evidence",
      #|    "artifact_id": "",
      #|    "authority_id": "",
      #|    "recorded_at": "2026-10-06T06:00:00Z"
      #|  },
      #|  {
      #|    "sequence": 3,
      #|    "event_id": "event-3",
      #|    "run_id": "owner-fixture-r1",
      #|    "work_item_id": "research",
      #|    "kind": "attempt-submitted",
      #|    "product_id": "moonwiki",
      #|    "declaration_id": "research",
      #|    "book_id": "book-selected",
      #|    "declaration_revision": "r1",
      #|    "source_digest": "sha256:fixture-r1",
      #|    "requested_authority": "observe",
      #|    "acceptance_criteria": [
      #|      "Evidence is reviewed"
      #|    ],
      #|    "operation": "query-evidence",
      #|    "input_contracts": [
      #|      "fixture.input.v1"
      #|    ],
      #|    "output_contracts": [
      #|      "fixture.output.v1"
      #|    ],
      #|    "required_claim": "research-evidence",
      #|    "input_artifacts": [
      #|      "evidence/input.json"
      #|    ],
      #|    "timeout_ms": 1000,
      #|    "request_id": "request-1",
      #|    "result_id": "",
      #|    "attempt_id": "attempt-1",
      #|    "idempotency_key": "key-1",
      #|    "external_job_id": "",
      #|    "attempt_status": "submitted",
      #|    "input_digest": "sha256:input",
      #|    "output_digest": "",
      #|    "output_artifacts": [],
      #|    "error_kind": "",
      #|    "compensable": false,
      #|    "depends_on": [],
      #|    "detail": "query-evidence",
      #|    "artifact_id": "",
      #|    "authority_id": "",
      #|    "recorded_at": "2026-10-06T06:00:00Z"
      #|  },
      #|  {
      #|    "sequence": 4,
      #|    "event_id": "event-4",
      #|    "run_id": "owner-fixture-r1",
      #|    "work_item_id": "research",
      #|    "kind": "attempt-reconciled",
      #|    "product_id": "moonwiki",
      #|    "declaration_id": "research",
      #|    "book_id": "book-selected",
      #|    "declaration_revision": "r1",
      #|    "source_digest": "sha256:fixture-r1",
      #|    "requested_authority": "observe",
      #|    "acceptance_criteria": [
      #|      "Evidence is reviewed"
      #|    ],
      #|    "operation": "query-evidence",
      #|    "input_contracts": [
      #|      "fixture.input.v1"
      #|    ],
      #|    "output_contracts": [
      #|      "fixture.output.v1"
      #|    ],
      #|    "required_claim": "research-evidence",
      #|    "input_artifacts": [
      #|      "evidence/input.json"
      #|    ],
      #|    "timeout_ms": 1000,
      #|    "request_id": "request-1",
      #|    "result_id": "result-1",
      #|    "attempt_id": "attempt-1",
      #|    "idempotency_key": "key-1",
      #|    "external_job_id": "",
      #|    "attempt_status": "succeeded",
      #|    "input_digest": "sha256:input",
      #|    "output_digest": "sha256:output",
      #|    "output_artifacts": [
      #|      "evidence/exact-output.json"
      #|    ],
      #|    "error_kind": "",
      #|    "compensable": false,
      #|    "depends_on": [],
      #|    "detail": "query-evidence",
      #|    "artifact_id": "",
      #|    "authority_id": "",
      #|    "recorded_at": "2026-10-06T06:00:00Z"
      #|  }
      #|]
    ),
  )
}

///|
fn owner_cli_failed_projection() -> Json raise {
  @json.parse(
    (
      #|{
      #|  "protocol": "moonflow.run-projection.v3",
      #|  "run_id": "owner-fixture-r1",
      #|  "book_id": "book-selected",
      #|  "declaration_revision": "r1",
      #|  "source_digest": "sha256:fixture-r1",
      #|  "last_sequence": 4,
      #|  "outcome": "failed",
      #|  "runnable_item_ids": [],
      #|  "items": [
      #|    {
      #|      "work_item_id": "research",
      #|      "declaration_id": "research",
      #|      "product_id": "moonwiki",
      #|      "requested_authority": "observe",
      #|      "acceptance_criteria": [
      #|        "Evidence is reviewed"
      #|      ],
      #|      "operation": "query-evidence",
      #|      "input_contracts": [
      #|        "fixture.input.v1"
      #|      ],
      #|      "output_contracts": [
      #|        "fixture.output.v1"
      #|      ],
      #|      "required_claim": "research-evidence",
      #|      "input_artifacts": [
      #|        "evidence/input.json"
      #|      ],
      #|      "timeout_ms": 1000,
      #|      "depends_on": [],
      #|      "status": "failed",
      #|      "attempt_count": 1,
      #|      "request_id": "request-1",
      #|      "result_id": "result-1",
      #|      "active_attempt_id": "attempt-1",
      #|      "idempotency_key": "key-1",
      #|      "external_job_id": "",
      #|      "attempt_status": "failed",
      #|      "input_digest": "sha256:input",
      #|      "output_digest": "",
      #|      "error_kind": "source-unavailable",
      #|      "compensable": false,
      #|      "blocker": "source-unavailable",
      #|      "acceptance_review_id": "",
      #|      "acceptance_review_artifact": "",
      #|      "acceptance_reviewer_id": "",
      #|      "artifacts": [
      #|        "evidence/exact-output.json"
      #|      ],
      #|      "approvals": []
      #|    }
      #|  ],
      #|  "owner_summary": {
      #|    "contract_id": "moonflow.owner-summary.v1",
      #|    "run_id": "owner-fixture-r1",
      #|    "book_id": "book-selected",
      #|    "declaration_revision": "r1",
      #|    "source_digest": "sha256:fixture-r1",
      #|    "last_sequence": 4,
      #|    "last_event_id": "event-4",
      #|    "recorded_at": "2026-10-06T06:00:00Z",
      #|    "outcome": "failed",
      #|    "outcome_label": "Work failed; recovery needs a decision",
      #|    "next_action": "Inspect the failure and determine a governed recovery",
      #|    "next_role": "run operator",
      #|    "actions": [
      #|      {
      #|        "work_item_id": "research",
      #|        "product_id": "moonwiki",
      #|        "status": "failed",
      #|        "action": "Inspect the failure and determine a governed recovery",
      #|        "next_role": "run operator",
      #|        "reasons": [
      #|          "source-unavailable"
      #|        ],
      #|        "depends_on": []
      #|      }
      #|    ],
      #|    "evidence": [
      #|      {
      #|        "work_item_id": "research",
      #|        "attempt_id": "attempt-1",
      #|        "result_id": "result-1",
      #|        "output_digest": "",
      #|        "artifacts": [
      #|          "evidence/exact-output.json"
      #|        ],
      #|        "review_id": "",
      #|        "review_artifact": "",
      #|        "reviewer_id": ""
      #|      }
      #|    ],
      #|    "acceptance_boundary": "Internal work acceptance does not establish customer approval, delivery acceptance or payment"
      #|  },
      #|  "owner_summary_observation": "event-head-matched"
      #|}
    ),
  )
}

///|
fn owner_cli_failed_events() -> Json raise {
  @json.parse(
    (
      #|[
      #|  {
      #|    "sequence": 0,
      #|    "event_id": "event-0",
      #|    "run_id": "owner-fixture-r1",
      #|    "work_item_id": "",
      #|    "kind": "run-created",
      #|    "product_id": "moonwiki",
      #|    "declaration_id": "",
      #|    "book_id": "book-selected",
      #|    "declaration_revision": "r1",
      #|    "source_digest": "sha256:fixture-r1",
      #|    "requested_authority": "observe",
      #|    "acceptance_criteria": [
      #|      "Evidence is reviewed"
      #|    ],
      #|    "operation": "query-evidence",
      #|    "input_contracts": [
      #|      "fixture.input.v1"
      #|    ],
      #|    "output_contracts": [
      #|      "fixture.output.v1"
      #|    ],
      #|    "required_claim": "research-evidence",
      #|    "input_artifacts": [
      #|      "evidence/input.json"
      #|    ],
      #|    "timeout_ms": 1000,
      #|    "request_id": "request-1",
      #|    "result_id": "",
      #|    "attempt_id": "attempt-1",
      #|    "idempotency_key": "key-1",
      #|    "external_job_id": "",
      #|    "attempt_status": "",
      #|    "input_digest": "sha256:input",
      #|    "output_digest": "",
      #|    "output_artifacts": [],
      #|    "error_kind": "source-unavailable",
      #|    "compensable": false,
      #|    "depends_on": [],
      #|    "detail": "query-evidence",
      #|    "artifact_id": "",
      #|    "authority_id": "",
      #|    "recorded_at": "2026-10-06T06:00:00Z"
      #|  },
      #|  {
      #|    "sequence": 1,
      #|    "event_id": "event-1",
      #|    "run_id": "owner-fixture-r1",
      #|    "work_item_id": "research",
      #|    "kind": "item-registered",
      #|    "product_id": "moonwiki",
      #|    "declaration_id": "research",
      #|    "book_id": "book-selected",
      #|    "declaration_revision": "r1",
      #|    "source_digest": "sha256:fixture-r1",
      #|    "requested_authority": "observe",
      #|    "acceptance_criteria": [
      #|      "Evidence is reviewed"
      #|    ],
      #|    "operation": "query-evidence",
      #|    "input_contracts": [
      #|      "fixture.input.v1"
      #|    ],
      #|    "output_contracts": [
      #|      "fixture.output.v1"
      #|    ],
      #|    "required_claim": "research-evidence",
      #|    "input_artifacts": [
      #|      "evidence/input.json"
      #|    ],
      #|    "timeout_ms": 1000,
      #|    "request_id": "request-1",
      #|    "result_id": "",
      #|    "attempt_id": "attempt-1",
      #|    "idempotency_key": "key-1",
      #|    "external_job_id": "",
      #|    "attempt_status": "",
      #|    "input_digest": "sha256:input",
      #|    "output_digest": "",
      #|    "output_artifacts": [],
      #|    "error_kind": "source-unavailable",
      #|    "compensable": false,
      #|    "depends_on": [],
      #|    "detail": "query-evidence",
      #|    "artifact_id": "",
      #|    "authority_id": "",
      #|    "recorded_at": "2026-10-06T06:00:00Z"
      #|  },
      #|  {
      #|    "sequence": 2,
      #|    "event_id": "event-2",
      #|    "run_id": "owner-fixture-r1",
      #|    "work_item_id": "research",
      #|    "kind": "item-ready",
      #|    "product_id": "moonwiki",
      #|    "declaration_id": "research",
      #|    "book_id": "book-selected",
      #|    "declaration_revision": "r1",
      #|    "source_digest": "sha256:fixture-r1",
      #|    "requested_authority": "observe",
      #|    "acceptance_criteria": [
      #|      "Evidence is reviewed"
      #|    ],
      #|    "operation": "query-evidence",
      #|    "input_contracts": [
      #|      "fixture.input.v1"
      #|    ],
      #|    "output_contracts": [
      #|      "fixture.output.v1"
      #|    ],
      #|    "required_claim": "research-evidence",
      #|    "input_artifacts": [
      #|      "evidence/input.json"
      #|    ],
      #|    "timeout_ms": 1000,
      #|    "request_id": "request-1",
      #|    "result_id": "",
      #|    "attempt_id": "attempt-1",
      #|    "idempotency_key": "key-1",
      #|    "external_job_id": "",
      #|    "attempt_status": "",
      #|    "input_digest": "sha256:input",
      #|    "output_digest": "",
      #|    "output_artifacts": [],
      #|    "error_kind": "source-unavailable",
      #|    "compensable": false,
      #|    "depends_on": [],
      #|    "detail": "query-evidence",
      #|    "artifact_id": "",
      #|    "authority_id": "",
      #|    "recorded_at": "2026-10-06T06:00:00Z"
      #|  },
      #|  {
      #|    "sequence": 3,
      #|    "event_id": "event-3",
      #|    "run_id": "owner-fixture-r1",
      #|    "work_item_id": "research",
      #|    "kind": "attempt-submitted",
      #|    "product_id": "moonwiki",
      #|    "declaration_id": "research",
      #|    "book_id": "book-selected",
      #|    "declaration_revision": "r1",
      #|    "source_digest": "sha256:fixture-r1",
      #|    "requested_authority": "observe",
      #|    "acceptance_criteria": [
      #|      "Evidence is reviewed"
      #|    ],
      #|    "operation": "query-evidence",
      #|    "input_contracts": [
      #|      "fixture.input.v1"
      #|    ],
      #|    "output_contracts": [
      #|      "fixture.output.v1"
      #|    ],
      #|    "required_claim": "research-evidence",
      #|    "input_artifacts": [
      #|      "evidence/input.json"
      #|    ],
      #|    "timeout_ms": 1000,
      #|    "request_id": "request-1",
      #|    "result_id": "",
      #|    "attempt_id": "attempt-1",
      #|    "idempotency_key": "key-1",
      #|    "external_job_id": "",
      #|    "attempt_status": "submitted",
      #|    "input_digest": "sha256:input",
      #|    "output_digest": "",
      #|    "output_artifacts": [],
      #|    "error_kind": "source-unavailable",
      #|    "compensable": false,
      #|    "depends_on": [],
      #|    "detail": "query-evidence",
      #|    "artifact_id": "",
      #|    "authority_id": "",
      #|    "recorded_at": "2026-10-06T06:00:00Z"
      #|  },
      #|  {
      #|    "sequence": 4,
      #|    "event_id": "event-4",
      #|    "run_id": "owner-fixture-r1",
      #|    "work_item_id": "research",
      #|    "kind": "attempt-reconciled",
      #|    "product_id": "moonwiki",
      #|    "declaration_id": "research",
      #|    "book_id": "book-selected",
      #|    "declaration_revision": "r1",
      #|    "source_digest": "sha256:fixture-r1",
      #|    "requested_authority": "observe",
      #|    "acceptance_criteria": [
      #|      "Evidence is reviewed"
      #|    ],
      #|    "operation": "query-evidence",
      #|    "input_contracts": [
      #|      "fixture.input.v1"
      #|    ],
      #|    "output_contracts": [
      #|      "fixture.output.v1"
      #|    ],
      #|    "required_claim": "research-evidence",
      #|    "input_artifacts": [
      #|      "evidence/input.json"
      #|    ],
      #|    "timeout_ms": 1000,
      #|    "request_id": "request-1",
      #|    "result_id": "result-1",
      #|    "attempt_id": "attempt-1",
      #|    "idempotency_key": "key-1",
      #|    "external_job_id": "",
      #|    "attempt_status": "failed",
      #|    "input_digest": "sha256:input",
      #|    "output_digest": "",
      #|    "output_artifacts": [
      #|      "evidence/exact-output.json"
      #|    ],
      #|    "error_kind": "source-unavailable",
      #|    "compensable": false,
      #|    "depends_on": [],
      #|    "detail": "query-evidence",
      #|    "artifact_id": "",
      #|    "authority_id": "",
      #|    "recorded_at": "2026-10-06T06:00:00Z"
      #|  }
      #|]
    ),
  )
}

///|
fn owner_cli_unknown_projection() -> Json raise {
  @json.parse(
    (
      #|{
      #|  "protocol": "moonflow.run-projection.v3",
      #|  "run_id": "owner-fixture-r1",
      #|  "book_id": "book-selected",
      #|  "declaration_revision": "r1",
      #|  "source_digest": "sha256:fixture-r1",
      #|  "last_sequence": 4,
      #|  "outcome": "blocked",
      #|  "runnable_item_ids": [],
      #|  "items": [
      #|    {
      #|      "work_item_id": "research",
      #|      "declaration_id": "research",
      #|      "product_id": "moonwiki",
      #|      "requested_authority": "observe",
      #|      "acceptance_criteria": [
      #|        "Evidence is reviewed"
      #|      ],
      #|      "operation": "query-evidence",
      #|      "input_contracts": [
      #|        "fixture.input.v1"
      #|      ],
      #|      "output_contracts": [
      #|        "fixture.output.v1"
      #|      ],
      #|      "required_claim": "research-evidence",
      #|      "input_artifacts": [
      #|        "evidence/input.json"
      #|      ],
      #|      "timeout_ms": 1000,
      #|      "depends_on": [],
      #|      "status": "blocked",
      #|      "attempt_count": 1,
      #|      "request_id": "request-1",
      #|      "result_id": "result-1",
      #|      "active_attempt_id": "attempt-1",
      #|      "idempotency_key": "key-1",
      #|      "external_job_id": "",
      #|      "attempt_status": "unknown",
      #|      "input_digest": "sha256:input",
      #|      "output_digest": "",
      #|      "error_kind": "",
      #|      "compensable": false,
      #|      "blocker": "adapter outcome unknown; reconciliation required",
      #|      "acceptance_review_id": "",
      #|      "acceptance_review_artifact": "",
      #|      "acceptance_reviewer_id": "",
      #|      "artifacts": [
      #|        "evidence/exact-output.json"
      #|      ],
      #|      "approvals": []
      #|    }
      #|  ],
      #|  "owner_summary": {
      #|    "contract_id": "moonflow.owner-summary.v1",
      #|    "run_id": "owner-fixture-r1",
      #|    "book_id": "book-selected",
      #|    "declaration_revision": "r1",
      #|    "source_digest": "sha256:fixture-r1",
      #|    "last_sequence": 4,
      #|    "last_event_id": "event-4",
      #|    "recorded_at": "2026-10-06T06:00:00Z",
      #|    "outcome": "blocked",
      #|    "outcome_label": "Work is blocked",
      #|    "next_action": "Reconcile the unknown outcome before any retry",
      #|    "next_role": "run operator",
      #|    "actions": [
      #|      {
      #|        "work_item_id": "research",
      #|        "product_id": "moonwiki",
      #|        "status": "unknown",
      #|        "action": "Reconcile the unknown outcome before any retry",
      #|        "next_role": "run operator",
      #|        "reasons": [
      #|          "adapter outcome unknown; reconciliation required"
      #|        ],
      #|        "depends_on": []
      #|      }
      #|    ],
      #|    "evidence": [
      #|      {
      #|        "work_item_id": "research",
      #|        "attempt_id": "attempt-1",
      #|        "result_id": "result-1",
      #|        "output_digest": "",
      #|        "artifacts": [
      #|          "evidence/exact-output.json"
      #|        ],
      #|        "review_id": "",
      #|        "review_artifact": "",
      #|        "reviewer_id": ""
      #|      }
      #|    ],
      #|    "acceptance_boundary": "Internal work acceptance does not establish customer approval, delivery acceptance or payment"
      #|  },
      #|  "owner_summary_observation": "event-head-matched"
      #|}
    ),
  )
}

///|
fn owner_cli_unknown_events() -> Json raise {
  @json.parse(
    (
      #|[
      #|  {
      #|    "sequence": 0,
      #|    "event_id": "event-0",
      #|    "run_id": "owner-fixture-r1",
      #|    "work_item_id": "",
      #|    "kind": "run-created",
      #|    "product_id": "moonwiki",
      #|    "declaration_id": "",
      #|    "book_id": "book-selected",
      #|    "declaration_revision": "r1",
      #|    "source_digest": "sha256:fixture-r1",
      #|    "requested_authority": "observe",
      #|    "acceptance_criteria": [
      #|      "Evidence is reviewed"
      #|    ],
      #|    "operation": "query-evidence",
      #|    "input_contracts": [
      #|      "fixture.input.v1"
      #|    ],
      #|    "output_contracts": [
      #|      "fixture.output.v1"
      #|    ],
      #|    "required_claim": "research-evidence",
      #|    "input_artifacts": [
      #|      "evidence/input.json"
      #|    ],
      #|    "timeout_ms": 1000,
      #|    "request_id": "request-1",
      #|    "result_id": "",
      #|    "attempt_id": "attempt-1",
      #|    "idempotency_key": "key-1",
      #|    "external_job_id": "",
      #|    "attempt_status": "",
      #|    "input_digest": "sha256:input",
      #|    "output_digest": "",
      #|    "output_artifacts": [],
      #|    "error_kind": "",
      #|    "compensable": false,
      #|    "depends_on": [],
      #|    "detail": "query-evidence",
      #|    "artifact_id": "",
      #|    "authority_id": "",
      #|    "recorded_at": "2026-10-06T06:00:00Z"
      #|  },
      #|  {
      #|    "sequence": 1,
      #|    "event_id": "event-1",
      #|    "run_id": "owner-fixture-r1",
      #|    "work_item_id": "research",
      #|    "kind": "item-registered",
      #|    "product_id": "moonwiki",
      #|    "declaration_id": "research",
      #|    "book_id": "book-selected",
      #|    "declaration_revision": "r1",
      #|    "source_digest": "sha256:fixture-r1",
      #|    "requested_authority": "observe",
      #|    "acceptance_criteria": [
      #|      "Evidence is reviewed"
      #|    ],
      #|    "operation": "query-evidence",
      #|    "input_contracts": [
      #|      "fixture.input.v1"
      #|    ],
      #|    "output_contracts": [
      #|      "fixture.output.v1"
      #|    ],
      #|    "required_claim": "research-evidence",
      #|    "input_artifacts": [
      #|      "evidence/input.json"
      #|    ],
      #|    "timeout_ms": 1000,
      #|    "request_id": "request-1",
      #|    "result_id": "",
      #|    "attempt_id": "attempt-1",
      #|    "idempotency_key": "key-1",
      #|    "external_job_id": "",
      #|    "attempt_status": "",
      #|    "input_digest": "sha256:input",
      #|    "output_digest": "",
      #|    "output_artifacts": [],
      #|    "error_kind": "",
      #|    "compensable": false,
      #|    "depends_on": [],
      #|    "detail": "query-evidence",
      #|    "artifact_id": "",
      #|    "authority_id": "",
      #|    "recorded_at": "2026-10-06T06:00:00Z"
      #|  },
      #|  {
      #|    "sequence": 2,
      #|    "event_id": "event-2",
      #|    "run_id": "owner-fixture-r1",
      #|    "work_item_id": "research",
      #|    "kind": "item-ready",
      #|    "product_id": "moonwiki",
      #|    "declaration_id": "research",
      #|    "book_id": "book-selected",
      #|    "declaration_revision": "r1",
      #|    "source_digest": "sha256:fixture-r1",
      #|    "requested_authority": "observe",
      #|    "acceptance_criteria": [
      #|      "Evidence is reviewed"
      #|    ],
      #|    "operation": "query-evidence",
      #|    "input_contracts": [
      #|      "fixture.input.v1"
      #|    ],
      #|    "output_contracts": [
      #|      "fixture.output.v1"
      #|    ],
      #|    "required_claim": "research-evidence",
      #|    "input_artifacts": [
      #|      "evidence/input.json"
      #|    ],
      #|    "timeout_ms": 1000,
      #|    "request_id": "request-1",
      #|    "result_id": "",
      #|    "attempt_id": "attempt-1",
      #|    "idempotency_key": "key-1",
      #|    "external_job_id": "",
      #|    "attempt_status": "",
      #|    "input_digest": "sha256:input",
      #|    "output_digest": "",
      #|    "output_artifacts": [],
      #|    "error_kind": "",
      #|    "compensable": false,
      #|    "depends_on": [],
      #|    "detail": "query-evidence",
      #|    "artifact_id": "",
      #|    "authority_id": "",
      #|    "recorded_at": "2026-10-06T06:00:00Z"
      #|  },
      #|  {
      #|    "sequence": 3,
      #|    "event_id": "event-3",
      #|    "run_id": "owner-fixture-r1",
      #|    "work_item_id": "research",
      #|    "kind": "attempt-submitted",
      #|    "product_id": "moonwiki",
      #|    "declaration_id": "research",
      #|    "book_id": "book-selected",
      #|    "declaration_revision": "r1",
      #|    "source_digest": "sha256:fixture-r1",
      #|    "requested_authority": "observe",
      #|    "acceptance_criteria": [
      #|      "Evidence is reviewed"
      #|    ],
      #|    "operation": "query-evidence",
      #|    "input_contracts": [
      #|      "fixture.input.v1"
      #|    ],
      #|    "output_contracts": [
      #|      "fixture.output.v1"
      #|    ],
      #|    "required_claim": "research-evidence",
      #|    "input_artifacts": [
      #|      "evidence/input.json"
      #|    ],
      #|    "timeout_ms": 1000,
      #|    "request_id": "request-1",
      #|    "result_id": "",
      #|    "attempt_id": "attempt-1",
      #|    "idempotency_key": "key-1",
      #|    "external_job_id": "",
      #|    "attempt_status": "submitted",
      #|    "input_digest": "sha256:input",
      #|    "output_digest": "",
      #|    "output_artifacts": [],
      #|    "error_kind": "",
      #|    "compensable": false,
      #|    "depends_on": [],
      #|    "detail": "query-evidence",
      #|    "artifact_id": "",
      #|    "authority_id": "",
      #|    "recorded_at": "2026-10-06T06:00:00Z"
      #|  },
      #|  {
      #|    "sequence": 4,
      #|    "event_id": "event-4",
      #|    "run_id": "owner-fixture-r1",
      #|    "work_item_id": "research",
      #|    "kind": "attempt-reconciled",
      #|    "product_id": "moonwiki",
      #|    "declaration_id": "research",
      #|    "book_id": "book-selected",
      #|    "declaration_revision": "r1",
      #|    "source_digest": "sha256:fixture-r1",
      #|    "requested_authority": "observe",
      #|    "acceptance_criteria": [
      #|      "Evidence is reviewed"
      #|    ],
      #|    "operation": "query-evidence",
      #|    "input_contracts": [
      #|      "fixture.input.v1"
      #|    ],
      #|    "output_contracts": [
      #|      "fixture.output.v1"
      #|    ],
      #|    "required_claim": "research-evidence",
      #|    "input_artifacts": [
      #|      "evidence/input.json"
      #|    ],
      #|    "timeout_ms": 1000,
      #|    "request_id": "request-1",
      #|    "result_id": "result-1",
      #|    "attempt_id": "attempt-1",
      #|    "idempotency_key": "key-1",
      #|    "external_job_id": "",
      #|    "attempt_status": "unknown",
      #|    "input_digest": "sha256:input",
      #|    "output_digest": "",
      #|    "output_artifacts": [
      #|      "evidence/exact-output.json"
      #|    ],
      #|    "error_kind": "",
      #|    "compensable": false,
      #|    "depends_on": [],
      #|    "detail": "query-evidence",
      #|    "artifact_id": "",
      #|    "authority_id": "",
      #|    "recorded_at": "2026-10-06T06:00:00Z"
      #|  }
      #|]
    ),
  )
}

///|
fn owner_cli_accepted_projection() -> Json raise {
  @json.parse(
    (
      #|{
      #|  "protocol": "moonflow.run-projection.v3",
      #|  "run_id": "owner-fixture-r1",
      #|  "book_id": "book-selected",
      #|  "declaration_revision": "r1",
      #|  "source_digest": "sha256:fixture-r1",
      #|  "last_sequence": 5,
      #|  "outcome": "accepted",
      #|  "runnable_item_ids": [],
      #|  "items": [
      #|    {
      #|      "work_item_id": "research",
      #|      "declaration_id": "research",
      #|      "product_id": "moonwiki",
      #|      "requested_authority": "observe",
      #|      "acceptance_criteria": [
      #|        "Evidence is reviewed"
      #|      ],
      #|      "operation": "query-evidence",
      #|      "input_contracts": [
      #|        "fixture.input.v1"
      #|      ],
      #|      "output_contracts": [
      #|        "fixture.output.v1"
      #|      ],
      #|      "required_claim": "research-evidence",
      #|      "input_artifacts": [
      #|        "evidence/input.json"
      #|      ],
      #|      "timeout_ms": 1000,
      #|      "depends_on": [],
      #|      "status": "accepted",
      #|      "attempt_count": 1,
      #|      "request_id": "request-1",
      #|      "result_id": "result-1",
      #|      "active_attempt_id": "attempt-1",
      #|      "idempotency_key": "key-1",
      #|      "external_job_id": "",
      #|      "attempt_status": "succeeded",
      #|      "input_digest": "sha256:input",
      #|      "output_digest": "sha256:output",
      #|      "error_kind": "",
      #|      "compensable": false,
      #|      "blocker": "",
      #|      "acceptance_review_id": "review-1",
      #|      "acceptance_review_artifact": "evidence/exact-review.json",
      #|      "acceptance_reviewer_id": "reviewer-1",
      #|      "artifacts": [
      #|        "evidence/exact-output.json",
      #|        "evidence/exact-review.json"
      #|      ],
      #|      "approvals": [
      #|        "reviewer-1"
      #|      ]
      #|    }
      #|  ],
      #|  "owner_summary": {
      #|    "contract_id": "moonflow.owner-summary.v1",
      #|    "run_id": "owner-fixture-r1",
      #|    "book_id": "book-selected",
      #|    "declaration_revision": "r1",
      #|    "source_digest": "sha256:fixture-r1",
      #|    "last_sequence": 5,
      #|    "last_event_id": "event-5",
      #|    "recorded_at": "2026-10-06T06:00:00Z",
      #|    "outcome": "accepted",
      #|    "outcome_label": "Internal work accepted for this revision",
      #|    "next_action": "No further internal work action is recorded for this revision",
      #|    "actions": [],
      #|    "evidence": [
      #|      {
      #|        "work_item_id": "research",
      #|        "attempt_id": "attempt-1",
      #|        "result_id": "result-1",
      #|        "output_digest": "sha256:output",
      #|        "artifacts": [
      #|          "evidence/exact-output.json",
      #|          "evidence/exact-review.json"
      #|        ],
      #|        "review_id": "review-1",
      #|        "review_artifact": "evidence/exact-review.json",
      #|        "reviewer_id": "reviewer-1"
      #|      }
      #|    ],
      #|    "acceptance_boundary": "Internal work acceptance does not establish customer approval, delivery acceptance or payment"
      #|  },
      #|  "owner_summary_observation": "event-head-matched"
      #|}
    ),
  )
}

///|
fn owner_cli_accepted_events() -> Json raise {
  @json.parse(
    (
      #|[
      #|  {
      #|    "sequence": 0,
      #|    "event_id": "event-0",
      #|    "run_id": "owner-fixture-r1",
      #|    "work_item_id": "",
      #|    "kind": "run-created",
      #|    "product_id": "moonwiki",
      #|    "declaration_id": "",
      #|    "book_id": "book-selected",
      #|    "declaration_revision": "r1",
      #|    "source_digest": "sha256:fixture-r1",
      #|    "requested_authority": "observe",
      #|    "acceptance_criteria": [
      #|      "Evidence is reviewed"
      #|    ],
      #|    "operation": "query-evidence",
      #|    "input_contracts": [
      #|      "fixture.input.v1"
      #|    ],
      #|    "output_contracts": [
      #|      "fixture.output.v1"
      #|    ],
      #|    "required_claim": "research-evidence",
      #|    "input_artifacts": [
      #|      "evidence/input.json"
      #|    ],
      #|    "timeout_ms": 1000,
      #|    "request_id": "request-1",
      #|    "result_id": "",
      #|    "attempt_id": "attempt-1",
      #|    "idempotency_key": "key-1",
      #|    "external_job_id": "",
      #|    "attempt_status": "",
      #|    "input_digest": "sha256:input",
      #|    "output_digest": "",
      #|    "output_artifacts": [],
      #|    "error_kind": "",
      #|    "compensable": false,
      #|    "depends_on": [],
      #|    "detail": "query-evidence",
      #|    "artifact_id": "",
      #|    "authority_id": "",
      #|    "recorded_at": "2026-10-06T06:00:00Z"
      #|  },
      #|  {
      #|    "sequence": 1,
      #|    "event_id": "event-1",
      #|    "run_id": "owner-fixture-r1",
      #|    "work_item_id": "research",
      #|    "kind": "item-registered",
      #|    "product_id": "moonwiki",
      #|    "declaration_id": "research",
      #|    "book_id": "book-selected",
      #|    "declaration_revision": "r1",
      #|    "source_digest": "sha256:fixture-r1",
      #|    "requested_authority": "observe",
      #|    "acceptance_criteria": [
      #|      "Evidence is reviewed"
      #|    ],
      #|    "operation": "query-evidence",
      #|    "input_contracts": [
      #|      "fixture.input.v1"
      #|    ],
      #|    "output_contracts": [
      #|      "fixture.output.v1"
      #|    ],
      #|    "required_claim": "research-evidence",
      #|    "input_artifacts": [
      #|      "evidence/input.json"
      #|    ],
      #|    "timeout_ms": 1000,
      #|    "request_id": "request-1",
      #|    "result_id": "",
      #|    "attempt_id": "attempt-1",
      #|    "idempotency_key": "key-1",
      #|    "external_job_id": "",
      #|    "attempt_status": "",
      #|    "input_digest": "sha256:input",
      #|    "output_digest": "",
      #|    "output_artifacts": [],
      #|    "error_kind": "",
      #|    "compensable": false,
      #|    "depends_on": [],
      #|    "detail": "query-evidence",
      #|    "artifact_id": "",
      #|    "authority_id": "",
      #|    "recorded_at": "2026-10-06T06:00:00Z"
      #|  },
      #|  {
      #|    "sequence": 2,
      #|    "event_id": "event-2",
      #|    "run_id": "owner-fixture-r1",
      #|    "work_item_id": "research",
      #|    "kind": "item-ready",
      #|    "product_id": "moonwiki",
      #|    "declaration_id": "research",
      #|    "book_id": "book-selected",
      #|    "declaration_revision": "r1",
      #|    "source_digest": "sha256:fixture-r1",
      #|    "requested_authority": "observe",
      #|    "acceptance_criteria": [
      #|      "Evidence is reviewed"
      #|    ],
      #|    "operation": "query-evidence",
      #|    "input_contracts": [
      #|      "fixture.input.v1"
      #|    ],
      #|    "output_contracts": [
      #|      "fixture.output.v1"
      #|    ],
      #|    "required_claim": "research-evidence",
      #|    "input_artifacts": [
      #|      "evidence/input.json"
      #|    ],
      #|    "timeout_ms": 1000,
      #|    "request_id": "request-1",
      #|    "result_id": "",
      #|    "attempt_id": "attempt-1",
      #|    "idempotency_key": "key-1",
      #|    "external_job_id": "",
      #|    "attempt_status": "",
      #|    "input_digest": "sha256:input",
      #|    "output_digest": "",
      #|    "output_artifacts": [],
      #|    "error_kind": "",
      #|    "compensable": false,
      #|    "depends_on": [],
      #|    "detail": "query-evidence",
      #|    "artifact_id": "",
      #|    "authority_id": "",
      #|    "recorded_at": "2026-10-06T06:00:00Z"
      #|  },
      #|  {
      #|    "sequence": 3,
      #|    "event_id": "event-3",
      #|    "run_id": "owner-fixture-r1",
      #|    "work_item_id": "research",
      #|    "kind": "attempt-submitted",
      #|    "product_id": "moonwiki",
      #|    "declaration_id": "research",
      #|    "book_id": "book-selected",
      #|    "declaration_revision": "r1",
      #|    "source_digest": "sha256:fixture-r1",
      #|    "requested_authority": "observe",
      #|    "acceptance_criteria": [
      #|      "Evidence is reviewed"
      #|    ],
      #|    "operation": "query-evidence",
      #|    "input_contracts": [
      #|      "fixture.input.v1"
      #|    ],
      #|    "output_contracts": [
      #|      "fixture.output.v1"
      #|    ],
      #|    "required_claim": "research-evidence",
      #|    "input_artifacts": [
      #|      "evidence/input.json"
      #|    ],
      #|    "timeout_ms": 1000,
      #|    "request_id": "request-1",
      #|    "result_id": "",
      #|    "attempt_id": "attempt-1",
      #|    "idempotency_key": "key-1",
      #|    "external_job_id": "",
      #|    "attempt_status": "submitted",
      #|    "input_digest": "sha256:input",
      #|    "output_digest": "",
      #|    "output_artifacts": [],
      #|    "error_kind": "",
      #|    "compensable": false,
      #|    "depends_on": [],
      #|    "detail": "query-evidence",
      #|    "artifact_id": "",
      #|    "authority_id": "",
      #|    "recorded_at": "2026-10-06T06:00:00Z"
      #|  },
      #|  {
      #|    "sequence": 4,
      #|    "event_id": "event-4",
      #|    "run_id": "owner-fixture-r1",
      #|    "work_item_id": "research",
      #|    "kind": "attempt-reconciled",
      #|    "product_id": "moonwiki",
      #|    "declaration_id": "research",
      #|    "book_id": "book-selected",
      #|    "declaration_revision": "r1",
      #|    "source_digest": "sha256:fixture-r1",
      #|    "requested_authority": "observe",
      #|    "acceptance_criteria": [
      #|      "Evidence is reviewed"
      #|    ],
      #|    "operation": "query-evidence",
      #|    "input_contracts": [
      #|      "fixture.input.v1"
      #|    ],
      #|    "output_contracts": [
      #|      "fixture.output.v1"
      #|    ],
      #|    "required_claim": "research-evidence",
      #|    "input_artifacts": [
      #|      "evidence/input.json"
      #|    ],
      #|    "timeout_ms": 1000,
      #|    "request_id": "request-1",
      #|    "result_id": "result-1",
      #|    "attempt_id": "attempt-1",
      #|    "idempotency_key": "key-1",
      #|    "external_job_id": "",
      #|    "attempt_status": "succeeded",
      #|    "input_digest": "sha256:input",
      #|    "output_digest": "sha256:output",
      #|    "output_artifacts": [
      #|      "evidence/exact-output.json"
      #|    ],
      #|    "error_kind": "",
      #|    "compensable": false,
      #|    "depends_on": [],
      #|    "detail": "query-evidence",
      #|    "artifact_id": "",
      #|    "authority_id": "",
      #|    "recorded_at": "2026-10-06T06:00:00Z"
      #|  },
      #|  {
      #|    "sequence": 5,
      #|    "event_id": "event-5",
      #|    "run_id": "owner-fixture-r1",
      #|    "work_item_id": "research",
      #|    "kind": "item-accepted",
      #|    "product_id": "moonwiki",
      #|    "declaration_id": "research",
      #|    "book_id": "book-selected",
      #|    "declaration_revision": "r1",
      #|    "source_digest": "sha256:fixture-r1",
      #|    "requested_authority": "observe",
      #|    "acceptance_criteria": [
      #|      "Evidence is reviewed"
      #|    ],
      #|    "operation": "query-evidence",
      #|    "input_contracts": [
      #|      "fixture.input.v1"
      #|    ],
      #|    "output_contracts": [
      #|      "fixture.output.v1"
      #|    ],
      #|    "required_claim": "research-evidence",
      #|    "input_artifacts": [
      #|      "evidence/input.json"
      #|    ],
      #|    "timeout_ms": 1000,
      #|    "request_id": "request-1",
      #|    "result_id": "result-1",
      #|    "attempt_id": "attempt-1",
      #|    "idempotency_key": "key-1",
      #|    "external_job_id": "",
      #|    "attempt_status": "",
      #|    "input_digest": "sha256:input",
      #|    "output_digest": "sha256:output",
      #|    "output_artifacts": [],
      #|    "error_kind": "",
      #|    "compensable": false,
      #|    "depends_on": [],
      #|    "detail": "review-1",
      #|    "artifact_id": "evidence/exact-review.json",
      #|    "authority_id": "reviewer-1",
      #|    "recorded_at": "2026-10-06T06:00:00Z"
      #|  }
      #|]
    ),
  )
}

///|
fn owner_cli_child_projection() -> Json raise {
  @json.parse(
    (
      #|{
      #|  "protocol": "moonflow.run-projection.v3",
      #|  "run_id": "owner-fixture-r2",
      #|  "book_id": "book-selected",
      #|  "declaration_revision": "r2",
      #|  "source_digest": "sha256:fixture-r2",
      #|  "last_sequence": 2,
      #|  "outcome": "ready",
      #|  "runnable_item_ids": [
      #|    "research"
      #|  ],
      #|  "items": [
      #|    {
      #|      "work_item_id": "research",
      #|      "declaration_id": "research",
      #|      "product_id": "moonwiki",
      #|      "requested_authority": "observe",
      #|      "acceptance_criteria": [
      #|        "Evidence is reviewed"
      #|      ],
      #|      "operation": "query-evidence",
      #|      "input_contracts": [
      #|        "fixture.input.v1"
      #|      ],
      #|      "output_contracts": [
      #|        "fixture.output.v1"
      #|      ],
      #|      "required_claim": "research-evidence",
      #|      "input_artifacts": [
      #|        "evidence/input.json"
      #|      ],
      #|      "timeout_ms": 1000,
      #|      "depends_on": [],
      #|      "status": "ready",
      #|      "attempt_count": 0,
      #|      "request_id": "",
      #|      "result_id": "",
      #|      "active_attempt_id": "",
      #|      "idempotency_key": "",
      #|      "external_job_id": "",
      #|      "attempt_status": "",
      #|      "input_digest": "",
      #|      "output_digest": "",
      #|      "error_kind": "",
      #|      "compensable": false,
      #|      "blocker": "",
      #|      "acceptance_review_id": "",
      #|      "acceptance_review_artifact": "",
      #|      "acceptance_reviewer_id": "",
      #|      "artifacts": [],
      #|      "approvals": []
      #|    }
      #|  ],
      #|  "owner_summary": {
      #|    "contract_id": "moonflow.owner-summary.v1",
      #|    "run_id": "owner-fixture-r2",
      #|    "book_id": "book-selected",
      #|    "declaration_revision": "r2",
      #|    "source_digest": "sha256:fixture-r2",
      #|    "last_sequence": 2,
      #|    "last_event_id": "event-2",
      #|    "recorded_at": "2026-10-06T06:00:00Z",
      #|    "outcome": "ready",
      #|    "outcome_label": "Work is ready for governed execution",
      #|    "next_action": "Continue through the existing execution controls",
      #|    "next_role": "run operator",
      #|    "actions": [
      #|      {
      #|        "work_item_id": "research",
      #|        "product_id": "moonwiki",
      #|        "status": "ready",
      #|        "action": "Continue through the existing execution controls",
      #|        "next_role": "run operator",
      #|        "reasons": [
      #|          "Dependencies are accepted; execution remains subject to existing authority checks"
      #|        ],
      #|        "depends_on": []
      #|      }
      #|    ],
      #|    "evidence": [
      #|      {
      #|        "work_item_id": "research",
      #|        "attempt_id": "",
      #|        "result_id": "",
      #|        "output_digest": "",
      #|        "artifacts": [],
      #|        "review_id": "",
      #|        "review_artifact": "",
      #|        "reviewer_id": ""
      #|      }
      #|    ],
      #|    "acceptance_boundary": "Internal work acceptance does not establish customer approval, delivery acceptance or payment"
      #|  },
      #|  "owner_summary_observation": "event-head-matched"
      #|}
    ),
  )
}

///|
fn owner_cli_child_events() -> Json raise {
  @json.parse(
    (
      #|[
      #|  {
      #|    "sequence": 0,
      #|    "event_id": "event-0",
      #|    "run_id": "owner-fixture-r2",
      #|    "work_item_id": "",
      #|    "kind": "run-created",
      #|    "product_id": "moonwiki",
      #|    "declaration_id": "",
      #|    "book_id": "book-selected",
      #|    "declaration_revision": "r2",
      #|    "source_digest": "sha256:fixture-r2",
      #|    "requested_authority": "observe",
      #|    "acceptance_criteria": [
      #|      "Evidence is reviewed"
      #|    ],
      #|    "operation": "query-evidence",
      #|    "input_contracts": [
      #|      "fixture.input.v1"
      #|    ],
      #|    "output_contracts": [
      #|      "fixture.output.v1"
      #|    ],
      #|    "required_claim": "research-evidence",
      #|    "input_artifacts": [
      #|      "evidence/input.json"
      #|    ],
      #|    "timeout_ms": 1000,
      #|    "request_id": "request-1",
      #|    "result_id": "",
      #|    "attempt_id": "attempt-1",
      #|    "idempotency_key": "key-1",
      #|    "external_job_id": "",
      #|    "attempt_status": "",
      #|    "input_digest": "sha256:input",
      #|    "output_digest": "",
      #|    "output_artifacts": [],
      #|    "error_kind": "",
      #|    "compensable": false,
      #|    "depends_on": [],
      #|    "detail": "query-evidence",
      #|    "artifact_id": "",
      #|    "authority_id": "",
      #|    "recorded_at": "2026-10-06T06:00:00Z"
      #|  },
      #|  {
      #|    "sequence": 1,
      #|    "event_id": "event-1",
      #|    "run_id": "owner-fixture-r2",
      #|    "work_item_id": "research",
      #|    "kind": "item-registered",
      #|    "product_id": "moonwiki",
      #|    "declaration_id": "research",
      #|    "book_id": "book-selected",
      #|    "declaration_revision": "r2",
      #|    "source_digest": "sha256:fixture-r2",
      #|    "requested_authority": "observe",
      #|    "acceptance_criteria": [
      #|      "Evidence is reviewed"
      #|    ],
      #|    "operation": "query-evidence",
      #|    "input_contracts": [
      #|      "fixture.input.v1"
      #|    ],
      #|    "output_contracts": [
      #|      "fixture.output.v1"
      #|    ],
      #|    "required_claim": "research-evidence",
      #|    "input_artifacts": [
      #|      "evidence/input.json"
      #|    ],
      #|    "timeout_ms": 1000,
      #|    "request_id": "request-1",
      #|    "result_id": "",
      #|    "attempt_id": "attempt-1",
      #|    "idempotency_key": "key-1",
      #|    "external_job_id": "",
      #|    "attempt_status": "",
      #|    "input_digest": "sha256:input",
      #|    "output_digest": "",
      #|    "output_artifacts": [],
      #|    "error_kind": "",
      #|    "compensable": false,
      #|    "depends_on": [],
      #|    "detail": "query-evidence",
      #|    "artifact_id": "",
      #|    "authority_id": "",
      #|    "recorded_at": "2026-10-06T06:00:00Z"
      #|  },
      #|  {
      #|    "sequence": 2,
      #|    "event_id": "event-2",
      #|    "run_id": "owner-fixture-r2",
      #|    "work_item_id": "research",
      #|    "kind": "item-ready",
      #|    "product_id": "moonwiki",
      #|    "declaration_id": "research",
      #|    "book_id": "book-selected",
      #|    "declaration_revision": "r2",
      #|    "source_digest": "sha256:fixture-r2",
      #|    "requested_authority": "observe",
      #|    "acceptance_criteria": [
      #|      "Evidence is reviewed"
      #|    ],
      #|    "operation": "query-evidence",
      #|    "input_contracts": [
      #|      "fixture.input.v1"
      #|    ],
      #|    "output_contracts": [
      #|      "fixture.output.v1"
      #|    ],
      #|    "required_claim": "research-evidence",
      #|    "input_artifacts": [
      #|      "evidence/input.json"
      #|    ],
      #|    "timeout_ms": 1000,
      #|    "request_id": "request-1",
      #|    "result_id": "",
      #|    "attempt_id": "attempt-1",
      #|    "idempotency_key": "key-1",
      #|    "external_job_id": "",
      #|    "attempt_status": "",
      #|    "input_digest": "sha256:input",
      #|    "output_digest": "",
      #|    "output_artifacts": [],
      #|    "error_kind": "",
      #|    "compensable": false,
      #|    "depends_on": [],
      #|    "detail": "query-evidence",
      #|    "artifact_id": "",
      #|    "authority_id": "",
      #|    "recorded_at": "2026-10-06T06:00:00Z"
      #|  }
      #|]
    ),
  )
}
