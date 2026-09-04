///|
struct AgentPassportInventory {
  knowledge_count : Int
  skill_count : Int
  schema_count : Int
  tool_count : Int
  app_count : Int
  recurring_work_count : Int
} derive(Debug, Eq)

///|
fn agent_passport_capabilities(
  inventory : AgentPassportInventory,
) -> Array[String] {
  let values : Array[String] = []
  if inventory.knowledge_count > 0 {
    values.push("Evidence-backed answers")
  }
  if inventory.skill_count > 0 {
    values.push("Reviewed procedures")
  }
  if inventory.schema_count > 0 {
    values.push("Structured briefs")
  }
  if inventory.tool_count > 0 {
    values.push("Connected tools")
  }
  if inventory.app_count > 0 {
    values.push("Interactive workspace")
  }
  if inventory.recurring_work_count > 0 {
    values.push("Recurring work")
  }
  values
}

///|
fn agent_passport_example_tasks(
  declared : Array[String],
  inventory : AgentPassportInventory,
) -> Array[String] {
  if !declared.is_empty() {
    return declared[:declared.length().min(3)].to_owned()
  }
  let values : Array[String] = []
  if inventory.knowledge_count > 0 {
    values.push("Answer questions using this book's evidence")
  }
  if inventory.skill_count > 0 {
    values.push("Apply its reviewed ways of working")
  }
  if inventory.recurring_work_count > 0 {
    values.push("Continue its scheduled background work")
  }
  if values.is_empty() {
    values.push("Work with this MoonBook in chat")
  }
  values
}

///|
fn agent_passport_projection(
  workspace : @desk.DeskWorkspace,
  book_id : String,
  summary : String,
  version : String,
  declared_tasks : Array[String],
  inventory : AgentPassportInventory,
) -> Json {
  let capabilities = agent_passport_capabilities(inventory)
  let tasks = agent_passport_example_tasks(declared_tasks, inventory)
  {
    "contract_id": "moonsuite.agent-passport.v1",
    "agent_id": workspace.id,
    "workspace_id": workspace.id,
    "book_id": book_id,
    "name": workspace.name,
    "summary": if summary == "" {
      "A reusable agent shaped by this MoonBook's knowledge and ways of working."
    } else {
      summary
    },
    "version": if version == "" {
      "local"
    } else {
      version
    },
    "status": match workspace.status {
      Ready => "ready"
      NeedsAttention => "needs_attention"
      Missing => "missing"
      Unknown => "unknown"
    },
    "source_kind": "moonbook",
    "capabilities": json_from_string_array(capabilities),
    "example_tasks": json_from_string_array(tasks),
    "knowledge_count": inventory.knowledge_count,
    "skill_count": inventory.skill_count,
    "schema_count": inventory.schema_count,
    "tool_count": inventory.tool_count,
    "app_count": inventory.app_count,
    "recurring_work_count": inventory.recurring_work_count,
  }
}

///|
async fn agent_directory_item_count(root : String, child : String) -> Int {
  read_directory_names(@pathx.join(root, child), include_hidden=false).length()
}

///|
async fn agent_passport_inventory(book_root : String) -> AgentPassportInventory {
  {
    knowledge_count: agent_directory_item_count(book_root, "wiki") +
    agent_directory_item_count(book_root, "raw"),
    skill_count: agent_directory_item_count(book_root, "skills"),
    schema_count: agent_directory_item_count(book_root, "schemas"),
    tool_count: agent_directory_item_count(book_root, "tools"),
    app_count: agent_directory_item_count(book_root, "apps") +
    agent_directory_item_count(book_root, "app"),
    recurring_work_count: agent_directory_item_count(book_root, "automations") +
    agent_directory_item_count(book_root, "watchers"),
  }
}

///|
async fn installed_agent_catalog(workspace_root : String) -> Json {
  let agents : Array[Json] = []
  let workspaces = discover_workspaces(workspace_root)
  for workspace in workspaces {
    let metadata = moonbook_metadata(workspace.root_path).unwrap_or(
      Json::object({}),
    )
    let declared_book_id = json_string(metadata, "book_id", default="")
      .trim()
      .to_owned()
    let fallback_id = json_string(metadata, "id", default="").trim().to_owned()
    let book_id = if declared_book_id != "" {
      declared_book_id
    } else if fallback_id != "" {
      fallback_id
    } else {
      workspace.id
    }
    let summary = json_string(
        metadata,
        "summary",
        default=json_string(metadata, "description", default=""),
      )
      .trim()
      .to_owned()
    agents.push(
      agent_passport_projection(
        workspace,
        book_id,
        summary,
        json_string(metadata, "version", default="").trim().to_owned(),
        json_string_array_items(metadata, "example_tasks"),
        agent_passport_inventory(workspace.root_path),
      ),
    )
  }
  api_contract_response(
    {
      "contract_id": "moonsuite.agent-catalog.v1",
      "agent_count": agents.length(),
      "agents": Json::array(agents),
    },
    ok=true,
    status="ready",
    message=if agents.is_empty() {
      "Create or import a MoonBook to make your first agent"
    } else {
      "Installed MoonBook agents are ready"
    },
    next_action=if agents.is_empty() {
      "create_moonbook"
    } else {
      "choose_agent"
    },
  )
}
