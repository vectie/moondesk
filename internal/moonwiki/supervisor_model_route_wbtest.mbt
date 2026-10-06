///|
fn supervisor_model_route_fixture(
  default_model : String,
  ready? : Bool = true,
) -> Json {
  {
    "contract": "moonclaw.moongate-route.v1",
    "ready": ready,
    "catalog_ready": true,
    "default_ready": ready,
    "default_model": default_model,
    "models": [
      { "name": "moongate/first" },
      { "name": "moongate/configured" },
      { "name": "moongate/explicit" },
    ],
  }
}

///|
fn supervisor_model_route_handoff(requested : String) -> Json {
  let payload : Json = {
    "contract_id": "moonsuite.supervisor-profile-activation.v1",
    "supervisor_id": "supervisor-user-a",
    "profile_id": "supervisor-user-a",
    "profile_version": 1,
    "profile_digest": "sha256:" + "a".repeat(64),
    "source_product": "moontown",
    "runtime_profile": { "exact": "profile" },
    "runtime_binding": {
      "workspace_id": "workspace-a",
      "building_id": "building-a",
      "book_ids": ["book-a"],
      "model": "",
      "requested_model": requested,
      "model_resolution": "pending_route",
      "max_active_workers": 3,
      "source_request_digest": "sha256:" + "b".repeat(64),
    },
    "activated_at": "2000",
  }
  {
    "schema": "moontown.supervisor-activation-handoff.v1",
    "handoff_id": "activation-route",
    "command_id": "command-route",
    "owner_user_id": "user-a",
    "payload": payload,
    "request_digest": supervisor_bridge_digest(payload),
  }
}

///|
test "supervisor resolution binds the configured model and exact authority digest" {
  let pending = supervisor_model_route_handoff("")
  guard supervisor_bridge_resolve_activation_model(
      pending,
      supervisor_model_route_fixture("moongate/configured"),
    )
    is Ok(resolved) else {
    fail(
      "configured default must resolve even when it is not the first catalog entry",
    )
  }
  let original_payload = json_object_field_or_empty(pending, "payload")
  let payload = json_object_field_or_empty(resolved, "payload")
  let binding = json_object_field_or_empty(payload, "runtime_binding")
  assert_eq(json_string(binding, "model", default=""), "moongate/configured")
  assert_eq(json_string(binding, "requested_model", default="missing"), "")
  assert_eq(
    json_object_field(payload, "runtime_profile"),
    json_object_field(original_payload, "runtime_profile"),
  )
  assert_eq(
    json_object_field(payload, "profile_digest"),
    json_object_field(original_payload, "profile_digest"),
  )
  assert_eq(
    json_string(
      json_object_field_or_empty(original_payload, "runtime_binding"),
      "model",
      default="missing",
    ),
    "",
  )
  let digest = supervisor_bridge_digest(payload)
  assert_eq(json_string(resolved, "request_digest", default=""), digest)
  assert_false(digest == json_string(pending, "request_digest", default=""))
  guard supervisor_bridge_materialized_grant(
      resolved, "activation", "activation-route", digest,
    )
    is Ok(grant) else {
    fail("durable activation must retain its exact grant")
  }
  assert_eq(
    json_string(
      json_object_field_or_empty(grant, "authority"),
      "digest",
      default="",
    ),
    digest,
  )
  let command : Json = {
    "profile": payload,
    "request_digest": digest,
    "contract_id": "moonclaw.supervisor-command.v1",
    "command_id": "command-route",
    "issued_at": "2000",
    "evaluated_at": "2026-08-01T00:00:01Z",
    "authority": json_object_field_or_empty(grant, "authority"),
  }
  guard supervisor_bridge_activation_request(command) is Ok(request) else {
    fail("resolved exact command must map")
  }
  assert_eq(json_object_field(request, "profile"), Some(payload))
  assert_eq(
    supervisor_bridge_resolve_activation_model(resolved, Json::null()),
    Ok(resolved),
  )
  assert_eq(
    supervisor_bridge_resolve_activation_model(
      resolved,
      supervisor_model_route_fixture("moongate/first"),
    ),
    Ok(resolved),
  )
}

///|
test "explicit supervisor route works without a default and missing route never falls back" {
  let pending = supervisor_model_route_handoff("moongate/explicit")
  guard supervisor_bridge_resolve_activation_model(
      pending,
      supervisor_model_route_fixture("", ready=false),
    )
    is Ok(resolved) else {
    fail("explicit route needs catalog readiness only")
  }
  let binding = json_object_field_or_empty(
    json_object_field_or_empty(resolved, "payload"),
    "runtime_binding",
  )
  assert_eq(json_string(binding, "model", default=""), "moongate/explicit")
  assert_eq(
    json_string(binding, "requested_model", default=""),
    "moongate/explicit",
  )
  for
    (requested, route) in [
      ("", Json::null()),
      ("", supervisor_model_route_fixture("", ready=false)),
      ("", supervisor_model_route_fixture("moongate/absent")),
      ("moongate/absent", supervisor_model_route_fixture("moongate/configured")),
    ] {
    assert_true(
      supervisor_bridge_resolve_activation_model(
        supervisor_model_route_handoff(requested),
        route,
      )
      is Err(_),
    )
  }
  guard pending is Object(fields) else { fail("fixture") }
  let tampered = fields.copy()
  tampered["request_digest"] = ("sha256:" + "0".repeat(64)).to_json()
  assert_true(
    supervisor_bridge_resolve_activation_model(
      Json::object(tampered),
      supervisor_model_route_fixture("moongate/configured"),
    )
    is Err(_),
  )
}

///|
async test "delegate transport preserves routed model and existing legacy selection and bounds" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-supervisor-model-" + @async.now().to_string(),
  )
  let book_root = workspace_context(root).book_root("book-a")
  @fsx.make_directory(book_root, recursive=true, exists_ok=true)
  @fsx.write_to_file(@pathx.join(book_root, "book.json"), "{}\n")
  for
    model in [
      "moongate/catalog-id/with-slash", "gpt-5.6-sol", "", "moongate/", "codex/other",
      " moongate/explicit",
    ] {
    let fixture = supervisor_bridge_delegate_fixture()
    guard fixture is Object(handoff_fields) &&
      json_object_field(fixture, "worker_task") is Some(Object(task_fields)) else {
      fail("delegate fixture")
    }
    let task = task_fields.copy()
    task["model"] = model.to_json()
    let handoff = handoff_fields.copy()
    handoff["worker_task"] = Json::object(task)
    let result = supervisor_bridge_execution_dispatch(
      Json::object(handoff),
      workspace_root=root,
    )
    if model == "gpt-5.6-sol" || model == "moongate/catalog-id/with-slash" {
      guard result is Ok(dispatch) else { fail("valid exact model should map") }
      assert_eq(
        json_string(
          json_object_field_or_empty(dispatch.body, "task"),
          "model",
          default="",
        ),
        model,
      )
      assert_eq(
        dispatch.request_digest,
        supervisor_bridge_digest(dispatch.body),
      )
      assert_eq(
        json_string(
          json_object_field_or_empty(dispatch.body, "scope"),
          "claim_ceiling",
          default="",
        ),
        "reviewable",
      )
      assert_eq(
        json_object_field_or_empty(
          json_object_field_or_empty(dispatch.body, "task"),
          "metadata",
        ),
        json_object_field_or_empty(Json::object(task), "metadata"),
      )
    } else {
      assert_true(result is Err(_))
    }
  }
}
