///|
/// Persist only recovery handles, never package contents or inspection members.
/// Saved browser state grants no authority: the host rechecks it on explicit GET.
struct AgentImportRecovery {
  library : String
  operation_id : String
  filename : String
  destination : String
  import_started : Bool
  reviewed_sha : String
  binding_digest : String?
} derive(FromJson, ToJson)

///|
#cfg(target="js")
extern "js" fn browser_agent_import_saved() -> String =
  #| () => {
  #|   try { return globalThis.localStorage?.getItem('moondesk.agent-import.recovery.v1') || '[]'; }
  #|   catch { return '[]'; }
  #| }

///|
#cfg(target="js")
extern "js" fn browser_agent_import_save(value : String) -> Unit =
  #| value => {
  #|   try { globalThis.localStorage?.setItem('moondesk.agent-import.recovery.v1', value); }
  #|   catch { /* Server retains the operation even if browser storage is unavailable. */ }
  #| }

///|
fn agent_import_restore_sessions(text : String) -> Array[AgentImportSession] {
  if text.length() > 131072 {
    return []
  }
  let items : Array[AgentImportRecovery] = @json.from_json(@json.parse(text)) catch {
    _ => return []
  }
  let sessions : Array[AgentImportSession] = []
  let seen : Map[String, Unit] = Map([])
  for item in items {
    let key = item.library + "\n" + item.operation_id
    if item.library == "" ||
      seen.contains(key) ||
      !portable_book_id_valid(item.operation_id) ||
      !item.filename.has_suffix(".moonbook-agent") ||
      !portable_book_path_valid(item.filename) ||
      item.filename.contains("/") ||
      (item.reviewed_sha != "" && !portable_book_sha_valid(item.reviewed_sha)) ||
      (item.binding_digest is Some(digest) && !portable_book_sha_valid(digest)) ||
      (
        item.import_started &&
        (
          !agent_import_destination_valid(item.destination) ||
          item.reviewed_sha == ""
        )
      ) {
      continue
    }
    seen[key] = ()
    sessions.push({
      ..init_agent_import_session(item.library),
      operation_id: item.operation_id,
      filename: item.filename,
      destination: item.destination,
      import_started: item.import_started,
      reviewed_sha: item.reviewed_sha,
      binding_digest: item.binding_digest.unwrap_or(""),
      exact_required: item.binding_digest is Some(_),
      status: "uncertain",
      error: "A saved package operation needs checking after reopening Desk.",
    })
  }
  sessions
}

///|
fn agent_import_recovery_json(state : AgentImportState) -> Json {
  let sessions = state.suspended.copy()
  sessions.push(state.session)
  let saved : Array[AgentImportRecovery] = []
  for session in sessions {
    if session.operation_id != "" &&
      session.filename != "" &&
      session.status != "awaiting-binding" {
      saved.push({
        library: session.library,
        operation_id: session.operation_id,
        filename: session.filename,
        destination: session.destination,
        import_started: session.import_started,
        reviewed_sha: session.reviewed_sha,
        binding_digest: if session.binding_digest == "" {
          None
        } else {
          Some(session.binding_digest)
        },
      })
    }
  }
  ToJson::to_json(saved)
}

///|
fn agent_import_persist_then(
  state : AgentImportState,
  command : @rabbita.Cmd,
) -> @rabbita.Cmd {
  let saved = agent_import_recovery_json(state).stringify()
  @cmd.custom_cmd(scheduler => {
    // Save the request handle before scheduling an import network effect.
    browser_agent_import_save(saved)
    scheduler.add(command)
  })
}
