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
  let events = package_session_events(session)
  let runtime_built = count_package_runtime_state(events, "built")
  let runtime_verified = count_package_runtime_state(events, "verified")
  {
    "kind": "mooncode-package-index",
    "protocol": protocol_version(),
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
    "runtime_session_id": session_runtime_session_id(session),
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
      "consumer": "moonclaw",
      "rule": "This index is the stable MoonBook package registry for a MoonCode session. Per-command package manifests remain audit records; index.json is the resumable handoff for bundle assembly, review, and extraction into a future mooncode component.",
    },
    "owner": package_artifact_owner(),
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
