///|
fn render_portable_book(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  let state = model.portable_book
  let busy = state.pending is Some(_)
  let bound = state.active &&
    state.workspace == model.selected_workspace_id &&
    state.library == model.workspace_library_path
  let book_name = model.workspaces
    .filter(workspace => workspace.id == model.selected_workspace_id)
    .get(0)
    .map(workspace => workspace.name)
    .unwrap_or(model.selected_workspace_id)
  section(
    class="side-section portable-book-export",
    style=["overflow-wrap: anywhere"],
    attrs=@html.Attrs::build()
      .data_set("testid", "portable-book-export")
      .aria_label("Local experienced Book package"),
    [
      h2("Experienced Book package"),
      p(
        "Prepare a local portable agent package with this Book’s accepted knowledge, learning and explicitly selected additional files. Inspect the complete package before downloading.",
      ),
      if model.selected_workspace_id == "" {
        p("Choose a Book to prepare or inspect its local packages.")
      } else if !bound {
        p("Waiting for the selected Book’s local export capability.")
      } else {
        div([
          strong("Selected Book: " + book_name),
          p(class="status-line", "Book ID: " + state.workspace),
          div(class="section-heading-row", [
            button(
              class="secondary-button compact-button",
              disabled=busy,
              attrs=@html.Attrs::build().data_set(
                "testid", "portable-book-refresh",
              ),
              on_click=dispatch(PortableBook(RefreshCatalog)),
              "Refresh local packages",
            ),
            if state.loaded {
              p(
                if state.available {
                  "Local preparation available"
                } else {
                  "Local preparation unavailable"
                },
              )
            } else {
              @html.nothing
            },
          ]),
          if state.capability_message == "" {
            @html.nothing
          } else {
            p(state.capability_message)
          },
          @html.label([
            span("Package version"),
            input(
              class="line-input",
              value=state.version,
              placeholder="For example, 1.0.0",
              maxlength=64,
              attrs=@html.Attrs::build()
                .aria_label("Experienced Book package version")
                .disabled(portable_book_inputs_locked(state))
                .data_set("testid", "portable-book-version"),
              on_input=value => dispatch(PortableBook(SetVersion(value))),
            ),
          ]),
          render_portable_book_picker(dispatch, state),
          render_portable_book_human_result_picker(dispatch, state),
          p(
            attrs=@html.Attrs::build().data_set(
              "testid", "portable-book-source-notice",
            ),
            "Prepare runs the existing pack operation. It may normalize wiki metadata, add missing provenance links, refresh generated pages and projections, and create missing keeper files. Viewing, refreshing, inspecting and downloading do not pack the Book.",
          ),
          button(
            class="primary-button",
            disabled=!portable_book_can_prepare(state),
            attrs=@html.Attrs::build().data_set(
              "testid", "portable-book-prepare",
            ),
            on_click=prepare_portable_book_click(dispatch),
            "Prepare local package",
          ),
          div(attrs=@html.Attrs::build().role("status").aria_live("polite"), [
            match state.pending {
              Some({ operation: PreparePackage(_), .. }) =>
                p("Preparing local package…")
              Some({ operation: InspectPackage(_), .. }) =>
                p("Inspecting saved package…")
              Some({ operation: Entries(_), .. }) => p("Reading this folder…")
              Some({ operation: ChooseHumanResult, .. }) =>
                p("Choosing and checking the accepted human result…")
              Some({ operation: Catalog, .. }) =>
                p("Reading local package capability and saved packages…")
              None => @html.nothing
            },
            if state.notice == "" {
              @html.nothing
            } else {
              p(state.notice)
            },
            if state.error == "" {
              @html.nothing
            } else {
              p(class="status-line", state.error)
            },
          ]),
          if state.operation_id == "" {
            @html.nothing
          } else {
            div([
              p("Preparation ID: " + state.operation_id),
              button(
                class="secondary-button",
                disabled=busy,
                attrs=@html.Attrs::build().data_set(
                  "testid", "portable-book-check",
                ),
                on_click=dispatch(PortableBook(CheckPreparation)),
                "Check saved package",
              ),
              if state.prepared is Some(_) || state.recovery_checked {
                button(
                  class="secondary-button",
                  disabled=busy,
                  attrs=@html.Attrs::build().data_set(
                    "testid", "portable-book-new",
                  ),
                  on_click=dispatch(PortableBook(StartNewPreparation)),
                  "Start a new preparation",
                )
              } else {
                @html.nothing
              },
              p(
                "Checking is read-only. Starting a new preparation keeps any earlier package and requires another explicit Prepare.",
              ),
            ])
          },
          match state.prepared {
            Some(prepared) =>
              render_portable_book_inspection(
                prepared,
                !busy && state.error == "",
              )
            None => @html.nothing
          },
          details(class="technical-details", [
            summary("Saved local packages (\{state.exports.length()})"),
            if state.loaded && state.exports.is_empty() {
              p("No saved local packages were reported.")
            } else {
              @html.nothing
            },
            @html.fragment(
              state.exports.map(item => {
                div([
                  p(
                    "Version " +
                    item.version +
                    " · \{item.package_size_bytes} bytes",
                  ),
                  p("SHA-256: " + item.package_sha256),
                  button(
                    class="secondary-button compact-button",
                    disabled=portable_book_inputs_locked(state),
                    on_click=dispatch(
                      PortableBook(InspectSaved(item.export_id)),
                    ),
                    "Inspect " + item.export_id,
                  ),
                ])
              }),
            ),
          ]),
        ])
      },
    ],
  )
}

