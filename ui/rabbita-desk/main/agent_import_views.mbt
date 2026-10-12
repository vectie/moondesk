///|
fn render_agent_import(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  let state = model.agent_import
  let session = state.session
  let busy = state.pending is Some(_)
  let ready = agent_import_ready(state) &&
    session.library == model.workspace_library_path
  section(
    class="desk-library-action agent-package-import",
    style=["overflow-wrap: anywhere"],
    attrs=@html.Attrs::build()
      .data_set("testid", "agent-package-import")
      .aria_label("Import experienced Book package"),
    [
      h3("Import a Book package"),
      p(
        "Choose a .moonbook-agent file, inspect its contents, then import into a new folder in this library.",
      ),
      if session.reply is None &&
        !session.import_started &&
        state.package_file is None {
        div([
          button(
            class="primary-button full",
            attrs=@html.Attrs::build().data_set("testid", "agent-import-choose"),
            disabled=!ready,
            on_click=choose_agent_package_click(dispatch),
            "1. Choose package",
          ),
          button(
            class="secondary-button full",
            attrs=@html.Attrs::build().data_set(
              "testid", "agent-import-choose-exact",
            ),
            disabled=!ready,
            on_click=choose_agent_package_click(dispatch, exact=true),
            "Choose a package received through Town",
          ),
          p(
            "For a Town package, keep the original .binding.json saved with the download. You will select both files. Desk checks the existing binding; it does not create one or sign its publisher identity.",
          ),
        ])
      } else {
        @html.nothing
      },
      div(attrs=@html.Attrs::build().role("status").aria_live("polite"), [
        match state.pending {
          Some({ operation: PickingPackage, .. }) =>
            p("Choose a package from your computer…")
          Some({ operation: PickingBinding, .. }) =>
            p("Choose the original Town binding file…")
          Some({ operation: StagingPackage, .. }) =>
            p("Inspecting package contents…")
          Some({ operation: ImportingPackage, .. }) =>
            p("Importing and checking every included file…")
          Some({ operation: CheckingImport, .. }) =>
            p("Checking the retained operation…")
          Some({ operation: CheckingBeforeOpen, .. }) =>
            p("Checking the imported Book before opening…")
          None => @html.nothing
        },
        if session.error != "" {
          p(
            class="status-line",
            attrs=@html.Attrs::build()
              .role("alert")
              .data_set("testid", "agent-import-error"),
            session.error,
          )
        } else {
          @html.nothing
        },
        match session.reply {
          Some(reply) if session.status == "inspected" && reply.message != "" =>
            p(reply.message)
          _ => @html.nothing
        },
      ]),
      if session.status == "awaiting-binding" {
        div([
          p("Selected package: " + session.filename),
          p(
            "Now choose its original Town .binding.json. The separate .receipt.json records transfer bytes and cannot replace the binding. If you only have a local export, cancel and use Choose package.",
          ),
          button(
            class="primary-button full",
            attrs=@html.Attrs::build().data_set(
              "testid", "agent-import-choose-binding",
            ),
            disabled=!ready,
            on_click=dispatch(AgentImport(ChooseBinding)),
            "Choose matching Town binding and inspect",
          ),
          p(
            "Both selected files are sent only to this Desk host for local inspection. Selection does not import a Book, share it through Town, or run agent work. File selections before inspection are kept only in this tab.",
          ),
        ])
      } else {
        @html.nothing
      },
      if session.status == "imported" {
        div([
          strong(
            "Book imported. Every included file matches the inspected package.",
          ),
          p("Folder: " + session.destination),
          if session.exact_required {
            p(
              "The original Town source binding was retained and every included file was checked. In Town, refresh Imported outputs for this same Book library or catalog. This does not upload or publish the Book.",
            )
          } else {
            @html.nothing
          },
          button(
            class="primary-button full",
            attrs=@html.Attrs::build().data_set("testid", "agent-import-open"),
            disabled=!ready,
            on_click=dispatch(AgentImport(OpenImportedPackage)),
            "Open Book",
          ),
        ])
      } else if session.status == "uncertain" ||
        session.status == "partial" ||
        (session.status == "importing" && !busy) {
        div([
          strong(
            if session.status == "partial" {
              "The Book is incomplete. It has not been opened."
            } else if !session.import_started {
              "The package inspection needs checking."
            } else {
              "The import outcome needs checking."
            },
          ),
          p(
            "Check the saved operation before continuing. Checking will not start another import.",
          ),
          button(
            class="primary-button full",
            attrs=@html.Attrs::build().data_set("testid", "agent-import-check"),
            disabled=!ready,
            on_click=dispatch(AgentImport(CheckImport)),
            if session.import_started {
              "Check import"
            } else {
              "Check inspection"
            },
          ),
          if session.import_started {
            button(
              class="secondary-button full",
              attrs=@html.Attrs::build().data_set(
                "testid", "agent-import-keep-attempt",
              ),
              disabled=!ready,
              on_click=dispatch(AgentImport(KeepAttemptAndStartNew)),
              "Keep this attempt and start another",
            )
          } else {
            @html.nothing
          },
        ])
      } else {
        @html.nothing
      },
      match session.reply {
        Some(reply) => render_agent_import_inspection(reply)
        None => @html.nothing
      },
      if session.status == "inspected" && !session.import_started {
        div([
          h3("3. Choose a new folder"),
          p("Active library: " + session.library),
          @html.label([
            span("New folder name"),
            input(
              class="line-input",
              value=session.destination,
              placeholder="For example, field-notes",
              maxlength=80,
              attrs=@html.Attrs::build()
                .aria_label("New Book folder name")
                .disabled(!ready)
                .data_set("testid", "agent-import-destination"),
              on_input=value => {
                dispatch(AgentImport(SetImportDestination(value)))
              },
            ),
          ]),
          p(
            "Start with a letter or number; use up to 80 letters, numbers, hyphens or underscores. Existing folders are never replaced. Included Book metadata and files are preserved.",
          ),
          button(
            class="primary-button full",
            attrs=@html.Attrs::build().data_set("testid", "agent-import-submit"),
            disabled=!agent_import_can_write(state),
            on_click=dispatch(AgentImport(ImportInspectedPackage)),
            "4. Import into this library",
          ),
        ])
      } else {
        @html.nothing
      },
      if session.operation_id != "" &&
        (!session.import_started || session.status == "imported") {
        button(
          class="secondary-button full",
          attrs=@html.Attrs::build().data_set("testid", "agent-import-cancel"),
          on_click=dispatch(AgentImport(CancelPackage)),
          if session.status == "imported" {
            "Import another package"
          } else {
            "Cancel selection"
          },
        )
      } else {
        @html.nothing
      },
      if session.operation_id == "" {
        @html.nothing
      } else {
        details(class="technical-details", [
          summary("Technical details"),
          p("Operation: " + session.operation_id),
          p("Library: " + session.library),
          p("Package: " + session.filename),
          p("Status: " + session.status),
          match session.reply {
            Some(reply) =>
              div([
                p("Package SHA-256: " + reply.source.package_sha256),
                p("Bundle digest: " + reply.source.bundle_digest),
                p("Book revision: " + reply.source.book_revision),
                p("Serialized size: \{reply.source.package_size_bytes} bytes"),
              ])
            None => @html.nothing
          },
        ])
      },
      if state.suspended.any(item => item.library == session.library) {
        div([
          h3("Earlier package attempts"),
          p(
            "These attempts and their folders are retained. Selecting one only opens its recovery controls.",
          ),
          ul(
            state.suspended
            .filter(item => item.library == session.library)
            .map(item => {
              li([
                p(
                  item.filename +
                  (if item.destination == "" {
                    ""
                  } else {
                    " → " + item.destination
                  }),
                ),
                button(
                  class="secondary-button full",
                  disabled=!ready,
                  on_click=dispatch(
                    AgentImport(SelectSavedImport(item.operation_id)),
                  ),
                  "Review saved attempt",
                ),
              ])
            }),
          ),
        ])
      } else {
        @html.nothing
      },
    ],
  )
}

