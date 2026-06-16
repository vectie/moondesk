///|
pub fn change_set_manifest(
  session : Json,
  events : Array[Json],
  recorded_at~ : String,
  manifest_path~ : String,
  absolute_manifest_path~ : String,
) -> Json {
  let diff_events = change_set_lane_entries(events, "diff")
  let test_events = change_set_lane_entries(events, "test")
  let artifact_events = change_set_lane_entries(events, "artifact")
  let review_events = change_set_lane_entries(events, "review")
  let accepted_count = count_review_command(events, "accept")
  let rejected_count = count_review_command(events, "reject")
  {
    "kind": "mooncode-change-set",
    "protocol": "mooncode.v1",
    "status": review_state(diff_events.length(), accepted_count, rejected_count),
    "session_id": json_string(session, "id", default=""),
    "workspace_id": json_string(session, "workspace_id", default=""),
    "workspace_name": json_string(session, "workspace_name", default=""),
    "task_id": json_string(session, "moonclaw_task_id", default=""),
    "recorded_at": recorded_at,
    "manifest_path": manifest_path,
    "absolute_manifest_path": absolute_manifest_path,
    "diffs": Json::array(diff_events),
    "tests": Json::array(test_events),
    "artifacts": Json::array(artifact_events),
    "reviews": Json::array(review_events),
    "diff_count": diff_events.length(),
    "test_count": test_events.length(),
    "artifact_count": artifact_events.length(),
    "review_count": review_events.length(),
    "accepted_review_count": accepted_count,
    "rejected_review_count": rejected_count,
    "pending_diff_count": pending_diff_count(
      diff_events.length(),
      accepted_count,
      rejected_count,
    ),
    "verified_test_count": count_verified_tests(events),
    "failed_test_count": count_failed_tests(events),
    "last_command_packet": summary_json_object_field_or_empty(
      session, "mooncode_last_command_packet",
    ),
    "last_review_receipt": summary_json_object_field_or_empty(
      session, "mooncode_last_review_receipt",
    ),
    "last_package_manifest": summary_json_object_field_or_empty(
      session, "mooncode_last_package_manifest",
    ),
    "owner": review_artifact_owner("moonbook"),
    "next_runtime_step": "MoonClaw or standalone MoonCode should promote this change set into verified patch staging, tests, and packaged MoonBook code.",
  }
}

///|
pub fn patch_set_manifest(
  session : Json,
  events : Array[Json],
  recorded_at~ : String,
  manifest_path~ : String,
  absolute_manifest_path~ : String,
) -> Json {
  let patches = patch_set_entries(events)
  let accepted_count = count_patch_review_state(patches, "accepted")
  let rejected_count = count_patch_review_state(patches, "rejected")
  let applied_count = count_patch_review_state(patches, "applied")
  let reverted_count = count_patch_review_state(patches, "reverted")
  let pending_count = count_patch_review_state(patches, "pending")
  let runtime_applied_count = count_patch_execution_state(patches, "applied")
  let runtime_reverted_count = count_patch_execution_state(patches, "reverted")
  let runtime_pending_count = count_patch_execution_state(patches, "pending")
  {
    "kind": "mooncode-patch-set",
    "protocol": "mooncode.v1",
    "status": patch_set_status(
      accepted_count, rejected_count, applied_count, reverted_count, pending_count,
    ),
    "execution_status": patch_execution_set_status(
      runtime_applied_count, runtime_reverted_count, runtime_pending_count,
    ),
    "session_id": json_string(session, "id", default=""),
    "workspace_id": json_string(session, "workspace_id", default=""),
    "workspace_name": json_string(session, "workspace_name", default=""),
    "task_id": json_string(session, "moonclaw_task_id", default=""),
    "recorded_at": recorded_at,
    "manifest_path": manifest_path,
    "absolute_manifest_path": absolute_manifest_path,
    "patches": Json::array(patches),
    "patch_count": patches.length(),
    "accepted_patch_count": accepted_count,
    "rejected_patch_count": rejected_count,
    "applied_patch_count": applied_count,
    "reverted_patch_count": reverted_count,
    "pending_patch_count": pending_count,
    "runtime_applied_patch_count": runtime_applied_count,
    "runtime_reverted_patch_count": runtime_reverted_count,
    "runtime_pending_patch_count": runtime_pending_count,
    "runtime_patch_proof_count": count_patch_execution_proofs(events),
    "last_command_packet": summary_json_object_field_or_empty(
      session, "mooncode_last_command_packet",
    ),
    "last_review_receipt": summary_json_object_field_or_empty(
      session, "mooncode_last_review_receipt",
    ),
    "change_set_manifest": summary_json_object_field_or_empty(
      session, "mooncode_last_change_set_manifest",
    ),
    "owner": review_artifact_owner("moonbook"),
    "next_runtime_step": "MoonClaw or standalone MoonCode should turn this patch set into explicit staged hunks with apply/revert and verified test gates.",
  }
}

///|
pub fn tool_approvals_manifest(
  session : Json,
  events : Array[Json],
  recorded_at~ : String,
  manifest_path~ : String,
  absolute_manifest_path~ : String,
) -> Json {
  let approvals = tool_approval_entries(events)
  let approved_count = count_tool_approval_state(approvals, "approved")
  let rejected_count = count_tool_approval_state(approvals, "rejected")
  let pending_count = count_tool_approval_state(approvals, "pending")
  {
    "kind": "mooncode-tool-approvals",
    "protocol": "mooncode.v1",
    "status": if rejected_count > 0 {
      "rejected"
    } else if pending_count > 0 {
      "pending"
    } else if approved_count > 0 {
      "approved"
    } else {
      "empty"
    },
    "session_id": json_string(session, "id", default=""),
    "workspace_id": json_string(session, "workspace_id", default=""),
    "workspace_name": json_string(session, "workspace_name", default=""),
    "task_id": json_string(session, "moonclaw_task_id", default=""),
    "recorded_at": recorded_at,
    "manifest_path": manifest_path,
    "absolute_manifest_path": absolute_manifest_path,
    "approvals": Json::array(approvals),
    "approval_count": approvals.length(),
    "pending_approval_count": pending_count,
    "approved_approval_count": approved_count,
    "rejected_approval_count": rejected_count,
    "last_command_packet": summary_json_object_field_or_empty(
      session, "mooncode_last_command_packet",
    ),
    "last_review_receipt": summary_json_object_field_or_empty(
      session, "mooncode_last_review_receipt",
    ),
    "owner": {
      "ui": "moondesk",
      "runtime": "moonclaw",
      "review": "moonbook",
      "extractable_component": "mooncode",
    },
    "next_runtime_step": "MoonClaw or standalone MoonCode should enforce these tool approval decisions before executing policy/review-gated tools.",
  }
}

///|
pub fn test_runs_manifest(
  session : Json,
  events : Array[Json],
  recorded_at~ : String,
  manifest_path~ : String,
  absolute_manifest_path~ : String,
) -> Json {
  let runs = test_run_entries(events)
  let passed_count = count_test_run_state(runs, "passed")
  let failed_count = count_test_run_state(runs, "failed")
  let running_count = count_test_run_state(runs, "running")
  let queued_count = count_test_run_state(runs, "queued")
  {
    "kind": "mooncode-test-runs",
    "protocol": "mooncode.v1",
    "status": if failed_count > 0 {
      "failed"
    } else if running_count > 0 {
      "running"
    } else if queued_count > 0 {
      "queued"
    } else if passed_count > 0 {
      "passed"
    } else {
      "empty"
    },
    "session_id": json_string(session, "id", default=""),
    "workspace_id": json_string(session, "workspace_id", default=""),
    "workspace_name": json_string(session, "workspace_name", default=""),
    "task_id": json_string(session, "moonclaw_task_id", default=""),
    "recorded_at": recorded_at,
    "manifest_path": manifest_path,
    "absolute_manifest_path": absolute_manifest_path,
    "runs": Json::array(runs),
    "run_count": runs.length(),
    "passed_run_count": passed_count,
    "failed_run_count": failed_count,
    "running_run_count": running_count,
    "queued_run_count": queued_count,
    "verified_run_count": count_verified_tests(events),
    "last_command_packet": summary_json_object_field_or_empty(
      session, "mooncode_last_command_packet",
    ),
    "change_set_manifest": summary_json_object_field_or_empty(
      session, "mooncode_last_change_set_manifest",
    ),
    "patch_set_manifest": summary_json_object_field_or_empty(
      session, "mooncode_last_patch_set_manifest",
    ),
    "owner": {
      "ui": "moondesk",
      "runtime": "moonclaw",
      "artifact": "moonbook",
      "test": "moonbook",
      "extractable_component": "mooncode",
    },
    "next_runtime_step": "MoonClaw or standalone MoonCode should execute these commands directly, stream stdout/stderr, and attach exact test/build logs.",
  }
}

