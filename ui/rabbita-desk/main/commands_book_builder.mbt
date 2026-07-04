///|
fn create_book_from_pattern_cmd(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Cmd {
  let cadence = clamp_int(
    int_text(model.book_pattern_cadence_minutes, 30),
    1,
    525600,
  )
  let websites = text_lines(model.book_pattern_websites)
  let skill_pack = text_lines(model.book_pattern_skill_pack)
  let notify_on = [
    trimmed_or(model.book_pattern_notify_rule, "accepted_new_knowledge"),
  ]
  let body : Json = {
    "base_type": model.selected_book_base_type,
    "pattern_id": model.selected_book_pattern_id,
    "book_id": trimmed_or(model.book_pattern_book_id, ""),
    "topic": trimmed_or(model.book_pattern_topic, "my domain"),
    "purpose": trimmed_or(model.book_pattern_purpose, ""),
    "websites": json_string_array(websites),
    "cadence_minutes": cadence,
    "source_policy": trimmed_or(model.book_pattern_source_policy, "web-first"),
    "notify_on": json_string_array(notify_on),
    "skill_pack": json_string_array(skill_pack),
    "analysis_method": trimmed_or(
      model.book_pattern_analysis_method,
      "# My Analysis Method\n\nScreen PDFs against the current book baseline and queue Bookkeeper review before accepted knowledge is published.",
    ),
    "notify_rule": trimmed_or(
      model.book_pattern_notify_rule,
      "accepted_new_knowledge",
    ),
    "watch": {
      "cadence_minutes": cadence,
      "source_policy": trimmed_or(model.book_pattern_source_policy, "web-first"),
      "websites": json_string_array(websites),
      "file_types": json_string_array(["pdf"]),
      "dedupe_by": json_string_array(["url", "title", "sha256"]),
    },
    "analysis": {
      "method_page": "wiki/methods/my-analysis-method.md",
      "notify_on": json_string_array(notify_on),
    },
  }
  @http.post(@desk.books_endpoint_url("from-pattern"))
  .with_json(body)
  .expect_json(result => {
    dispatch(
      CreatedBookFromPattern(
        http_result(result, "Could not publish book pattern"),
      ),
    )
  })
}

///|
fn export_app_tool_portable_cmd(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Cmd {
  let body : Json = { "book_id": selected_book_id_for_portable_export(model) }
  @http.post(@desk.books_endpoint_url("app-tool-portable"))
  .with_json(body)
  .expect_json(result => {
    dispatch(
      ExportedAppToolPortable(
        http_result(result, "Could not export portable app-tool bundle"),
      ),
    )
  })
}

///|
fn export_all_app_tool_portable_cmd(dispatch : Dispatch[Msg]) -> @rabbita.Cmd {
  @http.post(@desk.books_endpoint_url("app-tool-portable/all"))
  .with_json(Json::object({}))
  .expect_json(result => {
    dispatch(
      ExportedAllAppToolPortable(
        http_result(result, "Could not export all portable app-tool bundles"),
      ),
    )
  })
}
