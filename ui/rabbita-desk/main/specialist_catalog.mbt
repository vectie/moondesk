///|
// The specialist needs the current typed Book identity, while the MoonBooks
// shelf remains the only place that lists Books in the local navigation.
priv struct AgentPassportWire {
  contract_id : String
  agent_id : String
  workspace_id : String
  book_id : String
  name : String
  summary : String
  version : String
  status : String
  source_kind : String
  capabilities : Array[String]
  example_tasks : Array[String]
  knowledge_count : Int32
  skill_count : Int32
  schema_count : Int32
  tool_count : Int32
  app_count : Int32
  recurring_work_count : Int32
} derive(FromJson)

///|
priv struct SpecialistAgentCatalogWire {
  agent_count : Int32
  agents : Array[AgentPassportRecord]
} derive(FromJson)

///|
// The complete wire decoder above still checks all original required fields.
// The UI keeps only its consumed projection; metadata is not reserialized.
struct AgentPassportRecord {
  workspace_id : String
  book_id : String
  version : String
  status : String
  source_kind : String
  capabilities : Array[String]
}

///|
pub impl FromJson for AgentPassportRecord with fn from_json(json, path) {
  guard json is Object(_) else {
    raise JsonDecodeError(
      (path, "Expected object to deserialize AgentPassportRecord"),
    )
  }
  let wire : AgentPassportWire = @json.from_json(json, path~)
  let {
    contract_id: _,
    agent_id: _,
    workspace_id,
    book_id,
    name: _,
    summary: _,
    version,
    status,
    source_kind,
    capabilities,
    example_tasks: _,
    knowledge_count: _,
    skill_count: _,
    schema_count: _,
    tool_count: _,
    app_count: _,
    recurring_work_count: _,
  } = wire
  { workspace_id, book_id, version, status, source_kind, capabilities, }
}

///|
struct SpecialistAgentCatalog {
  agents : Array[AgentPassportRecord]
}

///|
pub impl FromJson for SpecialistAgentCatalog with fn from_json(json, path) {
  guard json is Object(_) else {
    raise JsonDecodeError(
      (path, "Expected object to deserialize SpecialistAgentCatalog"),
    )
  }
  let wire : SpecialistAgentCatalogWire = @json.from_json(json, path~)
  let { agent_count: _, agents, } = wire
  { agents, }
}

///|
fn fetch_specialist_catalog_cmd(
  dispatch : Dispatch[Msg],
  scope : String,
) -> @rabbita.Cmd {
  @http.get(@desk.agent_catalog_url()).expect_json(result => {
    dispatch(
      LoadedSpecialistCatalog(
        scope,
        http_result(result, "Invalid specialist Book catalog"),
      ),
    )
  })
}

///|
fn render_specialist_builder_action(dispatch : Dispatch[Msg]) -> @rabbita.Html {
  button(
    class="secondary-button compact-button",
    attrs=@html.Attrs::build().data_set("testid", "build-specialist"),
    on_click=dispatch(workspace_feature_msg("open-specialist")),
    "Build your specialist",
  )
}
