///|
/// Match the adapter's canonical section identity, never just a filename.
/// Authored entries with the same visible name keep their original text.
fn desk_system_entry_i18n_key(entry : @desk.DeskFileEntry) -> String? {
  guard entry.kind is Directory else { return None }
  match (entry.path, entry.display_name, entry.source_layer) {
    ("wiki", "Wiki", Wiki) => Some("desk.section_wiki")
    ("raw", "Raw Evidence", RawEvidence) => Some("desk.section_raw")
    ("inbox", "Inbox", Inbox) => Some("desk.section_inbox")
    ("skills", "Skills", Skill) => Some("desk.section_skills")
    ("schemas", "Schemas", Schema) => Some("desk.section_schemas")
    ("tools", "Tools", Tool) => Some("desk.section_tools")
    ("apps", "Apps", App) => Some("desk.section_apps")
    ("app", "App", App) => Some("desk.section_app")
    ("book/site/generated", "Generated Site", GeneratedSite) =>
      Some("desk.section_generated_site")
    ("site/generated", "Site Generated", GeneratedSite) =>
      Some("desk.section_site_generated")
    ("portable/app-tool", "Portable App Tool", PortableAppTool) =>
      Some("desk.section_portable_tool")
    ("reviews", "Reviews", Review) => Some("desk.section_reviews")
    ("wiki/reviews", "Review Queue", Review) =>
      Some("desk.section_review_queue")
    ("wiki/history", "Journal", History) => Some("desk.section_journal")
    (".moonsuite/products/moonclaw/jobs", "MoonClaw Runs", RunArtifact) =>
      Some("desk.section_runs")
    _ => None
  }
}

///|
fn desk_name_attrs(key : String?) -> @html.Attrs {
  match key {
    Some(key) =>
      @html.Attrs::build()
      .data_set("i18n-scope", "interface")
      .data_set("i18n", key)
    None => @html.Attrs::build().data_set("i18n-scope", "content")
  }
}

///|
fn desk_outline_label_i18n_key(
  label : String,
  path : String,
  entries : Array[@desk.DeskFileEntry],
) -> String? {
  if path == "" && label == "root" {
    return Some("desk.section_root")
  }
  for entry in entries {
    if entry.path == path && entry.display_name == label {
      return desk_system_entry_i18n_key(entry)
    }
  }
  None
}

///|
extern "js" fn interface_label(key : String, fallback : String) -> String =
  #|(key, fallback) => globalThis.window?.MoonSuiteI18n?.message?.(key) || fallback
