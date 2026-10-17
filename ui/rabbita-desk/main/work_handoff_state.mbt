///|
struct WorkHandoffTarget {
  task_id : String
  run_id : String
  session_id : String
  command_id : String
  book_root : String
  return_to : String
} derive(Eq, Debug)

///|
struct WorkHandoffCanonical {
  workspace_id : String
  root_path : String
  session_id : String
  command_id : String
  action : String
  claim_status : String
  receipt_status : String
  model : String
  context_path : String
} derive(Eq, Debug)

///|
struct WorkHandoffState {
  target : WorkHandoffTarget?
  generation : Int32
  phase : String
  message : String
  canonical : WorkHandoffCanonical?
  resume_scope : String
  context : Json
  output_hint : Json
  output : Json
  session : MoonCodeSession?
  session_error : String
  directory : String
  files_generation : Int32
  files_loading : Bool
  files_error : String
  entries : Array[@desk.DeskFileEntry]
  continuation : WorkContinuationState
  human_revision : WorkHumanRevisionState
}

///|
enum WorkHandoffMsg {
  Resolve
  Resolved(Int32, Result[Json, String])
  LookupTimedOut(Int32)
  Browse(String)
  FilesLoaded(Int32, Int32, String, Result[Array[@desk.DeskFileEntry], String])
  Exit
  FollowUp(WorkContinuationMsg)
  HumanRevision(WorkHumanRevisionMsg)
  TeachLearning(Int32, String, String, String)
  ReviewLearning(Int32)
}

///|
fn empty_work_handoff() -> WorkHandoffState {
  {
    target: None,
    generation: 0,
    phase: "inactive",
    message: "",
    canonical: None,
    resume_scope: "",
    context: Json::null(),
    output_hint: Json::null(),
    output: Json::null(),
    session: None,
    session_error: "",
    directory: "",
    files_generation: 0,
    files_loading: false,
    files_error: "",
    entries: [],
    continuation: empty_work_continuation(),
    human_revision: empty_work_human_revision(),
  }
}

///|
fn handoff_text(json : Json, field : String) -> String {
  match json {
    Object(fields) =>
      match fields.get(field) {
        Some(String(value)) => value
        _ => ""
      }
    _ => ""
  }
}

///|
fn handoff_field(json : Json, field : String) -> Json {
  match json {
    Object(fields) => fields.get(field).unwrap_or(Json::null())
    _ => Json::null()
  }
}

///|
fn work_handoff_from_query(query : String) -> WorkHandoffState {
  let json = @json.parse(work_handoff_query_json(query)) catch {
    _ => Json::null()
  }
  if handoff_text(json, "present") != "yes" {
    return empty_work_handoff()
  }
  let target = {
    task_id: handoff_text(json, "work_task"),
    run_id: handoff_text(json, "work_run"),
    session_id: handoff_text(json, "session"),
    command_id: handoff_text(json, "command"),
    book_root: handoff_text(json, "book_root"),
    return_to: handoff_text(json, "return_to"),
  }
  let valid = ![
    target.task_id,
    target.run_id,
    target.session_id,
    target.command_id,
    target.book_root,
  ].contains("")
  let output_hint : Json = if handoff_text(json, "work_output_command") != "" ||
    handoff_text(json, "work_output_path") != "" ||
    handoff_text(json, "work_output_evidence") != "" {
    {
      "command_id": handoff_text(json, "work_output_command"),
      "path": handoff_text(json, "work_output_path"),
      "evidence_id": handoff_text(json, "work_output_evidence"),
    }
  } else {
    Json::null()
  }
  {
    ..empty_work_handoff(),
    target: Some(target),
    output_hint,
    human_revision: work_human_revision_restore(
      target,
      output_hint,
      handoff_text(json, "work_accepted") == "false",
    ),
    continuation: work_continuation_restore(
      target,
      handoff_text(json, "work_mode") == "follow_up" &&
      handoff_text(json, "work_accepted") != "true",
    ),
    phase: if valid {
      "waiting"
    } else {
      "invalid_request"
    },
    message: if valid {
      "Resolving the exact saved work in this Desk library…"
    } else {
      "This work link is incomplete. Return to MoonProj to open the captured execution again."
    },
  }
}

