///|
fn wiki_chat_submission_body(model : Model) -> Json {
  {
    "workspace_id": model.selected_workspace_id,
    "task_id": model.wiki_agent_task_id,
    "document_path": if wiki_document_path_supported(model.selected_path) {
      model.selected_path
    } else {
      ""
    },
    "file_paths": Json::array(
      model.wiki_chat_file_paths.map(path => Json::string(path)),
    ),
    "context_items": Json::array(
      model.wiki_chat_context_items.map(item => item.to_json()),
    ),
    "message": model.request_prompt.trim().to_owned(),
  }
}

///|
fn submit_wiki_chat_cmd(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Cmd {
  let submitted_message = model.request_prompt.trim().to_owned()
  @http.post(@desk.moonclaw_endpoint_url("chat"))
  .with_json(wiki_chat_submission_body(model))
  .expect_json(result => {
    dispatch(
      SubmittedWikiChat(
        submitted_message,
        http_result(result, "Could not send this message"),
      ),
    )
  })
}

///|
/// Search the existing workspace index. This is intentionally a read-only
/// lookup: selecting a result attaches its workspace-relative path and never
/// copies or imports bytes into the book.
fn wiki_chat_file_search_cmd(
  dispatch : Dispatch[Msg],
  generation : Int,
  query : String,
  workspace_id : String,
) -> @rabbita.Cmd {
  @http.get(
    @desk.search_url(query) +
    "&" +
    @desk.desktop_api_query([
      ("contract", "pages-search.v1"),
      ("workspace", workspace_id),
      ("mode", "files"),
    ]),
  ).expect_json(result => {
    dispatch(
      LoadedWikiChatFileSearch(
        generation,
        http_result(result, "The workspace search could not be read"),
      ),
    )
  })
}
