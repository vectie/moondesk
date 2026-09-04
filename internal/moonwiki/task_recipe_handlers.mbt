///|
const TaskRecipeInstanceMaxRecords : Int = 512

///|
const TaskRecipeInputMaxChars : Int = 2_000

///|
let task_recipe_write_mutex : @async.Mutex = Mutex()

///|
fn task_recipe_field(
  key : String,
  label : String,
  placeholder : String,
  required : Bool,
) -> Json {
  {
    "key": key,
    "label": label,
    "placeholder": placeholder,
    "required": required,
  }
}

///|
fn task_recipe_catalog_records() -> Array[Json] {
  [
    {
      "contract": "moonsuite.task-recipe.v1",
      "recipe_id": "board-brief",
      "title": "Prepare a board brief",
      "summary": "Turn current evidence into a concise decision-ready report.",
      "deliverable": "A concise board brief with evidence, decisions, risks, and next steps.",
      "fields": [
        task_recipe_field("period", "Reporting period", "Q3 2026", true),
        task_recipe_field(
          "audience", "Audience", "Board and executive team", true,
        ),
        task_recipe_field(
          "source_set", "Use these sources", "Current book and selected document",
          false,
        ),
        task_recipe_field("tone", "Tone", "Direct and decision-oriented", false),
      ],
    },
    {
      "contract": "moonsuite.task-recipe.v1",
      "recipe_id": "document-review",
      "title": "Review a document",
      "summary": "Check a document against a clear goal and risk focus.",
      "deliverable": "A review with prioritized findings and proposed changes shown before saving.",
      "fields": [
        task_recipe_field(
          "review_goal", "Review goal", "What decision should this review support?",
          true,
        ),
        task_recipe_field(
          "risk_focus", "Focus", "Accuracy, completeness, clarity, or specific risks",
          true,
        ),
        task_recipe_field(
          "context", "Context", "Audience, jurisdiction, or constraints", false,
        ),
        task_recipe_field("deadline", "Needed by", "Optional deadline", false),
      ],
    },
    {
      "contract": "moonsuite.task-recipe.v1",
      "recipe_id": "track-topic",
      "title": "Track a topic",
      "summary": "Create a durable watch that reports only material changes.",
      "deliverable": "A source-backed update and a proposed recurring check for confirmation.",
      "fields": [
        task_recipe_field(
          "topic", "Topic", "What should this book watch?", true,
        ),
        task_recipe_field(
          "sources", "Preferred sources", "Sites, files, or publishers", true,
        ),
        task_recipe_field(
          "cadence", "Check frequency", "Daily, weekly, or monthly", true,
        ),
        task_recipe_field(
          "material_change", "Notify when", "What counts as a material change?",
          false,
        ),
      ],
    },
    {
      "contract": "moonsuite.task-recipe.v1",
      "recipe_id": "presentation",
      "title": "Create a presentation",
      "summary": "Shape a presentation around an audience and speaking constraint.",
      "deliverable": "A presentation outline and draft deck ready for review in the document viewer.",
      "fields": [
        task_recipe_field("audience", "Audience", "Who will see this?", true),
        task_recipe_field(
          "duration", "Speaking time", "For example, 15 minutes", true,
        ),
        task_recipe_field(
          "purpose", "Desired outcome", "What should the audience decide or remember?",
          true,
        ),
        task_recipe_field(
          "brand_source", "Style source", "Optional brand or reference deck", false,
        ),
      ],
    },
  ]
}

///|
fn task_recipe_by_id(recipe_id : String) -> Json? {
  for recipe in task_recipe_catalog_records() {
    if json_string(recipe, "recipe_id", default="") == recipe_id {
      return Some(recipe)
    }
  }
  None
}

///|
fn task_recipe_normalize_inputs(
  recipe : Json,
  payload : Json,
) -> Result[Json, String] {
  let submitted = json_object_field_or_empty(payload, "inputs")
  let values : Map[String, Json] = Map([])
  for field in json_array_items(recipe, "fields") {
    let key = json_string(field, "key", default="")
    let value = json_string(submitted, key, default="").trim().to_owned()
    if value.length() > TaskRecipeInputMaxChars ||
      (json_bool(field, "required", default=false) && value == "") {
      return Err("missing_or_invalid_recipe_input:" + key)
    }
    values[key] = value.to_json()
  }
  Ok(Json::object(values))
}