///|
fn work_handoff_decode(
  target : WorkHandoffTarget,
  json : Json,
) -> Result[WorkHandoffCanonical, String] {
  if handoff_text(json, "schema") != "moondesk.work-handoff.v1" {
    return Err("Invalid handoff response; retry the exact work lookup.")
  }
  if handoff_text(json, "state") != "ready" {
    let message = handoff_text(json, "message")
    return Err(
      if message == "" {
        "The exact work is not available yet. Retry without opening another chat."
      } else {
        message
      },
    )
  }
  let workspace = handoff_field(json, "workspace")
  let command = handoff_field(json, "original_command")
  let canonical = {
    workspace_id: handoff_text(workspace, "id"),
    root_path: handoff_text(workspace, "root_path"),
    session_id: handoff_text(json, "session_id"),
    command_id: handoff_text(command, "command_id"),
    action: handoff_text(command, "action"),
    claim_status: handoff_text(command, "claim_status"),
    receipt_status: handoff_text(command, "receipt_status"),
    model: handoff_text(command, "model"),
    context_path: handoff_text(command, "context_path"),
  }
  if canonical.workspace_id == "" ||
    canonical.root_path == "" ||
    canonical.session_id != target.session_id ||
    canonical.command_id != target.command_id ||
    handoff_normalize_root(canonical.root_path) !=
    handoff_normalize_root(target.book_root) {
    Err(
      "The host response did not match this exact workspace, session and command. Nothing else was opened.",
    )
  } else {
    Ok(canonical)
  }
}

///|
fn handoff_normalize_root(value : String) -> String {
  let parts : Array[String] = []
  for part in value.split("/") {
    if part == "" || part == "." {
      continue
    }
    if part == ".." {
      ignore(parts.pop())
    } else {
      parts.push(part.to_owned())
    }
  }
  (if value.has_prefix("/") { "/" } else { "" }) + parts.join("/")
}

///|
fn work_handoff_active(model : Model) -> Bool {
  model.work_handoff.target is Some(_)
}

///|
fn handoff_relative_path(root : String, path : String) -> String? {
  if path == "" {
    return None
  }
  let prefix = handoff_normalize_root(root) + "/"
  let path = if path.has_prefix(prefix) {
    path[prefix.length():].to_owned()
  } else {
    path
  }
  if path.has_prefix("/") || path.split("/").any(part => part == "..") {
    None
  } else {
    Some(path)
  }
}

///|
#cfg(target="js")
extern "js" fn work_handoff_query_json(query : String) -> String =
  #| query => {
  #|   const params = new URLSearchParams(query), out = {};
  #|   out.present = ['work_task','work_run','work_mode','command','book_root','return_to'].some(key => params.has(key)) ? 'yes' : 'no';
  #|   for (const key of ['work_task','work_run','session','command','book_root','return_to','work_mode','work_accepted','work_output_command','work_output_path','work_output_evidence']) out[key] = params.get(key) || '';
  #|   return JSON.stringify(out);
  #| }

///|
#cfg(target="js")
extern "js" fn work_handoff_initial_query() -> String =
  #| () => globalThis.location?.search || ''

///|
#cfg(target="js")
extern "js" fn handoff_safe_return(value : String, task : String) -> String =
  #| (value, task) => {
  #|   try { const url = new URL(value); return ['http:', 'https:'].includes(url.protocol) && !url.username && !url.password && url.searchParams.get('task') === task ? url.href : ''; } catch (_) { return ''; }
  #| }

///|
#cfg(target="js")
extern "js" fn handoff_return_host(value : String) -> String =
  #| value => { try { return new URL(value).host; } catch (_) { return ''; } }
