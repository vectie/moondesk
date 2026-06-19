///|
async fn app_tool_expand_portable_source_paths(
  book_root : String,
  initial_paths : Array[String],
) -> Array[String] {
  let paths : Array[String] = []
  for path in initial_paths {
    app_tool_push_unique(paths, path)
  }
  let mut index = 0
  while index < paths.length() {
    let relative = paths[index]
    index += 1
    if !app_tool_scan_text_asset(relative) {
      continue
    }
    let source = @pathx.join(book_root, relative)
    if !@fs.exists(source) || is_directory(source) {
      continue
    }
    let text = @fs.read_file(source).text() catch { _ => continue }
    for asset in app_tool_asset_references_from_text(relative, text) {
      if app_tool_portable_asset_exists(book_root, asset) {
        app_tool_push_unique(paths, asset)
      }
    }
  }
  paths
}

///|
async fn app_tool_portable_asset_exists(
  book_root : String,
  relative : String,
) -> Bool {
  let absolute = @pathx.join(book_root, relative)
  @fs.exists(absolute) && !is_directory(absolute)
}

///|
fn app_tool_asset_references_from_text(
  owner_relative : String,
  text : String,
) -> Array[String] {
  let paths : Array[String] = []
  for
    marker in [
      "src=\"", "src='", "href=\"", "href='", "poster=\"", "poster='", "data=\"",
      "data='", "from \"", "from '", "import \"", "import '", "import(\"", "import('",
      "new URL(\"", "new URL('",
    ] {
    app_tool_collect_marked_asset_refs(paths, owner_relative, text, marker)
  }
  for marker in ["srcset=\"", "srcset='"] {
    app_tool_collect_srcset_asset_refs(paths, owner_relative, text, marker)
  }
  app_tool_collect_css_url_asset_refs(paths, owner_relative, text)
  paths
}

///|
fn app_tool_collect_marked_asset_refs(
  paths : Array[String],
  owner_relative : String,
  text : String,
  marker : String,
) -> Unit {
  let mut tail = text
  while true {
    match tail.find(marker) {
      Some(index) => {
        let quote = marker[marker.length() - 1:]
        let value_start = index + marker.length()
        let rest = tail[value_start:]
        match rest.find(quote) {
          Some(end) => {
            app_tool_add_resolved_asset_ref(
              paths,
              owner_relative,
              rest[:end].to_owned(),
            )
            let next_start = value_start + end + 1
            if next_start >= tail.length() {
              break
            }
            tail = tail[next_start:].to_owned()
          }
          None => break
        }
      }
      None => break
    }
  }
}

///|
fn app_tool_collect_srcset_asset_refs(
  paths : Array[String],
  owner_relative : String,
  text : String,
  marker : String,
) -> Unit {
  let mut tail = text
  while true {
    match tail.find(marker) {
      Some(index) => {
        let quote = marker[marker.length() - 1:]
        let value_start = index + marker.length()
        let rest = tail[value_start:]
        match rest.find(quote) {
          Some(end) => {
            for item in rest[:end].split(",") {
              let candidate = item.trim().to_owned()
              match candidate.find(" ") {
                Some(space) =>
                  app_tool_add_resolved_asset_ref(
                    paths,
                    owner_relative,
                    candidate[:space].to_owned(),
                  )
                None =>
                  app_tool_add_resolved_asset_ref(
                    paths, owner_relative, candidate,
                  )
              }
            }
            let next_start = value_start + end + 1
            if next_start >= tail.length() {
              break
            }
            tail = tail[next_start:].to_owned()
          }
          None => break
        }
      }
      None => break
    }
  }
}

///|
fn app_tool_collect_css_url_asset_refs(
  paths : Array[String],
  owner_relative : String,
  text : String,
) -> Unit {
  let mut tail = text
  while true {
    match tail.find("url(") {
      Some(index) => {
        let rest = tail[index + 4:]
        match rest.find(")") {
          Some(end) => {
            app_tool_add_resolved_asset_ref(
              paths,
              owner_relative,
              rest[:end].to_owned(),
            )
            let next_start = index + 4 + end + 1
            if next_start >= tail.length() {
              break
            }
            tail = tail[next_start:].to_owned()
          }
          None => break
        }
      }
      None => break
    }
  }
}

///|
fn app_tool_add_resolved_asset_ref(
  paths : Array[String],
  owner_relative : String,
  raw_reference : String,
) -> Unit {
  match app_tool_resolve_asset_reference(owner_relative, raw_reference) {
    Some(path) => app_tool_push_unique(paths, path)
    None => ()
  }
}

///|
fn app_tool_resolve_asset_reference(
  owner_relative : String,
  raw_reference : String,
) -> String? {
  let reference = app_tool_strip_asset_reference_suffix(
    raw_reference.trim(chars=[' ', '\n', '\r', '\t', '"', '\'']).to_owned(),
  )
  if reference == "" || app_tool_asset_reference_is_external(reference) {
    return None
  }
  if reference.has_prefix("/") {
    let rooted = reference.trim(chars=['/']).to_owned()
    return clean_relative_path(rooted)
  }
  let base = @pathx.dirname(owner_relative).to_owned()
  let joined = if base == "." || base == "" {
    reference
  } else {
    @pathx.join(base, reference)
  }
  clean_relative_path(joined)
}

///|
fn app_tool_strip_asset_reference_suffix(reference : String) -> String {
  let mut end = reference.length()
  for delimiter in ["?", "#"] {
    match reference.find(delimiter) {
      Some(index) if index < end => end = index
      _ => ()
    }
  }
  reference[:end].to_owned()
}

///|
fn app_tool_asset_reference_is_external(reference : String) -> Bool {
  let lower = reference.to_lower()
  lower.has_prefix("http://") ||
  lower.has_prefix("https://") ||
  lower.has_prefix("//") ||
  lower.has_prefix("data:") ||
  lower.has_prefix("blob:") ||
  lower.has_prefix("mailto:") ||
  lower.has_prefix("javascript:") ||
  lower.has_prefix("#") ||
  lower.has_prefix("/api/")
}
