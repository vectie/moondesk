///|
fn work_output_decode(
  hint : Json,
  canonical : WorkHandoffCanonical,
  output : Json,
) -> Json {
  if hint is Null {
    return Json::null()
  }
  let path = handoff_text(output, "path")
  if handoff_text(output, "state") != "ready" {
    return output
  }
  if !["command_id", "path", "evidence_id"].all(key => {
      handoff_text(output, key) != "" &&
      handoff_text(output, key) == handoff_text(hint, key)
    }) ||
    handoff_text(output, "workspace_id") != canonical.workspace_id ||
    handoff_text(output, "content_scope") != "current_workspace_bytes" ||
    path.contains("\\") ||
    path.contains("\u0000") ||
    path.split("/").any(part => part == "" || part == "." || part == "..") ||
    handoff_relative_path(canonical.root_path, path) != Some(path) {
    {
      "state": "unavailable",
      "message": "Output response does not match the selected reference. Refresh exact work to retry.",
    }
  } else {
    output
  }
}

///|
fn render_work_output(
  state : WorkHandoffState,
  canonical : WorkHandoffCanonical,
) -> @rabbita.Html {
  if state.output_hint is Null {
    return @html.nothing
  }
  section(class="work-handoff-output", [
    h3("Selected output · current workspace file"),
    p("Command: " + handoff_text(state.output_hint, "command_id")),
    p("Reference: " + handoff_text(state.output_hint, "path")),
    p(
      "The command reference is verified separately from file contents. Later work or human edits may have changed this file; opening it does not select or accept a delivery report.",
    ),
    if handoff_text(state.output, "state") == "ready" {
      let path = handoff_text(state.output, "path")
      let url = @desk.workspace_file_url(canonical.workspace_id, path)
      div([
        a(href=url, download="", "Download current file"),
        if work_output_previewable(path) {
          a(
            href=url,
            target=Blank,
            attrs=@html.Attrs::build().rel("noopener noreferrer"),
            "Open current file",
          )
        } else {
          p(
            "Download this format to inspect it. Active documents are not opened inside the Desk origin.",
          )
        },
      ])
    } else {
      p(
        if handoff_text(state.output, "message") == "" {
          "Output reference unavailable. Refresh exact work to retry."
        } else {
          handoff_text(state.output, "message")
        },
      )
    },
  ])
}

///|
fn work_output_previewable(path : String) -> Bool {
  [
    ".md", ".txt", ".json", ".csv", ".tsv", ".log", ".pdf", ".png", ".jpg", ".jpeg",
    ".gif", ".webp", ".bmp", ".ico",
  ].any(extension => path.has_suffix(extension))
}
