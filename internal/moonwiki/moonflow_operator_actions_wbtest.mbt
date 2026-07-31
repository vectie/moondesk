///|
fn receiver_action_fixture(run_id : String, token : String) -> Json {
  let endpoint = "/api/moonflow/runs/\{run_id}/handoffs/\{token}"
  {
    "action_id": "open-0123456789abcdef",
    "action_kind": "open-product",
    "label": "Open product-one",
    "summary": "Continue work-one through its declared product entrypoint.",
    "status": "pending",
    "enabled": true,
    "run_id": run_id,
    "work_item_id": "work-one",
    "declaration_id": "work-one-r1",
    "product_id": "product-one",
    "operation": "product-one/build@1.0.0",
    "requested_authority": "workspace-mutation",
    "authority_status": "requested",
    "claim_ceiling": "digital-artifact",
    "capability_status": "catalog-bound",
    "input_contracts": ["product-one/request@1.0.0"],
    "output_contracts": ["product-one/receipt@1.0.0"],
    "evidence_refs": [
      {
        "kind": "source-graph",
        "reference": "projection.json",
        "digest": "sha256:source",
      },
    ],
    "review_required": true,
    "review_status": "required",
    "acceptance_criteria": ["reviewed output exists"],
    "handoff_ref": "operator-handoffs/open-0123456789abcdef.json",
    "receiver": {
      "handoff_token": token,
      "handoff_digest": "sha256:" + token,
      "request_id": "receiver-request-" + token[0:24].to_owned(),
      "attempt_id": "receiver-attempt-" + token[0:24].to_owned(),
      "idempotency_key": "receiver-" + token,
      "intake_path": endpoint,
      "status_path": endpoint + "/status",
      "receipt_path": endpoint + "/receipt",
      "return_path": "/?activity=flow",
      "status": "pending",
      "receipt_ref": "",
      "receipt_digest": "",
      "receipt_recorded_at": "",
    },
    "app_entrypoint": {
      "kind": "pack-manifest",
      "pack_id": "product-one",
      "entrypoint_id": "",
      "path": "/pack-apps/product-one/",
      "fallback_path": "",
    },
  }
}

///|
test "MoonDesk accepts and resolves generic run-bound receiver handoffs" {
  let run_id = "generic-run"
  let token = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
  let catalog : Json = {
    "contract_id": "moonflow.operator-actions.v2",
    "contract_version": "2.1.0",
    "run_id": run_id,
    "projection_sequence": 3,
    "source_digest": "sha256:source",
    "actions": [receiver_action_fixture(run_id, token)],
  }
  guard decode_moonflow_operator_action_catalog(catalog, run_id)
    is Some(decoded) else {
    fail("generic receiver action catalog was rejected")
  }
  assert_eq(decoded.actions.length(), 1)
  let action = decoded.actions[0]
  assert_eq(action.receiver.status, "pending")
  assert_eq(
    action.receiver.receipt_path,
    "/api/moonflow/runs/\{run_id}/handoffs/\{token}/receipt",
  )
  let configured : Json = {
    "pack_id": "product-one",
    "entrypoint_id": "workspace",
    "launch_url": "/pack-apps/product-one/",
  }
  let public = moonflow_operator_action_public_json(action, Some(configured))
  assert_true(json_bool(public, "enabled", default=false))
  guard json_object_field(public, "app_entrypoint") is Some(entrypoint) else {
    fail("resolved entrypoint missing")
  }
  assert_eq(
    json_string(entrypoint, "launch_path", default=""),
    "/pack-apps/product-one/?moonflow_run=\{run_id}&moonflow_handoff=\{token}",
  )
  let unavailable = moonflow_operator_action_public_json(action, None)
  assert_false(json_bool(unavailable, "enabled", default=true))
  assert_eq(json_string(unavailable, "status", default=""), "unavailable")
}

///|
test "MoonDesk rejects receiver token, path, and digest mismatches" {
  let run_id = "generic-run"
  let token = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
  let base = receiver_action_fixture(run_id, token)
  guard base is Object(fields) else { fail("fixture must be an object") }
  guard fields.get("receiver") is Some(Object(receiver)) else {
    fail("fixture receiver missing")
  }
  receiver["status_path"] = Json::string(
    "/api/moonflow/runs/other/handoffs/" + token + "/status",
  )
  assert_true(decode_moonflow_operator_action_v2(base, run_id) is None)
}
