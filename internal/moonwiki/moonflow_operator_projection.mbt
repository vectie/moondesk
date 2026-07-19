///|
fn moonflow_operator_surface_unavailable(
  run_id : String,
  status : String,
) -> Json {
  {
    "contract_id": "moonflow.operator-surface.v1",
    "run_id": run_id,
    "available": false,
    "status": status,
    "recorded_at": "",
  }
}

///|
/// Read MoonFlow's replaceable read-only operator projection. Canonical
/// closed-loop records remain owned by MoonFlow; this file grants no mutation
/// or effect authority.
async fn moonflow_operator_surface_projection(
  run_root : String,
  run_id : String,
) -> Json {
  let path = @pathx.join(run_root, "operator-projection.json")
  if !@fs.exists(path) {
    return moonflow_operator_surface_unavailable(run_id, "not_published")
  }
  let projection = @json.parse(@fs.read_file(path).text()) catch {
    _ => return moonflow_operator_surface_unavailable(run_id, "invalid")
  }
  let projected_run_id = json_string(projection, "run_id", default=run_id)
  if projected_run_id != run_id {
    return moonflow_operator_surface_unavailable(
      run_id, "run_identity_mismatch",
    )
  }
  let fields : Map[String, Json] = {}
  match projection {
    Object(existing) =>
      for key, value in existing {
        fields[key] = value
      }
    _ => return moonflow_operator_surface_unavailable(run_id, "invalid")
  }
  fields["contract_id"] = Json::string(
    json_string(
      projection,
      "contract_id",
      default="moonflow.operator-surface.v1",
    ),
  )
  fields["run_id"] = Json::string(run_id)
  fields["available"] = Json::boolean(
    match json_object_field(projection, "available") {
      Some(True) => true
      Some(False) => false
      _ => true
    },
  )
  fields["status"] = Json::string(
    json_string(projection, "status", default="published"),
  )
  Json::object(fields)
}
