///|
fn render_search_state_panel(
  state : SurfaceState,
  error? : String = "",
) -> @rabbita.Html {
  section(
    class="surface-state-panel",
    attrs=@html.Attrs::build()
      .data_set("state", surface_state_key(state))
      .data_set("testid", "pages-search-state"),
    [
      render_polite_state_announcement(
        "pages-search-state-announcement",
        pages_search_state_title(state),
        pages_search_state_detail(state),
      ),
      match pages_search_state_technical_detail(state) {
        Some(detail) =>
          details(class="technical-details", [
            summary("Technical details"),
            p(detail),
            if error == "" {
              @html.nothing
            } else {
              p(error)
            },
          ])
        None => @html.nothing
      },
    ],
  )
}

///|
fn search_action_label(state : SurfaceState?) -> String {
  match state {
    Some(surface_state) =>
      match pages_search_state_primary_action(surface_state) {
        Some(label) => label
        None => "Search"
      }
    None => "Search"
  }
}

///|
fn render_search_pane(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  aside(
    class="activity-pane user-pane",
    attrs=@html.Attrs::build().aria_label("Book search"),
    [
      div(class="pane-heading", [
        div([p(class="eyebrow", "All books"), h2("Search")]),
      ]),
      section(class="side-section", [
        input(
          class="line-input",
          value=model.pages_search.query,
          placeholder="Search pages, notes, and sources",
          on_input=fn(value) { dispatch(SetSearchQuery(value)) },
        ),
        button(
          class="primary-button full",
          attrs=@html.Attrs::build().data_set(
            "testid", "pages-search-state-action",
          ),
          disabled=model.pages_search.surface is Some(Loading),
          on_click=dispatch(SearchNow),
          search_action_label(model.pages_search.surface),
        ),
        p(class="status-line", model.pages_search.status),
      ]),
      match model.pages_search.surface {
        Some(state) =>
          render_search_state_panel(state, error=model.pages_search.error)
        None => @html.nothing
      },
      if model.pages_search.hits.is_empty() {
        @html.nothing
      } else {
        div(
          class="search-results",
          model.pages_search.hits.map(hit => {
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
        )
      },
    ],
  )
}
