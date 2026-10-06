///|
struct WorkContinuationState {
  enabled : Bool
  draft : String
  draft_status : String
  draft_token : String
  prior_command : String
  operation : Json
  phase : String
  error : String
  records : Array[Json]
  selected_return : String
  pending_guidance : Array[Json]
  guidance_state : String
  request : Int
  admission_possible : Bool
  prior_uncertainty : Bool
}

///|
enum WorkContinuationMsg {
  Draft(String, String)
  Prior(String, String)
  DiscardDraft(String)
  CopyDraft(String)
  Submit
  Stored(Int, Int, String, Bool)
  ResumeStored(Int, Int, String, Bool)
  Submitted(Int, Int, String, Result[Json, String])
  Recover
  Resume
  New
  SelectReturn(String)
  Poll(Int, String)
  AdmissionTimeout(Int, Int, String)
}

///|
fn empty_work_continuation() -> WorkContinuationState {
  {
    enabled: false,
    draft: "",
    draft_status: "empty",
    draft_token: work_continuation_nonce(),
    prior_command: "",
    operation: Json::null(),
    phase: "draft",
    error: "",
    records: [],
    selected_return: "",
    pending_guidance: [],
    guidance_state: "unavailable",
    request: 0,
    admission_possible: false,
    prior_uncertainty: false,
  }
}

///|
fn work_continuation_source(target : WorkHandoffTarget) -> Json {
  {
    "task_id": target.task_id,
    "run_id": target.run_id,
    "session_id": target.session_id,
    "original_command_id": target.command_id,
    "book_root": target.book_root,
  }
}

///|
fn work_continuation_matches(target : WorkHandoffTarget, record : Json) -> Bool {
  let source = handoff_field(record, "source")
  handoff_text(source, "task_id") == target.task_id &&
  handoff_text(source, "run_id") == target.run_id &&
  handoff_text(source, "session_id") == target.session_id &&
  handoff_text(source, "original_command_id") == target.command_id &&
  handoff_normalize_root(handoff_text(source, "book_root")) ==
  handoff_normalize_root(target.book_root)
}

///|
fn work_continuation_restore(
  target : WorkHandoffTarget,
  enabled : Bool,
) -> WorkContinuationState {
  let operation = @json.parse(
    work_continuation_read_saved(work_continuation_key(target)),
  ) catch {
    _ => Json::null()
  }
  let valid = handoff_text(operation, "schema") ==
    "moondesk.work-continuation-request.v1" &&
    handoff_text(operation, "operation") == "submit" &&
    work_continuation_matches(target, operation) &&
    handoff_text(operation, "continuation_id") != "" &&
    handoff_text(operation, "client_turn_id") != "" &&
    handoff_text(operation, "instruction") != ""
  let captured : Json = {
    "schema": "moondesk.work-continuation-request.v1",
    "operation": "submit",
    "continuation_id": handoff_text(operation, "continuation_id"),
    "client_turn_id": handoff_text(operation, "client_turn_id"),
    "source": work_continuation_source(target),
    "prior_result_command_id": handoff_text(
      operation, "prior_result_command_id",
    ),
    "instruction": handoff_text(operation, "instruction"),
  }
  let restored = {
    ..empty_work_continuation(),
    enabled,
    prior_command: if valid {
      handoff_text(operation, "prior_result_command_id")
    } else {
      target.command_id
    },
    operation: if valid {
      captured
    } else {
      Json::null()
    },
    admission_possible: valid &&
    work_continuation_dispatch_possible(work_continuation_key(target)),
    prior_uncertainty: valid &&
    work_continuation_dispatch_possible(work_continuation_key(target)),
    draft: if valid {
      handoff_text(operation, "instruction")
    } else {
      ""
    },
    phase: if valid {
      "recovering"
    } else {
      "draft"
    },
  }
  if valid {
    restored
  } else {
    work_continuation_draft_restore(target, restored)
  }
}

///|
fn handoff_json_array(json : Json, key : String) -> Array[Json] {
  match handoff_field(json, key) {
    Array(items) => items
    _ => []
  }
}

///|
fn work_continuation_record_valid(
  target : WorkHandoffTarget,
  record : Json,
) -> Bool {
  handoff_text(record, "schema") == "moondesk.work-continuation.v1" &&
  work_continuation_matches(target, record) &&
  handoff_text(record, "continuation_id") != "" &&
  handoff_text(record, "command_id") != "" &&
  handoff_text(record, "command_id") != target.command_id &&
  handoff_text(record, "session_id") == target.session_id
}

