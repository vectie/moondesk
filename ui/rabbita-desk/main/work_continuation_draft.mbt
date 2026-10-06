///|
/// This key is deliberately separate from immutable submitted-operation recovery.
/// Nothing in a local draft is executable or submitted by restoration.
fn work_continuation_draft_key(target : WorkHandoffTarget) -> String {
  "moondesk.work-continuation-draft.v1:" +
  work_continuation_source(target).stringify()
}

///|
fn work_continuation_draft_body(
  target : WorkHandoffTarget,
  text : String,
  prior : String,
) -> Json {
  {
    "schema": "moondesk.work-continuation-draft.v1",
    "source": work_continuation_source(target),
    "prior_result_command_id": prior,
    "text": text,
  }
}

///|
fn work_continuation_draft_identity_valid(target : WorkHandoffTarget) -> Bool {
  [
    target.task_id,
    target.run_id,
    target.session_id,
    target.command_id,
    target.book_root,
  ].all(value => value != "" && value.length() <= 8192)
}

///|
fn work_continuation_draft_valid(
  target : WorkHandoffTarget,
  draft : Json,
) -> Bool {
  guard draft is Object(fields) && fields.length() == 4 else { return false }
  let source = handoff_field(draft, "source")
  guard source is Object(identity) && identity.length() == 5 else {
    return false
  }
  work_continuation_draft_identity_valid(target) &&
  handoff_text(draft, "schema") == "moondesk.work-continuation-draft.v1" &&
  source == work_continuation_source(target) &&
  handoff_field(draft, "text") is String(text) &&
  text != "" &&
  text.length() <= 65536 &&
  handoff_text(draft, "prior_result_command_id") != "" &&
  handoff_text(draft, "prior_result_command_id").length() <= 8192
}

///|
fn work_continuation_draft_restore(
  target : WorkHandoffTarget,
  state : WorkContinuationState,
) -> WorkContinuationState {
  if !state.enabled || !work_continuation_draft_identity_valid(target) {
    return state
  }
  let raw = work_continuation_draft_read(work_continuation_draft_key(target))
  if raw == "unavailable" {
    return { ..state, draft_status: "storage_failed", }
  }
  if raw == "missing" {
    return { ..state, draft_status: "empty", }
  }
  let saved = @json.parse(raw) catch { _ => Json::null() }
  if !work_continuation_draft_valid(target, saved) {
    return { ..state, draft_status: "invalid", }
  }
  {
    ..state,
    draft: handoff_text(saved, "text"),
    prior_command: handoff_text(saved, "prior_result_command_id"),
    draft_status: "restored",
  }
}

///|
/// Save synchronously before returning the input transition. There is no delayed
/// save callback that can lose the last keystroke or overwrite a newer editor.
fn work_continuation_draft_save(
  target : WorkHandoffTarget,
  state : WorkContinuationState,
) -> WorkContinuationState {
  let status = if !work_continuation_draft_identity_valid(target) ||
    state.draft.length() > 65536 ||
    state.prior_command.length() > 8192 {
    "too_large"
  } else if work_continuation_draft_write(
      work_continuation_draft_key(target),
      if state.draft == "" {
        ""
      } else {
        work_continuation_draft_body(target, state.draft, state.prior_command).stringify()
      },
    ) {
    if state.draft == "" {
      "empty"
    } else {
      "saved"
    }
  } else {
    "storage_failed"
  }
  let next = { ..state, draft_status: status, }
  work_continuation_draft_unload_guard(work_continuation_draft_unsaved(next))
  next
}

///|
fn work_continuation_draft_unsaved(state : WorkContinuationState) -> Bool {
  state.draft != "" &&
  ["storage_failed", "too_large"].contains(state.draft_status) &&
  ["draft", "saving", "storage_failed"].contains(state.phase)
}

///|
fn work_continuation_draft_allow_departure(
  state : WorkContinuationState,
) -> Bool {
  if !work_continuation_draft_unsaved(state) {
    return true
  }
  if !work_continuation_draft_confirm_leave() {
    return false
  }
  work_continuation_draft_unload_guard(false)
  true
}

