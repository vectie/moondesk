///|
let moonflow_review_mutex : @async.Mutex = Mutex()

///|
// A validated append-only head has moved past this request and its mutation
// is absent. It cannot subsequently apply at the old expected head, even if
// another host process is still about to ask Flow to apply it.
fn moonflow_review_definitely_stale(snapshot : Json, request : Json) -> Bool {
  let payload = json_object_field(snapshot, "payload").unwrap_or(Json::null())
  json_string(payload, "head_digest", default="") !=
  json_string(request, "expected_head", default="") &&
  !json_array_items(payload, "events").any(event => {
    json_string(event, "mutation_id", default="") ==
    json_string(request, "mutation_id", default="")
  })
}

///|
fn moonflow_review_rejected(snapshot : Json, request : Json) -> Json {
  {
    "contract_id": "moondesk.exact-result-review.v1",
    "status": "rejected",
    "mutation_status": "not-applied",
    "rejection_reason": "stale-head",
    "rejected_request": request,
    "identity": json_object_field(request, "identity").unwrap_or(Json::null()),
    "mutation_id": json_string(request, "mutation_id", default=""),
    "observed_head": json_string(
      json_object_field(snapshot, "payload").unwrap_or(Json::null()),
      "head_digest",
      default="",
    ),
    "message": "Stale collaboration head. Flow confirms this original mutation did not apply and cannot apply at its old head. Reopen the review before choosing a new decision.",
  }
}

///|
type MoonFlowReviewRun = async (@trusted_host.MoonFlowReviewOperation) -> Result[
  String,
  String,
]

///|
async fn moonflow_review_snapshot(
  run : MoonFlowReviewRun,
  workspace_id : String,
) -> Json {
  let text = match run(@trusted_host.InspectReviewWorkspace(workspace_id~)) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let snapshot = @json.parse(text)
  let payload = json_object_field(snapshot, "payload").unwrap_or(Json::null())
  let workspace = json_object_field(payload, "workspace_ref").unwrap_or(
    Json::null(),
  )
  guard json_string(snapshot, "contract_id", default="") ==
    "moonflow.collaboration-snapshot.v1" &&
    json_string(workspace, "workspace_id", default="") == workspace_id &&
    is_sha256_digest(json_string(payload, "head_digest", default="")) else {
    fail("Flow did not validate the selected collaboration workspace")
  }
  snapshot
}

///|
fn moonflow_review_matching(snapshot : Json, digest : String) -> Array[Json] {
  json_array_items(
    json_object_field(snapshot, "payload").unwrap_or(Json::null()),
    "reviews",
  ).filter(review => json_string(review, "subject_digest", default="") == digest)
}

///|
async fn moonflow_review_evidence(
  workspace_root : String,
  review : Json,
) -> Json {
  let reference = json_string(review, "decision_evidence_ref", default="")
  let digest = json_string(review, "decision_evidence_digest", default="")
  if reference == "" {
    return Json::null()
  }
  guard reference.has_prefix(".moonsuite/products/moondesk/review-evidence/") &&
    is_sha256_digest(digest) &&
    reference ==
    ".moonsuite/products/moondesk/review-evidence/" +
    digest[7:].to_owned() +
    ".json" else {
    return {
      "status": "external-evidence",
      "message": "This existing decision uses evidence outside Desk's retained review-note format",
    }
  }
  let bytes = moonflow_retained_bytes(workspace_root, reference)
  guard moonflow_retained_sha(bytes) == digest else {
    fail("Immutable review evidence changed")
  }
  let value = @json.parse(@encoding/utf8.decode(bytes))
  guard json_string(value, "contract_id", default="") ==
    "moondesk.exact-result-review-evidence.v1" &&
    moonflow_retained_same(value, review, ["review_id", "subject_digest"]) &&
    json_string(value, "decision", default="") ==
    json_string(review, "state", default="") &&
    json_object_field(value, "reviewer") ==
    json_object_field(review, "assigned_reviewer") else {
    fail("Review evidence does not match the persisted decision")
  }
  value
}

