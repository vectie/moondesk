///|
/// Keep binary previews lazy and digest-bound. Test fixtures that do not carry
/// metadata retain their existing body as a compatibility fallback.
fn desk_preview_image_source(preview : @desk.DeskPreview) -> String {
  preview.metadata.get("artifact_url").unwrap_or(preview.body)
}

///|
fn desk_preview_image_attrs(preview : @desk.DeskPreview) -> @html.Attrs {
  let digest = preview.metadata.get("artifact_digest").unwrap_or("")
  @html.Attrs::build()
  .loading("lazy")
  .decoding("async")
  .data_set("artifact-digest", digest)
}