///|
pub fn package_manifest(
  session : Json,
  receipt : Json,
  command_packet : Json,
  context_path : String,
  detail : String,
  command_created_at : String,
  recorded_at : String,
  manifest_path : String,
  absolute_manifest_path : String,
  source_inventory : Array[Json],
) -> Json {
  let source_present_count = package_source_present_count(source_inventory)
  let promoted_source_count = package_source_promoted_count(source_inventory)
  {
    "kind": "mooncode-package-manifest",
    "protocol": "mooncode.v1",
    "status": "candidate",
    "package_kind": package_kind_for_path(context_path),
    "session_id": json_string(session, "id", default=""),
    "workspace_id": json_string(session, "workspace_id", default=""),
    "workspace_name": json_string(session, "workspace_name", default=""),
    "task_id": json_string(session, "moonclaw_task_id", default=""),
    "context_path": context_path,
    "candidate_paths": string_array_json(package_candidate_paths(context_path)),
    "source_inventory": Json::array(source_inventory),
    "promoted_sources": Json::array(source_inventory),
    "source_inventory_count": source_inventory.length(),
    "source_present_count": source_present_count,
    "promoted_source_count": promoted_source_count,
    "source_promotion_status": if promoted_source_count ==
      source_inventory.length() &&
      source_inventory.length() > 0 {
      "promoted"
    } else if promoted_source_count > 0 {
      "partially-promoted"
    } else {
      "not-promoted"
    },
    "source_inventory_status": if source_present_count > 0 {
      "source-bound"
    } else {
      "no-source-yet"
    },
    "command_id": json_string(command_packet, "command_id", default="command"),
    "command_created_at": command_created_at,
    "recorded_at": recorded_at,
    "manifest_path": manifest_path,
    "absolute_manifest_path": absolute_manifest_path,
    "review_receipt_path": json_string(receipt, "receipt_path", default=""),
    "detail": detail,
    "command_packet": command_packet,
    "owner": package_artifact_owner(),
    "next_runtime_step": "MoonClaw or standalone MoonCode should turn this candidate manifest into a verified tool, miniapp, generated site, or app-tool bundle.",
  }
}

///|
fn package_source_promoted_count(source_inventory : Array[Json]) -> Int {
  let mut count = 0
  for source in source_inventory {
    if json_bool(source, "promoted", default=false) {
      count += 1
    }
  }
  count
}

///|
pub fn package_index_manifest(
  session : Json,
  session_id : String,
  latest_manifest : Json,
  packages : Array[Json],
  recorded_at : String,
  manifest_path : String,
  absolute_manifest_path : String,
  package_root : String,
) -> Json {
  let source_bound = count_package_candidate_status(packages, "source-bound")
  let missing_source = count_package_candidate_status(packages, "no-source-yet")
  let events = json_array_items(session, "mooncode_command_events")
  let runtime_built = count_package_runtime_state(events, "built")
  let runtime_verified = count_package_runtime_state(events, "verified")
  {
    "kind": "mooncode-package-index",
    "protocol": "mooncode.v1",
    "status": if runtime_verified > 0 {
      "verified"
    } else if runtime_built > 0 {
      "built"
    } else if source_bound > 0 {
      "source-bound"
    } else if packages.length() > 0 {
      "candidate"
    } else {
      "empty"
    },
    "session_id": json_string(session, "id", default=session_id),
    "workspace_id": json_string(session, "workspace_id", default=""),
    "workspace_name": json_string(session, "workspace_name", default=""),
    "task_id": json_string(session, "moonclaw_task_id", default=""),
    "recorded_at": recorded_at,
    "manifest_path": manifest_path,
    "absolute_manifest_path": absolute_manifest_path,
    "package_root": package_root,
    "package_count": packages.length(),
    "source_bound_package_count": source_bound,
    "missing_source_package_count": missing_source,
    "executable_ready_count": source_bound,
    "runtime_built_package_count": runtime_built,
    "runtime_verified_package_count": runtime_verified,
    "runtime_package_proof_count": count_package_runtime_proofs(events),
    "package_kinds": string_array_json(package_index_kinds(packages)),
    "entry_points": string_array_json(package_index_entry_points(packages)),
    "packages": Json::array(packages),
    "latest_package_manifest": latest_manifest,
    "descriptor_contract": {
      "owner": "moonbook",
      "consumer": "moonclaw-or-standalone-mooncode",
      "rule": "This index is the stable MoonBook package registry for a MoonCode session. Per-command package manifests remain audit records; index.json is the resumable handoff for bundle assembly, review, and extraction into a future mooncode component.",
    },
    "owner": package_artifact_owner(),
  }
}

///|
pub fn package_candidates_projection(
  session : Json,
  session_id : String,
  packages : Array[Json],
  index_manifest : Json,
) -> Json {
  let source_bound = count_package_candidate_status(packages, "source-bound")
  let no_source = count_package_candidate_status(packages, "no-source-yet")
  let events = json_array_items(session, "mooncode_command_events")
  let projection_packages = package_projection_entries(packages, events)
  let runtime_built = count_package_runtime_state(events, "built")
  let runtime_verified = count_package_runtime_state(events, "verified")
  let last_package = if packages.length() > 0 {
    packages[packages.length() - 1]
  } else {
    Json::object({})
  }
  {
    "kind": "mooncode-package-candidates",
    "protocol": "mooncode.v1",
    "status": if runtime_verified > 0 {
      "verified"
    } else if runtime_built > 0 {
      "built"
    } else if packages.length() > 0 {
      "candidate"
    } else {
      "empty"
    },
    "session_id": session_id,
    "workspace_id": json_string(session, "workspace_id", default=""),
    "workspace_name": json_string(session, "workspace_name", default=""),
    "task_id": json_string(session, "moonclaw_task_id", default=""),
    "recorded_at": json_string(last_package, "recorded_at", default=""),
    "package_count": packages.length(),
    "source_bound_package_count": source_bound,
    "missing_source_package_count": no_source,
    "runtime_built_package_count": runtime_built,
    "runtime_verified_package_count": runtime_verified,
    "runtime_package_proof_count": count_package_runtime_proofs(events),
    "package_index_status": json_string(
      index_manifest,
      "status",
      default="missing",
    ),
    "package_index_path": json_string(
      index_manifest,
      "manifest_path",
      default="",
    ),
    "package_index_source_bound_count": summary_json_int(
      index_manifest,
      "source_bound_package_count",
      default=0,
    ),
    "package_index_executable_ready_count": summary_json_int(
      index_manifest,
      "executable_ready_count",
      default=0,
    ),
    "package_index_entry_points": Json::array(
      json_array_items(index_manifest, "entry_points"),
    ),
    "packages": Json::array(projection_packages),
    "last_package_manifest": last_package,
    "last_package_index_manifest": index_manifest,
    "owner": package_artifact_owner(),
    "rule": "Package candidates are MoonBook-owned manifests. Moondesk only renders package readiness and sends operator commands; MoonClaw or standalone MoonCode must assemble verified bundles and emit package_built or package_verified runtime proof events.",
  }
}

///|
pub fn change_set_manifest_event(manifest : Json, event_id : String) -> Json {
  review_manifest_event(
    manifest,
    event_id,
    lane="review",
    kind="change_set.manifest",
    title="MoonCode change set",
    detail_prefix="MoonBook change-set manifest recorded at",
    command_packet=summary_json_object_field_or_empty(
      manifest, "last_command_packet",
    ),
  )
}

