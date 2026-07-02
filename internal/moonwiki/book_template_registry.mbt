///|
async fn book_pattern_records_from_template_registry(
  workspace_root : String,
) -> Array[Json] {
  let records : Array[Json] = []
  for source in book_template_registry_sources(workspace_root) {
    let path = json_string(source, "path", default="")
    if !json_bool(source, "exists", default=false) {
      continue
    }
    let registry = read_json_file_or_object(path)
    for template in json_array_items(registry, "templates") {
      let id = json_string(template, "template_id", default="")
      if id == "" {
        continue
      }
      records.push(
        book_pattern_record_from_template(
          template,
          registry_root=json_string(source, "root", default=""),
        ),
      )
    }
    if records.length() > 0 {
      return records
    }
  }
  records
}

///|
async fn book_template_registry_status(workspace_root : String) -> Json {
  let context = workspace_context(workspace_root)
  let root = context.suite_root
  let sources = book_template_registry_sources(root)
  let templates : Array[Json] = []
  let missing_paths : Array[String] = []
  let mut selected_path = ""
  let mut selected_root = ""
  for source in sources {
    let path = json_string(source, "path", default="")
    if !json_bool(source, "exists", default=false) || selected_path != "" {
      continue
    }
    let registry = read_json_file_or_object(path)
    for template in json_array_items(registry, "templates") {
      templates.push(template)
      for
        missing in book_template_missing_paths(
          template,
          registry_root=json_string(source, "root", default=""),
        ) {
        missing_paths.push(missing)
      }
    }
    selected_path = path
    selected_root = json_string(source, "root", default="")
  }
  {
    "kind": "moontown-book-template-registry-status",
    "ready": selected_path != "" &&
    templates.length() > 0 &&
    missing_paths.length() == 0,
    "selected_path": selected_path,
    "selected_root": selected_root,
    "sources": Json::array(sources),
    "template_count": templates.length(),
    "missing_count": missing_paths.length(),
    "missing_paths": json_from_string_array(missing_paths),
    "templates": Json::array(templates),
    "base_types": Json::array(
      book_base_type_records_from_patterns(
        book_pattern_records_for_workspace(root),
      ),
    ),
  }
}

///|
async fn book_template_registry_sources(workspace_root : String) -> Array[Json] {
  let sources : Array[Json] = []
  let roots = [workspace_context(workspace_root).suite_root]
  let seen : Array[String] = []
  for root in roots {
    if root == "" || seen.contains(root) {
      continue
    }
    seen.push(root)
    let path = @pathx.join(root, "templates/books/templates.json")
    sources.push({ "root": root, "path": path, "exists": @fs.exists(path) })
  }
  sources
}

///|
async fn book_pattern_record_from_template(
  template : Json,
  registry_root~ : String,
) -> Json {
  let id = json_string(template, "template_id", default="")
  let install_path = resolve_registry_relative_path(
    registry_root,
    json_string(template, "install_example", default=""),
  )
  let install = read_json_file_or_object(install_path)
  let websites = json_string_array_items(install, "websites")
  let cadence = json_int(install, "cadence_ticks", default=30)
  let skills = template_skill_ids(template)
  {
    "id": id,
    "title": json_string(template, "title", default=id),
    "base_type": json_string(template, "book_type", default="research-book"),
    "description": json_string(
      template,
      "purpose",
      default="Reusable MoonBook template.",
    ),
    "output": if id == "pdf-evidence-watch" {
      "wiki findings and generated book site"
    } else {
      "template-defined MoonBook outputs"
    },
    "default_topic": "my domain",
    "default_cadence_minutes": cadence,
    "default_source_policy": "web-first",
    "standing_watch": json_bool(
      template,
      "standing_watch",
      default=book_pattern_supports_standing_watch(id),
    ),
    "creation_backend": json_string(
      template,
      "creation_backend",
      default=book_pattern_creation_backend(id),
    ),
    "default_websites": json_from_string_array(websites),
    "skills": json_from_string_array(skills),
    "template_registry_refs": json_from_string_array(
      template_registry_refs_from_template(template, registry_root~),
    ),
  }
}

///|
fn template_registry_refs_from_template(
  template : Json,
  registry_root~ : String,
) -> Array[String] {
  let refs : Array[String] = []
  let registry_ref = registry_ref_from_root(
    registry_root, "templates/books/templates.json",
  )
  if registry_ref != "" {
    refs.push(registry_ref)
  }
  let book_ref = registry_ref_from_root(
    registry_root,
    json_string(template, "root", default="") + "/book.json",
  )
  if book_ref != "" && !refs.contains(book_ref) {
    refs.push(book_ref)
  }
  refs
}

///|
fn registry_ref_from_root(root : String, relative : String) -> String {
  if root == "" || relative == "" {
    return ""
  }
  if relative.has_prefix("templates/books/") {
    "moontown://" + relative
  } else {
    @pathx.join(root, relative)
  }
}

///|
async fn book_template_missing_paths(
  template : Json,
  registry_root~ : String,
) -> Array[String] {
  let missing : Array[String] = []
  let template_root = resolve_registry_relative_path(
    registry_root,
    json_string(template, "root", default=""),
  )
  if template_root != "" && !@fs.exists(template_root) {
    missing.push(template_root)
  }
  let install_example = resolve_registry_relative_path(
    registry_root,
    json_string(template, "install_example", default=""),
  )
  if install_example != "" && !@fs.exists(install_example) {
    missing.push(install_example)
  }
  for required in json_string_array_items(template, "required_paths") {
    let path = if required.has_prefix("/") {
      required
    } else {
      @pathx.join(template_root, required)
    }
    if path != "" && !@fs.exists(path) && !missing.contains(path) {
      missing.push(path)
    }
  }
  missing
}

///|
fn resolve_registry_relative_path(root : String, path : String) -> String {
  if path == "" || path.has_prefix("/") {
    path
  } else {
    @pathx.join(root, path)
  }
}

///|
fn template_skill_ids(template : Json) -> Array[String] {
  let skills : Array[String] = []
  collect_template_skill_ids(
    skills,
    json_string_array_items(template, "required_paths"),
  )
  collect_template_skill_ids(
    skills,
    json_string_array_items(template, "editable_files"),
  )
  if skills.length() == 0 &&
    json_string(template, "template_id", default="") == "pdf-evidence-watch" {
    skills.push("pdf-watch")
    skills.push("pdf-analysis")
  }
  skills
}

///|
fn collect_template_skill_ids(
  skills : Array[String],
  paths : Array[String],
) -> Unit {
  for path in paths {
    let id = template_skill_id_from_path(path)
    if id != "" && !skills.contains(id) {
      skills.push(id)
    }
  }
}

///|
fn template_skill_id_from_path(path : String) -> String {
  let prefix = "skills/"
  let suffix = "/SKILL.md"
  if !path.has_prefix(prefix) || !path.has_suffix(suffix) {
    return ""
  }
  path[prefix.length():path.length() - suffix.length()].to_owned()
}