///|
async fn moonflow_review_inspection(
  workspace : @desk.DeskWorkspace,
  retained : MoonFlowRetainedResult,
  principal : Json?,
  unavailable : String,
  run : MoonFlowReviewRun,
) -> Json {
  let snapshot = moonflow_review_snapshot(run, workspace.id)
  let payload = json_object_field(snapshot, "payload").unwrap_or(Json::null())
  let reviews : Array[Json] = []
  for
    review in moonflow_review_matching(
      snapshot,
      json_string(retained.metadata, "sha256", default=""),
    ) {
    let evidence = moonflow_review_evidence(workspace.root_path, review) catch {
      error =>
        ({ "status": "unavailable", "message": error.to_string() } : Json)
    }
    reviews.push({
      "review": review,
      "authorized": match principal {
        Some(value) => moonflow_review_authorized(snapshot, review, value)
        None => false
      },
      "evidence": evidence,
    })
  }
  {
    "contract_id": "moondesk.exact-result-review.v1",
    "status": "ready",
    "identity": json_object_field(retained.metadata, "identity").unwrap_or(
      Json::null(),
    ),
    "sha256": json_string(retained.metadata, "sha256", default=""),
    "record_digest": json_string(retained.metadata, "record_digest", default=""),
    "head_digest": json_string(payload, "head_digest", default=""),
    "reviews": reviews,
    "message": if unavailable != "" {
      unavailable
    } else if reviews.is_empty() {
      "No existing collaboration review matches this exact artifact byte SHA-256"
    } else {
      "Existing exact-result collaboration review. Decisions do not accept a Flow item, accept customer work, or execute dependents."
    },
  }
}

///|
fn moonflow_review_request_valid(value : Json) -> Bool {
  guard value is Object(fields) &&
    fields.length() == 8 &&
    fields
    .iter()
    .all(pair => {
      [
        "identity", "sha256", "record_digest", "review_id", "expected_head", "mutation_id",
        "action", "notes",
      ].contains(pair.0)
    }) &&
    json_object_field(value, "identity") is Some(Object(identity)) &&
    identity.length() == 7 &&
    identity
    .iter()
    .all(pair => {
      [
        "workspace_id", "run_id", "work_item_id", "attempt_id", "result_id", "action_id",
        "artifact_index",
      ].contains(pair.0)
    }) else {
    return false
  }
  ["review_id", "mutation_id"].all(key => {
    moonflow_single_step_identifier(json_string(value, key, default=""))
  }) &&
  ["sha256", "record_digest", "expected_head"].all(key => {
    is_sha256_digest(json_string(value, key, default=""))
  }) &&
  ["begin", "approved", "changes-requested"].contains(
    json_string(value, "action", default=""),
  ) &&
  json_object_field(value, "notes") is Some(String(notes)) &&
  notes.length() <= 16384 &&
  !notes.contains("\u0000") &&
  (if json_string(value, "action", default="") == "begin" {
    notes == ""
  } else {
    notes.trim() != ""
  })
}