///|
pub fn patch_set_manifest_event(manifest : Json, event_id : String) -> Json {
  review_manifest_event(
    manifest,
    event_id,
    lane="review",
    kind="patch_set.manifest",
    title="MoonCode patch set",
    detail_prefix="MoonBook patch-set manifest recorded at",
    command_packet=summary_json_object_field_or_empty(
      manifest, "last_command_packet",
    ),
  )
}

///|
pub fn tool_approvals_manifest_event(
  manifest : Json,
  event_id : String,
) -> Json {
  review_manifest_event(
    manifest,
    event_id,
    lane="review",
    kind="tool_approvals.manifest",
    title="MoonCode tool approvals",
    detail_prefix="MoonBook tool-approval manifest recorded at",
    command_packet=summary_json_object_field_or_empty(
      manifest, "last_command_packet",
    ),
  )
}

///|
pub fn test_runs_manifest_event(manifest : Json, event_id : String) -> Json {
  review_manifest_event(
    manifest,
    event_id,
    lane="review",
    kind="test_runs.manifest",
    title="MoonCode test runs",
    detail_prefix="MoonBook test-run manifest recorded at",
    command_packet=summary_json_object_field_or_empty(
      manifest, "last_command_packet",
    ),
  )
}

///|
pub fn action_plan_manifest_event(manifest : Json, event_id : String) -> Json {
  review_manifest_event(
    manifest,
    event_id,
    lane="runtime",
    kind="action_plan.manifest",
    title="MoonCode action plan",
    detail_prefix="MoonCode action plan recorded at",
  )
}

///|
pub fn runtime_evidence_manifest_event(
  manifest : Json,
  event_id : String,
) -> Json {
  review_manifest_event(
    manifest,
    event_id,
    lane="runtime",
    kind="runtime_evidence.manifest",
    title="MoonCode runtime evidence",
    detail_prefix="MoonCode runtime evidence recorded at",
  )
}

///|
pub fn eval_report_manifest_event(manifest : Json, event_id : String) -> Json {
  review_manifest_event(
    manifest,
    event_id,
    lane="review",
    kind="eval_report.manifest",
    title="MoonCode eval report",
    detail_prefix="MoonBook eval report manifest recorded at",
    command_packet=summary_json_object_field_or_empty(
      manifest, "last_command_packet",
    ),
  )
}

///|
pub fn review_receipt_event(
  action : String,
  receipt_path : String,
  context_path : String,
  recorded_at : String,
  command_packet : Json,
  event_id : String,
) -> Json {
  event_record(
    id=event_id,
    lane="review",
    kind="receipt.\{action}",
    title="MoonBook review receipt",
    status="recorded",
    created_at=recorded_at,
    detail="MoonBook review receipt recorded at \{receipt_path}",
    path=if context_path == "" { receipt_path } else { context_path },
    command_packet~,
  )
}

///|
pub fn package_manifest_event(
  manifest : Json,
  context_path : String,
  recorded_at : String,
  command_packet : Json,
  event_id : String,
) -> Json {
  let manifest_path = json_string(manifest, "manifest_path", default="")
  event_record(
    id=event_id,
    lane="artifact",
    kind="package.manifest",
    title="MoonBook package manifest",
    status=json_string(manifest, "status", default="candidate"),
    created_at=recorded_at,
    detail="MoonCode package candidate recorded at \{manifest_path}",
    path=if context_path == "" { manifest_path } else { context_path },
    command_packet~,
  )
}

///|
pub fn package_index_manifest_event(manifest : Json, event_id : String) -> Json {
  review_manifest_event(
    manifest,
    event_id,
    lane="artifact",
    kind="package.index",
    title="MoonBook package index",
    detail_prefix="MoonCode package index recorded at",
    command_packet=summary_json_object_field_or_empty(
      summary_json_object_field_or_empty(manifest, "latest_package_manifest"),
      "command_packet",
    ),
  )
}

///|
pub fn runtime_handoff_manifest_event(
  manifest : Json,
  event_id : String,
) -> Json {
  review_manifest_event(
    manifest,
    event_id,
    lane="runtime",
    kind="runtime.handoff",
    title="MoonCode runtime handoff",
    detail_prefix="MoonCode runtime handoff recorded at",
    command_packet=summary_json_object_field_or_empty(
      manifest, "last_command_packet",
    ),
  )
}

///|
fn review_manifest_event(
  manifest : Json,
  event_id : String,
  lane~ : String,
  kind~ : String,
  title~ : String,
  detail_prefix~ : String,
  command_packet? : Json = Json::object({}),
) -> Json {
  let manifest_path = json_string(manifest, "manifest_path", default="")
  event_record(
    id=event_id,
    lane~,
    kind~,
    title~,
    status=json_string(manifest, "status", default="recorded"),
    created_at=json_string(manifest, "recorded_at", default=""),
    detail="\{detail_prefix} \{manifest_path}",
    path=manifest_path,
    command_packet~,
  )
}

///|
pub fn package_candidate_paths(context_path : String) -> Array[String] {
  if context_path == "" {
    ["tools/", "apps/", "book/site/generated/", "portable/app-tool/"]
  } else {
    [context_path]
  }
}

///|
pub fn package_kind_for_path(context_path : String) -> String {
  if context_path.has_prefix("tools/") {
    "tool"
  } else if context_path.has_prefix("apps/") {
    "miniapp"
  } else if context_path.has_prefix("book/site/generated/") ||
    context_path.has_prefix("site/generated/") {
    "generated-site"
  } else if context_path.has_prefix("portable/app-tool/") {
    "app-tool"
  } else {
    "app-tool-candidate"
  }
}

///|
pub fn package_manifest_list_contains(
  manifests : Array[Json],
  manifest_path : String,
) -> Bool {
  if manifest_path == "" {
    return false
  }
  for manifest in manifests {
    if json_string(manifest, "manifest_path", default="") == manifest_path {
      return true
    }
  }
  false
}

///|
pub fn change_set_manifest_relative_path(session_id : String) -> String {
  let safe_session = artifact_safe_id(session_id, fallback="session")
  "wiki/reviews/mooncode/\{safe_session}/change-set.json"
}

///|
pub fn patch_set_manifest_relative_path(session_id : String) -> String {
  let safe_session = artifact_safe_id(session_id, fallback="session")
  "wiki/reviews/mooncode/\{safe_session}/patch-set.json"
}

///|
pub fn tool_approvals_manifest_relative_path(session_id : String) -> String {
  let safe_session = artifact_safe_id(session_id, fallback="session")
  "wiki/reviews/mooncode/\{safe_session}/tool-approvals.json"
}

///|
pub fn test_runs_manifest_relative_path(session_id : String) -> String {
  let safe_session = artifact_safe_id(session_id, fallback="session")
  "wiki/reviews/mooncode/\{safe_session}/test-runs.json"
}

///|
pub fn action_plan_manifest_relative_path(session_id : String) -> String {
  let safe_session = artifact_safe_id(session_id, fallback="session")
  "wiki/reviews/mooncode/\{safe_session}/action-plan.json"
}

///|
pub fn runtime_evidence_manifest_relative_path(session_id : String) -> String {
  let safe_session = artifact_safe_id(session_id, fallback="session")
  "wiki/reviews/mooncode/\{safe_session}/runtime-evidence.json"
}

///|
pub fn eval_report_manifest_relative_path(session_id : String) -> String {
  let safe_session = artifact_safe_id(session_id, fallback="session")
  "wiki/reviews/mooncode/\{safe_session}/eval-report.json"
}

///|
pub fn runtime_handoff_manifest_relative_path(session_id : String) -> String {
  let safe_session = artifact_safe_id(session_id, fallback="session")
  "wiki/reviews/mooncode/\{safe_session}/runtime-handoff.json"
}

///|
pub fn review_receipt_relative_path(
  session_id : String,
  command_id : String,
  action : String,
) -> String {
  let safe_session = artifact_safe_id(session_id, fallback="session")
  let safe_command = artifact_safe_id(command_id, fallback="command")
  let safe_action = match action {
    "accept" => "accept"
    "reject" => "reject"
    "approve_tool" => "approve-tool"
    "reject_tool" => "reject-tool"
    "package" => "package"
    "apply_patch" => "apply-patch"
    "revert_patch" => "revert-patch"
    _ => "command"
  }
  "wiki/reviews/mooncode/\{safe_session}/\{safe_action}-\{safe_command}.json"
}

