///|
pub fn known_run_roots(book_root : String) -> Array[String] {
  [@moonsuite.product_artifact(book_root, "moonclaw", "jobs")]
}

///|
pub fn artifact_entry(
  workspace_id : String,
  path : String,
) -> @moondesk_core.DeskFileEntry {
  @moondesk_core.artifact_entry(workspace_id~, path~)
}

///|
pub fn run_projection(
  run_id : String,
  book_id : String,
  status : String,
  phase : String,
  summary : String,
  artifacts : Array[@moondesk_core.DeskRunArtifact],
) -> @moondesk_core.DeskRunProjection {
  @moondesk_core.run_projection(
    run_id~,
    book_id~,
    status~,
    phase~,
    summary~,
    artifacts~,
  )
}
