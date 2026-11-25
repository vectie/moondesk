///|
fn render_desk_folder_more_actions(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  desk_disclosure(
    "desk-more-actions",
    "desk-folder-more-actions",
    "More actions",
    [
      button(
        class="secondary-button full",
        attrs=@html.Attrs::build().data_set("testid", "desk-paste-clipboard"),
        title="Paste copied items here",
        on_click=dispatch(PasteDeskClipboard),
        "Paste Here",
      ),
      p(class="status-line", model.desk_clipboard_status),
      button(
        class="secondary-button full",
        attrs=@html.Attrs::build().data_set("testid", "desk-copy-path"),
        title="Copy folder path",
        on_click=dispatch(CopyDeskPath),
        "Copy Folder Path",
      ),
      p(class="status-line", model.desk_path_status),
      button(
        class="secondary-button full",
        title="Restore the most recently trashed item",
        on_click=dispatch(RestoreLastTrashedDeskEntry),
        "Restore Last",
      ),
      p(class="status-line", model.desk_trash_status),
      render_desk_trash_panel(dispatch, model),
    ],
  )
}

///|
fn render_desk_single_selection_more_actions(
  dispatch : Dispatch[Msg],
  model : Model,
  entry : @desk.DeskFileEntry,
) -> @rabbita.Html {
  desk_disclosure(
    "desk-more-actions",
    "desk-selection-more-actions",
    "More actions",
    [
      input(
        class="line-input",
        value=model.desk_move_target_directory,
        placeholder="Move to folder",
        on_input=fn(value) { dispatch(SetDeskMoveTargetDirectory(value)) },
      ),
      button(
        class="secondary-button full",
        title="Move selected item",
        on_click=dispatch(MoveDeskSelection),
        "Move",
      ),
      p(class="status-line", model.desk_move_status),
      button(
        class="secondary-button full",
        title="Duplicate selected item",
        on_click=dispatch(DuplicateDeskSelection),
        "Duplicate",
      ),
      p(class="status-line", model.desk_copy_status),
      div(class="desk-disclosure-actions", [
        button(
          class="secondary-button compact-button",
          attrs=@html.Attrs::build().data_set("testid", "desk-copy-selection"),
          title="Copy selected item",
          on_click=dispatch(CopyDeskSelection),
          "Copy",
        ),
        button(
          class="secondary-button compact-button",
          attrs=@html.Attrs::build().data_set("testid", "desk-cut-selection"),
          title="Cut selected item",
          on_click=dispatch(CutDeskSelection),
          "Cut",
        ),
        button(
          class="secondary-button compact-button",
          attrs=@html.Attrs::build().data_set("testid", "desk-paste-clipboard"),
          title="Paste into this folder",
          disabled=desk_workspace_action_disabled(model),
          on_click=dispatch(PasteDeskClipboard),
          "Paste",
        ),
      ]),
      p(class="status-line", model.desk_clipboard_status),
      button(
        class=desk_favorite_button_class(model, entry.path),
        attrs=@html.Attrs::build().data_set("testid", "desk-toggle-favorite"),
        title="Add or remove from Quick Access",
        on_click=dispatch(ToggleFavorite(entry.path)),
        desk_favorite_button_label(model, entry.path),
      ),
      button(
        class="secondary-button full",
        attrs=@html.Attrs::build().data_set("testid", "desk-copy-path"),
        title="Copy path",
        on_click=dispatch(CopyDeskPath),
        "Copy Path",
      ),
      p(class="status-line", model.desk_path_status),
      button(
        class="secondary-button full",
        title="Move selected item to Trash",
        on_click=dispatch(TrashDeskSelection),
        "Move to Trash",
      ),
      button(
        class="secondary-button full",
        title="Restore the most recently trashed item",
        on_click=dispatch(RestoreLastTrashedDeskEntry),
        "Restore Last",
      ),
      p(class="status-line", model.desk_trash_status),
      render_desk_trash_panel(dispatch, model),
      button(
        class="secondary-button full",
        on_click=dispatch(SelectWorkspaceMode(MoonCode)),
        "Ask Code",
      ),
      button(
        class="secondary-button full",
        on_click=dispatch(ClearDeskSelection),
        "Clear Selection",
      ),
    ],
  )
}

