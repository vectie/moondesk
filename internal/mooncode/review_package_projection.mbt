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
