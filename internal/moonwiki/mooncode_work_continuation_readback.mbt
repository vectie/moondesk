///|
fn mooncode_continuation_claims_items(claims : Json) -> Array[Json] {
  let items : Array[Json] = []
  for
    key in [
      "claimable_commands", "claimed_commands", "order_blocked_commands", "delivered_commands",
      "invalid_commands",
    ] {
    for item in json_array_items(claims, key) {
      items.push(item)
    }
  }
  items
}

///|
fn mooncode_continuation_item(
  target : MoonCodeWorkTarget,
  workspace : @desk.DeskWorkspace,
  claims : Json,
) -> Result[Json?, (Int, Json)] {
  let result = mooncode_work_command_projection(target, workspace, claims)
  if result.0 == 404 &&
    json_string(result.1, "state", default="") == "command_not_found" {
    return Ok(None)
  }
  if result.0 != 200 {
    return Err(result)
  }
  for item in mooncode_continuation_claims_items(claims) {
    if json_string(item, "command_id", default="") == target.command_id {
      return Ok(Some(item))
    }
  }
  Ok(None)
}

///|
fn mooncode_continuation_state(item : Json) -> String {
  let status = json_string(
    json_object_field_or_empty(item, "receipt"),
    "status",
    default="",
  )
  match status {
    "runtime-completed" => "completed"
    "runtime-failed" => "failed"
    "runtime-cancelled" => "cancelled"
    "runtime-claimed" => "running"
    "runtime-delivered" => "delivered"
    _ =>
      match json_string(item, "claim_status", default="") {
        "claimed" => "running"
        "invalid" => "invalid"
        _ => "queued"
      }
  }
}

///|
fn mooncode_continuation_settled(item : Json) -> Bool {
  ["completed", "failed", "cancelled", "delivered"].contains(
    mooncode_continuation_state(item),
  )
}

///|
fn mooncode_continuation_answer(receipt : Json) -> String {
  let mut answer = ""
  for
    result in json_array_items(
      json_object_field_or_empty(receipt, "execution"),
      "tool_results",
    ) {
    if json_string(result, "tool", default="") != "finish" ||
      !json_bool(result, "accepted", default=false) {
      continue
    }
    let nested = json_object_field_or_empty(result, "result")
    let nested = if nested == Json::empty_object() { result } else { nested }
    if json_bool(nested, "is_error", default=false) {
      continue
    }
    answer = json_string(
      json_object_field_or_empty(nested, "metadata"),
      "answer",
      default=json_string(nested, "output", default=""),
    )
  }
  answer
}

