///|
fn update_work_handoff(
  dispatch : Dispatch[Msg],
  msg : WorkHandoffMsg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  let state = model.work_handoff
  if msg is FollowUp(action) {
    return update_work_continuation(dispatch, action, model)
  }
  if msg is HumanRevision(action) {
    return update_work_human_revision(dispatch, action, model)
  }
  if msg is Exit {
    return (
      @rabbita.batch([
        @cmd.custom_cmd(_ => handoff_clear_navigation()),
        sync_mooncode_context_cmd(model.selected_workspace_id, ""),
        bootstrap_cmd(dispatch),
      ]),
      {
        ..model,
        work_handoff: {
          ..empty_work_handoff(),
          generation: state.generation + 1,
        },
        selected_mooncode_session_id: "",
        mooncode_auto_select_session: false,
        mooncode_selected_session_loading: false,
      },
    )
  }
  guard state.target is Some(target) else { return (@rabbita.none, model) }
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
    !work_output_location_matches(state.output_hint) {
    return (@rabbita.none, model)
  }
  match msg {
    TeachLearning(generation, command, turn, item) =>
      match work_learning_payload(model, generation, command, turn, item) {
        Some(payload) =>
          (
            workspace_feature_signal_cmd(
              "teach-captured-work",
              payload.stringify(),
            ),
            model,
          )
        None => (@rabbita.none, model)
      }
    ReviewLearning(generation) => {
      let binding = work_learning_binding(model)
      if generation != state.generation ||
        handoff_text(binding, "binding_key") == "" {
        return (@rabbita.none, model)
      }
      let payload : Json = { "binding": binding }
      (
        workspace_feature_signal_cmd(
          "review-captured-learning",
          payload.stringify(),
        ),
        model,
      )
    }
    Resolve => {
      if state.phase == "invalid_request" ||
        state.phase == "loading" ||
        ["opening", "saving"].contains(state.human_revision.phase) {
        return (@rabbita.none, model)
      }
      let generation = state.generation + 1
      (
        @rabbita.batch([
          fetch_work_handoff_cmd(
            dispatch,
            target,
            generation,
            output=state.output_hint,
            continuation_id=handoff_text(
              state.continuation.operation,
              "continuation_id",
            ),
          ),
          @rabbita.delay(
            dispatch(WorkHandoff(LookupTimedOut(generation))),
            10000,
          ),
        ]),
        {
          ..model,
          work_handoff: {
            ..state,
            generation,
            phase: "loading",
            message: "Resolving the exact saved work in this Desk library…",
            canonical: None,
            session: None,
            session_error: "",
            output: Json::null(),
            entries: [],
            files_error: "",
          },
        },
      )
    }
    Resolved(generation, result) => {
      if state.generation != generation || state.phase != "loading" {
        return (@rabbita.none, model)
      }
      let decoded = match result {
        Ok(json) => work_handoff_decode(target, json)
        Err(error) =>
          Err(
            "Exact work lookup failed: " +
            error +
            ". Retry when the host is available.",
          )
      }
      match decoded {
        Err(message) =>
          (
            @rabbita.none,
            {
              ..model,
              work_handoff: { ..state, phase: "unavailable", message, },
            },
          )
        Ok(canonical) => {
          let response = match result {
            Ok(json) => json
            Err(_) => Json::null()
          }
          let (session, session_error) = handoff_decode_transcript(
            canonical, response,
          )
          let continuation = work_continuation_draft_retire(
            target,
            work_continuation_reconcile(target, state.continuation, response),
          )
          let next = {
            ..model,
            work_handoff: {
              ..state,
              phase: "ready",
              message: if state.human_revision.enabled &&
                !(state.output_hint is Null) {
                "Exact native identity verified. You can inspect the current output and save a separate human revision."
              } else if state.continuation.enabled {
                "Exact native identity verified. Original execution and fresh follow-ups remain separate."
              } else {
                "Exact native identity verified by this Desk host. Inspection only."
              },
              canonical: Some(canonical),
              files_loading: true,
              files_generation: state.files_generation + 1,
              directory: "",
            },
            selected_workspace_id: canonical.workspace_id,
            requested_workspace_id: canonical.workspace_id,
            selected_mooncode_session_id: canonical.session_id,
            mooncode_selected_session_loading: true,
            mooncode_auto_select_session: false,
            workspace_mode: MoonCode,
            activity: Files,
          }
          (
            @rabbita.batch([
              handoff_canonicalize_cmd(target, canonical),
              fetch_work_handoff_files_cmd(
                dispatch,
                canonical,
                generation,
                next.work_handoff.files_generation,
                "",
              ),
              if continuation.phase == "saved" &&
                !work_continuation_settled(
                  work_continuation_current(continuation),
                ) {
                @rabbita.delay(
                  dispatch(
                    WorkHandoff(
                      FollowUp(
                        Poll(
                          generation,
                          handoff_text(
                            continuation.operation,
                            "continuation_id",
                          ),
                        ),
                      ),
                    ),
                  ),
                  2500,
                )
              } else {
                @rabbita.none
              },
            ]),
            {
              ..next,
              work_handoff: {
                ..next.work_handoff,
                session,
                resume_scope: work_resume_host_scope(response, canonical),
                session_error,
                context: handoff_field(response, "context"),
                output: work_output_decode(
                  state.output_hint,
                  canonical,
                  handoff_field(response, "output"),
                ),
                continuation,
              },
            },
          )
        }
      }
    }
    LookupTimedOut(generation) => {
      if generation != state.generation || state.phase != "loading" {
        return (@rabbita.none, model)
      }
      (
        @rabbita.none,
        {
          ..model,
          work_handoff: {
            ..state,
            phase: "unavailable",
            message: "Exact work lookup is taking too long. Retry the read; saved operation identities are retained.",
          },
        },
      )
    }
    Browse(directory) => {
      guard state.canonical is Some(canonical) else {
        return (@rabbita.none, model)
      }
      if directory.has_prefix("/") ||
        directory.split("/").any(part => part == "..") {
        return (@rabbita.none, model)
      }
      let request = state.files_generation + 1
      (
        fetch_work_handoff_files_cmd(
          dispatch,
          canonical,
          state.generation,
          request,
          directory,
        ),
        {
          ..model,
          work_handoff: {
            ..state,
            directory,
            files_generation: request,
            files_loading: true,
            files_error: "",
            entries: [],
          },
        },
      )
    }
    FilesLoaded(generation, request, directory, result) => {
      if state.generation != generation ||
        state.files_generation != request ||
        state.directory != directory ||
        state.phase != "ready" {
        return (@rabbita.none, model)
      }
      match result {
        Ok(entries) =>
          (
            @rabbita.none,
            {
              ..model,
              work_handoff: {
                ..state,
                entries,
                files_loading: false,
                files_error: "",
              },
            },
          )
        Err(error) =>
          (
            @rabbita.none,
            {
              ..model,
              work_handoff: {
                ..state,
                files_loading: false,
                files_error: error,
              },
            },
          )
      }
    }
    Exit => (@rabbita.none, model)
    FollowUp(_) => (@rabbita.none, model)
    HumanRevision(_) => (@rabbita.none, model)
  }
}

