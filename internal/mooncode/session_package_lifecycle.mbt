///|
// Session-level package/bundle lifecycle projection for MoonCode headers.

///|
pub fn session_package_lifecycle(session : Json, events : Array[Json]) -> Json {
  let session_id = json_string(session, "id", default="")
  let latest_manifest = summary_json_object_field_or_empty(
    session, "mooncode_last_package_manifest",
  )
  let index_manifest = summary_json_object_field_or_empty(
    session, "mooncode_last_package_index_manifest",
  )
  let packages = session_package_lifecycle_packages(
    latest_manifest, index_manifest,
  )
  let rows = package_projection_entries(packages, events)
  let source_bound = package_lifecycle_count(
    count_package_candidate_status(packages, "source-bound"),
    summary_json_int(index_manifest, "source_bound_package_count", default=0),
  )
  let missing_source = package_lifecycle_count(
    count_package_candidate_status(packages, "no-source-yet"),
    summary_json_int(index_manifest, "missing_source_package_count", default=0),
  )
  let runtime_built = package_lifecycle_count(
    count_package_runtime_state(events, "built"),
    summary_json_int(index_manifest, "runtime_built_package_count", default=0),
  )
  let runtime_verified = package_lifecycle_count(
    count_package_runtime_state(events, "verified"),
    summary_json_int(
      index_manifest,
      "runtime_verified_package_count",
      default=0,
    ),
  )
  let runtime_proofs = package_lifecycle_count(
    count_package_runtime_proofs(events),
    summary_json_int(index_manifest, "runtime_package_proof_count", default=0),
  )
  let executable_ready = package_lifecycle_count(
    summary_json_int(index_manifest, "executable_ready_count", default=0),
    source_bound,
  )
  let package_count = package_lifecycle_count(
    packages.length(),
    summary_json_int(index_manifest, "package_count", default=0),
  )
  let latest_status = package_lifecycle_status(
    package_count, source_bound, runtime_built, runtime_verified,
  )
  {
    "kind": "mooncode-package-lifecycle",
    "protocol": protocol_version(),
    "status": latest_status,
    "latest_status": latest_status,
    "session_id": session_id,
    "workspace_id": json_string(session, "workspace_id", default=""),
    "runtime_session_id": session_runtime_session_id(session),
    "package_count": package_count,
    "source_bound_package_count": source_bound,
    "missing_source_package_count": missing_source,
    "runtime_built_package_count": runtime_built,
    "runtime_verified_package_count": runtime_verified,
    "runtime_package_proof_count": runtime_proofs,
    "executable_ready_count": executable_ready,
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
    "package_root": json_string(index_manifest, "package_root", default=""),
    "entry_points": Json::array(
      json_array_items(index_manifest, "entry_points"),
    ),
    "rows": Json::array(rows),
    "latest_package_manifest": latest_manifest,
    "latest_package_index_manifest": index_manifest,
    "next_step": package_lifecycle_next_step(
      package_count, source_bound, missing_source, runtime_built, runtime_verified,
    ),
    "owner": package_artifact_owner(),
    "rule": "Moondesk renders package readiness and operator commands. MoonClaw must assemble and verify bundles. MoonBook owns the package manifests, source inventory, and package index.",
  }
}

///|
fn session_package_lifecycle_packages(
  latest_manifest : Json,
  index_manifest : Json,
) -> Array[Json] {
  let indexed = json_array_items(index_manifest, "packages")
  if indexed.length() > 0 {
    indexed
  } else if json_string(latest_manifest, "kind", default="") ==
    "mooncode-package-manifest" {
    [latest_manifest]
  } else {
    []
  }
}

///|
fn package_lifecycle_count(primary : Int, fallback : Int) -> Int {
  if primary > fallback {
    primary
  } else {
    fallback
  }
}

///|
fn package_lifecycle_status(
  package_count : Int,
  source_bound : Int,
  runtime_built : Int,
  runtime_verified : Int,
) -> String {
  if runtime_verified > 0 {
    "verified"
  } else if runtime_built > 0 {
    "built"
  } else if source_bound > 0 {
    "source-bound"
  } else if package_count > 0 {
    "candidate"
  } else {
    "empty"
  }
}

///|
fn package_lifecycle_next_step(
  package_count : Int,
  source_bound : Int,
  missing_source : Int,
  runtime_built : Int,
  runtime_verified : Int,
) -> String {
  if package_count == 0 {
    "Package accepted executable output when a tool, miniapp, generated site, or app-tool candidate is ready."
  } else if missing_source > 0 && source_bound == 0 {
    "Bind package candidates to MoonBook-owned source files before runtime assembly."
  } else if runtime_verified > 0 {
    "Verified package proof is available for review, publishing, or extraction into MoonCode."
  } else if runtime_built > 0 {
    "Run package verification and record package_verified proof before publishing."
  } else {
    "Ask MoonClaw to assemble and verify the source-bound package candidates."
  }
}