///|
fn mooncode_continuation_result(item : Json, events : Json) -> Json {
  let command_id = json_string(item, "command_id", default="")
  let session_id = json_string(item, "session_id", default="")
  let receipt = json_object_field_or_empty(item, "receipt")
  let mut state = mooncode_continuation_state(item)
  let mut checkpoint = ""
  let mut approval = ""
  let evidence : Array[Json] = []
  let output_refs : Array[Json] = []
  let receipt_id = json_string(
    receipt,
    "id",
    default=json_string(receipt, "claim_id", default=""),
  )
  if !receipt_id.is_empty() {
    evidence.push(receipt_id.to_json())
  }
  for event in json_array_items(events, "events") {
    if json_string(event, "session_id", default="") != session_id ||
      json_string(event, "command_id", default="") != command_id {
      continue
    }
    let event_kind = json_string(event, "kind", default="")
    if event_kind == "runtime.turn_checkpointed" {
      checkpoint = json_string(event, "state", default="")
      approval = json_string(event, "approval_id", default="")
    } else if ["runtime.turn_started", "runtime.planner_started"].contains(
        event_kind,
      ) &&
      ["planner-quantum-paused", "planner-replan-paused"].contains(checkpoint) {
      checkpoint = "resumed"
    } else if ["tool.approval_approved", "tool.approval_rejected"].contains(
        event_kind,
      ) &&
      !approval.is_empty() &&
      json_string(event, "approval_id", default="") == approval {
      checkpoint = "after-decision"
    }
    let id = json_string(event, "id", default="")
    if !id.is_empty() {
      evidence.push(id.to_json())
    }
    let kind = json_string(
      event,
      "event",
      default=json_string(event, "kind", default=""),
    )
    let tool = json_string(event, "tool", default="")
    let result = json_object_field_or_empty(event, "tool_result")
    if (
        (kind == "tool_result" && ["write", "edit"].contains(tool)) ||
        (kind == "patch_applied" && tool == "apply_patch")
      ) &&
      json_bool(result, "ok", default=false) &&
      !json_bool(result, "is_error", default=false) {
      let paths = [json_string(event, "path", default="")]
      for path in json_array_items(event, "changed_paths") {
        if path is String(value) {
          paths.push(value)
        }
      }
      for path in paths {
        if !path.is_empty() &&
          !@pathx.is_absolute(path) &&
          !path.split("/").any(part => part == "..") {
          output_refs.push({
            "path": path,
            "evidence_id": id,
            "command_id": command_id,
          })
        }
      }
    }
    if ["package_built", "package_verified"].contains(kind) {
      let packaged = json_object_field_or_empty(event, "package_result")
      let manifest = json_object_field_or_empty(packaged, "package_manifest")
      let paths = [
        json_string(event, "path", default=""),
        json_string(packaged, "path", default=""),
        json_string(manifest, "manifest_path", default=""),
        json_string(
          json_object_field_or_empty(packaged, "package_index"),
          "manifest_path",
          default="",
        ),
      ]
      for path in json_array_items(manifest, "candidate_paths") {
        if path is String(value) {
          paths.push(value)
        }
      }
      for source in json_array_items(manifest, "source_inventory") {
        paths.push(json_string(source, "path", default=""))
        paths.push(json_string(source, "promoted_path", default=""))
      }
      for path in paths {
        if !path.is_empty() &&
          !@pathx.is_absolute(path) &&
          !path.split("/").any(part => part == "..") {
          output_refs.push({
            "path": path,
            "evidence_id": id,
            "command_id": command_id,
          })
        }
      }
    }
  }
  let service = json_object_field_or_empty(events, "runtime_service")
  let runtime_status = json_string(service, "status", default="unavailable")
  if !mooncode_continuation_settled(item) {
    if checkpoint == "awaiting-approval" {
      state = "waiting_approval"
    } else if ["planner-quantum-paused", "planner-replan-paused"].contains(
        checkpoint,
      ) ||
      runtime_status == "waiting" ||
      (
        state == "running" &&
        ["failed", "cancelled", "stopped", "idle", "done"].contains(
          runtime_status,
        )
      ) {
      state = "interrupted"
    } else if state == "running" && runtime_status == "unavailable" {
      state = "unknown"
    }
  }
  {
    "command_id": command_id,
    "state": state,
    "runtime_status": runtime_status,
    "receipt": receipt,
    "summary": mooncode_continuation_answer(receipt),
    "error": if mooncode_continuation_state(item) == "failed" {
      "Native command failed; inspect its exact receipt"
    } else {
      ""
    },
    "evidence": Json::array(evidence),
    "output_refs": Json::array(output_refs),
  }
}

