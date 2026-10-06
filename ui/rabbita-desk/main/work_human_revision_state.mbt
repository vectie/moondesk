///|
struct WorkHumanRevisionState {
  enabled : Bool
  phase : String
  baseline : String
  draft : String
  base_digest : String
  current_content : String?
  operation : Json
  revision : Json
  request : Int
  local_saved : Bool
  message : String
}

///|
enum WorkHumanRevisionMsg {
  RevisionOpen
  RevisionDraft(String)
  RevisionSave
  RevisionRebase
  RevisionCopy
  RevisionReplied(Int, Int, String, Result[Json, String])
  RevisionTimedOut(Int, Int)
}

///|
fn empty_work_human_revision(enabled? : Bool = false) -> WorkHumanRevisionState {
  {
    enabled,
    phase: "idle",
    baseline: "",
    draft: "",
    base_digest: "",
    current_content: None,
    operation: Json::null(),
    revision: Json::null(),
    request: 0,
    local_saved: true,
    message: "",
  }
}

///|
fn work_human_revision_key(target : WorkHandoffTarget, output : Json) -> String {
  "moondesk.human-revision-editor.v1:" +
  ({ "source": work_continuation_source(target), "output": output } : Json).stringify()
}

///|
fn work_human_revision_source_matches(
  target : WorkHandoffTarget,
  source : Json,
) -> Bool {
  ["task_id", "run_id", "session_id", "original_command_id"].all(key => {
    handoff_field(source, key) ==
    handoff_field(work_continuation_source(target), key)
  }) &&
  handoff_normalize_root(handoff_text(source, "book_root")) ==
  handoff_normalize_root(target.book_root)
}

///|
fn work_human_revision_local_body(
  target : WorkHandoffTarget,
  output : Json,
  state : WorkHumanRevisionState,
) -> Json {
  {
    "schema": "moondesk.human-revision-draft.v1",
    "source": work_continuation_source(target),
    "output": output,
    "baseline_base64": work_human_revision_encode(state.baseline),
    "draft_base64": work_human_revision_encode(state.draft),
    "base_digest": state.base_digest,
    "operation_id": handoff_text(state.operation, "revision_id"),
  }
}

///|
fn work_human_revision_remember(
  target : WorkHandoffTarget,
  output : Json,
  state : WorkHumanRevisionState,
) -> WorkHumanRevisionState {
  let saved = work_human_revision_write(
    work_human_revision_key(target, output),
    work_human_revision_local_body(target, output, state).stringify(),
  )
  { ..state, local_saved: saved, }
}

///|
fn work_human_revision_restore(
  target : WorkHandoffTarget,
  output : Json,
  enabled : Bool,
) -> WorkHumanRevisionState {
  let empty = empty_work_human_revision(enabled~)
  if output is Null {
    return empty
  }
  let saved = @json.parse(
    work_human_revision_read(work_human_revision_key(target, output)),
  ) catch {
    _ => Json::null()
  }
  guard saved
    is {
      "schema": String("moondesk.human-revision-draft.v1"),
      "baseline_base64": String(encoded_baseline),
      "draft_base64": String(encoded_draft),
      ..
    } &&
    work_human_revision_source_matches(target, handoff_field(saved, "source")) &&
    handoff_field(saved, "output") == output else {
    return empty
  }
  let decoded_baseline = @json.parse(
    work_human_revision_decode_json(encoded_baseline),
  ) catch {
    _ => Json::null()
  }
  let decoded_draft = @json.parse(
    work_human_revision_decode_json(encoded_draft),
  ) catch {
    _ => Json::null()
  }
  guard decoded_baseline is String(baseline) && decoded_draft is String(draft) else {
    return empty
  }
  let id = handoff_text(saved, "operation_id")
  let valid_operation = id != ""
  let operation = work_human_revision_request(
    target,
    output,
    { ..empty, baseline, draft, },
    id,
  )
  {
    ..empty,
    baseline,
    draft,
    base_digest: handoff_text(saved, "base_digest"),
    operation: if valid_operation {
      operation
    } else {
      Json::null()
    },
    phase: if valid_operation {
      "retry"
    } else {
      "editing"
    },
    message: if valid_operation {
      "The exact operation and draft were restored. Capture may already exist; return confirmation is pending native identity verification."
    } else {
      "Your unsaved human edit was restored from this browser."
    },
  }
}

///|
fn work_human_revision_request(
  target : WorkHandoffTarget,
  output : Json,
  state : WorkHumanRevisionState,
  id : String,
) -> Json {
  {
    "operation": "save",
    "revision_id": id,
    "source": work_continuation_source(target),
    "output": output,
    "expected_content": state.baseline,
    "content": state.draft,
  }
}

