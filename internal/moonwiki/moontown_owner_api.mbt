///| MoonDesk is a typed local proxy here. MoonTown remains the only writer of
///| Town requests and standing-goal state.
async fn moontown_owner_service_url(
  workspace_root : String,
) -> Result[String, String] {
  guard configured_pack_app(workspace_root, "moontown") is Some(app) else {
    return Err(
      "MoonTown is not configured. Start its owner service, then refresh MoonDesk.",
    )
  }
  let service_url = json_string(app, "service_url", default="")
  if service_url == "" {
    return Err(
      "MoonTown has no safe local service URL. Repair its pack runtime configuration.",
    )
  }
  Ok(service_url)
}

///|
async fn moontown_owner_get_raw_json(
  service_url : String,
  path : String,
) -> Result[Json, String] {
  let (response, data) = @http.get(service_url + path) catch {
    error => return Err("MoonTown is unavailable at {path}: {error}")
  }
  let text = data.text() catch { _ => "" }
  if response.code < 200 || response.code > 299 {
    return Err("MoonTown returned {response.code} for {path}: {text}")
  }
  let payload = @json.parse(text) catch {
    _ => return Err("MoonTown returned invalid JSON for {path}")
  }
  Ok(payload)
}

///|
async fn verified_moontown_owner_service_url(
  workspace_root : String,
) -> Result[String, String] {
  let service_url = match moontown_owner_service_url(workspace_root) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let contract = match moontown_owner_get_raw_json(
    service_url,
    "/api/contract",
  ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if json_string(contract, "schema", default="") != "moontown.api.v1" {
    return Err(
      "MoonTown does not expose the required moontown.api.v1 contract. Upgrade or restart its owner service.",
    )
  }
  Ok(service_url)
}

///|
async fn moontown_owner_get_json(
  workspace_root : String,
  path : String,
) -> Result[Json, String] {
  let service_url = match verified_moontown_owner_service_url(workspace_root) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  moontown_owner_get_raw_json(service_url, path)
}

///|
async fn moontown_owner_post_json(
  workspace_root : String,
  path : String,
  body : Json,
) -> Result[Json, String] {
  let service_url = match verified_moontown_owner_service_url(workspace_root) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let (response, data) = @http.post(service_url + path, body, headers={
    "Content-Type": "application/json",
    "Accept": "application/json",
  }) catch {
    error => return Err("MoonTown is unavailable at {path}: {error}")
  }
  let text = data.text() catch { _ => "" }
  if response.code < 200 || response.code > 299 {
    return Err("MoonTown returned {response.code} for {path}: {text}")
  }
  let payload = @json.parse(text) catch {
    _ => return Err("MoonTown returned invalid JSON for {path}")
  }
  Ok(payload)
}

///|
fn moontown_owner_watch_payload(payload : Json) -> Json {
  {
    "title": json_string(payload, "title", default="Standing watch"),
    "prompt": json_string(payload, "prompt", default=""),
    "target_book_id": json_string(
      payload,
      "target_book_id",
      default=json_string(payload, "book_id", default="research-opc"),
    ),
    "cadence_ticks": clamp_int(
      json_int(payload, "cadence_ticks", default=60),
      1,
      525600,
    ),
    "quality_threshold": clamp_int(
      json_int(payload, "quality_threshold", default=85),
      1,
      100,
    ),
    "goal_id": json_string(payload, "id", default=""),
  }
}
