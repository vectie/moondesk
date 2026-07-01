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
    kind=MoonBook,
  )
}

///|
pub fn canonical_sections() -> Array[MoonBookSection] {
  [
    { label: "Wiki", path: "wiki", layer: Wiki, writable: false },
    { label: "Raw Evidence", path: "raw", layer: RawEvidence, writable: false },
    { label: "Inbox", path: "inbox", layer: Inbox, writable: true },
    { label: "Skills", path: "skills", layer: Skill, writable: false },
    { label: "Schemas", path: "schemas", layer: Schema, writable: false },
    { label: "Tools", path: "tools", layer: Tool, writable: false },
    { label: "Apps", path: "apps", layer: App, writable: false },
    { label: "App", path: "app", layer: App, writable: false },
    {
      label: "Generated Site",
      path: "book/site/generated",
      layer: GeneratedSite,
      writable: false,
    },
    {
      label: "Site Generated",
      path: "site/generated",
      layer: GeneratedSite,
      writable: false,
    },
    {
      label: "Portable App Tool",
      path: "portable/app-tool",
      layer: PortableAppTool,
      writable: false,
    },
    { label: "Reviews", path: "reviews", layer: Review, writable: false },
    {
      label: "Review Queue",
      path: "wiki/reviews",
      layer: Review,
      writable: false,
    },
    { label: "Journal", path: "wiki/history", layer: History, writable: false },
    {
      label: "MoonClaw Runs",
      path: ".moonsuite/products/moonclaw/jobs",
      layer: RunArtifact,
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
      kind=Directory,
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