///|
async fn moonflow_review_apply(
  suite_root : String,
  workspace : @desk.DeskWorkspace,
  request : Json,
  principal : Json,
  recorded_at : String,
  run : MoonFlowReviewRun,
) -> Json {
  guard moonflow_review_request_valid(request) else {
    fail(
      "Invalid bounded review fields; browser actor, role and authority are not accepted",
    )
  }
  let identity = json_object_field(request, "identity").unwrap_or(Json::null())
  let retained = moonflow_retained_result(suite_root, workspace, identity)
  guard moonflow_retained_same(retained.metadata, request, [
    "sha256", "record_digest",
  ]) else {
    fail(
      "Retained result bytes or records changed since inspection; reopen the result",
    )
  }
  let snapshot = moonflow_review_snapshot(run, workspace.id)
  let matches = moonflow_review_matching(
    snapshot,
    json_string(request, "sha256", default=""),
  ).filter(review => {
    json_string(review, "review_id", default="") ==
    json_string(request, "review_id", default="")
  })
  guard matches.length() == 1 &&
    moonflow_review_authorized(snapshot, matches[0], principal) else {
    fail(
      "Only the independent active assigned human reviewer can decide this exact artifact",
    )
  }
  let action = json_string(request, "action", default="")
  let mutation_id = json_string(request, "mutation_id", default="")
  if moonflow_review_definitely_stale(snapshot, request) {
    return moonflow_review_rejected(snapshot, request)
  }
  let relative = ".moonsuite/products/moondesk/review-mutations/" + mutation_id
  let mutation_ref = relative + "/mutation.json"
  let existing = @fs.exists(workspace.root_path + "/" + mutation_ref)
  let mutation = if existing {
    let saved = @json.parse(
      @encoding/utf8.decode(
        moonflow_retained_bytes(workspace.root_path, mutation_ref),
      ),
    )
    guard json_object_field(saved, "desk_request") == Some(request) &&
      json_object_field(saved, "actor") == Some(principal) else {
      fail(
        "Mutation identity was reused with different content; the original request is immutable",
      )
    }
    saved
  } else {
    let payload = json_object_field(snapshot, "payload").unwrap_or(Json::null())
    guard json_string(payload, "head_digest", default="") ==
      json_string(request, "expected_head", default="") else {
      fail(
        "Stale collaboration head; reopen the exact review before submitting",
      )
    }
    let state = json_string(matches[0], "state", default="")
    guard (action == "begin" && state == "requested") ||
      (action != "begin" && ["requested", "in-review"].contains(state)) else {
      fail(
        "This review is already decided or cannot begin from its current state",
      )
    }
    let review_id = json_string(request, "review_id", default="")
    let mutation_payload : Json = if action == "begin" {
      { "review_id": review_id }
    } else {
      let evidence : Json = {
        "contract_id": "moondesk.exact-result-review-evidence.v1",
        "identity": identity,
        "review_id": review_id,
        "subject_digest": json_string(request, "sha256", default=""),
        "record_digest": json_string(request, "record_digest", default=""),
        "decision": action,
        "notes": json_string(request, "notes", default=""),
        "reviewer": principal,
        "mutation_id": mutation_id,
        "recorded_at": recorded_at,
        "boundary": "collaboration-only; no Flow item acceptance, customer acceptance or execution",
      }
      let bytes = @encoding/utf8.encode(evidence.stringify())
      let digest = moonflow_retained_sha(bytes)
      let evidence_directory = ".moonsuite/products/moondesk/review-evidence"
      ignore(moonflow_plan_directory(workspace.root_path, evidence_directory))
      let reference = evidence_directory + "/" + digest[7:].to_owned() + ".json"
      if @fs.exists(workspace.root_path + "/" + reference) {
        guard moonflow_retained_bytes(workspace.root_path, reference) == bytes else {
          fail("Immutable review evidence collision")
        }
      } else {
        @fs.write_file(
          workspace.root_path + "/" + reference,
          bytes,
          create_mode=CreateNew,
          permission=0o400,
        )
      }
      {
        "review_id": review_id,
        "decision": action,
        "evidence_ref": reference,
        "evidence_digest": digest,
      }
    }
    let value : Json = {
      "contract_id": "moonflow.collaboration-operator-mutation.v1",
      "workspace_id": workspace.id,
      "action": if action == "begin" {
        "review-begin"
      } else {
        "decision"
      },
      "mutation_id": mutation_id,
      "actor": principal,
      "expected_head": json_string(request, "expected_head", default=""),
      "recorded_at": recorded_at,
      "payload": mutation_payload,
      "desk_request": request,
    }
    ignore(moonflow_plan_directory(workspace.root_path, relative))
    @fs.write_file(
      workspace.root_path + "/" + mutation_ref,
      value.stringify(),
      create_mode=CreateNew,
      permission=0o400,
    )
    value
  }
  // Recheck the selected bytes immediately before entering Flow's existing
  // process-locked, expected-head mutation boundary. No acceptance shortcut.
  let fresh = moonflow_retained_result(suite_root, workspace, identity)
  guard moonflow_retained_same(fresh.metadata, request, [
    "sha256", "record_digest",
  ]) else {
    fail("Result changed before review submission")
  }
  if action != "begin" {
    let evidence = json_object_field(mutation, "payload").unwrap_or(
      Json::null(),
    )
    let bytes = moonflow_retained_bytes(
      workspace.root_path,
      json_string(evidence, "evidence_ref", default=""),
    )
    guard moonflow_retained_sha(bytes) ==
      json_string(evidence, "evidence_digest", default="") else {
      fail("Immutable review notes changed before submission")
    }
  }
  let applied = run(
    if action == "begin" {
      @trusted_host.BeginExistingReview(
        workspace_id=workspace.id,
        mutation_ref~,
      )
    } else {
      @trusted_host.DecideExistingReview(
        workspace_id=workspace.id,
        mutation_ref~,
      )
    },
  )
  // Always reopen through Flow validation, including lost acknowledgment.
  let after = moonflow_review_snapshot(run, workspace.id)
  let after_payload = json_object_field(after, "payload").unwrap_or(
    Json::null(),
  )
  let mutation_payload = json_object_field(mutation, "payload").unwrap_or(
    Json::null(),
  )
  let detail = if action == "begin" {
    json_string(request, "review_id", default="")
  } else {
    [
      json_string(request, "review_id", default=""),
      action,
      json_string(mutation_payload, "evidence_ref", default=""),
      json_string(mutation_payload, "evidence_digest", default=""),
    ].join("|")
  }
  let kind = if action == "begin" { "review-started" } else { "review-decided" }
  let actor_text = ["kind", "principal_id", "issuer", "subject"]
    .map(key => json_string(principal, key, default=""))
    .join("|")
  let expected_payload_digest = moonflow_retained_sha(
    @encoding/utf8.encode(
      [
        mutation_id,
        kind,
        actor_text,
        json_string(mutation, "expected_head", default=""),
        detail,
        json_string(mutation, "recorded_at", default=""),
      ].join("|"),
    ),
  )
  let event = json_array_items(after_payload, "events").filter(event => {
    json_string(event, "mutation_id", default="") == mutation_id &&
    json_object_field(event, "actor") == Some(principal) &&
    json_string(event, "event_kind", default="") == kind &&
    json_string(event, "payload_digest", default="") == expected_payload_digest
  })
  guard event.length() == 1 else {
    if moonflow_review_definitely_stale(after, request) {
      return moonflow_review_rejected(after, request)
    }
    match applied {
      Err(message) => fail(message)
      Ok(_) =>
        fail("Review outcome unconfirmed; retry the original mutation identity")
    }
  }
  if action != "begin" {
    let decided = moonflow_review_matching(
      after,
      json_string(request, "sha256", default=""),
    ).filter(review => {
      json_string(review, "review_id", default="") ==
      json_string(request, "review_id", default="")
    })
    guard decided.length() == 1 &&
      json_string(decided[0], "state", default="") == action &&
      json_string(decided[0], "decision_evidence_ref", default="") ==
      json_string(mutation_payload, "evidence_ref", default="") &&
      json_string(decided[0], "decision_evidence_digest", default="") ==
      json_string(mutation_payload, "evidence_digest", default="") else {
      fail(
        "Persisted review decision does not match the original immutable evidence",
      )
    }
  }
  let verified_after = moonflow_retained_result(suite_root, workspace, identity)
  guard moonflow_retained_same(verified_after.metadata, request, [
    "sha256", "record_digest",
  ]) else {
    fail(
      "Decision was persisted but retained result changed; reopen the original review",
    )
  }
  let result = moonflow_review_inspection(
    workspace,
    verified_after,
    Some(principal),
    "",
    run,
  )
  if result is Object(fields) {
    fields["mutation_id"] = mutation_id.to_json()
    fields["mutation_status"] = (if existing {
      "reconciled"
    } else {
      "persisted"
    }).to_json()
  }
  result
}

