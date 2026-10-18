///|
fn work_human_revision_post(
  dispatch : Dispatch[Msg],
  generation : Int32,
  request : Int32,
  operation : String,
  body : Json,
) -> @rabbita.Cmd {
  @rabbita.batch([
    @http.post(@desk.mooncode_work_human_revisions_url())
    .with_json(body)
    .expect_json(result => {
      dispatch(
        WorkHandoff(
          HumanRevision(
            RevisionReplied(
              generation,
              request,
              operation,
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
      dispatch(
        WorkHandoff(HumanRevision(RevisionTimedOut(generation, request))),
      ),
      10000,
    ),
  ])
}

///|
fn update_work_human_revision(
  dispatch : Dispatch[Msg],
  msg : WorkHumanRevisionMsg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  let handoff = model.work_handoff
  guard handoff.target is Some(target) else { return (@rabbita.none, model) }
  let state = handoff.human_revision
  if !work_continuation_location_matches(
      handoff_target_query(
        target.task_id,
        target.run_id,
        target.session_id,
        target.command_id,
        target.book_root,
        target.return_to,
      ),
    ) ||
    !work_output_location_matches(handoff.output_hint) {
    return (@rabbita.none, model)
  }
  if msg is RevisionCopy {
    return (copy_text_to_clipboard_cmd(state.draft), model)
  }
  guard state.enabled &&
    work_human_revision_location_editable() &&
    handoff.canonical is Some(canonical) else {
    return (@rabbita.none, model)
  }
  let (command, next) = match msg {
    RevisionOpen => {
      if handoff.phase != "ready" ||
        handoff_text(handoff.output, "state") != "ready" ||
        !["idle", "open_failed", "saved"].contains(state.phase) {
        return (@rabbita.none, model)
      }
      let request = state.request + 1
      let body : Json = {
        "operation": "open",
        "source": work_continuation_source(target),
        "output": handoff.output_hint,
      }
      (
        work_human_revision_post(
          dispatch,
          handoff.generation,
          request,
          "open",
          body,
        ),
        {
          ..state,
          phase: "opening",
          request,
          message: "Opening the current file for a human edit…",
        },
      )
    }
    RevisionDraft(value) => {
      if state.phase != "editing" {
        return (@rabbita.none, model)
      }
      let next = {
        ..state,
        draft: value,
        message: "Your edit is a draft until you save a revision for this task.",
      }
      (
        @rabbita.none,
        work_human_revision_remember(target, handoff.output_hint, next),
      )
    }
    RevisionCopy => (copy_text_to_clipboard_cmd(state.draft), state)
    RevisionRebase => {
      guard state.phase == "conflict" && state.current_content is Some(current) else {
        return (@rabbita.none, model)
      }
      let next = {
        ..state,
        phase: "editing",
        baseline: current,
        base_digest: "",
        operation: Json::null(),
        current_content: None,
        message: "The displayed current file is now your baseline. Your draft is preserved; review it before saving a new revision.",
      }
      (
        @rabbita.none,
        work_human_revision_remember(target, handoff.output_hint, next),
      )
    }
    RevisionSave => {
      if handoff.phase != "ready" ||
        !["editing", "retry"].contains(state.phase) ||
        work_human_revision_utf8_length(state.draft) > 262144 ||
        state.draft.contains("\u0000") ||
        (state.phase == "editing" && state.draft == state.baseline) {
        return (@rabbita.none, model)
      }
      let operation = if state.operation is Object(_) {
        state.operation
      } else {
        work_human_revision_request(
          target,
          handoff.output_hint,
          state,
          work_continuation_nonce(),
        )
      }
      let captured = work_human_revision_remember(target, handoff.output_hint, {
        ..state,
        operation,
      })
      if !captured.local_saved {
        (
          @rabbita.none,
          {
            ..state,
            local_saved: false,
            message: "The exact save operation could not be retained in this browser. Nothing was sent. Retry saving or copy your edit.",
          },
        )
      } else {
        let request = state.request + 1
        (
          work_human_revision_post(
            dispatch,
            handoff.generation,
            request,
            "save",
            operation,
          ),
          {
            ..captured,
            request,
            phase: "saving",
            message: "Retaining this exact human revision separately from the working file…",
          },
        )
      }
    }
    RevisionTimedOut(generation, request) => {
      if generation != handoff.generation ||
        request != state.request ||
        !["saving", "opening"].contains(state.phase) {
        return (@rabbita.none, model)
      }
      (
        @rabbita.none,
        {
          ..state,
          phase: if state.phase == "opening" {
            if state.revision is Object(_) {
              "saved"
            } else {
              "open_failed"
            }
          } else {
            "retry"
          },
          message: "The response is taking too long. Recover the same operation; your draft and identity are retained.",
        },
      )
    }
    RevisionReplied(generation, request, operation, result) => {
      if generation != handoff.generation ||
        request != state.request ||
        (
          operation == "open" &&
          !["opening", "open_failed", "saved"].contains(state.phase)
        ) ||
        (operation == "save" && !["saving", "retry"].contains(state.phase)) {
        return (@rabbita.none, model)
      }
      let payload = match result {
        Ok(value) => value
        Err(_) => Json::null()
      }
      let message = match result {
        Err(error) => "No confirmed save response: " + error
        Ok(_) =>
          if handoff_text(payload, "message") == "" {
            "The host response could not confirm this exact operation. Retry without changing its identity."
          } else {
            handoff_text(payload, "message")
          }
      }
      if operation == "open" {
        if handoff_text(payload, "schema") ==
          "moondesk.human-revision-editor.v1" &&
          handoff_text(payload, "state") == "ready" &&
          work_human_revision_source_matches(
            target,
            handoff_field(payload, "source"),
          ) &&
          handoff_field(payload, "output") == handoff.output_hint &&
          handoff_text(payload, "workspace_id") == canonical.workspace_id &&
          handoff_field(payload, "content") is String(content) &&
          work_human_revision_utf8_length(content) <= 262144 {
          let next = {
            ..empty_work_human_revision(enabled=true),
            request: state.request,
            phase: "editing",
            baseline: content,
            draft: content,
            base_digest: handoff_text(payload, "base_digest"),
            message: "Editing a separate revision based on the current file. Saving it leaves the working file and original reviews unchanged.",
          }
          (
            @rabbita.none,
            work_human_revision_remember(target, handoff.output_hint, next),
          )
        } else {
          (
            @rabbita.none,
            {
              ..state,
              phase: if state.revision is Object(_) {
                "saved"
              } else {
                "open_failed"
              },
              message,
            },
          )
        }
      } else if work_human_revision_saved_matches(
          target,
          canonical,
          handoff.output_hint,
          state.operation,
          payload,
        ) {
        (
          @rabbita.none,
          {
            ..state,
            phase: "saved",
            revision: handoff_field(payload, "revision"),
            message: "Human revision saved and retained. Return it to MoonProj for review; this does not submit a report or accept the task.",
          },
        )
      } else if handoff_text(payload, "schema") ==
        "moondesk.human-revision-editor.v1" &&
        handoff_text(payload, "state") == "conflict" &&
        handoff_field(payload, "current_content") is String(current) {
        (
          @rabbita.none,
          {
            ..state,
            phase: "conflict",
            current_content: Some(current),
            message: "The file changed before your save. Nothing was overwritten. Your draft is preserved; inspect the current file below.",
          },
        )
      } else {
        (
          @rabbita.none,
          {
            ..state,
            phase: "retry",
            message: message +
            (if handoff_text(payload, "state") == "runtime_unavailable" {
              " Capture may already exist; return confirmation is pending native identity verification. Keep this exact operation and draft for retry."
            } else {
              " Capture may already exist; its outcome is not confirmed. Keep this exact operation and draft for retry."
            }),
          },
        )
      }
    }
  }
  work_human_revision_unload_guard(!next.local_saved)
  (command, { ..model, work_handoff: { ..handoff, human_revision: next, }, })
}
