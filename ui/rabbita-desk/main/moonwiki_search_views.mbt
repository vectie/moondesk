///|
fn render_search_pane(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  aside(class="activity-pane user-pane", [
    div(class="pane-heading", [
      div([p(class="eyebrow", "All books"), h2("Search")]),
    ]),
    section(class="side-section", [
      input(
        class="line-input",
        value=model.search_query,
        placeholder="Search pages, notes, and sources",
        on_input=fn(value) { dispatch(SetSearchQuery(value)) },
      ),
      button(
        class="primary-button full",
        on_click=dispatch(SearchNow),
        "Search",
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
            strong(hit.title),
            small("\{hit.workspace_name} | \{wiki_search_type_label(hit)}"),
            p(hit.snippet),
          ],
        )
      }),
    ),
  ])
}
