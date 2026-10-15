///|
// Only the suite-owned explicit installation binding grants project authority.
// Skill files, publisher imports, and unrelated MoonBooks cannot grant it.
async fn moonclaw_general_workspace_trust(
  suite_root : String,
  workspace_id : String,
  book_root : String,
) -> String {
  let config = read_json_file_or_object(
    moonsuite_product_artifact_for_workspace_root(
      suite_root, "moonfish", "moonclaw.json",
    ),
  )
  if json_string(config, "workspace_trust", default="") != "trusted" ||
    json_string(config, "workspace_id", default="") != workspace_id ||
    json_string(config, "execution_owner", default="") != "moonclaw" {
    return "unknown"
  }
  let configured_root = json_string(config, "book_root", default="")
  if configured_root == "" {
    return "unknown"
  }
  let configured = @fs.realpath(configured_root) catch { _ => return "unknown" }
  let selected = @fs.realpath(book_root) catch { _ => return "unknown" }
  if configured == selected {
    "trusted"
  } else {
    "unknown"
  }
}