///|
pub fn command_writes_review_receipt(action : String) -> Bool {
  action == "accept" ||
  action == "reject" ||
  action == "package" ||
  action == "commit" ||
  action == "approve_tool" ||
  action == "reject_tool" ||
  action == "apply_patch" ||
  action == "revert_patch"
}

///|
pub fn package_manifest_relative_path(
  session_id : String,
  command_id : String,
) -> String {
  let safe_session = artifact_safe_id(session_id, fallback="session")
  let safe_command = artifact_safe_id(command_id, fallback="command")
  "portable/app-tool/mooncode/\{safe_session}/package-\{safe_command}.json"
}

///|
pub fn package_index_manifest_relative_path(session_id : String) -> String {
  let safe_session = artifact_safe_id(session_id, fallback="session")
  "portable/app-tool/mooncode/\{safe_session}/index.json"
}

///|
pub fn artifact_safe_id(value : String, fallback~ : String) -> String {
  let trimmed = value.trim().to_owned()
  if trimmed == "" ||
    trimmed == "." ||
    trimmed == ".." ||
    trimmed.contains("/") ||
    trimmed.contains("\\") ||
    trimmed.contains(":") {
    fallback
  } else if trimmed.length() > 72 {
    fallback + "-" + artifact_id_digest(trimmed)
  } else {
    trimmed
  }
}

///|
fn artifact_id_digest(value : String) -> String {
  let digest = @crypto.bytes_to_hex_string(
    @crypto.sha256(@encoding/utf8.encode(value).to_fixedarray()),
  )
  digest[:16].to_owned()
}

///|
pub fn count_package_candidate_status(
  manifests : Array[Json],
  status : String,
) -> Int {
  let mut count = 0
  for manifest in manifests {
    if json_string(manifest, "source_inventory_status", default="") == status {
      count += 1
    }
  }
  count
}

///|
pub fn change_set_lane_entries(
  events : Array[Json],
  lane : String,
) -> Array[Json] {
  let entries : Array[Json] = []
  for event in events {
    if json_string(event, "lane", default="") == lane {
      entries.push(change_set_event_entry(event))
    }
  }
  entries
}

///|
pub fn change_set_event_entry(event : Json) -> Json {
  let packet = summary_json_object_field_or_empty(event, "command_packet")
  {
    "id": json_string(event, "id", default=""),
    "kind": json_string(event, "kind", default=""),
    "title": json_string(event, "title", default=""),
    "status": json_string(event, "status", default=""),
    "path": json_string(event, "path", default=""),
    "command": json_string(event, "command", default=""),
    "exit_code": summary_json_int(event, "exit_code", default=0),
    "created_at": json_string(event, "created_at", default=""),
    "detail": json_string(event, "detail", default=""),
    "diff": json_string(event, "diff", default=""),
    "command_id": json_string(packet, "command_id", default=""),
  }
}

///|
pub fn patch_set_entries(events : Array[Json]) -> Array[Json] {
  let entries : Array[Json] = []
  let seen : Map[String, Bool] = {}
  for event in events {
    if json_string(event, "lane", default="") != "diff" {
      continue
    }
    let path = json_string(event, "path", default="")
    let id = if path == "" {
      json_string(event, "id", default="patch:\{event.stringify()}")
    } else {
      path
    }
    if seen.get(id).unwrap_or(false) {
      continue
    }
    seen[id] = true
    entries.push(patch_set_event_entry(event, events))
  }
  entries
}

///|
pub fn count_patch_review_state(patches : Array[Json], state : String) -> Int {
  let mut count = 0
  for patch in patches {
    if json_string(patch, "review_state", default="") == state {
      count += 1
    }
  }
  count
}

///|
pub fn count_patch_execution_state(
  patches : Array[Json],
  state : String,
) -> Int {
  let mut count = 0
  for patch in patches {
    if json_string(patch, "execution_state", default="") == state {
      count += 1
    }
  }
  count
}

///|
pub fn count_patch_execution_proofs(events : Array[Json]) -> Int {
  let mut count = 0
  for event in events {
    if patch_execution_event_kind(event) != "" &&
      json_string(event, "status", default="") != "failed" {
      count += 1
    }
  }
  count
}

///|
pub fn count_package_runtime_proofs(events : Array[Json]) -> Int {
  let mut count = 0
  for event in events {
    if package_runtime_event_state(event) != "" &&
      json_string(event, "status", default="") != "failed" {
      count += 1
    }
  }
  count
}

///|
pub fn count_package_runtime_state(events : Array[Json], state : String) -> Int {
  let mut count = 0
  for event in events {
    if package_runtime_event_state(event) == state &&
      json_string(event, "status", default="") != "failed" {
      count += 1
    }
  }
  count
}

///|
pub fn test_run_entries(events : Array[Json]) -> Array[Json] {
  let entries : Array[Json] = []
  let seen : Map[String, Bool] = {}
  for event in events {
    if json_string(event, "lane", default="") != "test" {
      continue
    }
    let key = test_run_target(event)
    if seen.get(key).unwrap_or(false) {
      continue
    }
    seen[key] = true
    entries.push(test_run_entry(event))
  }
  entries
}

///|
pub fn test_run_state(event : Json) -> String {
  let status = json_string(event, "status", default="")
  if test_event_failed(event) {
    "failed"
  } else if test_event_is_completed(event) {
    "passed"
  } else if status == "running" || status == "started" {
    "running"
  } else {
    "queued"
  }
}

///|
pub fn count_test_run_state(runs : Array[Json], state : String) -> Int {
  let mut count = 0
  for run in runs {
    if json_string(run, "run_state", default="") == state {
      count += 1
    }
  }
  count
}

///|
pub fn patch_review_state_for_path(
  path : String,
  events : Array[Json],
) -> String {
  if patch_review_event_count(path, "revert_patch", events) > 0 {
    "reverted"
  } else if patch_review_event_count(path, "apply_patch", events) > 0 {
    "applied"
  } else if patch_review_event_count(path, "reject", events) > 0 {
    "rejected"
  } else if patch_review_event_count(path, "accept", events) > 0 {
    "accepted"
  } else {
    "pending"
  }
}

///|
pub fn patch_execution_state_for_path(
  path : String,
  events : Array[Json],
) -> String {
  if patch_execution_event_count(path, "runtime.patch_reverted", events) > 0 {
    "reverted"
  } else if patch_execution_event_count(path, "runtime.patch_applied", events) >
    0 {
    "applied"
  } else {
    "pending"
  }
}

///|
pub fn patch_review_target_matches(
  target : String,
  event_path : String,
) -> Bool {
  target == "" ||
  event_path == "" ||
  event_path == target ||
  event_path == patch_review_parent_target(target) ||
  event_path.has_prefix(target + "#hunk-")
}

///|
fn patch_set_status(
  accepted_count : Int,
  rejected_count : Int,
  applied_count : Int,
  reverted_count : Int,
  pending_count : Int,
) -> String {
  if reverted_count > 0 {
    "reverted"
  } else if applied_count > 0 {
    "applied"
  } else if rejected_count > 0 {
    "rejected"
  } else if pending_count > 0 {
    "pending"
  } else if accepted_count > 0 {
    "accepted"
  } else {
    "empty"
  }
}

///|
fn patch_execution_set_status(
  applied_count : Int,
  reverted_count : Int,
  pending_count : Int,
) -> String {
  if reverted_count > 0 {
    "reverted"
  } else if pending_count > 0 && applied_count > 0 {
    "partial"
  } else if applied_count > 0 {
    "applied"
  } else {
    "pending"
  }
}

