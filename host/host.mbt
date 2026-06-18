///|
pub struct DeskRoot {
  id : String
  label : String
  path : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub struct HostConfig {
  roots : Array[DeskRoot]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn default_config(workspace_root : String) -> HostConfig {
  {
    roots: [
      {
        id: @moondesk_core.stable_id("root", workspace_root),
        label: @moondesk_core.display_name(workspace_root),
        path: @pathx.normalize(workspace_root),
      },
    ],
  }
}

///|
pub fn is_path_under_root(root : String, candidate : String) -> Bool {
  let root = @pathx.normalize(root)
  let candidate = @pathx.normalize(candidate)
  candidate == root || candidate.has_prefix(root + "/")
}

///|
pub async fn read_scoped_text(root : String, relative_path : String) -> String? {
  let candidate = @pathx.join(root, relative_path)
  if !is_path_under_root(root, candidate) || !@fsx.exists(candidate) {
    None
  } else {
    Some(@fsx.read_file(candidate))
  }
}