///|
fn work_human_revision_saved_matches(
  target : WorkHandoffTarget,
  canonical : WorkHandoffCanonical,
  output : Json,
  operation : Json,
  payload : Json,
) -> Bool {
  let revision = handoff_field(payload, "revision")
  let content = handoff_field(revision, "content")
  handoff_text(payload, "schema") == "moondesk.human-revision-editor.v1" &&
  handoff_text(payload, "state") == "saved" &&
  handoff_field(payload, "content") == handoff_field(operation, "content") &&
  handoff_text(revision, "schema") == "moonproj.human-revision.v1" &&
  handoff_text(revision, "state") == "saved" &&
  handoff_text(revision, "revision_id") ==
  handoff_text(operation, "revision_id") &&
  handoff_text(revision, "task_id") == target.task_id &&
  handoff_text(revision, "original_run_id") == target.run_id &&
  handoff_text(revision, "session_id") == target.session_id &&
  handoff_text(revision, "original_command_id") == target.command_id &&
  handoff_normalize_root(handoff_text(revision, "workspace")) ==
  handoff_normalize_root(canonical.root_path) &&
  handoff_text(revision, "workspace_id") == canonical.workspace_id &&
  handoff_field(revision, "output") == output &&
  handoff_text(revision, "author_type") == "human" &&
  handoff_text(revision, "capture_scope") == "immutable_human_revision" &&
  handoff_text(handoff_field(revision, "base"), "scope") ==
  "current_workspace_bytes_at_edit" &&
  handoff_text(content, "path") ==
  ".moonsuite/products/moonproj/human-revisions/" +
  handoff_text(operation, "revision_id") +
  "/content.txt" &&
  handoff_text(content, "sha256").length() == 64 &&
  handoff_field(content, "size_bytes") ==
  work_human_revision_utf8_length(handoff_text(operation, "content")).to_json()
}

///|
#cfg(target="js")
extern "js" fn work_human_revision_read(key : String) -> String =
  #| key => { try { const raw=globalThis.localStorage?.getItem(key); return typeof raw==='string' && raw.length<=2097152 ? raw : 'null'; } catch (_) { return 'null'; } }

///|
#cfg(target="js")
extern "js" fn work_human_revision_encode(value : String) -> String =
  #| value => {const bytes=new TextEncoder().encode(value);let raw='';for(let start=0;start<bytes.length;start+=8192)raw+=String.fromCharCode(...bytes.subarray(start,start+8192));return btoa(raw);}

///|
#cfg(target="js")
extern "js" fn work_human_revision_decode_json(value : String) -> String =
  #| value => {try {return JSON.stringify(new TextDecoder('utf-8',{fatal:true}).decode(Uint8Array.from(atob(value),c=>c.charCodeAt(0))));}catch(_){return 'null';}}

///|
#cfg(target="js")
extern "js" fn work_human_revision_write(key : String, value : String) -> Bool =
  #| (key,value) => { try { if(!globalThis.localStorage || value.length>2097152)return false;globalThis.localStorage.setItem(key,value);return globalThis.localStorage.getItem(key)===value; } catch(_){return false;} }

///|
#cfg(target="js")
extern "js" fn work_human_revision_utf8_length(value : String) -> Int =
  #| value => new TextEncoder().encode(value).length

///|
#cfg(target="js")
extern "js" fn work_human_revision_location_editable() -> Bool =
  #| () => !globalThis.location || new URLSearchParams(globalThis.location.search).get('work_accepted') === 'false'

///|
#cfg(target="js")
extern "js" fn work_human_revision_download_url(value : String) -> String =
  #| value => 'data:text/plain;charset=utf-8,' + encodeURIComponent(value)

///|
#cfg(target="js")
extern "js" fn work_human_revision_return_url(
  back : String,
  task : String,
  id : String,
) -> String =
  #| (back,task,id) => { try {const u=new URL(back);if(!['http:','https:'].includes(u.protocol)||u.username||u.password||u.searchParams.get('task')!==task||!id)return '';for(const k of ['continuation_id','continuation_command','source_run','human_revision_id'])u.searchParams.delete(k);u.searchParams.set('human_revision_id',id);return u.href;}catch(_){return '';} }

///|
fn work_human_revision_allow_departure(state : WorkHumanRevisionState) -> Bool {
  state.local_saved ||
  state.phase == "idle" ||
  state.phase == "saved" ||
  work_human_revision_confirm_leave()
}

///|
#cfg(target="js")
extern "js" fn work_human_revision_confirm_leave() -> Bool =
  #| () => typeof globalThis.confirm==='function' && globalThis.confirm('This human edit is not saved in this browser. Cancel to keep it open and copy your text. Leave without saving?')

///|
#cfg(target="js")
extern "js" fn work_human_revision_unload_guard(unsaved : Bool) =
  #| unsaved => { const key='__moondeskHumanRevisionUnload';if(!globalThis.addEventListener||!globalThis.removeEventListener||Boolean(globalThis[key])===unsaved)return;if(globalThis[key]){globalThis.removeEventListener('beforeunload',globalThis[key]);delete globalThis[key];}if(unsaved){const fn=e=>{e.preventDefault();e.returnValue='';};globalThis[key]=fn;globalThis.addEventListener('beforeunload',fn);} }