///|
fn mooncode_continuation_response(
  snapshot : Json,
  item : Json?,
  events : Json,
  admission : String,
  message? : String = "",
) -> Json {
  let result = match item {
    Some(value) => mooncode_continuation_result(value, events)
    None => Json::empty_object()
  }
  let fields : Map[String, Json] = {
    "schema": "moondesk.work-continuation.v1".to_json(),
    "state": json_string(
      result,
      "state",
      default=if admission == "accepted" { "queued" } else { admission },
    ).to_json(),
    "session_id": json_string(
      json_object_field_or_empty(snapshot, "source"),
      "session_id",
      default="",
    ).to_json(),
    "admission": admission.to_json(),
    "message": message.to_json(),
    "input_status": json_string(snapshot, "input_status", default="verified").to_json(),
  }
  for
    key in [
      "continuation_id", "client_turn_id", "command_id", "source", "instruction",
      "prior_result_command_id", "model", "original_context", "input",
    ] {
    fields[key] = json_object_field(snapshot, key).unwrap_or(Json::null())
  }
  for
    key in [
      "summary", "error", "evidence", "output_refs", "receipt", "runtime_status",
    ] {
    fields[key] = json_object_field(result, key).unwrap_or(Json::null())
  }
  Json::object(fields)
}

///|
fn mooncode_continuation_pending_guidance(
  target : MoonCodeWorkTarget,
  claims : Json,
  events : Json,
) -> Array[Json] {
  let output : Array[Json] = []
  let ids : Array[String] = []
  for event in json_array_items(events, "events") {
    if json_string(event, "session_id", default="") != target.session_id ||
      json_string(event, "kind", default="") != "steer_deferred" {
      continue
    }
    let id = json_string(event, "command_id", default="")
    let settled = json_array_items(events, "events").any(other => {
      json_string(other, "session_id", default="") == target.session_id &&
      json_string(other, "command_id", default="") == id &&
      ["steer_applied", "steer_dropped"].contains(
        json_string(other, "kind", default=""),
      )
    })
    if !id.is_empty() && !settled && !ids.contains(id) {
      ids.push(id)
      output.push({
        "command_id": id,
        "text": json_string(
          event,
          "steering_text",
          default=json_string(event, "content", default=""),
        ),
        "receipt_status": "deferred",
        "source_event_id": json_string(event, "id", default=""),
      })
    }
  }
  for item in mooncode_continuation_claims_items(claims) {
    let id = json_string(item, "command_id", default="")
    if json_string(item, "session_id", default="") == target.session_id &&
      json_string(item, "action", default="") == "steer" &&
      !mooncode_continuation_settled(item) &&
      !ids.contains(id) {
      ids.push(id)
      output.push({
        "command_id": id,
        "text": json_string(
          json_object_field_or_empty(item, "command"),
          "text",
          default="",
        ),
        "receipt_status": json_string(
          json_object_field_or_empty(item, "receipt"),
          "status",
          default="queued",
        ),
        "source_event_id": "",
      })
    }
  }
  output
}

///|
fn mooncode_continuation_events_valid(
  events : Json,
  target : MoonCodeWorkTarget,
) -> Bool {
  json_string(events, "session_id", default="") == target.session_id &&
  mooncode_work_normalized_root(json_string(events, "book_root", default="")) ==
  mooncode_work_normalized_root(target.book_root) &&
  json_object_field(events, "events") is Some(Array(_))
}

///|
async fn mooncode_continuation_read_evidence(
  target : MoonCodeWorkTarget,
  root : String,
  read : async (String) -> Result[Json, String],
) -> Json {
  let events = match
    read(
      @mooncode.moonclaw_native_runtime_events_endpoint(target.session_id, root),
    ) {
    Ok(value) if mooncode_continuation_events_valid(value, target) => value
    _ => return Json::null()
  }
  let service = match
    read(
      @mooncode.moonclaw_native_runtime_service_endpoint(
        target.session_id,
        root,
      ),
    ) {
    Ok(value) if json_string(value, "session_id", default="") ==
      target.session_id &&
      mooncode_work_normalized_root(json_string(value, "book_root", default="")) ==
      mooncode_work_normalized_root(target.book_root) => value
    _ => Json::null()
  }
  events |> mooncode_session_with_field("runtime_service", service)
}

///|
fn mooncode_continuation_native_matches(snapshot : Json, item : Json) -> Bool {
  let body = @json.parse(json_string(snapshot, "request_body", default="")) catch {
    _ => return false
  }
  json_object_field(item, "command") == Some(body)
}
