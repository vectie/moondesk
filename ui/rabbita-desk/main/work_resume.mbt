///|
struct WorkResumeState {
  scope : String
  entries : Array[Json]
  status : String
  forgotten_read : String
}

///|
fn empty_work_resume() -> WorkResumeState {
  { scope: "", entries: [], status: "empty", forgotten_read: "", }
}

///|
fn work_resume_host_scope(
  response : Json,
  canonical : WorkHandoffCanonical,
) -> String {
  let scope = handoff_json_array(response, "resume_scope")
  if scope.length() != 5 ||
    !scope.all(value => {
      value is String(text) && text != "" && text.length() <= 8192
    }) ||
    scope[3] != canonical.workspace_id.to_json() ||
    scope[4] != canonical.root_path.to_json() {
    return ""
  }
  scope.to_json().stringify()
}

///|
fn work_resume_scope(model : Model) -> String {
  if work_handoff_active(model) {
    return model.work_handoff.resume_scope
  }
  if model.workspace_suite_root_path == "" ||
    model.workspace_books_root_path == "" ||
    model.workspace_library_path == "" ||
    !model.workspaces.any(book => {
      book.id == model.selected_workspace_id && book.root_path != ""
    }) {
    return ""
  }
  desk_quick_access_scope(model)
}

///|
fn work_resume_key(scope : String) -> String {
  "moondesk.work-resume.v1:" + scope
}

///|
fn work_resume_entry_valid(entry : Json, scope : String) -> Bool {
  guard entry is Object(fields) && fields.length() == 4 else { return false }
  let query = handoff_text(entry, "query")
  query != "" &&
  query.length() <= 32768 &&
  handoff_text(entry, "title") != "" &&
  handoff_text(entry, "title").length() <= 200 &&
  handoff_text(entry, "observed") != "" &&
  handoff_text(entry, "observed").length() <= 160 &&
  handoff_text(entry, "schema") == "moondesk.work-resume-entry.v1" &&
  work_resume_checked_query(query, scope) == query
}

///|
fn work_resume_load(scope : String) -> WorkResumeState {
  if scope == "" {
    return { ..empty_work_resume(), status: "unavailable", }
  }
  let raw = work_continuation_draft_read(work_resume_key(scope))
  if raw == "unavailable" {
    return { ..empty_work_resume(), scope, status: "unavailable", }
  }
  if raw == "missing" {
    return { ..empty_work_resume(), scope, status: "empty", }
  }
  let saved = @json.parse(raw) catch { _ => Json::null() }
  guard saved is Object(fields) &&
    fields.length() == 3 &&
    handoff_text(saved, "schema") == "moondesk.work-resume.v1" &&
    handoff_text(saved, "scope") == scope &&
    handoff_field(saved, "entries") is Array(items) &&
    items.length() <= 12 else {
    return { ..empty_work_resume(), scope, status: "invalid", }
  }
  let entries : Array[Json] = []
  for item in items {
    if !work_resume_entry_valid(item, scope) ||
      entries.any(old => {
        handoff_text(old, "query") == handoff_text(item, "query")
      }) {
      return { ..empty_work_resume(), scope, status: "invalid", }
    }
    entries.push(item)
  }
  { ..empty_work_resume(), scope, entries, status: "saved", }
}

///|
fn work_resume_save(
  state : WorkResumeState,
  entries : Array[Json],
) -> WorkResumeState {
  let body : Json = {
    "schema": "moondesk.work-resume.v1",
    "scope": state.scope,
    "entries": entries,
  }
  if work_continuation_draft_write(
      work_resume_key(state.scope),
      body.stringify(),
    ) {
    { ..state, entries, status: "saved", }
  } else {
    // A failed write must not pretend that a forgotten item is removed.
    { ..state, status: "storage_failed", }
  }
}

///|
fn work_resume_capture(
  model : Model,
  state : WorkResumeState,
) -> WorkResumeState {
  let handoff = model.work_handoff
  guard handoff.target is Some(target) &&
    handoff.canonical is Some(canonical) &&
    handoff.phase == "ready" &&
    state.scope != "" else {
    return state
  }
  if !(handoff.output_hint is Null) &&
    handoff_text(handoff.output, "state") != "ready" {
    return state
  }
  let query = work_resume_make_query(
    target,
    handoff.continuation.enabled,
    handoff.output_hint,
  )
  if state.forgotten_read ==
    work_resume_read_identity(query, handoff.generation) {
    return state
  }
  let title = if !(handoff.output_hint is Null) {
    "Output · " + handoff_text(handoff.output_hint, "path")
  } else {
    match handoff.session {
      Some(session) if session.title.trim().to_owned() != "" => session.title
      _ => @desk.display_name(canonical.root_path) + " · captured work"
    }
  }
  let entry : Json = {
    "schema": "moondesk.work-resume-entry.v1",
    "query": query,
    "title": work_resume_label(title, 200),
    "observed": work_resume_label(
      canonical.claim_status + " / " + handoff_display(canonical.receipt_status),
      160,
    ),
  }
  if !work_resume_entry_valid(entry, state.scope) {
    return state
  }
  // Another tab may have resolved work since this screen was rendered.
  let latest = work_resume_load(state.scope)
  if latest.status == "unavailable" {
    return { ..state, status: "unavailable", }
  }
  let entries = [entry] +
    latest.entries.filter(old => handoff_text(old, "query") != query)
  work_resume_save(
    latest,
    entries[:Int32::min(entries.length(), 12)].to_owned(),
  )
}