///|
fn work_continuation_reconcile(
  target : WorkHandoffTarget,
  state : WorkContinuationState,
  response : Json,
) -> WorkContinuationState {
  let records = handoff_json_array(response, "continuations").filter(record => {
    work_continuation_record_valid(target, record)
  })
  let selected = handoff_field(response, "continuation")
  let id = handoff_text(state.operation, "continuation_id")
  let valid = work_continuation_record_valid(target, selected) &&
    handoff_text(selected, "continuation_id") == id &&
    handoff_text(selected, "client_turn_id") ==
    handoff_text(state.operation, "client_turn_id") &&
    handoff_text(selected, "instruction") ==
    handoff_text(state.operation, "instruction") &&
    handoff_text(selected, "prior_result_command_id") ==
    handoff_text(state.operation, "prior_result_command_id")
  if valid &&
    !records.any(record => handoff_text(record, "continuation_id") == id) {
    records.push(selected)
  }
  let phase = if id == "" {
    "draft"
  } else if handoff_text(response, "continuation_state") == "conflict" {
    "conflict"
  } else if valid {
    "saved"
  } else if handoff_text(response, "continuation_state") == "not_found" {
    "missing"
  } else {
    "uncertain"
  }
  {
    ..state,
    records,
    phase,
    error: if phase == "missing" && state.admission_possible {
      "This exact operation is not visible yet, but an earlier submission may still arrive. Retry only the same saved identity; do not discard it or create a new one."
    } else if phase == "missing" && state.error != "" {
      state.error
    } else if phase == "conflict" {
      "Captured-input conflict: " +
      handoff_text(response, "continuation_message") +
      ". Native work remains visible. Do not discard or create another command to bypass this conflict."
    } else if id != "" && !valid && phase != "missing" {
      "Cannot verify this saved operation yet. Refresh exact work before retrying; no new command will be created."
    } else {
      ""
    },
    pending_guidance: handoff_json_array(response, "pending_guidance"),
    guidance_state: handoff_text(response, "pending_guidance_state"),
  }
}

///|
fn work_continuation_settled(record : Json) -> Bool {
  ["completed", "failed", "cancelled", "invalid", "delivered"].contains(
    handoff_text(record, "state"),
  )
}

///|
fn work_continuation_input_verified(record : Json) -> Bool {
  handoff_text(record, "input_status") == "verified"
}

///|
fn work_continuation_current(state : WorkContinuationState) -> Json {
  state.records
  .filter(record => {
    handoff_text(record, "continuation_id") ==
    handoff_text(state.operation, "continuation_id")
  })
  .get(0)
  .unwrap_or(Json::null())
}

///|
fn work_continuation_submit_body(
  target : WorkHandoffTarget,
  state : WorkContinuationState,
  id : String,
) -> Json {
  {
    "schema": "moondesk.work-continuation-request.v1",
    "operation": "submit",
    "continuation_id": id,
    "client_turn_id": "turn-" + id,
    "source": work_continuation_source(target),
    "prior_result_command_id": state.prior_command,
    "instruction": state.draft,
  }
}

///|
fn work_continuation_key(target : WorkHandoffTarget) -> String {
  "moondesk.work-continuation.v1:" +
  work_continuation_source(target).stringify()
}

///|
#cfg(target="js")
extern "js" fn work_continuation_read_saved(key : String) -> String =
  #| key => { try { return globalThis.localStorage?.getItem(key) || 'null'; } catch (_) { return 'null'; } }

///|
#cfg(target="js")
extern "js" fn work_continuation_write(
  key : String,
  body : String,
  possible : Bool,
) -> Bool =
  #| (key, body, possible) => { try { if (!globalThis.localStorage) return false; const mark=possible?'possible':'not_sent'; globalThis.localStorage.setItem(key, body); globalThis.localStorage.setItem(key+':dispatch',mark); return globalThis.localStorage.getItem(key) === body && globalThis.localStorage.getItem(key+':dispatch') === mark; } catch (_) { return false; } }

///|
fn work_continuation_store(key : String, body : String) -> Bool {
  work_continuation_write(key, body, true)
}

///|
#cfg(target="js")
extern "js" fn work_continuation_dispatch_possible(key : String) -> Bool =
  #| key => { try { return globalThis.localStorage?.getItem(key+':dispatch') !== 'not_sent'; } catch (_) { return true; } }

///|
#cfg(target="js")
extern "js" fn work_continuation_forget(key : String) =
  #| key => { try { globalThis.localStorage?.removeItem(key); globalThis.localStorage?.removeItem(key+':dispatch'); } catch (_) {} }

///|
#cfg(target="js")
extern "js" fn work_continuation_nonce() -> String =
  #| () => 'followup-' + (globalThis.crypto?.randomUUID ? globalThis.crypto.randomUUID() : Date.now() + '-' + Math.random().toString(36).slice(2))

///|
#cfg(target="js")
extern "js" fn work_continuation_read_url(base : String, id : String) -> String =
  #| (base, id) => id ? base + '&continuation_id=' + encodeURIComponent(id) : base

///|
#cfg(target="js")
extern "js" fn work_continuation_return_url(
  back : String,
  task : String,
  run : String,
  id : String,
  command : String,
) -> String =
  #| (back, task, run, id, command) => { try { const url = new URL(back); if (!['http:','https:'].includes(url.protocol) || url.username || url.password || url.searchParams.get('task') !== task) return ''; url.searchParams.set('continuation_id',id); url.searchParams.set('continuation_command',command); url.searchParams.set('source_run',run); return url.href; } catch (_) { return ''; } }
