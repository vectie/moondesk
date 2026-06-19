///|
async fn app_tool_rewrite_portable_local_asset_roots(
  bundle_root : String,
  copied_paths : Array[String],
) -> Unit {
  for owner in copied_paths {
    if !app_tool_scan_text_asset(owner) {
      continue
    }
    let path = @pathx.join(bundle_root, owner)
    let text = @fs.read_file(path).text() catch { _ => continue }
    let rewritten = app_tool_rewrite_local_asset_roots_in_text(
      owner, text, copied_paths,
    )
    if rewritten != text {
      @fsx.write_to_file(path, rewritten, create=0o644) catch {
        _ => continue
      }
    }
  }
}

///|
fn app_tool_rewrite_local_asset_roots_in_text(
  owner_relative : String,
  text : String,
  copied_paths : Array[String],
) -> String {
  let mut rewritten = text
  for target in copied_paths {
    if target == owner_relative || !app_tool_rewritable_local_asset_path(target) {
      continue
    }
    let relative_target = app_tool_relative_reference_from_owner(
      owner_relative, target,
    )
    rewritten = app_tool_rewrite_root_asset_reference(
      rewritten,
      "/" + target,
      relative_target,
    )
  }
  rewritten
}

///|
fn app_tool_rewritable_local_asset_path(path : String) -> Bool {
  path != "" &&
  !path.has_prefix("api/") &&
  !path.has_prefix("portable/") &&
  path != "portable-runtime.js" &&
  path != "portable-api-snapshot.json" &&
  !path.has_suffix(".html")
}

///|
fn app_tool_relative_reference_from_owner(
  owner_relative : String,
  target : String,
) -> String {
  let owner_dir = @pathx.dirname(owner_relative).to_owned()
  if owner_dir == "." || owner_dir == "" {
    target
  } else {
    let pieces = owner_dir.split("/").to_array()
    let prefixes : Array[String] = []
    for _ in pieces {
      prefixes.push("..")
    }
    prefixes.join("/") + "/" + target
  }
}

///|
fn app_tool_rewrite_root_asset_reference(
  text : String,
  root_reference : String,
  relative_reference : String,
) -> String {
  text
  .replace_all(old="\"\{root_reference}\"", new="\"\{relative_reference}\"")
  .replace_all(old="'\{root_reference}'", new="'\{relative_reference}'")
  .replace_all(old="`\{root_reference}`", new="`\{relative_reference}`")
  .replace_all(old="(\{root_reference})", new="(\{relative_reference})")
  .replace_all(old="(\"\{root_reference}\")", new="(\"\{relative_reference}\")")
  .replace_all(old="('\{root_reference}')", new="('\{relative_reference}')")
}