///|
fn render_portable_book_picker(
  dispatch : Dispatch[Msg],
  state : PortableBookState,
) -> @rabbita.Html {
  let busy = state.pending is Some(_)
  let locked = portable_book_inputs_locked(state)
  details(class="technical-details", [
    summary("Additional regular files (\{state.paths.length()} selected)"),
    p(
      "No additional files are preselected. The standard package also includes accepted Book content; the full included-member list appears after preparation. Choose individual files, not folders. The host validates each selection as a regular file within this Book.",
    ),
    if state.paths.is_empty() {
      p("No additional files selected.")
    } else {
      ul(
        state.paths.map(path => {
          li([
            span(path),
            button(
              class="secondary-button compact-button",
              disabled=locked,
              on_click=dispatch(PortableBook(RemoveFile(path))),
              "Remove " + path,
            ),
          ])
        }),
      )
    },
    p("Folder: " + (if state.directory == "" { "/" } else { state.directory })),
    div(class="section-heading-row", [
      button(
        class="secondary-button compact-button",
        disabled=busy,
        on_click=dispatch(PortableBook(BrowseFiles(""))),
        "Book root",
      ),
      if state.directory == "" {
        @html.nothing
      } else {
        button(
          class="secondary-button compact-button",
          disabled=busy,
          on_click=dispatch(
            PortableBook(BrowseFiles(parent_path(state.directory))),
          ),
          "Parent folder",
        )
      },
      button(
        class="secondary-button compact-button",
        disabled=busy,
        attrs=@html.Attrs::build().data_set("testid", "portable-book-browse"),
        on_click=dispatch(PortableBook(BrowseFiles(state.directory))),
        "Read this folder",
      ),
    ]),
    if state.entries_loaded && state.entries.is_empty() {
      p("This folder has no listed files.")
    } else {
      @html.nothing
    },
    ul(
      state.entries.map(entry => {
        li([
          if entry.kind == Directory {
            button(
              class="secondary-button compact-button",
              disabled=busy,
              on_click=dispatch(PortableBook(BrowseFiles(entry.path))),
              "Open folder: " + entry.display_name,
            )
          } else {
            button(
              class=if state.paths.contains(entry.path) {
                "option-chip active"
              } else {
                "option-chip"
              },
              disabled=locked || !entry.readable,
              attrs=@html.Attrs::build()
                .aria_pressed(
                  if state.paths.contains(entry.path) {
                    "true"
                  } else {
                    "false"
                  },
                )
                .data_set("testid", "portable-book-file"),
              on_click=dispatch(PortableBook(ToggleFile(entry.path))),
              (if state.paths.contains(entry.path) {
                "Selected: "
              } else {
                "Add: "
              }) +
              entry.display_name,
            )
          },
          small(" " + entry.path),
        ])
      }),
    ),
  ])
}

