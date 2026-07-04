///|
// Command-owned package/review model flow gate.
//
// This report keeps package/review readiness deterministic: a package turn is
// accepted only when one command owner has the manifest, review decision, test
// evidence, verified readiness, and final assistant summary. Evidence without a
// matching package command is stale diagnostics, not completion proof.

///|
priv struct PackageReviewModelFlow {
  command_id : String
  client_turn_id : String
  runtime_session_id : String
  run_id : String
  action : String
  model : String
  command_seen_at : String
  mut package_manifest_count : Int
  mut diff_review_count : Int
  mut review_accept_count : Int
  mut review_reject_count : Int
  mut test_pass_count : Int
  mut test_fail_count : Int
  mut package_built_count : Int
  mut package_verified_count : Int
  mut readiness_failed_count : Int
  mut assistant_summary_count : Int
  mut failure_event_count : Int
  mut latest_event_id : String
  mut latest_kind : String
  mut latest_status : String
  mut latest_created_at : String
}

///|
pub fn package_review_model_flow_contract_json() -> Json {
  @mooncode_core.package_review_flow_contract_json()
}

///|
pub fn package_review_model_flow_report(
  session_id : String,
  events : Array[Json],
) -> Json {
  let flows : Array[PackageReviewModelFlow] = []
  let stale_evidence : Array[Json] = []
  let mut observed_at = ""
  for event in events {
    observed_at = package_review_latest_timestamp(
      observed_at,
      json_string(event, "created_at", default=""),
    )
    match package_review_command_candidate(event) {
      Some(flow) =>
        if package_review_flow_index(flows, flow.command_id) < 0 {
          flows.push(flow)
        }
      None => ()
    }
  }
  for event in events {
    if package_review_event_is_flow_evidence(event) {
      let command_id = package_review_event_command_id(event)
      if command_id == "" {
        stale_evidence.push(
          package_review_stale_evidence(
            event,
            @mooncode_core.package_review_flow_reason_missing_command_owner(),
          ),
        )
      } else {
        let index = package_review_flow_index(flows, command_id)
        if index >= 0 {
          package_review_apply_event(flows[index], event)
        } else {
          stale_evidence.push(
            package_review_stale_evidence(
              event,
              @mooncode_core.package_review_flow_reason_evidence_without_package_command(),
            ),
          )
        }
      }
    }
  }
  let flow_items : Array[Json] = []
  let mut accepted_count = 0
  let mut rejected_count = 0
  let mut failed_count = 0
  let mut incomplete_count = 0
  for flow in flows {
    let status = package_review_flow_status(flow)
    if status == @mooncode_core.package_review_flow_status_accepted() {
      accepted_count += 1
    } else if status == @mooncode_core.package_review_flow_status_rejected() {
      rejected_count += 1
    } else if status == @mooncode_core.package_review_flow_status_failed() {
      failed_count += 1
    } else {
      incomplete_count += 1
    }
    flow_items.push(package_review_flow_json(flow, status))
  }
  let status = if stale_evidence.length() > 0 {
    @mooncode_core.package_review_flow_status_stale()
  } else if failed_count > 0 {
    @mooncode_core.package_review_flow_status_failed()
  } else if incomplete_count > 0 {
    @mooncode_core.package_review_flow_status_running()
  } else if rejected_count > 0 && accepted_count == 0 {
    @mooncode_core.package_review_flow_status_rejected()
  } else if accepted_count > 0 {
    @mooncode_core.package_review_flow_status_accepted()
  } else {
    @mooncode_core.package_review_flow_status_empty()
  }
  {
    "kind": @mooncode_core.package_review_flow_report_kind(),
    "protocol": protocol_version(),
    "session_id": session_id,
    "observed_at": observed_at,
    "status": status,
    "contract_satisfied": flows.length() > 0 &&
    stale_evidence.length() == 0 &&
    incomplete_count == 0,
    "package_command_count": flows.length(),
    "accepted_command_count": accepted_count,
    "rejected_command_count": rejected_count,
    "failed_command_count": failed_count,
    "incomplete_command_count": incomplete_count,
    "stale_evidence_count": stale_evidence.length(),
    "stale_evidence": Json::array(stale_evidence),
    "commands": Json::array(flow_items),
    "contract": package_review_model_flow_contract_json(),
  }
}

