///|
fn pack_app_proxy_scoped_target(
  entrypoint_path : String,
  rest : ArrayView[String],
) -> String? {
  if !is_safe_pack_route_path(entrypoint_path) {
    return None
  }
  if rest.is_empty() {
    return Some(entrypoint_path)
  }
  let target_path = "/" + rest.join("/")
  if !is_safe_pack_route_path(target_path) {
    return None
  }
  let scope = if entrypoint_path.has_suffix(".html") {
    @pathx.dirname(entrypoint_path).to_owned()
  } else {
    entrypoint_path
  }
  if scope == "/" ||
    target_path == entrypoint_path ||
    target_path == scope ||
    target_path.has_prefix(scope + "/") {
    Some(target_path)
  } else {
    None
  }
}
