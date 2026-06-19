///|
async fn app_tool_copy_book_path(
  book_root : String,
  bundle_root : String,
  relative : String,
  copied_paths : Array[String],
  missing_paths : Array[String],
  skipped_paths : Array[String],
) -> Unit {
  match clean_relative_path(relative) {
    Some(path) =>
      if path == "" || path == "portable" || path.has_prefix("portable/") {
        app_tool_push_unique(skipped_paths, relative)
        return
      } else {
        let source = @pathx.join(book_root, path)
        if !@fs.exists(source) {
          if app_tool_optional_source_path(path) {
            app_tool_push_unique(skipped_paths, path)
          } else {
            app_tool_push_unique(missing_paths, path)
          }
        } else if is_directory(source) {
          app_tool_copy_dir_recursive(
            book_root, bundle_root, path, copied_paths, missing_paths, skipped_paths,
          )
        } else {
          app_tool_copy_file(
            book_root, bundle_root, path, copied_paths, missing_paths,
          )
        }
      }
    None => app_tool_push_unique(skipped_paths, relative)
  }
}

///|
async fn app_tool_copy_dir_recursive(
  book_root : String,
  bundle_root : String,
  relative_dir : String,
  copied_paths : Array[String],
  missing_paths : Array[String],
  skipped_paths : Array[String],
) -> Unit {
  let source_dir = @pathx.join(book_root, relative_dir)
  @fsx.make_directory(
    @pathx.join(bundle_root, relative_dir),
    recursive=true,
    exists_ok=true,
  ) catch {
    _ => {
      app_tool_push_unique(missing_paths, relative_dir)
      return
    }
  }
  for name in read_directory_names(source_dir, include_hidden=true) {
    if app_tool_should_skip_copy_name(name) {
      app_tool_push_unique(skipped_paths, @pathx.join(relative_dir, name))
      continue
    }
    let child_relative = @pathx.join(relative_dir, name)
    if child_relative == "portable" || child_relative.has_prefix("portable/") {
      app_tool_push_unique(skipped_paths, child_relative)
      continue
    }
    let child_source = @pathx.join(book_root, child_relative)
    if is_directory(child_source) {
      app_tool_copy_dir_recursive(
        book_root, bundle_root, child_relative, copied_paths, missing_paths, skipped_paths,
      )
    } else {
      app_tool_copy_file(
        book_root, bundle_root, child_relative, copied_paths, missing_paths,
      )
    }
  }
}

///|
fn app_tool_should_skip_copy_name(name : String) -> Bool {
  name == "DS_Store" ||
  name == ".git" ||
  name == "node_modules" ||
  name == "_build" ||
  name == "portable"
}

///|
fn app_tool_optional_source_path(relative : String) -> Bool {
  [
    "app", "book/site/generated", "site/generated", "book/outputs", "wiki/reports",
    "wiki/tools", "raw/analysis-runs", "skills", "schemas",
  ].contains(relative)
}

///|
async fn app_tool_copy_file(
  book_root : String,
  bundle_root : String,
  relative : String,
  copied_paths : Array[String],
  missing_paths : Array[String],
) -> Unit {
  let source = @pathx.join(book_root, relative)
  let target = @pathx.join(bundle_root, relative)
  let bytes = @fs.read_file(source).binary() catch {
    _ => {
      app_tool_push_unique(missing_paths, relative)
      return
    }
  }
  @fsx.make_directory(
    @pathx.dirname(target).to_owned(),
    recursive=true,
    exists_ok=true,
  ) catch {
    _ => {
      app_tool_push_unique(missing_paths, relative)
      return
    }
  }
  write_bytes_file(target, bytes, create=0o644) catch {
    _ => {
      app_tool_push_unique(missing_paths, relative)
      return
    }
  }
  app_tool_push_unique(copied_paths, relative)
}

///|
fn app_tool_push_unique(items : Array[String], item : String) -> Unit {
  if item != "" && !items.contains(item) {
    items.push(item)
  }
}
