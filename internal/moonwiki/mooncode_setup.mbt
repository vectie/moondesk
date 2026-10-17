///|
let mooncode_setup_mutex : @async.Mutex = Mutex()

///|
fn mooncode_setup_skill_field(content : String, key : String) -> String {
  let lines = content.split("\n").collect()
  if lines.is_empty() || lines[0].trim() != "---" {
    return ""
  }
  for index in 1..<lines.length() {
    let line = lines[index]
    if line.trim() == "---" {
      break
    }
    if line.has_prefix(key + ":") {
      let value = line[key.length() + 1:].trim().to_owned()
      if value.has_prefix("\"") && value.has_suffix("\"") {
        let parsed = @json.parse(value) catch { _ => Json::null() }
        match parsed {
          String(text) => return text
          _ => return ""
        }
      }
      if value.has_prefix("'") && value.has_suffix("'") && value.length() >= 2 {
        return value[1:value.length() - 1].to_owned()
      }
      return value
    }
  }
  ""
}

///|
fn mooncode_setup_relative_file(path : String) -> Bool {
  if path == "" || path.has_prefix("/") || path.contains("\\") {
    return false
  }
  for part in path.split("/") {
    if part == "" || part == "." || part == ".." {
      return false
    }
  }
  true
}

///|
fn mooncode_setup_skill_files(payload : Json) -> Result[Array[Json], String] {
  let id = json_string(payload, "id", default="")
  if !mooncode_setup_relative_file(id) || id.contains("/") || id.has_prefix(".") {
    return Err("Give this skill a folder name, such as review-changes")
  }
  let files = json_array_items(payload, "files")
  let seen : Map[String, Bool] = Map([])
  for file in files {
    let path = json_string(file, "path", default="")
    if !mooncode_setup_relative_file(path) || seen.contains(path) {
      return Err("Each skill file needs a unique relative path")
    }
    seen[path] = true
  }
  if !seen.contains("SKILL.md") {
    return Err("Add a SKILL.md file with a name, description and instructions")
  }
  for file in files {
    if json_string(file, "path", default="") == "SKILL.md" {
      let content = json_string(file, "content", default="")
      if mooncode_setup_skill_field(content, "name") != id ||
        mooncode_setup_skill_field(content, "description") == "" {
        return Err(
          "SKILL.md needs YAML name matching its folder and a description",
        )
      }
    }
  }
  Ok(files)
}

///|
fn mooncode_setup_path(book_root : String, workspace_id : String) -> String {
  moonsuite_product_artifact_for_workspace_root(
    book_root,
    "moondesk",
    "coding-setup/" + @desk.stable_id("book", workspace_id) + ".json",
  )
}

///|
async fn mooncode_setup_write(path : String, text : String) -> Unit {
  @fsx.make_directory(@pathx.dirname(path), recursive=true, exists_ok=true)
  @fsx.write_to_file(path, text)
}

///|
async fn mooncode_setup_read(path : String) -> String {
  if @fsx.exists(path) {
    @fsx.read_file(path)
  } else {
    ""
  }
}

///|
async fn mooncode_setup_files(root : String, relative : String) -> Array[Json] {
  let files : Array[Json] = []
  let dir = if relative == "" { root } else { @pathx.join(root, relative) }
  if !@fsx.exists(dir) {
    return files
  }
  let entries = read_directory_names(dir, include_hidden=true)
  for entry in entries {
    let path = if relative == "" { entry } else { relative + "/" + entry }
    match @fs.kind(@pathx.join(root, path), follow_symlink=false) {
      Directory => files.append(mooncode_setup_files(root, path))
      Regular => {
        let text = @fsx.read_file(@pathx.join(root, path)) catch {
          _ => continue
        }
        files.push({ "path": path, "content": text })
      }
      _ => ()
    }
  }
  files.sort_by((a, b) => {
    json_string(a, "path", default="").compare(
      json_string(b, "path", default=""),
    )
  })
  files
}