///|
fn render_desk_inline_preview(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(
    class="desk-inline-preview",
    attrs=@html.Attrs::build().data_set("testid", "desk-preview"),
    match model.preview {
      Some(preview) =>
        [
          render_json_table_link(
            model.selected_workspace_id,
            model.selected_path,
          ),
          match model.preview_state {
            Some(state) => render_preview_state_panel(dispatch, model, state)
            None => @html.nothing
          },
        ] +
        (match preview.renderer {
          Markdown
          | Text
          | Json
          | DirectoryListing
          | Unsupported
          | ArtifactSummary =>
            [
              strong(preview.title),
              pre(class="source-block compact", code(preview.body)),
            ]
          Image =>
            [
              strong(preview.title),
              img(
                src=desk_preview_image_source(preview),
                alt=preview.title,
                attrs=desk_preview_image_attrs(preview),
              ),
            ]
          Html =>
            [
              strong(preview.title),
              p(
                class="status-line",
                "Run this executable artifact in MoonDesk's isolated preview.",
              ),
              button(
                class="primary-button full",
                attrs=@html.Attrs::build().data_set(
                  "testid", "desk-open-embedded-preview",
                ),
                on_click=dispatch(SelectWorkspaceMode(MoonCode)),
                "Open in Code",
              ),
            ]
        })
      None =>
        [
          match model.preview_state {
            Some(state) => render_preview_state_panel(dispatch, model, state)
            None => render_preview_state_panel(dispatch, model, FirstUseEmpty)
          },
        ]
    },
  )
}

///|
fn render_desk_multi_selection_details(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(class="desk-detail-panel", [
    div(class="desk-detail-title", [
      span(class="tree-icon", "*"),
      h3("\{model.desk_selected_paths.length()} items selected"),
    ]),
    info_row("Selection", desk_multi_selection_count_label(model)),
    info_row("Total Size", desk_multi_selection_size_label(model)),
    desk_disclosure(
      "desk-technical-details",
      "desk-multi-selection-technical-details",
      "Selection details",
      [
        info_row("Focused", empty_root_path(model.selected_path)),
        info_row("Folder", empty_root_path(model.current_directory)),
        info_row("Items", desk_selected_paths_summary(model)),
      ],
    ),
    div(class="desk-detail-actions", [
      input(
        class="line-input",
        value=model.desk_move_target_directory,
        placeholder="Target directory",
        on_input=fn(value) { dispatch(SetDeskMoveTargetDirectory(value)) },
      ),
      button(
        class="secondary-button full",
        title="Move selected items to target directory",
        on_click=dispatch(MoveDeskSelection),
        "Move",
      ),
      p(class="status-line", model.desk_move_status),
      button(
        class="secondary-button full",
        title="Duplicate selected items in their current directories",
        on_click=dispatch(DuplicateDeskSelection),
        "Duplicate",
      ),
      p(class="status-line", model.desk_copy_status),
      button(
        class="secondary-button full",
        attrs=@html.Attrs::build().data_set("testid", "desk-copy-selection"),
        title="Copy selected items to the Desk clipboard",
        on_click=dispatch(CopyDeskSelection),
        "Copy",
      ),
      button(
        class="secondary-button full",
        attrs=@html.Attrs::build().data_set("testid", "desk-cut-selection"),
        title="Cut selected items to move them with Paste Here",
        on_click=dispatch(CutDeskSelection),
        "Cut",
      ),
      button(
        class="secondary-button full",
        attrs=@html.Attrs::build().data_set("testid", "desk-paste-clipboard"),
        title="Paste copied items into the current directory",
        on_click=dispatch(PasteDeskClipboard),
        "Paste Here",
      ),
      p(class="status-line", model.desk_clipboard_status),
      button(
        class="secondary-button full",
        attrs=@html.Attrs::build().data_set("testid", "desk-copy-path"),
        title="Copy selected virtual paths",
        on_click=dispatch(CopyDeskPath),
        "Copy Paths",
      ),
      p(class="status-line", model.desk_path_status),
      button(
        class="secondary-button full",
        title="Move selected items to scoped MoonBook trash",
        on_click=dispatch(TrashDeskSelection),
        "Move to Trash",
      ),
      button(
        class="secondary-button full",
        title="Restore the most recently trashed item",
        on_click=dispatch(RestoreLastTrashedDeskEntry),
        "Restore Last",
      ),
      p(class="status-line", model.desk_trash_status),
      render_desk_trash_panel(dispatch, model),
      button(
        class="secondary-button full",
        attrs=@html.Attrs::build().data_set("testid", "desk-reveal-selection"),
        on_click=dispatch(RevealSelection),
        "Reveal Focused",
      ),
      button(
        class="secondary-button full",
        on_click=dispatch(ClearDeskSelection),
        "Clear Selection",
      ),
    ]),
  ])
}