///|
fn package_review_command_candidate(event : Json) -> PackageReviewModelFlow? {
  let kind = json_string(event, "kind", default="")
  let action = package_review_event_action(event)
  if !@mooncode_core.package_review_flow_event_is_package_command(event) {
    return None
  }
  let command_id = package_review_event_command_id(event)
  if command_id == "" {
    return None
  }
  let packet = runtime_json_object_field_or_empty(event, "command_packet")
  Some({
    command_id,
    client_turn_id: json_string(packet, "client_turn_id", default=command_id),
    runtime_session_id: json_string(packet, "runtime_session_id", default=""),
    run_id: package_review_event_run_id(event),
    action,
    model: json_string(packet, "model", default=""),
    command_seen_at: json_string(event, "created_at", default=""),
    package_manifest_count: 0,
    diff_review_count: 0,
    review_accept_count: 0,
    review_reject_count: 0,
    test_pass_count: 0,
    test_fail_count: 0,
    package_built_count: 0,
    package_verified_count: 0,
    readiness_failed_count: 0,
    assistant_summary_count: 0,
    failure_event_count: 0,
    latest_event_id: json_string(event, "id", default=""),
    latest_kind: kind,
    latest_status: json_string(event, "status", default=""),
    latest_created_at: json_string(event, "created_at", default=""),
  })
}

///|
fn package_review_flow_index(
  flows : Array[PackageReviewModelFlow],
  command_id : String,
) -> Int {
  for index, flow in flows {
    if flow.command_id == command_id {
      return index
    }
  }
  -1
}

///|
fn package_review_apply_event(
  flow : PackageReviewModelFlow,
  event : Json,
) -> Unit {
  let status = json_string(event, "status", default="")
  if package_review_event_is_package_manifest(event) {
    flow.package_manifest_count += 1
  }
  if package_review_event_is_diff_review(event) {
    flow.diff_review_count += 1
  }
  if package_review_event_is_accept(event) {
    flow.review_accept_count += 1
  }
  if package_review_event_is_reject(event) {
    flow.review_reject_count += 1
  }
  if package_review_event_is_test_result(event) {
    if package_review_event_failed(event) {
      flow.test_fail_count += 1
    } else {
      flow.test_pass_count += 1
    }
  }
  if @mooncode_core.package_review_flow_event_is_package_built(event) {
    if status == @mooncode_core.package_review_flow_status_failed() {
      flow.readiness_failed_count += 1
    } else {
      flow.package_built_count += 1
    }
  }
  if @mooncode_core.package_review_flow_event_is_package_verified(event) {
    if status == @mooncode_core.package_review_flow_status_failed() {
      flow.readiness_failed_count += 1
    } else {
      flow.package_verified_count += 1
    }
  }
  if package_review_event_is_assistant_summary(event) {
    flow.assistant_summary_count += 1
  }
  if package_review_event_is_failure(event) {
    flow.failure_event_count += 1
  }
  package_review_note_latest(flow, event)
}