///|
async fn mooncode_setup_snapshot(
  book_root : String,
  workspace_id : String,
) -> Json {
  let state = read_json_file_or_object(
    mooncode_setup_path(book_root, workspace_id),
  )
  let root = moonsuite_product_artifact_for_workspace_root(
    book_root, "moonclaw", "skills",
  )
  let skills : Array[Json] = []
  if @fsx.exists(root) {
    for id in read_directory_names(root, include_hidden=true) {
      if id.has_prefix(".") {
        continue
      }
      let dir = @pathx.join(root, id)
      if @fs.kind(dir, follow_symlink=false) is Directory {
        let files = mooncode_setup_files(dir, "")
        if files.any(file => {
            ["SKILL.md", "skill.md"].contains(
              json_string(file, "path", default=""),
            )
          }) {
          skills.push({ "id": id, "files": Json::array(files) })
        }
      }
    }
  }
  skills.sort_by((a, b) => {
    json_string(a, "id", default="").compare(json_string(b, "id", default=""))
  })
  {
    "workspace_id": workspace_id,
    "instructions": mooncode_setup_read(@pathx.join(book_root, "AGENTS.md")),
    "instructions_path": "AGENTS.md",
    "skills_path": root,
    "skills": Json::array(skills),
    "integrations": Json::array(mooncode_setup_integrations(book_root)),
    "knowledge": Json::array(
      read_json_array_file(mooncode_knowledge_path(book_root)),
    ),
    "embeddings": mooncode_knowledge_embeddings_public(book_root),
    "presets": Json::array(json_array_items(state, "presets")),
    "templates": Json::array(json_array_items(state, "templates")),
    "history": Json::array(json_array_items(state, "history")),
  }
}

///|
async fn mooncode_setup_apply(
  book_root : String,
  workspace_id : String,
  payload : Json,
) -> Result[Json, String] {
  let state_path = mooncode_setup_path(book_root, workspace_id)
  let current = read_json_file_or_object(state_path)
  let fields = match current {
    Object(fields) => fields
    _ => Map([])
  }
  let action = json_string(payload, "action", default="")
  let history = json_array_items(current, "history")
  let record : Json = match action {
    "save-embeddings" =>
      match mooncode_knowledge_embeddings_save(book_root, payload) {
        Ok(record) => record
        Err(message) => return Err(message)
      }
    "remove-skill" => {
      let id = json_string(payload, "id", default="")
      if !mooncode_setup_relative_file(id) ||
        id.contains("/") ||
        id.has_prefix(".") {
        return Err("Select an installed skill")
      }
      let root = moonsuite_product_artifact_for_workspace_root(
        book_root,
        "moonclaw",
        "skills/" + id,
      )
      let previous = mooncode_setup_files(root, "")
      for file in previous {
        @fs.remove(@pathx.join(root, json_string(file, "path", default="")))
      }
      {
        "kind": "skill",
        "id": id,
        "files": [],
        "previous_files": Json::array(previous),
      }
    }
    "save-integrations" =>
      match mooncode_setup_save_integrations(book_root, payload) {
        Ok(record) => record
        Err(message) => return Err(message)
      }
    "save-skill" => {
      let files = match mooncode_setup_skill_files(payload) {
        Ok(files) => files
        Err(error) => return Err(error)
      }
      let id = json_string(payload, "id", default="")
      let root = moonsuite_product_artifact_for_workspace_root(
        book_root,
        "moonclaw",
        "skills/" + id,
      )
      let previous = mooncode_setup_files(root, "")
      for file in files {
        mooncode_setup_write(
          @pathx.join(root, json_string(file, "path", default="")),
          json_string(file, "content", default=""),
        )
      }
      // A skill save replaces its text file set, so removed support files do not remain active.
      for file in previous {
        let path = json_string(file, "path", default="")
        if !files.any(item => json_string(item, "path", default="") == path) {
          @fs.remove(@pathx.join(root, path))
        }
      }
      {
        "kind": "skill",
        "id": id,
        "files": Json::array(files),
        "previous_files": Json::array(previous),
      }
    }
    "save-instructions" => {
      let content = json_string(payload, "content", default="")
      let path = @pathx.join(book_root, "AGENTS.md")
      let previous = mooncode_setup_read(path)
      mooncode_setup_write(path, content)
      {
        "kind": "instructions",
        "content": content,
        "previous_content": previous,
      }
    }
    "save-presets" => {
      let presets = json_array_items(payload, "presets")
      for preset in presets {
        if json_string(preset, "name", default="").trim().is_empty() ||
          json_string(preset, "model", default="").trim().is_empty() {
          return Err("Each preset needs a name and model")
        }
      }
      let previous = json_array_items(current, "presets")
      fields["presets"] = Json::array(presets)
      {
        "kind": "presets",
        "presets": Json::array(presets),
        "previous": Json::array(previous),
      }
    }
    "save-templates" => {
      let templates = json_array_items(payload, "templates")
      for template in templates {
        if json_string(template, "name", default="").trim().is_empty() ||
          json_string(template, "text", default="").trim().is_empty() {
          return Err("Each prompt needs a name and instructions")
        }
      }
      let previous = json_array_items(current, "templates")
      fields["templates"] = Json::array(templates)
      {
        "kind": "templates",
        "templates": Json::array(templates),
        "previous": Json::array(previous),
      }
    }
    _ => return Err("Choose a setup action")
  }
  let entry = match record {
    Object(values) => values
    _ => Map([])
  }
  entry["saved_at"] = ToJson::to_json(@async.now().to_string())
  history.insert(0, Json::object(entry))
  fields["history"] = Json::array(history)
  mooncode_setup_write(state_path, Json::object(fields).stringify(indent=2))
  Ok(mooncode_setup_snapshot(book_root, workspace_id))
}

