///|
pub fn display_name(path : StringView) -> String {
  let parts = path.split("/").to_array()
  if parts.length() == 0 {
    path.to_string()
  } else {
    let name = parts[parts.length() - 1].to_string()
    if name == "" && parts.length() > 1 {
      parts[parts.length() - 2].to_string()
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
    "." + parts[parts.length() - 1].to_string().to_lower()
  }
}

///|
pub fn infer_entry_kind(
  path : StringView,
  is_directory? : Bool = false,
) -> EntryKind {
  if is_directory {
    EntryKind::Directory
  } else {
    match extension(path) {
      ".md" | ".markdown" | ".mbt.md" => EntryKind::Markdown
      ".html" | ".htm" => EntryKind::Html
      ".json" | ".jsonl" => EntryKind::Json
      ".png" | ".jpg" | ".jpeg" | ".gif" | ".webp" | ".svg" => EntryKind::Image
      ".txt" | ".log" => EntryKind::Text
      _ => EntryKind::Unknown
    }
  }
}

///|
pub fn renderer_for_kind(kind : EntryKind) -> PreviewRenderer {
  match kind {
    EntryKind::Markdown => PreviewRenderer::Markdown
    EntryKind::Html => PreviewRenderer::Html
    EntryKind::Json => PreviewRenderer::Json
    EntryKind::Image => PreviewRenderer::Image
    EntryKind::Text => PreviewRenderer::Text
    EntryKind::Artifact => PreviewRenderer::ArtifactSummary
    EntryKind::Directory => PreviewRenderer::DirectoryListing
    EntryKind::Unknown => PreviewRenderer::Unsupported
  }
}

///|
pub fn infer_source_layer(path : StringView) -> SourceLayer {
  let path = path.to_string()
  if path.has_prefix("wiki/history/") || path.contains("/wiki/history/") {
    SourceLayer::History
  } else if path.has_prefix("wiki/") || path.contains("/wiki/") {
    SourceLayer::Wiki
  } else if path.has_prefix("raw/") || path.contains("/raw/") {
    SourceLayer::RawEvidence
  } else if path.has_prefix("reviews/") || path.contains("/reviews/") {
    SourceLayer::Review
  } else if path.contains("site/generated/") {
    SourceLayer::GeneratedSite
  } else if path.has_prefix("book/") || path.contains("/book/") {
    SourceLayer::BookOutput
  } else if path.has_prefix("inbox/") || path.contains("/inbox/") {
    SourceLayer::Inbox
  } else if path.contains("moonclaw") || path.contains(".moonclaw") {
    SourceLayer::RunArtifact
  } else if path.has_prefix(".moontown/") {
    SourceLayer::Config
  } else {
    SourceLayer::Workspace
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
