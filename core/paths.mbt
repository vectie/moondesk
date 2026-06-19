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
pub fn infer_source_layer(path : StringView) -> SourceLayer {
  let path = path.to_owned()
  if path.has_prefix("wiki/history/") || path.contains("/wiki/history/") {
    History
  } else if path.has_prefix("wiki/") || path.contains("/wiki/") {
    Wiki
  } else if path.has_prefix("raw/") || path.contains("/raw/") {
    RawEvidence
  } else if path.has_prefix("reviews/") || path.contains("/reviews/") {
    Review
  } else if path.contains("site/generated/") {
    GeneratedSite
  } else if path.has_prefix("book/") || path.contains("/book/") {
    BookOutput
  } else if path.has_prefix("inbox/") || path.contains("/inbox/") {
    Inbox
  } else if path.contains("moonclaw") || path.contains(".moonclaw") {
    RunArtifact
  } else if path.has_prefix(".moontown/") {
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