///|
fn task_recipe_prompt(recipe : Json, inputs : Json) -> String {
  let lines : Array[String] = []
  for field in json_array_items(recipe, "fields") {
    let key = json_string(field, "key", default="")
    let value = json_string(inputs, key, default="")
    if value != "" {
      lines.push("- " + json_string(field, "label", default=key) + ": " + value)
    }
  }
  "Use the “" +
  json_string(recipe, "title", default="task") +
  "” recipe for this MoonBook.\n\nBrief:\n" +
  lines.join("\n") +
  "\n\nDeliverable: " +
  json_string(recipe, "deliverable", default="Complete the requested work.") +
  " Use the book and explicitly attached material as context. Ask only for a missing material decision; otherwise begin and keep proposed document changes reviewable before saving."
}

///|
fn task_recipe_instance(
  workspace_id : String,
  recipe : Json,
  inputs : Json,
  now : String,
) -> Json {
  let recipe_id = json_string(recipe, "recipe_id", default="")
  let prompt = task_recipe_prompt(recipe, inputs)
  {
    "contract": "moonsuite.task-recipe-instance.v1",
    "instance_id": @desk.stable_id(
      "task-recipe-instance",
      workspace_id + ":" + recipe_id + ":" + now,
    ),
    "workspace_id": workspace_id,
    "recipe_id": recipe_id,
    "title": json_string(recipe, "title", default="Task"),
    "inputs": inputs,
    "prompt": prompt,
    "status": "ready",
    "created_at": now,
  }
}

///|
fn task_recipe_instances_path(workspace_root : String) -> String {
  moonsuite_product_artifact_for_workspace_root(
    workspace_root, "moondesk", "recipes/instances.v1.json",
  )
}

///|
async fn write_task_recipe_instances(
  workspace_root : String,
  records : Array[Json],
) -> Unit {
  let path = task_recipe_instances_path(workspace_root)
  let parent = @pathx.dirname(path).to_owned()
  @fsx.make_directory(parent, recursive=true, exists_ok=true)
  let content = Json::array(records).stringify(indent=2) + "\n"
  if @fsx.exists(path) {
    if @fsx.read_file(path) == content {
      return
    }
  }
  let temp = @pathx.join(
    parent,
    ".task-recipes." +
    @desk.stable_id("recipe-write", @async.now().to_string()) +
    ".tmp",
  )
  @fs.write_file(
    temp,
    @encoding/utf8.encode(content),
    create_mode=CreateNew,
    permission=0o600,
    sync=Full,
  )
  @fs.rename(temp, path, replace=true)
  @fs.chmod(path, 0o600)
}

///|
async fn create_task_recipe_instance(
  workspace_root : String,
  payload : Json,
  now : String,
) -> Result[Json, String] {
  let workspace_id = json_string(payload, "workspace_id", default="")
    .trim()
    .to_owned()
  let recipe_id = json_string(payload, "recipe_id", default="")
    .trim()
    .to_owned()
  if workspace_id == "" || recipe_id == "" {
    return Err("workspace_and_recipe_required")
  }
  if find_workspace(workspace_root, workspace_id) is None {
    return Err("unknown_workspace")
  }
  let recipe = match task_recipe_by_id(recipe_id) {
    Some(value) => value
    None => return Err("unknown_recipe")
  }
  let inputs = match task_recipe_normalize_inputs(recipe, payload) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let instance = task_recipe_instance(workspace_id, recipe, inputs, now)
  task_recipe_write_mutex.acquire()
  defer task_recipe_write_mutex.release()
  let path = task_recipe_instances_path(workspace_root)
  @fsx.make_directory(
    @pathx.dirname(path).to_owned(),
    recursive=true,
    exists_ok=true,
  )
  let records = read_json_array_file(path)
  let next = [instance] + records
  while next.length() > TaskRecipeInstanceMaxRecords {
    next.pop() |> ignore
  }
  write_task_recipe_instances(workspace_root, next)
  Ok(instance)
}

///|
async fn handle_task_recipe_catalog(
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let recipes = task_recipe_catalog_records()
  send_json(conn, method_, {
    "contract": "moonsuite.task-recipe-catalog.v1",
    "recipe_count": recipes.length(),
    "recipes": Json::array(recipes),
  })
}

///|
async fn handle_create_task_recipe_instance(
  workspace_root : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let payload = match read_json_body(body) {
    Some(value) => value
    None => {
      send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
      return
    }
  }
  match
    create_task_recipe_instance(
      workspace_root,
      payload,
      @async.now().to_string(),
    ) {
    Ok(instance) => send_json(conn, method_, instance)
    Err("unknown_workspace") =>
      send_api_error(conn, method_, 404, "Not Found", "Unknown workspace")
    Err("unknown_recipe") =>
      send_api_error(conn, method_, 404, "Not Found", "Unknown task recipe")
    Err(error) => send_api_error(conn, method_, 400, "Bad Request", error)
  }
}