///|
fn render_portable_book_inspection(
  prepared : PortableBookPrepared,
  allow_download : Bool,
) -> @rabbita.Html {
  let inspection = prepared.inspection
  let private_count = inspection.files
    .filter(file => file.sensitivity == "user-private")
    .length()
  section(
    class="surface-state-panel",
    attrs=@html.Attrs::build().data_set("testid", "portable-book-inspection"),
    [
      h3("Complete prepared package"),
      p("Agent: " + inspection.agent_id + " · Version: " + inspection.version),
      p("Book revision: " + inspection.book_revision),
      p("Package: " + prepared.path),
      p("Serialized package size: \{prepared.source.package_size_bytes} bytes"),
      p("Package SHA-256: " + prepared.source.package_sha256),
      p("Bundle digest: " + inspection.bundle_digest),
      p(
        "Verified members: \{inspection.file_count} · Decoded bytes: \{inspection.total_bytes}",
      ),
      if private_count > 0 {
        div(
          class="quiet-empty-state",
          attrs=@html.Attrs::build()
            .role("alert")
            .data_set("testid", "portable-book-private-warning"),
          [
            strong("Contains user-private content: \{private_count} member(s)"),
            p(
              "Review the user-private members below before downloading or sharing this package.",
            ),
          ],
        )
      } else {
        p("No included member is marked user-private in this inspection.")
      },
      h3("All included members (\{inspection.files.length()})"),
      ul(
        inspection.files.map(file => {
          li(
            attrs=@html.Attrs::build()
              .data_set("testid", "portable-book-member")
              .data_set("sensitivity", file.sensitivity),
            [
              strong(file.path),
              if file.sensitivity == "user-private" {
                strong(" · USER-PRIVATE")
              } else {
                @html.nothing
              },
              p(
                "Role: " +
                file.role +
                " · Sensitivity: " +
                file.sensitivity +
                " · Review status: " +
                file.review_status,
              ),
              p("Size: \{file.size_bytes} bytes · Digest: " + file.digest),
            ],
          )
        }),
      ),
      h3("All exclusions (\{inspection.exclusions.length()})"),
      if inspection.exclusions.is_empty() {
        p("No exclusions were reported.")
      } else {
        ul(
          inspection.exclusions.map(item => {
            li(
              attrs=@html.Attrs::build().data_set(
                "testid", "portable-book-exclusion",
              ),
              [strong(item.path), p(item.reason)],
            )
          }),
        )
      },
      details(class="technical-details", [
        summary("Package policy and compatibility"),
        p("Contract: " + inspection.contract),
        h3("Export policy"),
        pre(inspection.export_policy.stringify(indent=2)),
        h3("Compatibility"),
        pre(inspection.compatibility.stringify(indent=2)),
        h3("Memory policy"),
        pre(inspection.memory_policy.stringify(indent=2)),
        h3("Memory metrics"),
        pre(inspection.memory_metrics.stringify(indent=2)),
      ]),
      if allow_download {
        a(
          class="primary-button",
          href=portable_book_download_url(prepared),
          download="",
          attrs=@html.Attrs::build()
            .data_set("testid", "portable-book-download")
            .data_set("package-sha256", prepared.source.package_sha256),
          "Download this exact package",
        )
      } else {
        p("Check the saved package successfully before downloading.")
      },
      p(
        "Download is bound to the inspected package SHA-256. If the saved bytes change, the host rejects the stale download.",
      ),
    ],
  )
}