///|
fn patch_set_event_entry(event : Json, events : Array[Json]) -> Json {
  let path = json_string(event, "path", default="")
  let diff = json_string(event, "diff", default="")
  let packet = summary_json_object_field_or_empty(event, "command_packet")
  let review_state = patch_review_state_for_path(path, events)
  let execution_state = patch_execution_state_for_path(path, events)
  let hunks = patch_hunks(path, diff, events)
  let runtime_proof_count = patch_execution_event_count(path, "", events)
  {
    "id": json_string(event, "id", default=""),
    "path": path,
    "title": json_string(event, "title", default=""),
    "status": json_string(event, "status", default=""),
    "review_state": review_state,
    "execution_state": execution_state,
    "created_at": json_string(event, "created_at", default=""),
    "detail": json_string(event, "detail", default=""),
    "diff": diff,
    "diff_present": diff != "",
    "hunks": Json::array(hunks),
    "hunk_count": hunks.length(),
    "command": json_string(event, "command", default=""),
    "command_id": json_string(packet, "command_id", default=""),
    "accepted_review_count": patch_review_event_count(path, "accept", events),
    "rejected_review_count": patch_review_event_count(path, "reject", events),
    "applied_review_count": patch_review_event_count(
      path, "apply_patch", events,
    ),
    "reverted_review_count": patch_review_event_count(
      path, "revert_patch", events,
    ),
    "runtime_applied_count": patch_execution_event_count(
      path, "runtime.patch_applied", events,
    ),
    "runtime_reverted_count": patch_execution_event_count(
      path, "runtime.patch_reverted", events,
    ),
    "runtime_proof_count": runtime_proof_count,
    "execution_verified": execution_state == "applied" ||
    execution_state == "reverted",
    "package_review_count": patch_review_event_count(path, "package", events),
    "gate_status": patch_review_gate_status(
      review_state, execution_state, runtime_proof_count,
    ),
    "next_action": patch_review_next_action(
      review_state, execution_state, runtime_proof_count,
    ),
    "blocked_reason": patch_review_blocked_reason(
      review_state, execution_state, runtime_proof_count,
    ),
  }
}

///|
fn test_run_entry(event : Json) -> Json {
  let command = json_string(event, "command", default="")
  let packet = summary_json_object_field_or_empty(event, "command_packet")
  {
    "id": json_string(event, "id", default="test:\{event.stringify()}"),
    "title": json_string(event, "title", default="Test/build run"),
    "kind": json_string(event, "kind", default=""),
    "status": json_string(event, "status", default=""),
    "run_state": test_run_state(event),
    "created_at": json_string(event, "created_at", default=""),
    "path": json_string(event, "path", default=""),
    "command": command,
    "exit_code": summary_json_int(event, "exit_code", default=0),
    "detail": json_string(event, "detail", default=""),
    "target": test_run_target(event),
    "verified": test_event_is_completed(event) && !test_event_failed(event),
    "command_id": json_string(packet, "command_id", default=""),
  }
}

///|
fn test_run_target(event : Json) -> String {
  let command = json_string(event, "command", default="")
  if command != "" {
    return command
  }
  let path = json_string(event, "path", default="")
  if path != "" {
    return path
  }
  json_string(event, "id", default="test:\{event.stringify()}")
}

///|
fn patch_hunks(
  path : String,
  diff : String,
  events : Array[Json],
) -> Array[Json] {
  let hunks : Array[Json] = []
  if diff == "" {
    return hunks
  }
  let lines : Array[String] = diff
    .split("\n")
    .map(line => line.to_owned())
    .collect()
  let mut current_header = ""
  let current_lines : Array[String] = []
  let mut hunk_index = 0
  let flush = fn() {
    if current_header != "" || current_lines.length() > 0 {
      hunk_index += 1
      hunks.push(
        patch_hunk_record(
          path, hunk_index, current_header, current_lines, events,
        ),
      )
      current_lines.clear()
      current_header = ""
    }
  }
  for line in lines {
    if line.has_prefix("@@") {
      flush()
      current_header = line
    } else if current_header != "" ||
      line.has_prefix("+") ||
      line.has_prefix("-") ||
      line.has_prefix(" ") {
      current_lines.push(line)
    }
  }
  flush()
  if hunks.length() == 0 {
    hunks.push(patch_hunk_record(path, 1, "synthetic", lines, events))
  }
  hunks
}

///|
fn patch_hunk_record(
  path : String,
  index : Int,
  header : String,
  lines : Array[String],
  events : Array[Json],
) -> Json {
  let mut added = 0
  let mut removed = 0
  let mut context = 0
  for line in lines {
    if line.has_prefix("+") && !line.has_prefix("+++") {
      added += 1
    } else if line.has_prefix("-") && !line.has_prefix("---") {
      removed += 1
    } else {
      context += 1
    }
  }
  let hunk_id = "hunk-\{index}"
  let target = patch_hunk_target(path, hunk_id)
  let review_state = patch_review_state_for_path(target, events)
  let execution_state = patch_execution_state_for_path(target, events)
  let runtime_proof_count = patch_execution_event_count(target, "", events)
  {
    "id": hunk_id,
    "index": index,
    "target": target,
    "header": header,
    "review_state": review_state,
    "execution_state": execution_state,
    "added_lines": added,
    "removed_lines": removed,
    "context_lines": context,
    "line_count": lines.length(),
    "preview": trim_event_text(lines.join("\n")),
    "accepted_review_count": patch_review_event_count(target, "accept", events),
    "rejected_review_count": patch_review_event_count(target, "reject", events),
    "applied_review_count": patch_review_event_count(
      target, "apply_patch", events,
    ),
    "reverted_review_count": patch_review_event_count(
      target, "revert_patch", events,
    ),
    "runtime_applied_count": patch_execution_event_count(
      target, "runtime.patch_applied", events,
    ),
    "runtime_reverted_count": patch_execution_event_count(
      target, "runtime.patch_reverted", events,
    ),
    "runtime_proof_count": runtime_proof_count,
    "gate_status": patch_review_gate_status(
      review_state, execution_state, runtime_proof_count,
    ),
    "next_action": patch_review_next_action(
      review_state, execution_state, runtime_proof_count,
    ),
    "blocked_reason": patch_review_blocked_reason(
      review_state, execution_state, runtime_proof_count,
    ),
  }
}

///|
fn patch_review_gate_status(
  review_state : String,
  execution_state : String,
  runtime_proof_count : Int,
) -> String {
  if review_state == "rejected" {
    "blocked"
  } else if execution_state == "applied" || execution_state == "reverted" {
    "runtime-proven"
  } else if review_state == "applied" ||
    review_state == "reverted" ||
    (runtime_proof_count == 0 && review_state == "accepted") {
    "runtime-needed"
  } else if review_state == "pending" {
    "needs-review"
  } else {
    "ready"
  }
}

///|
fn patch_review_next_action(
  review_state : String,
  execution_state : String,
  runtime_proof_count : Int,
) -> String {
  if review_state == "rejected" {
    "none"
  } else if execution_state == "applied" {
    "run_tests"
  } else if execution_state == "reverted" {
    "review"
  } else if review_state == "pending" {
    "accept-or-reject"
  } else if review_state == "accepted" {
    "apply_patch"
  } else if review_state == "applied" || review_state == "reverted" {
    if runtime_proof_count > 0 {
      "run_tests"
    } else {
      "await-runtime-proof"
    }
  } else {
    "review"
  }
}

///|
fn patch_review_blocked_reason(
  review_state : String,
  execution_state : String,
  runtime_proof_count : Int,
) -> String {
  if review_state == "rejected" {
    "Operator rejected this patch target; accept it again before applying or packaging."
  } else if execution_state == "applied" {
    "Runtime applied this patch target; run tests before package or commit."
  } else if execution_state == "reverted" {
    "Runtime reverted this patch target; review the diff before applying again."
  } else if review_state == "applied" || review_state == "reverted" {
    if runtime_proof_count > 0 {
      "Runtime proof is present; run tests before package or commit."
    } else {
      "Operator requested patch execution; MoonClaw or standalone MoonCode must emit runtime proof."
    }
  } else if review_state == "accepted" {
    "Accepted by operator and ready for MoonClaw or standalone MoonCode to apply."
  } else {
    ""
  }
}

///|
fn patch_hunk_target(path : String, hunk_id : String) -> String {
  if path == "" {
    hunk_id
  } else {
    path + "#" + hunk_id
  }
}

///|
fn patch_review_event_count(
  path : String,
  command : String,
  events : Array[Json],
) -> Int {
  let mut count = 0
  for event in events {
    if json_string(event, "lane", default="") != "review" ||
      json_string(event, "command", default="") != command ||
      json_string(event, "status", default="") == "failed" {
      continue
    }
    let event_path = json_string(event, "path", default="")
    if patch_review_target_matches(path, event_path) {
      count += 1
    }
  }
  count
}