///|
fn desk_favorite_button_class(model : Model, path : String) -> String {
  if has_string(model.favorites, path) {
    "secondary-button full active"
  } else {
    "secondary-button full"
  }
}

///|
fn desk_favorite_button_label(model : Model, path : String) -> String {
  if has_string(model.favorites, path) {
    "Remove Favorite"
  } else {
    "Add Favorite"
  }
}

///|
fn desk_multi_selection_count_label(model : Model) -> String {
  let entries = desk_selected_entries(model)
  if entries.length() == 0 {
    "\{model.desk_selected_paths.length()} selected"
  } else {
    desk_entry_count_label(desk_entry_counts(entries))
  }
}

///|
fn desk_multi_selection_size_label(model : Model) -> String {
  let entries = desk_selected_entries(model)
  let mut known = 0
  let mut total = 0
  for entry in entries {
    match entry.size_bytes {
      Some(bytes) => {
        known += 1
        total += bytes
      }
      None => ()
    }
  }
  if known == 0 {
    "-"
  } else if known == entries.length() {
    size_label(Some(total))
  } else {
    size_label(Some(total)) + " known"
  }
}

///|
fn desk_selected_entries(model : Model) -> Array[@desk.DeskFileEntry] {
  let entries : Array[@desk.DeskFileEntry] = []
  for path in model.desk_selected_paths {
    match find_entry(model, path) {
      Some(entry) => entries.push(entry)
      None => ()
    }
  }
  entries
}

///|
fn render_desk_trash_panel(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(
    class="desk-trash-panel",
    attrs=@html.Attrs::build().data_set("testid", "desk-trash-panel"),
    [
      strong("Trash"),
      if model.desk_trash_entries.length() == 0 {
        p(class="status-line", "Trash is empty")
      } else {
        div(
          class="desk-trash-list",
          model.desk_trash_entries.map(entry => {
            button(
              class="desk-trash-row",
              attrs=@html.Attrs::build()
                .data_set("testid", "desk-trash-row")
                .data_set("workspace-id", entry.workspace_id)
                .data_set("trash-path", entry.trash_path)
                .data_set("receipt-path", entry.receipt_path)
                .data_set("original-path", entry.original_path),
              title="Restore " + entry.original_path,
              on_click=dispatch(RestoreDeskTrashEntry(entry.trash_path)),
              [span(entry.original_path), small(entry.trashed_at)],
            )
          }),
        )
      },
    ],
  )
}

///|
fn desk_selected_paths_summary(model : Model) -> String {
  let limit = if model.desk_selected_paths.length() < 4 {
    model.desk_selected_paths.length()
  } else {
    4
  }
  let parts : Array[String] = []
  for index in 0..<limit {
    parts.push(empty_root_path(model.desk_selected_paths[index]))
  }
  if model.desk_selected_paths.length() > limit {
    parts.push("+\{model.desk_selected_paths.length() - limit} more")
  }
  parts.join(", ")
}

