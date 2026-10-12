///|
fn render_portable_book_groups(
  dispatch : Dispatch[Msg],
  state : PortableBookState,
) -> @rabbita.Html {
  let locked = portable_book_inputs_locked(state)
  section(
    attrs=@html.Attrs::build()
      .data_set("testid", "portable-book-groups")
      .aria_label("Named deliverables"),
    [
      h3("Named deliverables"),
      p(
        "Keep a report with its images or an app with its assets together. In Choose files, browse to the deliverable’s folder, then name it here. Add each file explicitly; its path relative to that folder is preserved.",
      ),
      p(
        "New deliverable folder: " +
        (if state.directory == "" { "Book root" } else { state.directory }),
      ),
      @html.label([
        span("Deliverable name"),
        input(
          class="line-input",
          value=state.group_name,
          maxlength=120,
          placeholder="For example, Customer report or Demo app",
          attrs=@html.Attrs::build()
            .disabled(locked)
            .aria_label("New deliverable name"),
          on_input=value => {
            dispatch(PortableBook(OutputGroup(NameNewGroup(value))))
          },
        ),
      ]),
      button(
        class="secondary-button",
        disabled=locked ||
          state.group_name.trim().is_empty() ||
          state.output_groups.length() >= 16,
        on_click=dispatch(PortableBook(OutputGroup(AddGroup))),
        "Add named deliverable",
      ),
      p(
        "Unprepared selections stay in this tab. After reloading, inspect a saved package below. Preview and app entrypoint are descriptive file references; this does not run an app.",
      ),
      @html.fragment(
        state.output_groups.map(group => {
          section(
            class="surface-state-panel",
            attrs=@html.Attrs::build()
              .data_set("testid", "portable-book-group")
              .data_set("group-id", group.artifact_id),
            [
              @html.label([
                span("Name"),
                input(
                  class="line-input",
                  value=group.label,
                  maxlength=120,
                  attrs=@html.Attrs::build()
                    .disabled(locked)
                    .aria_label("Deliverable name " + group.artifact_id),
                  on_input=value => {
                    dispatch(
                      PortableBook(
                        OutputGroup(RenameGroup(group.artifact_id, value)),
                      ),
                    )
                  },
                ),
              ]),
              p(
                "Layout root: " +
                (if group.root == "" { "Book root" } else { group.root }),
              ),
              button(
                class="secondary-button compact-button",
                disabled=locked,
                attrs=@html.Attrs::build().aria_pressed(
                  if state.selected_group == group.artifact_id {
                    "true"
                  } else {
                    "false"
                  },
                ),
                on_click=dispatch(
                  PortableBook(OutputGroup(SelectGroup(group.artifact_id))),
                ),
                if state.selected_group == group.artifact_id {
                  "Adding files to this deliverable"
                } else {
                  "Choose this deliverable for files"
                },
              ),
              button(
                class="secondary-button compact-button",
                disabled=locked,
                on_click=dispatch(PortableBook(BrowseFiles(group.root))),
                "Browse its folder",
              ),
              button(
                class="secondary-button compact-button",
                disabled=locked,
                on_click=dispatch(
                  PortableBook(OutputGroup(RemoveGroup(group.artifact_id))),
                ),
                "Remove deliverable",
              ),
              if group.files.is_empty() {
                p(
                  "Choose at least one file below, or remove this empty deliverable before preparing.",
                )
              } else {
                @html.nothing
              },
              ul(
                group.files.map(file => {
                  li(
                    attrs=@html.Attrs::build().data_set(
                      "testid", "portable-book-group-member",
                    ),
                    [
                      strong(file.path),
                      small(" · Book source: " + file.source_path),
                      div([
                        button(
                          class="secondary-button compact-button",
                          disabled=locked,
                          attrs=@html.Attrs::build().aria_pressed(
                            if group.preview_path == Some(file.path) {
                              "true"
                            } else {
                              "false"
                            },
                          ),
                          on_click=dispatch(
                            PortableBook(
                              OutputGroup(
                                ChooseGroupPreview(group.artifact_id, file.path),
                              ),
                            ),
                          ),
                          if group.preview_path == Some(file.path) {
                            "Preview selected · clear"
                          } else {
                            "Choose as preview"
                          },
                        ),
                        button(
                          class="secondary-button compact-button",
                          disabled=locked,
                          attrs=@html.Attrs::build().aria_pressed(
                            if group.app_entrypoint == Some(file.path) {
                              "true"
                            } else {
                              "false"
                            },
                          ),
                          on_click=dispatch(
                            PortableBook(
                              OutputGroup(
                                ChooseGroupEntrypoint(
                                  group.artifact_id,
                                  file.path,
                                ),
                              ),
                            ),
                          ),
                          if group.app_entrypoint == Some(file.path) {
                            "App entrypoint selected · clear"
                          } else {
                            "Choose as app entrypoint"
                          },
                        ),
                        button(
                          class="secondary-button compact-button",
                          disabled=locked,
                          on_click=dispatch(
                            PortableBook(
                              OutputGroup(
                                RemoveGroupFile(
                                  group.artifact_id,
                                  file.source_path,
                                ),
                              ),
                            ),
                          ),
                          "Remove file",
                        ),
                      ]),
                    ],
                  )
                }),
              ),
            ],
          )
        }),
      ),
    ],
  )
}

///|
fn render_portable_group_add_file(
  dispatch : Dispatch[Msg],
  state : PortableBookState,
  entry : @desk.DeskFileEntry,
) -> @rabbita.Html {
  guard state.output_groups
    .filter(group => group.artifact_id == state.selected_group)
    .get(0)
    is Some(group) else {
    return @html.nothing
  }
  let selected = group.files.any(file => file.source_path == entry.path)
  let relative = portable_book_group_relative(group, entry.path)
  button(
    class=if selected { "option-chip active" } else { "option-chip" },
    disabled=portable_book_inputs_locked(state) ||
      !entry.readable ||
      relative is None ||
      (!selected && portable_book_group_count(state) >= 128),
    attrs=@html.Attrs::build()
      .data_set("testid", "portable-book-group-file")
      .aria_pressed(if selected { "true" } else { "false" }),
    on_click=dispatch(PortableBook(OutputGroup(ToggleGroupFile(entry.path)))),
    if relative is None {
      "Outside " + group.label + " folder"
    } else if selected {
      "In " + group.label + ": " + relative.unwrap()
    } else {
      "Add to " + group.label + ": " + relative.unwrap()
    },
  )
}