///|
fn package_review_flow_status(flow : PackageReviewModelFlow) -> String {
  if flow.failure_event_count > 0 ||
    flow.test_fail_count > 0 ||
    flow.readiness_failed_count > 0 {
    @mooncode_core.package_review_flow_status_failed()
  } else if flow.review_reject_count > 0 {
    if flow.assistant_summary_count > 0 {
      @mooncode_core.package_review_flow_status_rejected()
    } else {
      @mooncode_core.package_review_flow_status_waiting_for_assistant()
    }
  } else if flow.package_manifest_count == 0 {
    @mooncode_core.package_review_flow_status_waiting_for_manifest()
  } else if flow.review_accept_count == 0 {
    @mooncode_core.package_review_flow_status_waiting_for_review()
  } else if flow.test_pass_count == 0 {
    @mooncode_core.package_review_flow_status_waiting_for_tests()
  } else if flow.package_verified_count == 0 {
    @mooncode_core.package_review_flow_status_waiting_for_readiness()
  } else if flow.assistant_summary_count == 0 {
    @mooncode_core.package_review_flow_status_waiting_for_assistant()
  } else {
    @mooncode_core.package_review_flow_status_accepted()
  }
}

///|
fn package_review_flow_json(
  flow : PackageReviewModelFlow,
  status : String,
) -> Json {
  {
    "command_id": flow.command_id,
    "client_turn_id": flow.client_turn_id,
    "runtime_session_id": flow.runtime_session_id,
    "run_id": flow.run_id,
    "action": flow.action,
    "model": flow.model,
    "command_seen_at": flow.command_seen_at,
    "status": status,
    "terminal": package_review_flow_terminal(status),
    "accepted": status == @mooncode_core.package_review_flow_status_accepted(),
    "rejected": status == @mooncode_core.package_review_flow_status_rejected(),
    "failed": status == @mooncode_core.package_review_flow_status_failed(),
    "package_manifest_count": flow.package_manifest_count,
    "diff_review_count": flow.diff_review_count,
    "review_accept_count": flow.review_accept_count,
    "review_reject_count": flow.review_reject_count,
    "test_pass_count": flow.test_pass_count,
    "test_fail_count": flow.test_fail_count,
    "package_built_count": flow.package_built_count,
    "package_verified_count": flow.package_verified_count,
    "readiness_failed_count": flow.readiness_failed_count,
    "assistant_summary_count": flow.assistant_summary_count,
    "failure_event_count": flow.failure_event_count,
    "missing_steps": string_array_json(
      package_review_missing_steps(flow, status),
    ),
    "latest_event_id": flow.latest_event_id,
    "latest_kind": flow.latest_kind,
    "latest_status": flow.latest_status,
    "latest_created_at": flow.latest_created_at,
    "owner": {
      "command_id": flow.command_id,
      "client_turn_id": flow.client_turn_id,
      "runtime_session_id": flow.runtime_session_id,
      "run_id": flow.run_id,
      "action": flow.action,
    },
  }
}

///|
fn package_review_missing_steps(
  flow : PackageReviewModelFlow,
  status : String,
) -> Array[String] {
  let missing : Array[String] = []
  if @mooncode_core.package_review_flow_status_is_terminal(status) {
    return missing
  }
  if flow.review_reject_count > 0 {
    if flow.assistant_summary_count == 0 {
      missing.push(
        @mooncode_core.package_review_flow_missing_step_assistant_summary(),
      )
    }
    return missing
  }
  if flow.package_manifest_count == 0 {
    missing.push(
      @mooncode_core.package_review_flow_missing_step_package_manifest(),
    )
  }
  if flow.review_accept_count == 0 {
    missing.push(
      @mooncode_core.package_review_flow_missing_step_review_accept_receipt(),
    )
  }
  if flow.test_pass_count == 0 {
    missing.push(
      @mooncode_core.package_review_flow_missing_step_test_evidence(),
    )
  }
  if flow.package_verified_count == 0 {
    missing.push(
      @mooncode_core.package_review_flow_missing_step_package_verified(),
    )
  }
  if flow.assistant_summary_count == 0 {
    missing.push(
      @mooncode_core.package_review_flow_missing_step_assistant_summary(),
    )
  }
  missing
}

///|
fn package_review_flow_terminal(status : String) -> Bool {
  @mooncode_core.package_review_flow_status_is_terminal(status)
}