///|
fn selected_desk_entry(model : Model) -> @desk.DeskFileEntry? {
  find_entry(model, model.selected_path)
}

///|
fn desk_entry_counts(
  entries : Array[@desk.DeskFileEntry],
) -> (Int32, Int32, Int32) {
  let mut directories = 0
  let mut files = 0
  for entry in entries {
    if entry.kind is Directory {
      directories += 1
    } else {
      files += 1
    }
  }
  (entries.length(), directories, files)
}

///|
fn desk_entry_count_label(counts : (Int32, Int32, Int32)) -> String {
  let (total, directories, files) = counts
  "\{count_noun(total, "item")}, \{count_noun(directories, "folder")}, \{count_noun(files, "file")}"
}

///|
fn count_noun(count : Int32, noun : String) -> String {
  if count == 1 {
    "\{count} \{noun}"
  } else {
    "\{count} \{noun}s"
  }
}

///|
fn desk_entry_count_label_for_model(
  model : Model,
  counts : (Int32, Int32, Int32),
  visible_count : Int32,
) -> String {
  match model.desk_entries_state {
    Some(FirstUseEmpty) => "No MoonBook selected"
    Some(Loading) =>
      if model.entries.is_empty() {
        "Loading items"
      } else {
        "Refreshing \{count_noun(model.entries.length(), "item")}"
      }
    Some(Stale) =>
      if model.entries.is_empty() {
        "Item count unavailable"
      } else {
        "\{count_noun(model.entries.length(), "retained item")}"
      }
    Some(Disconnected)
    | Some(CapabilityLimited)
    | Some(RecoverableError)
    | Some(TerminalError) => "Item count unavailable"
    Some(LegitimateZero) => desk_entry_count_label(counts)
    None =>
      if model.desk_filter_query.trim().to_owned() == "" {
        desk_entry_count_label(counts)
      } else {
        "\{visible_count} of \{model.entries.length()} shown"
      }
  }
}

///|
fn desk_selection_label(model : Model) -> String {
  if model.desk_selected_paths.length() > 1 {
    "\{model.desk_selected_paths.length()} selected"
  } else if model.selected_path == "" {
    "No selection"
  } else {
    "Selected " + empty_root_path(model.selected_path)
  }
}

///|
fn desk_access_label(entry : @desk.DeskFileEntry?) -> String {
  match entry {
    Some(entry) if entry.writable => "Writable"
    Some(_) => "Read-only"
    None => "Browse only"
  }
}

///|
fn desk_directory_title(path : String) -> String {
  if path == "" {
    "MoonBook Root"
  } else {
    path
  }
}

///|
fn parent_path(path : String) -> String {
  match path.rev_split_once("/") {
    Some((parent, _)) => parent.to_owned()
    None => ""
  }
}

///|
fn empty_root_path(path : String) -> String {
  if path == "" {
    "/"
  } else {
    path
  }
}

///|
fn optional_text(value : String?, fallback : String) -> String {
  match value {
    Some(text) if text != "" => text
    _ => fallback
  }
}

///|
fn size_label(value : Int32?) -> String {
  match value {
    Some(size) if size >= 1024 * 1024 => "\{size / (1024 * 1024)} MB"
    Some(size) if size >= 1024 => "\{size / 1024} KB"
    Some(size) => "\{size} B"
    None => "-"
  }
}

///|
fn yes_no(value : Bool) -> String {
  if value {
    "yes"
  } else {
    "no"
  }
}

///|
fn kind_label(kind : @desk.EntryKind) -> String {
  match kind {
    Directory => "folder"
    Markdown => "markdown"
    Html => "html"
    Json => "json"
    Image => "image"
    Artifact => "artifact"
    Text => "text"
    Unknown => "unknown"
  }
}