///|
fn patch_execution_event_count(
  path : String,
  kind : String,
  events : Array[Json],
) -> Int {
  let mut count = 0
  for event in events {
    let event_kind = patch_execution_event_kind(event)
    if event_kind == "" || json_string(event, "status", default="") == "failed" {
      continue
    }
    if kind != "" && event_kind != kind {
      continue
    }
    let event_path = json_string(event, "path", default="")
    if patch_review_target_matches(path, event_path) {
      count += 1
    }
  }
  count
}

///|
fn patch_execution_event_kind(event : Json) -> String {
  let kind = json_string(event, "kind", default="")
  match kind {
    "runtime.patch_applied" | "runtime.patch_reverted" => kind
    _ => ""
  }
}

///|
fn patch_review_parent_target(target : String) -> String {
  if !target.contains("#hunk-") {
    return target
  }
  let parts : Array[String] = target
    .split("#hunk-")
    .map(part => part.to_owned())
    .collect()
  if parts.length() == 0 {
    target
  } else {
    parts[0]
  }
}

///|
fn review_artifact_owner(artifact_owner : String) -> Json {
  {
    "ui": "moondesk",
    "runtime": "moonclaw",
    "artifact": artifact_owner,
    "review": "moonbook",
    "extractable_component": "mooncode",
  }
}

///|
fn package_index_kinds(packages : Array[Json]) -> Array[String] {
  let kinds : Array[String] = []
  let seen : Map[String, Bool] = {}
  for pkg in packages {
    let kind = json_string(pkg, "package_kind", default="")
    if kind != "" && !seen.get(kind).unwrap_or(false) {
      seen[kind] = true
      kinds.push(kind)
    }
  }
  kinds
}

///|
fn package_index_entry_points(packages : Array[Json]) -> Array[String] {
  let entries : Array[String] = []
  let seen : Map[String, Bool] = {}
  for pkg in packages {
    for source in json_array_items(pkg, "source_inventory") {
      let path = json_string(source, "path", default="")
      if path != "" &&
        json_bool(source, "package_ready", default=false) &&
        !seen.get(path).unwrap_or(false) {
        seen[path] = true
        entries.push(path)
      }
    }
  }
  entries
}

///|
fn package_projection_entries(
  packages : Array[Json],
  events : Array[Json],
) -> Array[Json] {
  packages.map(manifest => package_projection_entry(manifest, events))
}

///|
fn package_projection_entry(manifest : Json, events : Array[Json]) -> Json {
  let built = count_package_runtime_state_for_manifest(
    manifest, events, "built",
  )
  let verified = count_package_runtime_state_for_manifest(
    manifest, events, "verified",
  )
  let proof_count = built + verified
  let execution_state = if verified > 0 {
    "verified"
  } else if built > 0 {
    "built"
  } else {
    "pending"
  }
  let with_state = package_with_field(
    manifest,
    "execution_state",
    execution_state.to_json(),
  )
  let with_built = package_with_field(
    with_state,
    "runtime_built_count",
    built.to_json(),
  )
  let with_verified = package_with_field(
    with_built,
    "runtime_verified_count",
    verified.to_json(),
  )
  let with_proof = package_with_field(
    with_verified,
    "runtime_proof_count",
    proof_count.to_json(),
  )
  package_with_field(with_proof, "execution_verified", (verified > 0).to_json())
}

///|
fn count_package_runtime_state_for_manifest(
  manifest : Json,
  events : Array[Json],
  state : String,
) -> Int {
  let mut count = 0
  for event in events {
    if package_runtime_event_state(event) == state &&
      json_string(event, "status", default="") != "failed" &&
      package_runtime_event_matches_manifest(manifest, event) {
      count += 1
    }
  }
  count
}

