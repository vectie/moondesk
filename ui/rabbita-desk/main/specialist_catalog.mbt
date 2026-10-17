///|
// The specialist needs the current typed Book identity, while the MoonBooks
// shelf remains the only place that lists Books in the local navigation.
struct AgentPassportRecord {
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
  knowledge_count : Int
  skill_count : Int
  schema_count : Int
  tool_count : Int
  app_count : Int
  recurring_work_count : Int
} derive(FromJson)

///|
struct SpecialistAgentCatalog {
  agent_count : Int
  agents : Array[AgentPassportRecord]
} derive(FromJson)

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