///|
fn sync_work_resume(previous : Model, model : Model, msg : Msg) -> Model {
  let scope = work_resume_scope(model)
  let state = if model.work_resume.scope != scope {
    work_resume_load(scope)
  } else {
    model.work_resume
  }
  let state = match msg {
    WorkHandoff(Resolved(generation, Ok(_))) if previous.work_handoff.phase ==
      "loading" &&
      previous.work_handoff.generation == generation &&
      model.work_handoff.generation == generation &&
      model.work_handoff.phase == "ready" => work_resume_capture(model, state)
    _ => state
  }
  { ..model, work_resume: state, }
}

///|
fn forget_resumable_work(
  model : Model,
  scope : String,
  query : String?,
) -> Model {
  if scope == "" ||
    scope != work_resume_scope(model) ||
    scope != model.work_resume.scope {
    return model
  }
  let current = {
    ..work_resume_load(scope),
    forgotten_read: model.work_resume.forgotten_read,
  }
  if current.status == "unavailable" {
    return { ..model, work_resume: current, }
  }
  let entries = match query {
    Some(query) =>
      current.entries.filter(entry => handoff_text(entry, "query") != query)
    None => []
  }
  let saved = work_resume_save(current, entries)
  // A successful forget is newer than a read already in flight. Ignore only
  // that route/request's later capture, not a fresh explicit refresh.
  let saved = if saved.status == "saved" &&
    model.work_handoff.phase == "loading" &&
    model.work_handoff.target is Some(target) {
    let pending = work_resume_make_query(
      target,
      model.work_handoff.continuation.enabled,
      model.work_handoff.output_hint,
    )
    if query is None || query == Some(pending) {
      {
        ..saved,
        forgotten_read: work_resume_read_identity(
          pending,
          model.work_handoff.generation,
        ),
      }
    } else {
      saved
    }
  } else {
    saved
  }
  { ..model, work_resume: saved, }
}

///|
fn work_resume_read_identity(query : String, generation : Int32) -> String {
  query + "\n" + generation.to_string()
}

///|
fn work_resume_make_query(
  target : WorkHandoffTarget,
  follow_up : Bool,
  output : Json,
) -> String {
  work_resume_query_raw(
    handoff_target_query(
      target.task_id,
      target.run_id,
      target.session_id,
      target.command_id,
      target.book_root,
      target.return_to,
    ),
    follow_up,
    handoff_text(output, "command_id"),
    handoff_text(output, "path"),
    handoff_text(output, "evidence_id"),
  )
}

///|
#cfg(target="js")
extern "js" fn work_resume_label(value : String, limit : Int32) -> String =
  #| (value, limit) => value.replace(/[\u0000-\u001f\u007f]/g, ' ').slice(0, limit)

///|
/// The saved route is same-page only. Do not retain arbitrary return URL query
/// parameters/fragments, workspaces, credentials, content or execution state.
#cfg(target="js")
extern "js" fn work_resume_query_raw(
  target : String,
  follow_up : Bool,
  command : String,
  path : String,
  evidence : String,
) -> String =
  #| (target, followUp, command, path, evidence) => {
  #|   const p = new URLSearchParams(target), back = p.get('return_to');
  #|   try { const u = new URL(back); if (!['http:','https:'].includes(u.protocol) || u.username || u.password || u.searchParams.get('task') !== p.get('work_task')) throw new Error(); u.search=''; u.hash=''; u.searchParams.set('task',p.get('work_task')); p.set('return_to',u.href); } catch (_) { p.set('return_to',''); }
  #|   p.set('work_mode',followUp?'follow_up':'inspect');
  #|   if(command && path && evidence) { p.set('work_output_command',command); p.set('work_output_path',path); p.set('work_output_evidence',evidence); }
  #|   return '?' + p.toString();
  #| }

///|
#cfg(target="js")
extern "js" fn work_resume_checked_query(
  query : String,
  scope : String,
) -> String =
  #| (query, scope) => {
  #|   try {
  #|     const identity=JSON.parse(scope); if(!Array.isArray(identity)||identity.length!==5||!identity.every(x=>typeof x==='string'&&x&&x.length<=8192))return '';
  #|     if(!query.startsWith('?')||query.includes('#'))return '';
  #|     const p=new URLSearchParams(query), keys=['work_task','work_run','session','command','book_root','return_to','work_mode'];
  #|     const output=['work_output_command','work_output_path','work_output_evidence'];
  #|     if([...p.keys()].some(k=>!keys.includes(k)&&!output.includes(k))||[...new Set(p.keys())].some(k=>p.getAll(k).length!==1))return '';
  #|     if(keys.some(k=>!p.has(k))||keys.filter(k=>k!=='return_to').some(k=>!p.get(k)||p.get(k).length>8192||/[\u0000-\u001f\u007f]/.test(p.get(k))))return '';
  #|     const root=p.get('book_root'), normalized=s=>s.replace(/\/+$/,'')||'/';
  #|     if(!root.startsWith('/')||root.split('/').some(x=>x==='.'||x==='..')||normalized(root)!==normalized(identity[4])||!['inspect','follow_up'].includes(p.get('work_mode')))return '';
  #|     const back=p.get('return_to'); if(back){const u=new URL(back);if(!['http:','https:'].includes(u.protocol)||u.username||u.password||u.hash||[...u.searchParams.keys()].join(',')!=='task'||u.searchParams.get('task')!==p.get('work_task'))return '';}
  #|     if(output.some(k=>p.has(k))){if(output.some(k=>!p.get(k)||p.get(k).length>8192))return ''; const path=p.get('work_output_path');if(path.startsWith('/')||path.includes('\\')||/[\u0000-\u001f\u007f]/.test(path)||path.split('/').some(x=>!x||x==='.'||x==='..'))return '';}
  #|     return '?' + p.toString();
  #|   } catch (_) { return ''; }
  #| }