///|
async fn handle_moonflow_review(
  workspace_root : String,
  identity : Json?,
  cookie : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let request = match identity {
    Some(value) => ({ "identity": value } : Json)
    None => moonflow_plan_read_body(body) catch { _ => Json::null() }
  }
  let selected = json_object_field(request, "identity").unwrap_or(Json::null())
  let result = try {
    guard find_workspace(
        workspace_root,
        json_string(selected, "workspace_id", default=""),
      )
      is Some(workspace) else {
      fail("Select a registered Book before reviewing a retained result")
    }
    let runtime = match @trusted_host.moonflow_review_runtime() {
      Ok(value) => value
      Err(message) => fail(message)
    }
    let run : MoonFlowReviewRun = operation => {
      @trusted_host.run_moonflow_review(runtime, workspace.root_path, operation)
    }
    let suite_root = @fs.realpath(workspace_context(workspace_root).suite_root)
    if identity is Some(_) {
      let retained = moonflow_retained_result(suite_root, workspace, selected)
      let mut unavailable = ""
      let principal = Some(moonflow_review_principal(cookie, workspace.id)) catch {
        error => {
          unavailable = error.to_string()
          None
        }
      }
      moonflow_review_inspection(
        workspace, retained, principal, unavailable, run,
      )
    } else {
      moonflow_review_mutex.acquire()
      defer moonflow_review_mutex.release()
      let principal = moonflow_review_principal(cookie, workspace.id)
      moonflow_review_apply(
        suite_root,
        workspace,
        request,
        principal,
        moonflow_server_utc_timestamp(),
        run,
      )
    }
  } catch {
    error =>
      (
        {
          "contract_id": "moondesk.exact-result-review.v1",
          "status": "unavailable",
          "identity": selected,
          "mutation_id": json_string(request, "mutation_id", default=""),
          "message": error.to_string(),
        } : Json)
  }
  send_json(conn, method_, result)
}
