///|
pub fn display_name(path : StringView) -> String {
  let parts = path.split("/").to_array()
  if parts.length() == 0 {
    path.to_owned()
  } else {
    let name = parts[parts.length() - 1].to_owned()
    if name == "" && parts.length() > 1 {
      parts[parts.length() - 2].to_owned()
    } else {
      name
    }
  }
}

///|
pub fn extension(path : StringView) -> String {
  let name = display_name(path)
  let parts = name.split(".").to_array()
  if parts.length() <= 1 {
    ""
  } else {
    "." + parts[parts.length() - 1].to_owned().to_lower()
  }
}

///|
pub fn infer_entry_kind(
  path : StringView,
  is_directory? : Bool = false,
) -> EntryKind {
  if is_directory {
    Directory
  } else {
    match extension(path) {
      ".md" | ".markdown" | ".mbt.md" => Markdown
      ".html" | ".htm" => Html
      ".json" | ".jsonl" => Json
      ".png" | ".jpg" | ".jpeg" | ".gif" | ".webp" | ".svg" => Image
      ".txt" | ".log" => Text
      _ => Unknown
    }
  }
}

///|
pub fn renderer_for_kind(kind : EntryKind) -> PreviewRenderer {
  match kind {
    Markdown => Markdown
    Html => Html
    Json => Json
    Image => Image
    Text => Text
    Artifact => ArtifactSummary
    Directory => DirectoryListing
    Unknown => Unsupported
  }
}

///|
pub fn moonsuite_product_display_dir(product_id : String) -> String {
  @moonsuite.product_display_dir(product_id)
}

///|
pub fn moonsuite_product_display_artifact(
  product_id : String,
  relative : String,
) -> String {
  @moonsuite.product_display_artifact(product_id, relative)
}

///|
pub fn moonsuite_product_display_absolute_artifact(
  product_id : String,
  relative : String,
) -> String {
  @moonsuite.product_display_absolute_artifact(product_id, relative)
}

///|
pub fn moonsuite_root_for_workspace_root(workspace_root : String) -> String {
  @moonsuite.suite_root_for_workspace_root(workspace_root)
}

///|
pub fn moonsuite_books_root(root : String) -> String {
  @moonsuite.books_root(root)
}

///|
pub fn moonsuite_state_display_dir() -> String {
  @moonsuite.state_dir(".")
}

///|
pub fn moonsuite_tmp_display_dir() -> String {
  @moonsuite.tmp_root(".")
}

///|
pub fn moonsuite_internal_relative_path(path : StringView) -> Bool {
  let clean = path.to_owned().trim(chars=['/']).to_owned()
  let state_dir = moonsuite_state_display_dir()
  let tmp_dir = moonsuite_tmp_display_dir()
  clean == state_dir ||
  clean.has_prefix(state_dir + "/") ||
  clean == tmp_dir ||
  clean.has_prefix(tmp_dir + "/")
}

///|
pub fn infer_source_layer(path : StringView) -> SourceLayer {
  let path = path.to_owned()
  if path == "wiki/history" ||
    path.has_prefix("wiki/history/") ||
    path.contains("/wiki/history/") {
    History
  } else if path == "wiki/reviews" ||
    path.has_prefix("wiki/reviews/") ||
    path.contains("/wiki/reviews/") {
    Review
  } else if path == "wiki" ||
    path.has_prefix("wiki/") ||
    path.contains("/wiki/") {
    Wiki
  } else if path == "raw" || path.has_prefix("raw/") || path.contains("/raw/") {
    RawEvidence
  } else if path == "skills" ||
    path.has_prefix("skills/") ||
    path.contains("/skills/") {
    Skill
  } else if path == "schemas" ||
    path.has_prefix("schemas/") ||
    path.contains("/schemas/") {
    Schema
  } else if path == "tools" ||
    path.has_prefix("tools/") ||
    path.contains("/tools/") {
    Tool
  } else if path == "portable/app-tool" ||
    path.has_prefix("portable/app-tool/") ||
    path.contains("/portable/app-tool/") {
    PortableAppTool
  } else if path == "apps" ||
    path.has_prefix("apps/") ||
    path.contains("/apps/") ||
    path == "app" ||
    path.has_prefix("app/") ||
    path.contains("/app/") {
    App
  } else if path == "reviews" ||
    path.has_prefix("reviews/") ||
    path.contains("/reviews/") {
    Review
  } else if path == "site/generated" ||
    path == "book/site/generated" ||
    path.has_prefix("site/generated/") ||
    path.has_prefix("book/site/generated/") ||
    path.contains("/site/generated/") {
    GeneratedSite
  } else if path.has_prefix("book/") || path.contains("/book/") {
    BookOutput
  } else if path == "inbox" ||
    path.has_prefix("inbox/") ||
    path.contains("/inbox/") {
    Inbox
  } else if path == moonsuite_product_display_dir("moonclaw") ||
    path.has_prefix(moonsuite_product_display_dir("moonclaw") + "/") {
    RunArtifact
  } else if moonsuite_internal_relative_path(path) {
    Config
  } else {
    Workspace
  }
}

///|
pub fn stable_id(prefix : String, value : String) -> String {
  let mut out = ""
  for ch in value {
    if (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9') {
      out = out + ch.to_string()
    } else if ch >= 'A' && ch <= 'Z' {
      out = out + ch.to_string().to_lower()
    } else if out == "" || !out.has_suffix("-") {
      out = out + "-"
    }
  }
  let out = out.trim(chars=['-']).to_owned()
  if out == "" {
    prefix
  } else {
    prefix + "-" + out
  }
}
