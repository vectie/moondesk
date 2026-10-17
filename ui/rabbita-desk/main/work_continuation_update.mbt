///|
fn work_continuation_post(
  dispatch : Dispatch[Msg],
  generation : Int32,
  request : Int32,
  id : String,
  body : Json,
) -> @rabbita.Cmd {
  @rabbita.batch([
    @http.post("/api/mooncode/work-handoff/continuations")
    .with_json(body)
    .expect_json(result => {
      dispatch(
        WorkHandoff(
          FollowUp(
            Submitted(
              generation,
              request,
              id,
              match result {
                Ok(json) => Ok(json)
                Err(error) => Err(error.to_string())
              },
            ),
          ),
        ),
      )
    }),
    @rabbita.delay(
      dispatch(WorkHandoff(FollowUp(AdmissionTimeout(generation, request, id)))),
      5000,
    ),
  ])
}

///|
fn update_work_continuation(
  dispatch : Dispatch[Msg],
  msg : WorkContinuationMsg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  let handoff = model.work_handoff
  guard handoff.target is Some(target) else { return (@rabbita.none, model) }
  let state = handoff.continuation
  if !work_continuation_location_matches(
      handoff_target_query(
        target.task_id,
        target.run_id,
        target.session_id,
        target.command_id,
        target.book_root,
        target.return_to,
      ),
    ) {
    return (@rabbita.none, model)
  }
  let (command, next) = match msg {
    Draft(token, value) =>
      if state.enabled && state.phase == "draft" && token == state.draft_token {
        (
          @rabbita.none,
          work_continuation_draft_save(target, { ..state, draft: value, }),
        )
      } else {
        (@rabbita.none, state)
      }
    DiscardDraft(token) => {
      if !state.enabled || state.phase != "draft" || token != state.draft_token {
        return (@rabbita.none, model)
      }
      let cleared = work_continuation_draft_save(target, { ..state, draft: "", })
      (
        @rabbita.none,
        if cleared.draft_status == "empty" {
          { ..cleared, draft_token: work_continuation_nonce(), error: "", }
        } else {
          {
            ..state,
            draft_status: if work_continuation_draft_read(
                work_continuation_draft_key(target),
              ) ==
              work_continuation_draft_body(
                target,
                state.draft,
                state.prior_command,
              ).stringify() {
              "saved"
            } else {
              cleared.draft_status
            },
            error: "Could not discard the local draft. Your text is retained; retry when browser storage is available.",
          }
        },
      )
    }
    CopyDraft(token) =>
      if state.enabled && state.phase == "draft" && token == state.draft_token {
        (copy_text_to_clipboard_cmd(state.draft), state)
      } else {
        (@rabbita.none, state)
      }
    Prior(token, command) => {
      let valid = command == target.command_id ||
        state.records.any(record => {
          handoff_text(record, "command_id") == command &&
          work_continuation_settled(record) &&
          work_continuation_input_verified(record)
        })
      if state.enabled &&
        state.phase == "draft" &&
        valid &&
        token == state.draft_token {
        (
          @rabbita.none,
          work_continuation_draft_save(target, {
            ..state,
            prior_command: command,
            error: "",
          }),
        )
      } else {
        (@rabbita.none, state)
      }
    }
    Submit => {
      if !state.enabled ||
        handoff.phase != "ready" ||
        state.draft.trim().is_empty() ||
        state.draft.length() > 65536 ||
        !["draft", "missing"].contains(state.phase) {
        return (@rabbita.none, model)
      }
      if state.phase == "draft" &&
        !work_continuation_draft_prior_valid(target, state) {
        return (
          @rabbita.none,
          {
            ..model,
            work_handoff: {
              ..handoff,
              continuation: {
                ..state,
                error: "The draft's prior result is not verified here. Refresh exact work or choose a verified prior result before submitting.",
              },
            },
          },
        )
      }
      let body = if state.phase == "missing" {
        state.operation
      } else {
        work_continuation_submit_body(target, state, work_continuation_nonce())
      }
      let id = handoff_text(body, "continuation_id")
      let request = state.request + 1
      (
        @cmd.custom_cmd(scheduler => {
          scheduler.add(
            dispatch(
              WorkHandoff(
                FollowUp(
                  Stored(
                    handoff.generation,
                    request,
                    id,
                    work_continuation_store(
                      work_continuation_key(target),
                      body.stringify(),
                    ),
                  ),
                ),
              ),
            ),
          )
        }),
        {
          ..state,
          operation: body,
          phase: "saving",
          request,
          error: "",
          admission_possible: true,
          prior_uncertainty: state.prior_uncertainty || state.admission_possible,
        },
      )
    }
    Stored(generation, request, id, stored) => {
      if generation != handoff.generation ||
        request != state.request ||
        id != handoff_text(state.operation, "continuation_id") ||
        state.phase != "saving" {
        return (@rabbita.none, model)
      }
      if !stored {
        (
          @rabbita.none,
          {
            ..state,
            phase: "storage_failed",
            admission_possible: false,
            error: if state.prior_uncertainty {
              "This retry was not sent because browser storage failed. An earlier attempt remains uncertain; recover the same identity."
            } else {
              "This browser could not save the operation identity. Nothing was submitted. Enable local storage, then retry saving this same operation."
            },
          },
        )
      } else {
        work_continuation_draft_unload_guard(false)
        (
          work_continuation_post(
            dispatch,
            generation,
            request,
            id,
            state.operation,
          ),
          { ..state, phase: "submitting", admission_possible: true, },
        )
      }
    }
    Submitted(generation, request, id, result) => {
      if request != state.request ||
        id != handoff_text(state.operation, "continuation_id") ||
        !["submitting", "recovering", "missing", "uncertain"].contains(
          state.phase,
        ) {
        return (@rabbita.none, model)
      }
      ignore(generation)
      let error = match result {
        Ok(record) if handoff_text(record, "schema") ==
          "moondesk.work-continuation.v1" &&
          handoff_text(record, "admission") == "not_sent" =>
          "Native submission was not sent: " + handoff_text(record, "message")
        Ok(record) if work_continuation_record_valid(target, record) &&
          handoff_text(record, "continuation_id") == id &&
          handoff_text(record, "client_turn_id") ==
          handoff_text(state.operation, "client_turn_id") => ""
        Ok(_) =>
          "Submission response did not match the saved operation. Read its canonical identity before retrying."
        Err(error) =>
          "Submission response was lost or failed: " +
          error +
          ". The saved operation may already exist; checking it will not create another."
      }
      let not_sent = !state.prior_uncertainty &&
        (match result {
          Ok(record) =>
            handoff_text(record, "schema") == "moondesk.work-continuation.v1" &&
            handoff_text(record, "admission") == "not_sent"
          _ => false
        })
      (
        @rabbita.batch([
          if not_sent {
            @cmd.custom_cmd(_ => {
              ignore(
                work_continuation_write(
                  work_continuation_key(target),
                  state.operation.stringify(),
                  false,
                ),
              )
            })
          } else {
            @rabbita.none
          },
          dispatch(WorkHandoff(Resolve)),
        ]),
        { ..state, phase: "recovering", error, admission_possible: !not_sent, },
      )
    }
    Recover =>
      if state.phase == "storage_failed" {
        let id = handoff_text(state.operation, "continuation_id")
        let request = state.request + 1
        (
          @cmd.custom_cmd(scheduler => {
            scheduler.add(
              dispatch(
                WorkHandoff(
                  FollowUp(
                    Stored(
                      handoff.generation,
                      request,
                      id,
                      work_continuation_store(
                        work_continuation_key(target),
                        state.operation.stringify(),
                      ),
                    ),
                  ),
                ),
              ),
            )
          }),
          { ..state, phase: "saving", request, },
        )
      } else {
        (dispatch(WorkHandoff(Resolve)), state)
      }
    Resume => {
      if !state.enabled ||
        handoff.phase != "ready" ||
        state.phase != "saved" ||
        (
          work_continuation_settled(work_continuation_current(state)) &&
          handoff_text(work_continuation_current(state), "input_status") !=
          "missing"
        ) {
        return (@rabbita.none, model)
      }
      let id = handoff_text(state.operation, "continuation_id")
      let request = state.request + 1
      (
        @cmd.custom_cmd(scheduler => {
          scheduler.add(
            dispatch(
              WorkHandoff(
                FollowUp(
                  ResumeStored(
                    handoff.generation,
                    request,
                    id,
                    work_continuation_store(
                      work_continuation_key(target),
                      state.operation.stringify(),
                    ),
                  ),
                ),
              ),
            ),
          )
        }),
        {
          ..state,
          request,
          phase: "saving_resume",
          error: "",
          admission_possible: true,
        },
      )
    }
    ResumeStored(generation, request, id, stored) => {
      if generation != handoff.generation ||
        request != state.request ||
        id != handoff_text(state.operation, "continuation_id") ||
        state.phase != "saving_resume" {
        return (@rabbita.none, model)
      }
      if !stored {
        (
          @rabbita.none,
          {
            ..state,
            phase: "saved",
            error: "Could not save recovery identity; Resume was not sent. Retry when browser storage is available.",
          },
        )
      } else {
        let body : Json = {
          "schema": "moondesk.work-continuation-request.v1",
          "operation": "resume",
          "continuation_id": id,
          "source": work_continuation_source(target),
        }
        (
          work_continuation_post(dispatch, generation, request, id, body),
          { ..state, phase: "submitting", },
        )
      }
    }
    New => {
      if !state.enabled ||
        state.phase == "conflict" ||
        (state.phase == "missing" && state.admission_possible) ||
        (state.phase == "storage_failed" && state.prior_uncertainty) ||
        (
          !(state.operation is Null) &&
          !["missing", "storage_failed"].contains(state.phase) &&
          !work_continuation_settled(work_continuation_current(state))
        ) {
        return (@rabbita.none, model)
      }
      let draft_removed = work_continuation_draft_remove_matching(
        work_continuation_draft_key(target),
        work_continuation_draft_body(target, state.draft, state.prior_command).stringify(),
      )
      let fresh = {
        ..state,
        draft: if draft_removed {
          ""
        } else {
          state.draft
        },
        draft_status: if draft_removed {
          "empty"
        } else {
          "storage_failed"
        },
        draft_token: work_continuation_nonce(),
        prior_command: if draft_removed {
          target.command_id
        } else {
          state.prior_command
        },
        operation: Json::null(),
        admission_possible: false,
        prior_uncertainty: false,
        phase: "draft",
        error: "",
        request: state.request + 1,
      }
      (
        @cmd.custom_cmd(_ => {
          work_continuation_forget(work_continuation_key(target))
        }),
        if draft_removed {
          work_continuation_draft_restore(target, fresh)
        } else {
          fresh
        },
      )
    }
    SelectReturn(id) =>
      if state.records.any(record => {
          handoff_text(record, "continuation_id") == id &&
          handoff_text(record, "state") == "completed" &&
          handoff_text(record, "admission") == "accepted" &&
          work_continuation_input_verified(record)
        }) {
        (@rabbita.none, { ..state, selected_return: id, })
      } else {
        (@rabbita.none, state)
      }
    Poll(generation, id) => {
      if generation != handoff.generation ||
        id != handoff_text(state.operation, "continuation_id") ||
        state.phase != "saved" ||
        work_continuation_settled(work_continuation_current(state)) {
        return (@rabbita.none, model)
      }
      (dispatch(WorkHandoff(Resolve)), state)
    }
    AdmissionTimeout(generation, request, id) => {
      if generation != handoff.generation ||
        request != state.request ||
        id != handoff_text(state.operation, "continuation_id") ||
        state.phase != "submitting" {
        return (@rabbita.none, model)
      }
      (
        dispatch(WorkHandoff(Resolve)),
        {
          ..state,
          phase: "recovering",
          error: "The submission response is delayed. Reading the exact saved identity without submitting another command.",
          admission_possible: true,
        },
      )
    }
  }
  work_continuation_draft_unload_guard(work_continuation_draft_unsaved(next))
  (command, { ..model, work_handoff: { ..handoff, continuation: next, }, })
}

///|
#cfg(target="js")
extern "js" fn work_continuation_location_matches(target : String) -> Bool =
  #| target => { if (!globalThis.location) return true; const url = new URL(globalThis.location.href), expected = new URLSearchParams(target); return ['work_task','work_run','session','command','book_root','return_to'].every(key => (url.searchParams.get(key)||'') === (expected.get(key)||'')); }
