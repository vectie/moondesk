///|
fn work_icon_action(
  dispatch : Dispatch[Msg],
  label : String,
  icon : String,
  message : Msg,
) -> @rabbita.Html {
  button(
    class="moon-icon-button",
    title=label,
    attrs=@html.Attrs::build().aria_label(label),
    on_click=dispatch(message),
    [ui_icon(icon)],
  )
}

///|
fn render_work_book_switcher(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  div(class="title-copy work-book-context", [
    details(
      class="work-book-switcher",
      attrs=@html.Attrs::build().data_set("testid", "work-book-switcher"),
      [
        summary(
          attrs=@html.Attrs::build().aria_label(
            "Current MoonBook: " + workspace_name(model) + ". Switch book",
          ),
          [
            ui_icon("book"),
            span(workspace_name(model)),
            ui_icon("chevron-down"),
          ],
        ),
        div(class="work-book-menu", [
          input(
            class="line-input",
            value=model.moonbook_query,
            placeholder="Find a MoonBook…",
            attrs=@html.Attrs::build().aria_label(
              "Find a MoonBook to switch to",
            ),
            on_input=fn(query) { dispatch(SetMoonBookQuery(query)) },
          ),
          div(
            class="work-book-options",
            matching_moonbooks(model).map(book => {
              button(
                class="work-book-option",
                title=book.name,
                attrs=@html.Attrs::build().aria_pressed(
                  (book.id == model.selected_workspace_id).to_string(),
                ),
                on_click=dispatch(SelectWorkspace(book.id)),
                [ui_icon("book"), span(book.name)],
              )
            }),
          ),
        ]),
      ],
    ),
  ])
}

///|
fn render_work_shortcuts(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  div(
    class="work-shortcuts",
    attrs=@html.Attrs::build().role("toolbar").aria_label("Current work"),
    [
      match model.work_return {
        Some(origin) =>
          work_icon_action(
            dispatch,
            "Back to " + origin.title,
            "chevron-left",
            ReturnToWork,
          )
        None => @html.nothing
      },
      work_icon_action(
        dispatch,
        "Start a task",
        "plus",
        OpenMoonBook(model.selected_workspace_id, StartTask),
      ),
      work_icon_action(
        dispatch,
        "Recent tasks",
        "history",
        workspace_feature_msg("open-toolbox", first="threads"),
      ),
      work_icon_action(
        dispatch,
        "Results",
        "files",
        workspace_feature_msg("open-toolbox", first="results"),
      ),
      details(class="work-tools-menu", [
        summary(
          class="moon-icon-button",
          title="Book tools",
          attrs=@html.Attrs::build().aria_label("Book tools"),
          [ui_icon("more")],
        ),
        div(class="work-tools-options", [
          match model.work_return {
            Some(origin) =>
              button(on_click=dispatch(ReturnToWork), "Back to " + origin.title)
            None => @html.nothing
          },
          button(
            on_click=dispatch(
              workspace_feature_msg("open-toolbox", first="threads"),
            ),
            "Recent tasks",
          ),
          button(
            on_click=dispatch(
              workspace_feature_msg("open-toolbox", first="results"),
            ),
            "Results",
          ),
          button(
            on_click=dispatch(
              workspace_feature_msg("open-toolbox", first="schedules"),
            ),
            "Schedules",
          ),
          button(
            on_click=dispatch(
              workspace_feature_msg("open-toolbox", first="room"),
            ),
            "Book room",
          ),
          button(
            on_click=dispatch(
              workspace_feature_msg("open-toolbox", first="calendar"),
            ),
            "Calendar",
          ),
          button(
            on_click=dispatch(
              workspace_feature_msg("open-toolbox", first="inbox"),
            ),
            "Inbox",
          ),
          button(
            on_click=dispatch(
              workspace_feature_msg("open-toolbox", first="learning"),
            ),
            "Learning",
          ),
          button(
            on_click=dispatch(
              workspace_feature_msg("open-toolbox", first="preferences"),
            ),
            "Preferences",
          ),
        ]),
      ]),
    ],
  )
}