///|
async fn handle_mooncode_setup(
  workspace_root : String,
  workspace_id : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let workspace = match find_workspace(workspace_root, workspace_id) {
    Some(workspace) => workspace
    None => {
      send_api_error(
        conn, method_, 404, "Not Found", "Select a MoonBook to set up coding",
      )
      return
    }
  }
  if method_ is Get {
    send_json(
      conn,
      method_,
      mooncode_setup_snapshot(workspace.root_path, workspace_id),
    )
  } else if method_ is Post {
    let payload = match read_json_body(body) {
      Some(payload) => payload
      None => {
        send_api_error(
          conn, method_, 400, "Bad Request", "Invalid setup request",
        )
        return
      }
    }
    mooncode_setup_mutex.acquire()
    defer mooncode_setup_mutex.release()
    if json_string(payload, "action", default="") == "test-integration" {
      handle_mooncode_setup_test_integration(
        workspace_root,
        workspace.root_path,
        payload,
        method_,
        conn,
      )
      return
    }
    match mooncode_setup_apply(workspace.root_path, workspace_id, payload) {
      Ok(snapshot) => send_json(conn, method_, snapshot)
      Err(message) => send_api_error(conn, method_, 400, "Bad Request", message)
    }
  } else {
    send_method_not_allowed_with_methods(conn, method_, ["GET", "POST"])
  }
}

///|
async fn handle_mooncode_presets(
  workspace_root : String,
  workspace_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  if !(method_ is Get) {
    send_method_not_allowed_with_methods(conn, method_, ["GET"])
    return
  }
  let workspace = match find_workspace(workspace_root, workspace_id) {
    Some(workspace) => workspace
    None => {
      send_api_error(conn, method_, 404, "Not Found", "Select a MoonBook")
      return
    }
  }
  let state = read_json_file_or_object(
    mooncode_setup_path(workspace.root_path, workspace_id),
  )
  send_json(conn, method_, Json::array(json_array_items(state, "presets")))
}