///|
fn render_agent_import_inspection(reply : AgentImportReply) -> @rabbita.Html {
  let inspection = reply.inspection
  let private_count = inspection.files
    .filter(file => file.sensitivity == "user-private")
    .length()
  section(
    attrs=@html.Attrs::build().data_set("testid", "agent-import-inspection"),
    [
      h3("2. Inspect the package"),
      p(reply.filename),
      strong(
        "Book: " + inspection.agent_id + " · Version: " + inspection.version,
      ),
      p(
        "\{inspection.file_count} included files · \{inspection.total_bytes} decoded bytes",
      ),
      if private_count > 0 {
        p(
          attrs=@html.Attrs::build()
            .role("alert")
            .data_set("testid", "agent-import-private-warning"),
          "Contains user-private content: \{private_count} file(s). Review the marked files before importing or sharing.",
        )
      } else {
        p(
          "No included file is marked user-private. Sensitivity labels come from the package; inspect the contents before sharing.",
        )
      },
      p(
        "Import retains the included knowledge and learning. Opening the Book does not launch packaged apps or start agent work.",
      ),
      if reply.town_binding is Null {
        p("Ordinary local import. No Town listing provenance is created.")
      } else {
        div(
          attrs=@html.Attrs::build().data_set(
            "testid", "agent-import-binding-inspection",
          ),
          [
            h3("Original Town source binding"),
            p("Listing: " + handoff_text(reply.town_binding, "listing_id")),
            p(
              "Publisher principal: " +
              handoff_text(reply.town_binding, "publisher_principal_id"),
            ),
            p("Tenant: " + handoff_text(reply.town_binding, "tenant_id")),
            p(
              "Expected package: " +
              handoff_text(
                handoff_field(reply.town_binding, "source"),
                "package_filename",
              ),
            ),
            p(
              "Binding digest: " +
              handoff_text(reply.town_binding, "binding_digest"),
            ),
            p(
              "This publisher-declared expectation matches the inspected package bytes. It is not a signature, factual review, or permission to run the Book. Import preserves the binding for Town's read-only imported outputs view.",
            ),
            details(class="technical-details", [
              summary("Inspect complete original binding"),
              pre(reply.town_binding.stringify(indent=2)),
            ]),
          ],
        )
      },
      h3("Included contents"),
      ul(
        inspection.files.map(file => {
          li(
            attrs=@html.Attrs::build().data_set("testid", "agent-import-member"),
            [
              strong(file.path),
              p(
                file.role +
                " · " +
                file.sensitivity +
                " · " +
                file.review_status,
              ),
              details(class="technical-details", [
                summary("File details"),
                p("\{file.size_bytes} bytes · " + file.digest),
              ]),
            ],
          )
        }),
      ),
      h3("Excluded contents"),
      if inspection.exclusions.is_empty() {
        p("No exclusions reported.")
      } else {
        ul(
          inspection.exclusions.map(item => {
            li(
              attrs=@html.Attrs::build().data_set(
                "testid", "agent-import-exclusion",
              ),
              [strong(item.path), p(item.reason)],
            )
          }),
        )
      },
      details(class="technical-details", [
        summary("Package policies and compatibility"),
        h3("Export policy"),
        pre(inspection.export_policy.stringify(indent=2)),
        h3("Compatibility"),
        pre(inspection.compatibility.stringify(indent=2)),
        h3("Memory policy"),
        pre(inspection.memory_policy.stringify(indent=2)),
        h3("Memory metrics"),
        pre(inspection.memory_metrics.stringify(indent=2)),
      ]),
    ],
  )
}
