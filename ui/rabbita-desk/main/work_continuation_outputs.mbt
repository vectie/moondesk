///|
fn work_continuation_output_url(
  target : WorkHandoffTarget,
  record : Json,
  output : Json,
  allow_edit? : Bool = false,
) -> String {
  let path = handoff_text(output, "path")
  if !handoff_json_array(record, "output_refs").contains(output) ||
    !work_continuation_record_valid(target, record) ||
    handoff_text(record, "admission") != "accepted" ||
    !work_continuation_input_verified(record) ||
    handoff_text(output, "command_id") != handoff_text(record, "command_id") ||
    handoff_text(output, "evidence_id") == "" ||
    path == "" ||
    path.length() > 4096 ||
    path.has_prefix("/") ||
    path.contains("\\") ||
    path.contains("\u0000") ||
    path.split("/").any(part => part == "" || part == "." || part == "..") {
    return ""
  }
  work_continuation_output_query(
    handoff_target_query(
      target.task_id,
      target.run_id,
      target.session_id,
      target.command_id,
      target.book_root,
      target.return_to,
    ),
    handoff_text(output, "command_id"),
    path,
    handoff_text(output, "evidence_id"),
    allow_edit,
  )
}

///|
#cfg(target="js")
extern "js" fn work_continuation_output_query(
  target : String,
  command : String,
  path : String,
  evidence : String,
  allow_edit : Bool,
) -> String =
  #| (target, command, path, evidence, allowEdit) => { const query = new URLSearchParams(target); query.set('work_mode', 'inspect'); query.set('work_accepted',allowEdit?'false':'true'); query.set('work_output_command', command); query.set('work_output_path', path); query.set('work_output_evidence', evidence); return '?' + query.toString(); }

///|
fn render_work_continuation_outputs(
  target : WorkHandoffTarget,
  record : Json,
  allow_edit? : Bool = false,
) -> @rabbita.Html {
  let outputs = handoff_json_array(record, "output_refs")
  div(class="work-continuation-outputs", [
    strong("Output files · read only"),
    if outputs.is_empty() {
      p("No output file references are recorded for this follow-up.")
    } else {
      div([
        p(
          "Inspect a reference in a new tab. Your unsent instruction, prior result and selected return result stay here. File contents are the current workspace bytes.",
        ),
        div(
          outputs.map(output => {
            let url = work_continuation_output_url(
              target,
              record,
              output,
              allow_edit~,
            )
            let path = match output {
              String(value) => value
              _ => handoff_text(output, "path")
            }
            if url == "" {
              p(
                (if path == "" { "Output reference" } else { path }) +
                " · unavailable: the exact command, file path and evidence could not be verified. Refresh exact work to retry.",
              )
            } else {
              div([
                a(
                  href=url,
                  target=Blank,
                  escape=true,
                  attrs=@html.Attrs::build().rel("noopener noreferrer"),
                  "Inspect output · " + path + " (new tab)",
                ),
                p(
                  "Command: " +
                  handoff_text(output, "command_id") +
                  " · Evidence: " +
                  handoff_text(output, "evidence_id"),
                ),
              ])
            }
          }),
        ),
      ])
    },
  ])
}
