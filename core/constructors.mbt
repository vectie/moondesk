///|
pub fn workspace(
  id~ : String,
  name~ : String,
  root_path~ : String,
  kind~ : WorkspaceKind,
  status? : WorkspaceStatus = Ready,
  last_seen_at? : String? = None,
) -> DeskWorkspace {
  { id, name, root_path, kind, status, last_seen_at }
}

///|
pub fn file_entry(
  workspace_id~ : String,
  path~ : String,
  is_directory? : Bool = false,
  writable? : Bool = false,
  readable? : Bool = true,
  size_bytes? : Int? = None,
  modified_at? : String? = None,
) -> DeskFileEntry {
  let kind = infer_entry_kind(path, is_directory~)
  {
    id: stable_id(workspace_id, path),
    workspace_id,
    path,
    display_name: display_name(path),
    kind,
    source_layer: infer_source_layer(path),
    readable,
    writable,
    size_bytes,
    modified_at,
  }
}

///|
pub fn file_entry_detail(
  workspace_id~ : String,
  path~ : String,
  display_name~ : String,
  kind~ : EntryKind,
  source_layer~ : SourceLayer,
  readable? : Bool = true,
  writable? : Bool = false,
  size_bytes? : Int? = None,
  modified_at? : String? = None,
) -> DeskFileEntry {
  {
    id: stable_id(workspace_id, path),
    workspace_id,
    path,
    display_name,
    kind,
    source_layer,
    readable,
    writable,
    size_bytes,
    modified_at,
  }
}

///|
pub fn artifact_entry(workspace_id~ : String, path~ : String) -> DeskFileEntry {
  file_entry_detail(
    workspace_id~,
    path~,
    display_name=display_name(path),
    kind=Artifact,
    source_layer=RunArtifact,
  )
}

///|
pub fn preview(
  entry : DeskFileEntry,
  body~ : String,
  warnings? : Array[String] = [],
) -> DeskPreview {
  {
    entry_id: entry.id,
    renderer: renderer_for_kind(entry.kind),
    title: entry.display_name,
    body,
    metadata: {},
    warnings,
  }
}

///|
pub fn normalize_review_policy(value : String) -> String {
  let policy = value.trim().to_owned()
  if policy == "" {
    "bookkeeper_review"
  } else {
    policy
  }
}

///|
pub fn run_artifact(
  id~ : String,
  path~ : String,
  title? : String = display_name(path),
  kind? : EntryKind = infer_entry_kind(path),
) -> DeskRunArtifact {
  { id, path, title, kind }
}

///|
pub fn run_projection(
  run_id~ : String,
  book_id~ : String,
  status~ : String,
  phase~ : String,
  summary~ : String,
  artifacts~ : Array[DeskRunArtifact],
  goal_id? : String? = None,
  started_at? : String? = None,
  updated_at? : String? = None,
) -> DeskRunProjection {
  {
    run_id,
    book_id,
    goal_id,
    status,
    phase,
    summary,
    artifacts,
    started_at,
    updated_at,
  }
}