///|
fn handoff_decode_transcript(
  canonical : WorkHandoffCanonical,
  json : Json,
) -> (MoonCodeSession?, String) {
  let transcript = handoff_field(json, "transcript")
  if handoff_text(transcript, "state") != "ready" {
    let message = handoff_text(transcript, "message")
    return (
      None,
      if message == "" {
        "Saved transcript is unavailable. Refresh exact work to retry."
      } else {
        message
      },
    )
  }
  match decode_mooncode_selected_session(handoff_field(json, "session")) {
    Ok(session) if session.id == canonical.session_id &&
      session.workspace_id == canonical.workspace_id &&
      handoff_normalize_root(session.cwd) ==
      handoff_normalize_root(canonical.root_path) => (Some(session), "")
    Ok(_) =>
      (
        None,
        "The transcript identity does not match the resolved work. Retry the lookup.",
      )
    Err(error) => (None, error)
  }
}

///|
/// Bound work never uses ordinary command/composer mutation actions. Explicit
/// navigation exits the binding before ordinary Desk behavior resumes.
fn work_handoff_blocks(msg : Msg) -> Bool {
  match msg {
    WorkHandoff(_)
    | ForgetResumableWork(_, _)
    | ClearResumableWork(_)
    | Bootstrap
    | RetryBootstrap
    | ToggleCommand
    | SetCommandQuery(_) => false
    _ => !work_handoff_leaves(msg)
  }
}

///|
fn work_handoff_leaves(msg : Msg) -> Bool {
  match msg {
    NewMoonCodeSession
    | SelectMoonCodeSession(_)
    | SelectWorkspace(_)
    | SelectWorkspaceMode(_)
    | SelectActivity(_)
    | SelectSearchHit(_, _) => true
    _ => false
  }
}