///|
fn package_review_note_latest(
  flow : PackageReviewModelFlow,
  event : Json,
) -> Unit {
  let created_at = json_string(event, "created_at", default="")
  if package_review_latest_timestamp(flow.latest_created_at, created_at) ==
    created_at {
    flow.latest_event_id = json_string(event, "id", default="")
    flow.latest_kind = json_string(event, "kind", default="")
    flow.latest_status = json_string(event, "status", default="")
    flow.latest_created_at = created_at
  }
}

///|
fn package_review_event_is_flow_evidence(event : Json) -> Bool {
  @mooncode_core.package_review_flow_event_is_evidence(event)
}

///|
fn package_review_event_is_package_manifest(event : Json) -> Bool {
  @mooncode_core.package_review_flow_event_is_package_manifest(event)
}

///|
fn package_review_event_is_diff_review(event : Json) -> Bool {
  @mooncode_core.package_review_flow_event_is_diff_review(event)
}

///|
fn package_review_event_is_accept(event : Json) -> Bool {
  @mooncode_core.package_review_flow_event_is_accept(event)
}

///|
fn package_review_event_is_reject(event : Json) -> Bool {
  @mooncode_core.package_review_flow_event_is_reject(event)
}

///|
fn package_review_event_is_test_result(event : Json) -> Bool {
  @mooncode_core.package_review_flow_event_is_test_result(event)
}

///|
fn package_review_event_is_assistant_summary(event : Json) -> Bool {
  @mooncode_core.package_review_flow_event_is_assistant_summary(event)
}

///|
fn package_review_event_is_failure(event : Json) -> Bool {
  @mooncode_core.package_review_flow_event_is_failure(event)
}

///|
fn package_review_event_failed(event : Json) -> Bool {
  @mooncode_core.package_review_flow_event_failed(event)
}

///|
fn package_review_stale_evidence(event : Json, reason : String) -> Json {
  {
    "reason": reason,
    "event_id": json_string(event, "id", default=""),
    "kind": json_string(event, "kind", default=""),
    "status": json_string(event, "status", default=""),
    "created_at": json_string(event, "created_at", default=""),
    "command_id": package_review_event_command_id(event),
    "action": package_review_event_action(event),
    "owner": package_review_event_owner(event),
  }
}

///|
fn package_review_event_owner(event : Json) -> Json {
  let packet = runtime_json_object_field_or_empty(event, "command_packet")
  {
    "event_id": json_string(event, "id", default=""),
    "kind": json_string(event, "kind", default=""),
    "command_id": package_review_event_command_id(event),
    "client_turn_id": json_string(packet, "client_turn_id", default=""),
    "runtime_session_id": json_string(packet, "runtime_session_id", default=""),
    "run_id": package_review_event_run_id(event),
    "action": package_review_event_action(event),
  }
}

///|
fn package_review_event_command_id(event : Json) -> String {
  let packet = runtime_json_object_field_or_empty(event, "command_packet")
  let packet_id = json_string(packet, "command_id", default="")
  if packet_id != "" {
    return packet_id
  }
  runtime_first_string(
    event,
    ["command_id", "commandId", "mooncode_command_id"],
    default="",
  )
}

///|
fn package_review_event_action(event : Json) -> String {
  let command = json_string(event, "command", default="")
  if command != "" {
    return command
  }
  let packet = runtime_json_object_field_or_empty(event, "command_packet")
  json_string(packet, "action", default="")
}

///|
fn package_review_event_run_id(event : Json) -> String {
  let packet = runtime_json_object_field_or_empty(event, "command_packet")
  let packet_run_id = json_string(packet, "run_id", default="")
  if packet_run_id != "" {
    return packet_run_id
  }
  runtime_first_string(event, ["run_id", "moonclaw_run_id"], default="")
}

///|
fn package_review_latest_timestamp(
  current : String,
  candidate : String,
) -> String {
  if candidate == "" {
    current
  } else if current == "" || candidate >= current {
    candidate
  } else {
    current
  }
}
