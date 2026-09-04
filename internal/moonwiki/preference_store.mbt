///|
fn preference_dir(workspace_root : String) -> String {
  moonsuite_product_artifact_for_workspace_root(
    workspace_root, "moondesk", "preferences",
  )
}

///|
fn saved_views_path(workspace_root : String) -> String {
  @pathx.join(preference_dir(workspace_root), "views.json")
}

///|
fn tags_path(workspace_root : String) -> String {
  @pathx.join(preference_dir(workspace_root), "tags.json")
}

///|
fn agent_preferences_path(workspace_root : String) -> String {
  @pathx.join(preference_dir(workspace_root), "agent-memory.json")
}

///|
async fn write_preference_records(path : String, records : Array[Json]) -> Unit {
  let content = Json::array(records).stringify(indent=2) + "\n"
  if @fsx.exists(path) {
    if @fsx.read_file(path) == content {
      return
    }
  }
  let parent = @pathx.dirname(path).to_owned()
  @fsx.make_directory(parent, recursive=true, exists_ok=true)
  let temp = @pathx.join(
    parent,
    ".preference-records." +
    @desk.stable_id("preference-write", @async.now().to_string()) +
    ".tmp",
  )
  @fs.write_file(
    temp,
    @encoding/utf8.encode(content),
    create_mode=CreateNew,
    permission=0o600,
    sync=Full,
  )
  @fs.rename(temp, path, replace=true)
  @fs.chmod(path, 0o600)
}
