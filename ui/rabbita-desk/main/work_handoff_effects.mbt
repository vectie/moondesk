///|
fn fetch_work_handoff_cmd(
  dispatch : Dispatch[Msg],
  target : WorkHandoffTarget,
  generation : Int32,
  continuation_id~ : String = "",
  output~ : Json = Json::null(),
) -> @rabbita.Cmd {
  @http.get(
    work_output_read_url(
      work_continuation_read_url(
        work_handoff_read_url(
          target.session_id,
          target.command_id,
          target.book_root,
        ),
        continuation_id,
      ),
      output,
    ),
  ).expect_json(result => {
    dispatch(
      WorkHandoff(
        Resolved(
          generation,
          match result {
            Ok(json) => Ok(json)
            Err(error) => Err(error.to_string())
          },
        ),
      ),
    )
  })
}

///|
fn fetch_work_handoff_files_cmd(
  dispatch : Dispatch[Msg],
  canonical : WorkHandoffCanonical,
  generation : Int32,
  request : Int32,
  directory : String,
) -> @rabbita.Cmd {
  @http.get(@desk.workspace_entries_url(canonical.workspace_id, directory)).expect_json(result => {
      dispatch(
        WorkHandoff(
          FilesLoaded(
            generation,
            request,
            directory,
            http_result(
              result, "Could not read files in this workspace. Retry the folder.",
            ),
          ),
        ),
      )
    },
  )
}

///|
fn work_handoff_read_url(
  session : String,
  command : String,
  root : String,
) -> String {
  @desk.mooncode_work_handoff_url(session, command, root)
}

///|
#cfg(target="js")
extern "js" fn handoff_sync_workspace(target : String, workspace : String) =
  #| (target, workspace) => {
  #|   if (!globalThis.location || !globalThis.history) return;
  #|   const url = new URL(globalThis.location.href), expected = new URLSearchParams(target);
  #|   if (!['work_task','work_run','session','command','book_root','return_to'].every(key => (url.searchParams.get(key)||'') === (expected.get(key)||''))) return;
  #|   url.searchParams.set('workspace', workspace); url.searchParams.set('activity', 'code');
  #|   globalThis.history.replaceState(null, '', url.href);
  #| }

///|
#cfg(target="js")
extern "js" fn handoff_target_query(
  task : String,
  run : String,
  session : String,
  command : String,
  root : String,
  return_to : String,
) -> String =
  #| (task, run, session, command, root, returnTo) => new URLSearchParams({work_task:task, work_run:run, session, command, book_root:root, return_to:returnTo}).toString()

///|
fn handoff_canonicalize_cmd(
  target : WorkHandoffTarget,
  canonical : WorkHandoffCanonical,
) -> @rabbita.Cmd {
  @cmd.custom_cmd(_ => {
    handoff_sync_workspace(
      handoff_target_query(
        target.task_id,
        target.run_id,
        target.session_id,
        target.command_id,
        target.book_root,
        target.return_to,
      ),
      canonical.workspace_id,
    )
  })
}

///|
fn handoff_departure_cmd(next : Model) -> @rabbita.Cmd {
  @rabbita.batch([
    @cmd.custom_cmd(_ => handoff_clear_navigation()),
    sync_mooncode_context_cmd(
      next.selected_workspace_id,
      next.selected_mooncode_session_id,
    ),
  ])
}

///|
#cfg(target="js")
extern "js" fn handoff_clear_navigation() =
  #| () => {
  #|   const guard=globalThis.__moondeskHumanRevisionUnload;if(guard&&globalThis.removeEventListener){globalThis.removeEventListener('beforeunload',guard);delete globalThis.__moondeskHumanRevisionUnload;}
  #|   if (!globalThis.location || !globalThis.history) return;
  #|   const url = new URL(globalThis.location.href);
  #|   for (const key of ['work_task','work_run','work_mode','work_accepted','command','book_root','return_to','work_output_command','work_output_path','work_output_evidence']) url.searchParams.delete(key);
  #|   globalThis.history.replaceState(null, '', url.href);
  #| }

///|
#cfg(target="js")
extern "js" fn work_output_read_url_raw(
  value : String,
  command : String,
  path : String,
  evidence : String,
) -> String =
  #| (value, command, path, evidence) => { const url = new URL(value, 'https://desk.invalid'); for (const [key, value] of [['output_command',command],['output_path',path],['output_evidence',evidence]]) url.searchParams.set(key, value); return url.pathname + url.search; }

///|
fn work_output_read_url(value : String, output : Json) -> String {
  if output is Null {
    value
  } else {
    work_output_read_url_raw(
      value,
      handoff_text(output, "command_id"),
      handoff_text(output, "path"),
      handoff_text(output, "evidence_id"),
    )
  }
}

///|
#cfg(target="js")
extern "js" fn work_output_location_matches_raw(
  command : String,
  path : String,
  evidence : String,
) -> Bool =
  #| (command, path, evidence) => { if (!globalThis.location) return true; const p = new URLSearchParams(globalThis.location.search); return [['work_output_command',command],['work_output_path',path],['work_output_evidence',evidence]].every(([key, value]) => (p.get(key)||'') === value); }

///|
fn work_output_location_matches(output : Json) -> Bool {
  work_output_location_matches_raw(
    handoff_text(output, "command_id"),
    handoff_text(output, "path"),
    handoff_text(output, "evidence_id"),
  )
}
