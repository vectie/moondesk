///|
/// Resolve the authenticated account from the configured identity service.
/// Browser role/principal/forwarded identity headers are never consulted.
async fn moonflow_review_account(cookie : String) -> Json {
  guard moondesk_authenticated_account(cookie) is Some(account) else {
    fail(
      "Review unavailable: the host could not verify the authenticated account",
    )
  }
  guard json_string(account, "state", default="") == "Active" &&
    json_string(account, "account_id", default="") != "" &&
    json_string(account, "subject_ref", default="") != "" else {
    fail("Review requires an active authenticated account")
  }
  account
}

///|
fn moonflow_review_mapped_principal(
  mapping : Json,
  endpoint : String,
  account : Json,
  workspace_id : String,
) -> Json raise {
  guard json_string(mapping, "contract_id", default="") ==
    "moondesk.review-principal-map.v1" &&
    json_string(mapping, "identity_endpoint", default="") == endpoint else {
    fail(
      "Review unavailable: host account mapping does not match the authenticated identity service",
    )
  }
  let matches = json_array_items(mapping, "bindings").filter(binding => {
    json_string(binding, "workspace_id", default="") == workspace_id &&
    moonflow_retained_same(binding, account, ["account_id", "subject_ref"])
  })
  guard matches.length() == 1 else {
    fail(
      "Review unavailable: this authenticated account has no unambiguous host mapping for the selected Book",
    )
  }
  let principal = json_object_field(matches[0], "principal").unwrap_or(
    Json::null(),
  )
  guard json_string(principal, "contract_id", default="") ==
    "moonsuite.principal-ref.v1" &&
    json_string(principal, "kind", default="") == "human" else {
    fail("Review mapping must identify an existing human principal")
  }
  principal
}

///|
async fn moonflow_review_principal(
  cookie : String,
  workspace_id : String,
) -> Json {
  let path = moondesk_access_env("MOONDESK_REVIEW_PRINCIPAL_MAP")
  guard path.has_prefix("/") &&
    @fs.exists(path) &&
    @fs.realpath(path) == path &&
    @fs.kind(path, follow_symlink=false) == Regular else {
    fail(
      "Review unavailable: production human-principal mapping has not been configured by the host",
    )
  }
  let account = @async.with_timeout(5000, () => moonflow_review_account(cookie))
  let mapping = @json.parse(agent_export_bounded_text(path, 65536))
  moonflow_review_mapped_principal(
    mapping,
    moondesk_access_env("MOONDESK_IDENTITY_ENDPOINT"),
    account,
    workspace_id,
  )
}

///|
fn moonflow_review_authorized(
  snapshot : Json,
  review : Json,
  principal : Json,
) -> Bool {
  let payload = json_object_field(snapshot, "payload").unwrap_or(Json::null())
  json_string(principal, "kind", default="") == "human" &&
  json_object_field(review, "assigned_reviewer") == Some(principal) &&
  json_object_field(review, "submitted_by") != Some(principal) &&
  json_array_items(payload, "memberships")
  .filter(membership => {
    json_object_field(membership, "principal") == Some(principal) &&
    json_string(membership, "status", default="") == "active" &&
    json_array_items(membership, "roles").contains(ToJson::to_json("reviewer"))
  })
  .length() ==
  1
}
