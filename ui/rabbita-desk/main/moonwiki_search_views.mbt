///|
fn render_search_pane(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  aside(class="explorer-pane", [
    div(class="pane-heading", [
      div([p(class="eyebrow", "cross-book"), h2("Search")]),
      button(
        class="icon-button",
        title="Run Search",
        on_click=dispatch(SearchNow),
        "S",
      ),
    ]),
    section(class="side-section", [
      input(
        class="line-input",
        value=model.search_query,
        placeholder="Find markdown, json, html, logs...",
        on_input=fn(value) { dispatch(SetSearchQuery(value)) },
        "",
      ),
      button(
        class="primary-button full",
        on_click=dispatch(SearchNow),
        "Search Books",
      ),
      p(class="status-line", model.search_status),
    ]),
    div(
      class="search-results",
      model.search_hits.map(hit => {
        button(
          class="search-result",
          title=hit.path,
          on_click=dispatch(SelectSearchHit(hit.workspace_id, hit.path)),
          [
            span(class="record-kind", layer_label(hit.source_layer)),
            strong(hit.title),
            small(
              "\{icon_for_kind(hit.kind)} \{hit.workspace_name} / \{hit.path}",
            ),
            p(hit.snippet),
          ],
        )
      }),
    ),
  ])
}
