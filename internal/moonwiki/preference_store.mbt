///|
fn preference_dir(workspace_root : String) -> String {
  @pathx.join(
    @pathx.normalize(workspace_root),
    ".moontown/moondesk-preferences",
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
async fn write_preference_records(path : String, records : Array[Json]) -> Unit {
  @fsx.make_directory(
    @pathx.dirname(path).to_owned(),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    path,
    Json::array(records).stringify(indent=2) + "\n",
    create=0o644,
  )
}