///|
fn package_runtime_event_matches_manifest(
  manifest : Json,
  event : Json,
) -> Bool {
  let path = json_string(event, "path", default="")
  if path == "" {
    return false
  }
  if package_runtime_path_matches(
      path,
      json_string(manifest, "context_path", default=""),
    ) ||
    package_runtime_path_matches(
      path,
      json_string(manifest, "manifest_path", default=""),
    ) ||
    package_runtime_path_matches(
      path,
      json_string(manifest, "review_receipt_path", default=""),
    ) {
    return true
  }
  for candidate in json_array_items(manifest, "candidate_paths") {
    match candidate {
      Json::String(candidate_path) =>
        if package_runtime_path_matches(path, candidate_path) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn package_runtime_path_matches(path : String, target : String) -> Bool {
  target != "" &&
  (
    path == target ||
    path.has_prefix(target + "/") ||
    target.has_prefix(path + "/")
  )
}

///|
fn package_runtime_event_state(event : Json) -> String {
  match json_string(event, "kind", default="") {
    "runtime.package_verified" => "verified"
    "runtime.package_built" => "built"
    _ => ""
  }
}

///|
fn package_source_present_count(records : Array[Json]) -> Int {
  let mut count = 0
  for record in records {
    if json_bool(record, "package_ready", default=false) {
      count += 1
    }
  }
  count
}

///|
fn package_artifact_owner() -> Json {
  {
    "ui": "moondesk",
    "runtime": "moonclaw",
    "artifact": "moonbook",
    "packaging": "moonbook",
    "extractable_component": "mooncode",
  }
}

///|
fn package_with_field(base : Json, key : String, value : Json) -> Json {
  match base {
    Json::Object(fields) => {
      let next : Map[String, Json] = {}
      for item in fields {
        next[item.0] = item.1
      }
      next[key] = value
      Json::object(next)
    }
    _ => base
  }
}

///|
test "mooncode change set manifest summarizes reviewable work" {
  let events : Array[Json] = [
    event_record(
      id="diff-1",
      lane="diff",
      kind="tool.write",
      title="Write file",
      status="done",
      created_at="1",
      detail="updated",
      path="tools/demo/main.mbt",
      diff="+fn main { println(\"ok\") }",
    ),
    event_record(
      id="test-1",
      lane="test",
      kind="tool.moon_check",
      title="Moon check",
      status="done",
      created_at="2",
      detail="passed",
      command="moon check",
    ),
  ]
  let manifest = change_set_manifest(
    { "id": "s1", "workspace_id": "book", "moonclaw_task_id": "task" },
    events,
    recorded_at="2026-06-15T00:00:00Z",
    manifest_path="wiki/reviews/mooncode/s1/change-set.json",
    absolute_manifest_path="/tmp/book/wiki/reviews/mooncode/s1/change-set.json",
  )
  assert_eq(json_string(manifest, "kind", default=""), "mooncode-change-set")
  assert_eq(summary_json_int(manifest, "diff_count", default=0), 1)
  assert_eq(summary_json_int(manifest, "verified_test_count", default=0), 1)
  assert_eq(json_string(manifest, "status", default=""), "pending")
}

///|
test "mooncode patch set groups hunks and review state" {
  let diff = "@@ -1 +1 @@\n-old\n+new\n context"
  let events : Array[Json] = [
    event_record(
      id="diff-1",
      lane="diff",
      kind="tool.edit",
      title="Edit file",
      status="done",
      created_at="1",
      detail="edited",
      path="tools/demo/main.mbt",
      diff~,
    ),
    event_record(
      id="review-1",
      lane="review",
      kind="command.apply_patch",
      title="Apply patch",
      status="done",
      created_at="2",
      detail="applied",
      path="tools/demo/main.mbt#hunk-1",
      command="apply_patch",
    ),
  ]
  let manifest = patch_set_manifest(
    { "id": "s1", "workspace_id": "book" },
    events,
    recorded_at="2026-06-15T00:00:00Z",
    manifest_path="wiki/reviews/mooncode/s1/patch-set.json",
    absolute_manifest_path="/tmp/book/wiki/reviews/mooncode/s1/patch-set.json",
  )
  assert_eq(json_string(manifest, "status", default=""), "applied")
  assert_eq(summary_json_int(manifest, "patch_count", default=0), 1)
  let patch = json_array_items(manifest, "patches")[0]
  assert_eq(summary_json_int(patch, "hunk_count", default=0), 1)
  assert_eq(json_string(patch, "review_state", default=""), "applied")
  assert_eq(json_string(patch, "execution_state", default=""), "pending")
  assert_eq(json_string(patch, "gate_status", default=""), "runtime-needed")
  assert_eq(
    json_string(patch, "next_action", default=""),
    "await-runtime-proof",
  )
  assert_true(
    json_string(patch, "blocked_reason", default="").contains("runtime proof"),
  )
  let hunks = json_array_items(patch, "hunks")
  assert_eq(json_string(hunks[0], "gate_status", default=""), "runtime-needed")
  assert_eq(
    json_string(hunks[0], "next_action", default=""),
    "await-runtime-proof",
  )
  assert_eq(
    summary_json_int(manifest, "runtime_patch_proof_count", default=0),
    0,
  )
}

///|
test "mooncode patch set separates runtime execution proof from operator review" {
  let events : Array[Json] = [
    event_record(
      id="diff-1",
      lane="diff",
      kind="tool.edit",
      title="Edit file",
      status="done",
      created_at="1",
      detail="edited",
      path="tools/demo/main.mbt",
      diff="@@ -1 +1 @@\n-old\n+new",
    ),
    event_record(
      id="review-1",
      lane="review",
      kind="command.apply_patch",
      title="Apply patch",
      status="done",
      created_at="2",
      detail="operator accepted apply",
      path="tools/demo/main.mbt",
      command="apply_patch",
    ),
    event_record(
      id="runtime-1",
      lane="review",
      kind="runtime.patch_applied",
      title="Patch applied by runtime",
      status="done",
      created_at="3",
      detail="applied cleanly",
      path="tools/demo/main.mbt",
      command="apply_patch",
    ),
  ]
  let manifest = patch_set_manifest(
    { "id": "s1", "workspace_id": "book" },
    events,
    recorded_at="2026-06-15T00:00:00Z",
    manifest_path="wiki/reviews/mooncode/s1/patch-set.json",
    absolute_manifest_path="/tmp/book/wiki/reviews/mooncode/s1/patch-set.json",
  )
  assert_eq(json_string(manifest, "status", default=""), "applied")
  assert_eq(json_string(manifest, "execution_status", default=""), "applied")
  assert_eq(
    summary_json_int(manifest, "runtime_applied_patch_count", default=0),
    1,
  )
  assert_eq(
    summary_json_int(manifest, "runtime_patch_proof_count", default=0),
    1,
  )
  let patch = json_array_items(manifest, "patches")[0]
  assert_eq(json_string(patch, "review_state", default=""), "applied")
  assert_eq(json_string(patch, "execution_state", default=""), "applied")
  assert_eq(json_string(patch, "gate_status", default=""), "runtime-proven")
  assert_eq(json_string(patch, "next_action", default=""), "run_tests")
  assert_true(json_bool(patch, "execution_verified", default=false))
}

///|
test "mooncode tool approvals manifest tracks pending policy gates" {
  let events : Array[Json] = [
    event_record(
      id="tool-1",
      lane="tool",
      kind="tool.shell",
      title="Run command",
      status="running",
      created_at="1",
      detail="execute_command",
      command="moon test",
    ),
  ]
  let manifest = tool_approvals_manifest(
    { "id": "s1", "workspace_id": "book" },
    events,
    recorded_at="2026-06-15T00:00:00Z",
    manifest_path="wiki/reviews/mooncode/s1/tool-approvals.json",
    absolute_manifest_path="/tmp/book/wiki/reviews/mooncode/s1/tool-approvals.json",
  )
  assert_eq(json_string(manifest, "status", default=""), "pending")
  assert_eq(summary_json_int(manifest, "pending_approval_count", default=0), 1)
}

///|
test "mooncode test runs manifest separates passed and failed runs" {
  let events : Array[Json] = [
    event_record(
      id="test-1",
      lane="test",
      kind="tool.moon_check",
      title="Moon check",
      status="done",
      created_at="1",
      detail="passed",
      command="moon check",
    ),
    event_record(
      id="test-2",
      lane="test",
      kind="tool.shell",
      title="Build",
      status="failed",
      created_at="2",
      detail="failed",
      command="moon build",
      exit_code=1,
    ),
  ]
  let manifest = test_runs_manifest(
    { "id": "s1", "workspace_id": "book" },
    events,
    recorded_at="2026-06-15T00:00:00Z",
    manifest_path="wiki/reviews/mooncode/s1/test-runs.json",
    absolute_manifest_path="/tmp/book/wiki/reviews/mooncode/s1/test-runs.json",
  )
  assert_eq(json_string(manifest, "status", default=""), "failed")
  assert_eq(summary_json_int(manifest, "passed_run_count", default=0), 1)
  assert_eq(summary_json_int(manifest, "failed_run_count", default=0), 1)
  assert_eq(summary_json_int(manifest, "verified_run_count", default=0), 1)
}

///|
test "mooncode package manifest and index summarize executable candidates" {
  let session : Json = {
    "id": "s1",
    "workspace_id": "book",
    "workspace_name": "Book",
    "moonclaw_task_id": "task",
  }
  let command_packet : Json = {
    "protocol": "mooncode.v1",
    "command_id": "cmd-1",
    "session_id": "s1",
  }
  let source_inventory : Array[Json] = [
    {
      "path": "tools/demo/main.mbt",
      "exists": true,
      "kind": "file",
      "size_bytes": 32,
      "sha256": "abc123",
      "package_ready": true,
    },
  ]
  let manifest = package_manifest(
    session,
    { "receipt_path": "wiki/reviews/mooncode/s1/package-cmd-1.json" },
    command_packet,
    "tools/demo/main.mbt",
    "Package tool",
    "2026-06-15T00:00:00Z",
    "2026-06-15T00:01:00Z",
    "portable/app-tool/mooncode/s1/package-cmd-1.json",
    "/tmp/book/portable/app-tool/mooncode/s1/package-cmd-1.json",
    source_inventory,
  )
  assert_eq(
    json_string(manifest, "kind", default=""),
    "mooncode-package-manifest",
  )
  assert_eq(json_string(manifest, "package_kind", default=""), "tool")
  assert_eq(
    json_string(manifest, "source_inventory_status", default=""),
    "source-bound",
  )
  assert_eq(summary_json_int(manifest, "source_present_count", default=0), 1)

  let index = package_index_manifest(
    session,
    "s1",
    manifest,
    [manifest],
    "2026-06-15T00:02:00Z",
    "portable/app-tool/mooncode/s1/index.json",
    "/tmp/book/portable/app-tool/mooncode/s1/index.json",
    "portable/app-tool/mooncode/s1",
  )
  assert_eq(json_string(index, "kind", default=""), "mooncode-package-index")
  assert_eq(json_string(index, "status", default=""), "source-bound")
  assert_eq(summary_json_int(index, "package_count", default=0), 1)
  assert_eq(summary_json_int(index, "executable_ready_count", default=0), 1)
  assert_eq(
    summary_json_int(index, "runtime_verified_package_count", default=0),
    0,
  )
  let entry_points = json_array_items(index, "entry_points")
  assert_eq(entry_points.length(), 1)
  assert_true(entry_points[0] is Json::String("tools/demo/main.mbt"))

  let candidates = package_candidates_projection(
    session,
    "s1",
    [manifest],
    index,
  )
  assert_eq(
    json_string(candidates, "kind", default=""),
    "mooncode-package-candidates",
  )
  assert_eq(summary_json_int(candidates, "package_count", default=0), 1)
  assert_eq(
    summary_json_int(
      candidates,
      "package_index_executable_ready_count",
      default=0,
    ),
    1,
  )
}

///|
test "mooncode package candidates separate source readiness from runtime proof" {
  let manifest = package_manifest(
    {
      "id": "s1",
      "workspace_id": "book",
      "mooncode_command_events": [
        event_record(
          id="pkg-proof",
          lane="artifact",
          kind="runtime.package_verified",
          title="Package verified by runtime",
          status="done",
          created_at="3",
          detail="verified",
          path="tools/demo/main.mbt",
          command="package",
        ),
      ],
    },
    { "receipt_path": "wiki/reviews/mooncode/s1/package-cmd-1.json" },
    { "command_id": "cmd-1" },
    "tools/demo/main.mbt",
    "Package tool",
    "2026-06-15T00:00:00Z",
    "2026-06-15T00:01:00Z",
    "portable/app-tool/mooncode/s1/package-cmd-1.json",
    "/tmp/book/portable/app-tool/mooncode/s1/package-cmd-1.json",
    [
      {
        "path": "tools/demo/main.mbt",
        "exists": true,
        "kind": "file",
        "package_ready": true,
      },
    ],
  )
  let session : Json = {
    "id": "s1",
    "workspace_id": "book",
    "mooncode_command_events": [
      event_record(
        id="pkg-proof",
        lane="artifact",
        kind="runtime.package_verified",
        title="Package verified by runtime",
        status="done",
        created_at="3",
        detail="verified",
        path="tools/demo/main.mbt",
        command="package",
      ),
    ],
  }
  let index = package_index_manifest(
    session,
    "s1",
    manifest,
    [manifest],
    "2026-06-15T00:02:00Z",
    "portable/app-tool/mooncode/s1/index.json",
    "/tmp/book/portable/app-tool/mooncode/s1/index.json",
    "portable/app-tool/mooncode/s1",
  )
  assert_eq(json_string(index, "status", default=""), "verified")
  assert_eq(
    summary_json_int(index, "runtime_verified_package_count", default=0),
    1,
  )
  let candidates = package_candidates_projection(
    session,
    "s1",
    [manifest],
    index,
  )
  assert_eq(json_string(candidates, "status", default=""), "verified")
  assert_eq(
    summary_json_int(candidates, "runtime_package_proof_count", default=0),
    1,
  )
  let projected = json_array_items(candidates, "packages")[0]
  assert_eq(json_string(projected, "execution_state", default=""), "verified")
  assert_true(json_bool(projected, "execution_verified", default=false))
}

///|
test "mooncode package manifest tracks missing default roots" {
  let manifest = package_manifest(
    { "id": "s1" },
    Json::object({}),
    { "command_id": "cmd-1" },
    "",
    "Package workspace",
    "2026-06-15T00:00:00Z",
    "2026-06-15T00:01:00Z",
    "portable/app-tool/mooncode/s1/package-cmd-1.json",
    "/tmp/book/portable/app-tool/mooncode/s1/package-cmd-1.json",
    [
      {
        "path": "tools/",
        "exists": false,
        "kind": "missing",
        "package_ready": false,
      },
    ],
  )
  assert_eq(
    json_string(manifest, "package_kind", default=""),
    "app-tool-candidate",
  )
  assert_eq(
    json_string(manifest, "source_inventory_status", default=""),
    "no-source-yet",
  )
  assert_eq(json_array_items(manifest, "candidate_paths").length(), 4)
  assert_false(
    package_manifest_list_contains([manifest], "portable/app-tool/missing.json"),
  )
  assert_true(
    package_manifest_list_contains(
      [manifest],
      "portable/app-tool/mooncode/s1/package-cmd-1.json",
    ),
  )
}

///|
test "mooncode artifact paths sanitize session and command ids" {
  assert_eq(
    change_set_manifest_relative_path("s1"),
    "wiki/reviews/mooncode/s1/change-set.json",
  )
  assert_eq(
    patch_set_manifest_relative_path("../bad"),
    "wiki/reviews/mooncode/session/patch-set.json",
  )
  assert_eq(
    review_receipt_relative_path("s1", "cmd-1", "approve_tool"),
    "wiki/reviews/mooncode/s1/approve-tool-cmd-1.json",
  )
  assert_eq(
    review_receipt_relative_path("s1", "cmd/1", "unexpected"),
    "wiki/reviews/mooncode/s1/command-command.json",
  )
  assert_eq(
    package_manifest_relative_path("s1", "cmd-1"),
    "portable/app-tool/mooncode/s1/package-cmd-1.json",
  )
  assert_eq(
    package_index_manifest_relative_path("s1"),
    "portable/app-tool/mooncode/s1/index.json",
  )
}

///|
test "mooncode review receipt policy covers review and execution decisions" {
  for
    action in [
      "accept", "reject", "package", "commit", "approve_tool", "reject_tool", "apply_patch",
      "revert_patch",
    ] {
    assert_true(command_writes_review_receipt(action))
  }
  for action in ["prompt", "steer", "cancel", "run_test", "run_eval"] {
    assert_false(command_writes_review_receipt(action))
  }
}

///|
test "mooncode artifact safe id shortens long ids deterministically" {
  let long_id = "session-" + "x".repeat(80)
  let safe = artifact_safe_id(long_id, fallback="session")
  assert_true(safe.has_prefix("session-"))
  assert_true(safe.length() < long_id.length())
  assert_eq(safe, artifact_safe_id(long_id, fallback="session"))
}

///|
test "mooncode review manifest events keep protocol lanes extractable" {
  let packet : Json = { "command_id": "cmd-1" }
  let change_event = change_set_manifest_event(
    {
      "session_id": "s1",
      "status": "pending",
      "recorded_at": "2026-06-15T00:00:00Z",
      "manifest_path": "wiki/reviews/mooncode/s1/change-set.json",
      "last_command_packet": packet,
    },
    "change-event",
  )
  assert_eq(json_string(change_event, "id", default=""), "change-event")
  assert_eq(json_string(change_event, "lane", default=""), "review")
  assert_eq(
    json_string(change_event, "kind", default=""),
    "change_set.manifest",
  )
  assert_eq(json_string(change_event, "status", default=""), "pending")
  assert_eq(
    json_string(
      summary_json_object_field_or_empty(change_event, "command_packet"),
      "command_id",
      default="",
    ),
    "cmd-1",
  )

  let action_event = action_plan_manifest_event(
    {
      "session_id": "s1",
      "status": "ready",
      "recorded_at": "2026-06-15T00:01:00Z",
      "manifest_path": "wiki/reviews/mooncode/s1/action-plan.json",
    },
    "action-event",
  )
  assert_eq(json_string(action_event, "lane", default=""), "runtime")
  assert_eq(
    json_string(action_event, "kind", default=""),
    "action_plan.manifest",
  )
  assert_eq(
    runtime_evidence_manifest_relative_path("s1"),
    "wiki/reviews/mooncode/s1/runtime-evidence.json",
  )
  let evidence_event = runtime_evidence_manifest_event(
    {
      "session_id": "s1",
      "status": "proven",
      "recorded_at": "2026-06-15T00:02:00Z",
      "manifest_path": "wiki/reviews/mooncode/s1/runtime-evidence.json",
    },
    "runtime-evidence-event",
  )
  assert_eq(json_string(evidence_event, "lane", default=""), "runtime")
  assert_eq(
    json_string(evidence_event, "kind", default=""),
    "runtime_evidence.manifest",
  )
  assert_eq(json_string(evidence_event, "status", default=""), "proven")
}

///|
test "mooncode package and receipt events preserve review targets" {
  let packet : Json = { "command_id": "cmd-1" }
  let receipt = review_receipt_event(
    "accept", "wiki/reviews/mooncode/s1/accept-cmd-1.json", "tools/demo/main.mbt",
    "2026-06-15T00:00:00Z", packet, "receipt-event",
  )
  assert_eq(json_string(receipt, "kind", default=""), "receipt.accept")
  assert_eq(json_string(receipt, "path", default=""), "tools/demo/main.mbt")

  let package_event = package_manifest_event(
    {
      "status": "candidate",
      "command_id": "cmd-1",
      "manifest_path": "portable/app-tool/mooncode/s1/package-cmd-1.json",
    },
    "",
    "2026-06-15T00:01:00Z",
    packet,
    "package-event",
  )
  assert_eq(json_string(package_event, "lane", default=""), "artifact")
  assert_eq(json_string(package_event, "kind", default=""), "package.manifest")
  assert_eq(
    json_string(package_event, "path", default=""),
    "portable/app-tool/mooncode/s1/package-cmd-1.json",
  )

  let runtime_event = runtime_handoff_manifest_event(
    {
      "session_id": "s1",
      "status": "bridge-resumable",
      "recorded_at": "2026-06-15T00:02:00Z",
      "manifest_path": "wiki/reviews/mooncode/s1/runtime-handoff.json",
      "last_command_packet": packet,
    },
    "runtime-event",
  )
  assert_eq(json_string(runtime_event, "lane", default=""), "runtime")
  assert_eq(json_string(runtime_event, "kind", default=""), "runtime.handoff")
}
