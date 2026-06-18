///|
pub struct MoonBookSection {
  label : String
  path : String
  layer : @moondesk_core.SourceLayer
  writable : Bool
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn workspace_from_root(
  root_path : String,
  name : String,
) -> @moondesk_core.DeskWorkspace {
  @moondesk_core.workspace(
    id=@moondesk_core.stable_id("book", name),
    name~,
    root_path~,
    kind=@moondesk_core.WorkspaceKind::MoonBook,
  )
}

///|
pub fn canonical_sections() -> Array[MoonBookSection] {
  [
    {
      label: "Wiki",
      path: "wiki",
      layer: @moondesk_core.SourceLayer::Wiki,
      writable: false,
    },
    {
      label: "Raw Evidence",
      path: "raw",
      layer: @moondesk_core.SourceLayer::RawEvidence,
      writable: false,
    },
    {
      label: "Inbox",
      path: "inbox",
      layer: @moondesk_core.SourceLayer::Inbox,
      writable: true,
    },
    {
      label: "Reviews",
      path: "reviews",
      layer: @moondesk_core.SourceLayer::Review,
      writable: false,
    },
    {
      label: "Generated Site",
      path: "book/site/generated",
      layer: @moondesk_core.SourceLayer::GeneratedSite,
      writable: false,
    },
    {
      label: "Journal",
      path: "wiki/history",
      layer: @moondesk_core.SourceLayer::History,
      writable: false,
    },
    {
      label: "MoonClaw Runs",
      path: "moonclaw-jobs",
      layer: @moondesk_core.SourceLayer::RunArtifact,
      writable: false,
    },
  ]
}

///|
pub fn section_entries(
  workspace_id : String,
) -> Array[@moondesk_core.DeskFileEntry] {
  canonical_sections().map(section => {
    @moondesk_core.file_entry_detail(
      workspace_id~,
      path=section.path,
      display_name=section.label,
      kind=@moondesk_core.EntryKind::Directory,
      source_layer=section.layer,
      writable=section.writable,
    )
  })
}

///|
pub fn generated_site_entry(
  workspace_id : String,
) -> @moondesk_core.DeskFileEntry {
  @moondesk_core.file_entry(
    workspace_id~,
    path="book/site/generated/index.html",
  )
}
