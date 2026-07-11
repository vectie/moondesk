///|
// MoonCode aggregate package-candidate projection.

///|
pub fn package_candidates_projection(
  session : Json,
  session_id : String,
  packages : Array[Json],
  index_manifest : Json,
) -> Json {
  let source_bound = count_package_candidate_status(packages, "source-bound")
  let no_source = count_package_candidate_status(packages, "no-source-yet")
  let events = package_session_events(session)
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
    "protocol": protocol_version(),
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
    "runtime_session_id": session_runtime_session_id(session),
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
    "rule": "Package candidates are MoonBook-owned manifests. MoonDesk only renders package readiness and sends operator commands; MoonClaw must assemble verified bundles and emit package_built or package_verified runtime proof events.",
  }
}

///|
fn package_session_events(session : Json) -> Array[Json] {
  merge_events(
    [],
    json_array_items(session, "mooncode_command_events"),
    json_array_items(session, "mooncode_events"),
  )
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
fn package_with_field(base : Json, key : String, value : Json) -> Json {
  match base {
    Object(fields) => {
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
