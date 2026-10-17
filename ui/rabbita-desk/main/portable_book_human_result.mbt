///|
struct PortableBookHumanRecord {
  record_id : String
  record_version : String
  record_digest : String
} derive(FromJson, ToJson, Eq, Debug)

///|
struct PortableBookHumanRevision {
  revision_id : String
  original_run_id : String
  session_id : String
  original_command_id : String
  output_command_id : String
  output_evidence_id : String
  revision_snapshot_digest : String
} derive(FromJson, ToJson, Eq, Debug)

///|
/// Ephemeral browser selection. raw_base64 encodes the original file bytes,
/// never a serialization of the parsed source observation or preview text.
struct PortableBookHumanResult {
  filename : String
  raw_base64 : String
  raw_size_bytes : Int32
  raw_sha256 : String
  task : PortableBookHumanRecord
  report : PortableBookHumanRecord
  revision : PortableBookHumanRevision
  content_text : String
  content_size_bytes : Int32
  content_sha256 : String
} derive(FromJson, ToJson, Eq, Debug)

///|
fn portable_book_human_result_preview_notice() -> String {
  "Captured accepted human revision from MoonProj. Unsigned source observation only: no live authenticity, signature, or acceptance authority is established. The source is non-authorizing. Import does not run, review, or promote a lesson."
}

///|
fn render_portable_book_human_result_picker(
  dispatch : Dispatch[Msg],
  state : PortableBookState,
) -> @rabbita.Html {
  let locked = portable_book_inputs_locked(state)
  section(
    class="surface-state-panel",
    attrs=@html.Attrs::build().data_set("testid", "portable-book-human-result"),
    [
      h3("Accepted human result source"),
      p(
        "Choose one exported MoonProj JSON file, up to 512 KiB, containing up to 256 KiB of UTF-8 text. Selection stays in this page only and is cleared on reload or a context change.",
      ),
      button(
        class="secondary-button",
        disabled=locked,
        attrs=@html.Attrs::build().data_set(
          "testid", "portable-book-human-result-choose",
        ),
        on_click=dispatch(PortableBook(ChooseAcceptedHumanResult)),
        "Choose accepted human result",
      ),
      match state.accepted_human_result {
        None => p("No accepted human result selected.")
        Some(source) =>
          div([
            render_portable_book_human_result_preview(source),
            button(
              class="secondary-button compact-button",
              disabled=locked,
              attrs=@html.Attrs::build().data_set(
                "testid", "portable-book-human-result-remove",
              ),
              on_click=dispatch(PortableBook(RemoveAcceptedHumanResult)),
              "Remove accepted human result",
            ),
            p(
              "Prepare local package explicitly includes this exact source JSON and its text alongside the selected Book content and additional files.",
            ),
          ])
      },
    ],
  )
}

///|
fn render_portable_book_human_result_preview(
  source : PortableBookHumanResult,
) -> @rabbita.Html {
  div(
    attrs=@html.Attrs::build().data_set(
      "testid", "portable-book-human-result-preview",
    ),
    [
      p(portable_book_human_result_preview_notice()),
      p(
        "File: " +
        source.filename +
        " · Source JSON: \{source.raw_size_bytes} bytes",
      ),
      p("Source JSON SHA-256: " + source.raw_sha256),
      p(
        "Task: " +
        source.task.record_id +
        " · Version: " +
        source.task.record_version,
      ),
      p("Task digest: " + source.task.record_digest),
      p(
        "Report: " +
        source.report.record_id +
        " · Version: " +
        source.report.record_version,
      ),
      p("Report digest: " + source.report.record_digest),
      p("Revision: " + source.revision.revision_id),
      p("Revision snapshot digest: " + source.revision.revision_snapshot_digest),
      p(
        "Original run: " +
        source.revision.original_run_id +
        " · Session: " +
        source.revision.session_id,
      ),
      p("Original command: " + source.revision.original_command_id),
      p(
        "Output command: " +
        source.revision.output_command_id +
        " · Output evidence: " +
        source.revision.output_evidence_id,
      ),
      p(
        "Text: \{source.content_size_bytes} bytes · SHA-256: " +
        source.content_sha256,
      ),
      p(
        "Text size and SHA-256 match the captured bytes. This integrity check does not verify the source claims.",
      ),
      h3("Full captured text"),
      // Rabbita pre emits a text node. Never interpret the source as HTML/Markdown.
      pre(
        style=["white-space: pre-wrap", "overflow-wrap: anywhere"],
        attrs=@html.Attrs::build().data_set(
          "testid", "portable-book-human-result-text",
        ),
        source.content_text,
      ),
    ],
  )
}