///|
fn work_continuation_draft_prior_valid(
  target : WorkHandoffTarget,
  state : WorkContinuationState,
) -> Bool {
  state.prior_command == target.command_id ||
  state.records.any(record => {
    work_continuation_record_valid(target, record) &&
    handoff_text(record, "command_id") == state.prior_command &&
    work_continuation_settled(record) &&
    work_continuation_input_verified(record)
  })
}

///|
/// Retire only a canonically confirmed exact input. Failed, delayed, conflicting
/// and uncertain submissions keep both the draft and existing operation record.
fn work_continuation_draft_retire(
  target : WorkHandoffTarget,
  state : WorkContinuationState,
) -> WorkContinuationState {
  let record = work_continuation_current(state)
  if state.phase != "saved" ||
    handoff_text(record, "admission") != "accepted" ||
    !work_continuation_input_verified(record) {
    return state
  }
  let expected = work_continuation_draft_body(
    target,
    handoff_text(state.operation, "instruction"),
    handoff_text(state.operation, "prior_result_command_id"),
  ).stringify()
  {
    ..state,
    draft_status: if work_continuation_draft_remove_matching(
        work_continuation_draft_key(target),
        expected,
      ) {
      "retired"
    } else {
      "retire_failed"
    },
  }
}

///|
fn work_continuation_draft_status(state : WorkContinuationState) -> String {
  match state.draft_status {
    "saved" =>
      "Draft saved on this browser only. Reopen this exact work to continue; nothing has been submitted."
    "restored" =>
      "Unsent draft restored from this browser. Review it before submitting."
    "storage_failed" =>
      "Draft not saved: browser storage is unavailable or full. Keep this page open and copy your text before leaving; an older saved draft may return."
    "invalid" =>
      "Stored draft could not be read or did not match this exact work. Nothing was restored or submitted."
    "too_large" =>
      "Draft not saved: the local draft limit was exceeded. Copy your text before leaving."
    "retire_failed" =>
      "Submission is confirmed, but its old local draft could not be cleared. The saved operation remains authoritative."
    _ =>
      "Unsent drafts stay in this browser for this exact work. Nothing is submitted until you choose Capture and start."
  }
}

///|
#cfg(target="js")
extern "js" fn work_continuation_draft_read(key : String) -> String =
  #| key => { try { const storage = globalThis.localStorage; if (!storage) return 'unavailable'; const raw = storage.getItem(key); return raw === null ? 'missing' : (typeof raw === 'string' && raw.length <= 655360 ? raw : 'invalid'); } catch (_) { return 'unavailable'; } }

///|
#cfg(target="js")
extern "js" fn work_continuation_draft_write(
  key : String,
  body : String,
) -> Bool =
  #| (key, body) => { try { const storage = globalThis.localStorage; if (!storage || body.length > 655360) return false; if (body === '') { if (storage.getItem(key) === null) return true; storage.removeItem(key); return storage.getItem(key) === null; } if (storage.getItem(key) === body) return true; storage.setItem(key, body); return storage.getItem(key) === body; } catch (_) { return false; } }

///|
#cfg(target="js")
extern "js" fn work_continuation_draft_remove_matching(
  key : String,
  expected : String,
) -> Bool =
  #| (key, expected) => { try { const storage = globalThis.localStorage; if (!storage) return false; const saved = storage.getItem(key); if (saved === null || saved !== expected) return true; storage.removeItem(key); return storage.getItem(key) === null; } catch (_) { return false; } }

///|
#cfg(target="js")
extern "js" fn work_continuation_draft_confirm_leave() -> Bool =
  #| () => typeof globalThis.confirm === 'function' && globalThis.confirm('Your follow-up draft is not saved. Cancel to keep it open and retry saving or copy your text. Leave without saving?')

///|
#cfg(target="js")
extern "js" fn work_continuation_draft_unload_guard(unsaved : Bool) =
  #| unsaved => { const key = '__moondeskUnsentFollowupUnload'; if (!globalThis.addEventListener || !globalThis.removeEventListener || Boolean(globalThis[key]) === unsaved) return; if (globalThis[key]) { globalThis.removeEventListener('beforeunload', globalThis[key]); delete globalThis[key]; } if (unsaved) { const handler = event => { event.preventDefault(); event.returnValue = ''; }; globalThis[key] = handler; globalThis.addEventListener('beforeunload', handler); } }
