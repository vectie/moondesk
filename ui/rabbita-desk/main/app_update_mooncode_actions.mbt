///|
fn update_mooncode_actions(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    CheckoutGitHubPull(number) => {
      let workspace_id = mooncode_git_workspace_id(model)
      guard workspace_id != "" &&
        !model.github_checkout_pending &&
        model.github_context is Some(context) &&
        context.state == "ready" &&
        model.git_projection is Some(projection) &&
        projection.state == "ready" &&
        model.git_projection_workspace_id == workspace_id else {
        return (@rabbita.none, model)
      }
      let mut selected : GitHubPullProjection? = None
      for pull in context.pull_requests {
        if pull.number == number &&
          !pull.head_matches &&
          github_checkout_head_valid(pull.head_oid) {
          selected = Some(pull)
          break
        }
      }
      guard selected is Some(pull) else { return (@rabbita.none, model) }
      (
        checkout_github_pull_cmd(
          dispatch,
          workspace_id,
          context.repository,
          number,
          pull.head_oid,
        ),
        {
          ..model,
          github_checkout_workspace_id: workspace_id,
          github_checkout_repository: context.repository,
          github_checkout_number: number,
          github_checkout_head_oid: pull.head_oid,
          github_checkout_pending: true,
          github_checkout_status: "Creating an isolated PR worktree…",
          github_checkout_target_workspace_id: "",
        },
      )
    }
    CheckedOutGitHubPull(workspace_id, number, head_oid, result) => {
      guard model.github_checkout_pending &&
        model.github_checkout_workspace_id == workspace_id &&
        model.github_checkout_number == number &&
        model.github_checkout_head_oid == head_oid else {
        return (@rabbita.none, model)
      }
      match result {
        Ok(reply) if reply.contract == "moondesk.github_checkout.v1" &&
          reply.repository == model.github_checkout_repository &&
          reply.number == number &&
          reply.head_oid == head_oid &&
          reply.workspace.id != "" &&
          reply.workspace.root_path != "" => {
          let workspaces = model.workspaces.filter(workspace => {
            workspace.id != reply.workspace.id
          })
          workspaces.push(reply.workspace)
          (
            @rabbita.none,
            {
              ..model,
              workspaces,
              github_checkout_pending: false,
              github_checkout_status: "PR worktree ready. Open its MoonBook to review and code there.",
              github_checkout_target_workspace_id: reply.workspace.id,
            },
          )
        }
        Ok(_) =>
          (
            @rabbita.none,
            {
              ..model,
              github_checkout_pending: false,
              github_checkout_status: "PR checkout response did not match the requested commit.",
            },
          )
        Err(error) =>
          (
            @rabbita.none,
            {
              ..model,
              github_checkout_pending: false,
              github_checkout_status: "PR checkout failed. \{error}",
            },
          )
      }
    }
    OpenCheckedOutGitHubPull => {
      let target = model.github_checkout_target_workspace_id
      guard target != "" && has_workspace(model.workspaces, target) else {
        return (@rabbita.none, model)
      }
      (dispatch(SelectWorkspace(target)), model)
    }
    ToggleMoonCodeSchedules => {
      let workspace_id = model.selected_workspace_id
      guard workspace_id != "" else { return (@rabbita.none, model) }
      if model.mooncode_schedules_visible &&
        model.mooncode_schedules_workspace_id == workspace_id {
        return (@rabbita.none, { ..model, mooncode_schedules_visible: false, })
      }
      let generation = model.mooncode_schedules_generation + 1
      let commands = [
        fetch_mooncode_schedules_cmd(dispatch, workspace_id, generation),
        @rabbita.delay(
          dispatch(MoonCodeSchedulesTimedOut(workspace_id, generation)),
          10_000,
        ),
      ]
      match model.moonclaw_daemon {
        Some(daemon) if daemon.running =>
          commands.push(fetch_mooncode_sessions_cmd(dispatch, ""))
        _ => ()
      }
      (
        @rabbita.batch(commands),
        {
          ..model,
          mooncode_schedules_visible: true,
          mooncode_schedules_workspace_id: workspace_id,
          mooncode_schedules_generation: generation,
          mooncode_schedules_loading: true,
          mooncode_schedules_error: "",
          mooncode_schedules_status: "",
        },
      )
    }
    RefreshMoonCodeSchedules => {
      let workspace_id = model.selected_workspace_id
      guard workspace_id != "" && !model.mooncode_schedules_loading else {
        return (@rabbita.none, model)
      }
      let generation = model.mooncode_schedules_generation + 1
      let commands = [
        fetch_mooncode_schedules_cmd(dispatch, workspace_id, generation),
        @rabbita.delay(
          dispatch(MoonCodeSchedulesTimedOut(workspace_id, generation)),
          10_000,
        ),
      ]
      match model.moonclaw_daemon {
        Some(daemon) if daemon.running =>
          commands.push(fetch_mooncode_sessions_cmd(dispatch, ""))
        _ => ()
      }
      (
        @rabbita.batch(commands),
        {
          ..model,
          mooncode_schedules_visible: true,
          mooncode_schedules_workspace_id: workspace_id,
          mooncode_schedules_generation: generation,
          mooncode_schedules_loading: true,
          mooncode_schedules_error: "",
        },
      )
    }
    LoadedMoonCodeSchedules(workspace_id, generation, result) => {
      guard workspace_id == model.selected_workspace_id &&
        workspace_id == model.mooncode_schedules_workspace_id &&
        generation == model.mooncode_schedules_generation &&
        model.mooncode_schedules_loading else {
        return (@rabbita.none, model)
      }
      match result {
        Ok(state) if mooncode_schedule_state_valid(state) =>
          (
            @rabbita.none,
            {
              ..model,
              mooncode_schedules_loading: false,
              mooncode_schedule_state: Some(state),
              mooncode_schedules_error: "",
            },
          )
        Ok(_) =>
          (
            @rabbita.none,
            {
              ..model,
              mooncode_schedules_loading: false,
              mooncode_schedules_error: "MoonTown returned invalid Code schedules.",
            },
          )
        Err(error) =>
          (
            @rabbita.none,
            {
              ..model,
              mooncode_schedules_loading: false,
              mooncode_schedules_error: error,
            },
          )
      }
    }
    MoonCodeSchedulesTimedOut(workspace_id, generation) => {
      guard workspace_id == model.selected_workspace_id &&
        workspace_id == model.mooncode_schedules_workspace_id &&
        generation == model.mooncode_schedules_generation &&
        model.mooncode_schedules_loading else {
        return (@rabbita.none, model)
      }
      (
        @rabbita.none,
        {
          ..model,
          mooncode_schedules_loading: false,
          mooncode_schedules_error: "MoonTown is unavailable. Your draft is safe; retry when it reconnects.",
        },
      )
    }
    SetMoonCodeScheduleId(value) =>
      (@rabbita.none, { ..model, mooncode_schedule_id_draft: value, })
    SetMoonCodeSchedulePrompt(value) =>
      (@rabbita.none, { ..model, mooncode_schedule_prompt_draft: value, })
    SetMoonCodeScheduleInterval(value) =>
      (@rabbita.none, { ..model, mooncode_schedule_interval_draft: value, })
    CreateMoonCodeSchedule => {
      let workspace_id = model.selected_workspace_id
      let id = model.mooncode_schedule_id_draft.trim().to_owned()
      let prompt = model.mooncode_schedule_prompt_draft.trim().to_owned()
      let selected_model = mooncode_selected_runtime_model(model, None)
      let minutes = @string.parse_int(
        model.mooncode_schedule_interval_draft.trim(),
      ) catch {
        _ => 0
      }
      if workspace_id == "" ||
        !mooncode_schedule_id_valid(id) ||
        prompt == "" ||
        prompt.length() > 4000 ||
        selected_model == "" ||
        minutes < 1 ||
        minutes > 43200 ||
        model.mooncode_schedules_saving {
        return (
          @rabbita.none,
          {
            ..model,
            mooncode_schedules_error: "Choose a MoonBook and model, then enter a schedule ID, prompt, and cadence in minutes.",
          },
        )
      }
      (
        mutate_mooncode_schedule_cmd(
          dispatch,
          workspace_id,
          {
            "action": "create",
            "id": id,
            "book_id": workspace_id,
            "prompt": prompt,
            "model": selected_model,
            "interval_seconds": minutes * 60,
          },
          true,
        ),
        {
          ..model,
          mooncode_schedules_saving: true,
          mooncode_schedules_error: "",
          mooncode_schedules_status: "",
        },
      )
    }
    SetMoonCodeScheduleEnabled(id, enabled) => {
      let workspace_id = model.selected_workspace_id
      guard workspace_id != "" &&
        !model.mooncode_schedules_saving &&
        model.mooncode_schedule_state is Some(state) &&
        state.schedules.any(schedule => {
          schedule.id == id && schedule.book_id == workspace_id
        }) else {
        return (@rabbita.none, model)
      }
      (
        mutate_mooncode_schedule_cmd(
          dispatch,
          workspace_id,
          { "action": if enabled { "resume" } else { "pause" }, "id": id },
          false,
        ),
        {
          ..model,
          mooncode_schedules_saving: true,
          mooncode_schedules_error: "",
          mooncode_schedules_status: "",
        },
      )
    }
    SavedMoonCodeSchedule(workspace_id, creating, result) => {
      guard model.mooncode_schedules_saving else {
        return (@rabbita.none, model)
      }
      if workspace_id != model.selected_workspace_id {
        return (@rabbita.none, { ..model, mooncode_schedules_saving: false, })
      }
      match result {
        Ok(state) if mooncode_schedule_state_valid(state) =>
          (
            @rabbita.none,
            {
              ..model,
              mooncode_schedules_saving: false,
              mooncode_schedule_state: Some(state),
              mooncode_schedule_id_draft: if creating {
                ""
              } else {
                model.mooncode_schedule_id_draft
              },
              mooncode_schedule_prompt_draft: if creating {
                ""
              } else {
                model.mooncode_schedule_prompt_draft
              },
              mooncode_schedules_status: "Code schedule saved in MoonTown.",
              mooncode_schedules_error: "",
            },
          )
        Ok(_) =>
          (
            @rabbita.none,
            {
              ..model,
              mooncode_schedules_saving: false,
              mooncode_schedules_error: "MoonTown returned an invalid schedule receipt.",
            },
          )
        Err(error) =>
          (
            @rabbita.none,
            {
              ..model,
              mooncode_schedules_saving: false,
              mooncode_schedules_error: error,
            },
          )
      }
    }
    ToggleMoonCodeJobs => {
      let session_id = model.selected_mooncode_session_id
      guard session_id != "" && selected_mooncode_session(model) is Some(_) else {
        return (@rabbita.none, model)
      }
      if model.mooncode_jobs_visible &&
        model.mooncode_jobs_session_id == session_id {
        return (@rabbita.none, { ..model, mooncode_jobs_visible: false, })
      }
      if model.mooncode_jobs_session_id == session_id &&
        model.mooncode_job_history is Some(_) {
        return (
          @rabbita.none,
          {
            ..model,
            mooncode_jobs_visible: true,
            mooncode_skills_visible: false,
          },
        )
      }
      (
        fetch_mooncode_jobs_cmd(dispatch, session_id),
        {
          ..model,
          mooncode_jobs_session_id: session_id,
          mooncode_jobs_visible: true,
          mooncode_skills_visible: false,
          mooncode_jobs_loading: true,
          mooncode_jobs_error: "",
          mooncode_job_history: None,
        },
      )
    }
    RefreshMoonCodeJobs => {
      let session_id = model.selected_mooncode_session_id
      guard session_id != "" &&
        !model.mooncode_jobs_loading &&
        selected_mooncode_session(model) is Some(_) else {
        return (@rabbita.none, model)
      }
      (
        fetch_mooncode_jobs_cmd(dispatch, session_id),
        {
          ..model,
          mooncode_jobs_session_id: session_id,
          mooncode_jobs_visible: true,
          mooncode_skills_visible: false,
          mooncode_jobs_loading: true,
          mooncode_jobs_error: "",
          mooncode_job_history: None,
        },
      )
    }
    LoadedMoonCodeJobs(session_id, result) => {
      guard session_id == model.selected_mooncode_session_id &&
        session_id == model.mooncode_jobs_session_id &&
        model.mooncode_jobs_loading else {
        return (@rabbita.none, model)
      }
      match result {
        Ok(history) if mooncode_job_history_valid(history) &&
          history.session_id == session_id =>
          (
            @rabbita.none,
            {
              ..model,
              mooncode_jobs_loading: false,
              mooncode_job_history: Some(history),
              mooncode_jobs_error: "",
            },
          )
        Ok(_) =>
          (
            @rabbita.none,
            {
              ..model,
              mooncode_jobs_loading: false,
              mooncode_jobs_error: "MoonClaw returned invalid job history.",
            },
          )
        Err(error) =>
          (
            @rabbita.none,
            {
              ..model,
              mooncode_jobs_loading: false,
              mooncode_jobs_error: error,
            },
          )
      }
    }
    ToggleMoonCodeSkills => {
      let workspace_id = model.selected_workspace_id
      guard workspace_id != "" else { return (@rabbita.none, model) }
      if model.mooncode_skills_visible &&
        model.mooncode_skills_workspace_id == workspace_id {
        return (@rabbita.none, { ..model, mooncode_skills_visible: false, })
      }
      if model.mooncode_skills_workspace_id == workspace_id &&
        model.mooncode_skill_catalog is Some(_) {
        return (
          @rabbita.none,
          {
            ..model,
            mooncode_skills_visible: true,
            mooncode_jobs_visible: false,
          },
        )
      }
      (
        fetch_mooncode_skills_cmd(dispatch, workspace_id),
        {
          ..model,
          mooncode_skills_workspace_id: workspace_id,
          mooncode_skills_visible: true,
          mooncode_jobs_visible: false,
          mooncode_skills_loading: true,
          mooncode_skills_error: "",
          mooncode_skill_catalog: None,
        },
      )
    }
    RefreshMoonCodeSkills => {
      let workspace_id = model.selected_workspace_id
      guard workspace_id != "" && !model.mooncode_skills_loading else {
        return (@rabbita.none, model)
      }
      (
        fetch_mooncode_skills_cmd(dispatch, workspace_id),
        {
          ..model,
          mooncode_skills_workspace_id: workspace_id,
          mooncode_skills_visible: true,
          mooncode_jobs_visible: false,
          mooncode_skills_loading: true,
          mooncode_skills_error: "",
          mooncode_skill_catalog: None,
        },
      )
    }
    LoadedMoonCodeSkills(workspace_id, result) => {
      guard workspace_id == model.selected_workspace_id &&
        workspace_id == model.mooncode_skills_workspace_id &&
        model.mooncode_skills_loading else {
        return (@rabbita.none, model)
      }
      match result {
        Ok(catalog) if catalog.kind == "mooncode-skill-catalog" &&
          catalog.owner == "moonclaw" &&
          catalog.book_root != "" &&
          !catalog.content_included &&
          catalog.skill_count == catalog.skills.length() &&
          catalog.skills.all(skill => skill.authority == "moonclaw") =>
          (
            @rabbita.none,
            {
              ..model,
              mooncode_skills_loading: false,
              mooncode_skill_catalog: Some(catalog),
              mooncode_skills_error: "",
            },
          )
        Ok(_) =>
          (
            @rabbita.none,
            {
              ..model,
              mooncode_skills_loading: false,
              mooncode_skills_error: "MoonClaw returned an invalid skill catalog.",
            },
          )
        Err(error) =>
          (
            @rabbita.none,
            {
              ..model,
              mooncode_skills_loading: false,
              mooncode_skills_error: error,
            },
          )
      }
    }
    OpenGitHubInlineReview(number) => {
      let workspace_id = mooncode_git_workspace_id(model)
      guard model.git_projection is Some(projection) &&
        model.github_context is Some(context) &&
        context.state == "ready" &&
        context.branch == projection.branch &&
        context.pull_requests.any(pull => {
          pull.number == number &&
          pull.head_matches &&
          pull.head_oid == projection.head
        }) &&
        workspace_id != "" else {
        return (@rabbita.none, model)
      }
      if model.github_inline_draft.trim() != "" &&
        model.github_inline_number != number {
        return (
          @rabbita.none,
          {
            ..model,
            github_inline_error: "Post or discard the current line draft before opening another PR.",
          },
        )
      }
      (
        fetch_github_inline_review_cmd(
          dispatch,
          workspace_id,
          number,
          projection.head,
        ),
        {
          ..model,
          github_inline_workspace_id: workspace_id,
          github_inline_number: number,
          github_inline_loading: true,
          github_inline_error: "",
          github_inline_query: "",
          github_inline_published_url: "",
        },
      )
    }
    OpenGitHubSavedInlineDraft(selected_draft) => {
      let workspace_id = mooncode_git_workspace_id(model)
      guard model.github_context is Some(context) && workspace_id != "" else {
        return (@rabbita.none, model)
      }
      let mut selected : GitHubInlineDraftProjection? = None
      for draft in context.inline_drafts {
        if github_inline_same_draft_anchor(draft, selected_draft) {
          selected = Some(draft)
          break
        }
      }
      guard selected is Some(draft) else { return (@rabbita.none, model) }
      let number = draft.number
      if model.github_inline_draft.trim() != "" && !model.github_inline_saved {
        return (
          @rabbita.none,
          {
            ..model,
            github_inline_error: "Save or discard the current line draft first.",
          },
        )
      }
      let can_fetch = model.git_projection is Some(projection) &&
        projection.head == draft.head_oid &&
        context.state == "ready" &&
        context.pull_requests.any(pull => {
          pull.number == number && pull.head_matches
        })
      (
        if can_fetch {
          fetch_github_inline_review_cmd(
            dispatch,
            workspace_id,
            number,
            draft.head_oid,
          )
        } else {
          @rabbita.none
        },
        {
          ..model,
          github_inline_workspace_id: workspace_id,
          github_inline_number: number,
          github_inline_review: None,
          github_inline_loading: can_fetch,
          github_inline_query: "",
          github_inline_error: if can_fetch {
            ""
          } else {
            "The saved line draft is available locally. Refresh the PR before posting."
          },
          github_inline_path: draft.path,
          github_inline_hunk: draft.hunk,
          github_inline_side: draft.side,
          github_inline_line: draft.line,
          github_inline_draft: draft.body,
          github_inline_record: Some(draft),
          github_inline_saved: true,
          github_inline_published_url: "",
        },
      )
    }
    LoadedGitHubInlineReview(workspace_id, number, head, result) => {
      guard workspace_id == mooncode_git_workspace_id(model) &&
        model.github_inline_workspace_id == workspace_id &&
        model.github_inline_number == number &&
        model.git_projection is Some(projection) &&
        projection.head == head else {
        return (@rabbita.none, model)
      }
      match result {
        Ok(review) if review.state == "ready" &&
          review.head_oid == head &&
          review.branch == projection.branch &&
          review.number == number => {
          let mut retained_record = model.github_inline_record
          let mut retained_body = model.github_inline_draft
          let mut saved = model.github_inline_saved
          if retained_body == "" {
            for draft in review.drafts {
              if draft.number == number {
                retained_record = Some(draft)
                retained_body = draft.body
                saved = true
                break
              }
            }
          }
          let mut selected_path = model.github_inline_path
          if selected_path == "" && retained_record is Some(draft) {
            selected_path = draft.path
          }
          if !review.files.any(file => file.path == selected_path) {
            selected_path = if review.files.is_empty() {
              ""
            } else {
              review.files[0].path
            }
          }
          let mut selected_hunk = model.github_inline_hunk
          let mut selected_side = model.github_inline_side
          let mut selected_line = model.github_inline_line
          if selected_hunk == "" && retained_record is Some(draft) {
            selected_hunk = draft.hunk
            selected_side = draft.side
            selected_line = draft.line
          }
          let expected_digest = match retained_record {
            Some(draft) => draft.digest
            None => ""
          }
          if selected_hunk != "" &&
            !review.files.any(file => {
              file.path == selected_path &&
              (expected_digest == "" || file.digest == expected_digest) &&
              file.patch.contains(selected_hunk)
            }) {
            selected_hunk = ""
            selected_side = ""
            selected_line = 0
          }
          (
            @rabbita.none,
            {
              ..model,
              github_inline_review: Some(review),
              github_inline_loading: false,
              github_inline_error: if retained_body != "" && selected_line == 0 {
                "The PR patch changed. Select a fresh line before posting your retained draft."
              } else {
                ""
              },
              github_inline_path: selected_path,
              github_inline_hunk: selected_hunk,
              github_inline_side: selected_side,
              github_inline_line: selected_line,
              github_inline_draft: retained_body,
              github_inline_record: retained_record,
              github_inline_saved: saved,
            },
          )
        }
        Ok(_) =>
          (
            @rabbita.none,
            {
              ..model,
              github_inline_review: None,
              github_inline_loading: false,
              github_inline_error: "GitHub PR file response is stale.",
            },
          )
        Err(error) =>
          (
            @rabbita.none,
            {
              ..model,
              github_inline_review: None,
              github_inline_loading: false,
              github_inline_error: error,
            },
          )
      }
    }
    CloseGitHubInlineReview =>
      if (model.github_inline_draft.trim() != "" && !model.github_inline_saved) ||
        model.github_inline_saving ||
        model.github_inline_saving_draft {
        (
          @rabbita.none,
          {
            ..model,
            github_inline_error: "Post or discard the line draft before closing remote review.",
          },
        )
      } else {
        (
          @rabbita.none,
          {
            ..model,
            github_inline_workspace_id: "",
            github_inline_number: 0,
            github_inline_review: None,
            github_inline_loading: false,
            github_inline_error: "",
            github_inline_query: "",
            github_inline_path: "",
            github_inline_hunk_index: 0,
            github_inline_hunk: "",
            github_inline_side: "",
            github_inline_line: 0,
            github_inline_draft: "",
            github_inline_record: None,
            github_inline_saved: false,
            github_inline_published_url: "",
          },
        )
      }
    SetGitHubInlineQuery(query) =>
      (@rabbita.none, { ..model, github_inline_query: query, })
    SelectGitHubInlineFile(path) =>
      if model.github_inline_saving || model.github_inline_saving_draft {
        (@rabbita.none, model)
      } else if model.github_inline_draft.trim() != "" &&
        !model.github_inline_saved &&
        path != model.github_inline_path {
        (
          @rabbita.none,
          {
            ..model,
            github_inline_error: "Save or discard the current line draft before choosing another file.",
          },
        )
      } else if model.github_inline_review is Some(review) &&
        review.files.any(file => file.path == path) {
        let moving = path != model.github_inline_path
        (
          @rabbita.none,
          {
            ..model,
            github_inline_path: path,
            github_inline_hunk_index: if moving {
              0
            } else {
              model.github_inline_hunk_index
            },
            github_inline_hunk: if moving {
              ""
            } else {
              model.github_inline_hunk
            },
            github_inline_side: if moving {
              ""
            } else {
              model.github_inline_side
            },
            github_inline_line: if moving {
              0
            } else {
              model.github_inline_line
            },
            github_inline_draft: if moving {
              ""
            } else {
              model.github_inline_draft
            },
            github_inline_record: if moving {
              None
            } else {
              model.github_inline_record
            },
            github_inline_saved: if moving {
              false
            } else {
              model.github_inline_saved
            },
            github_inline_error: "",
            github_inline_published_url: "",
          },
        )
      } else {
        (@rabbita.none, model)
      }
    SelectGitHubInlineHunk(index) =>
      if model.github_inline_draft.trim() != "" &&
        !model.github_inline_saved &&
        index != model.github_inline_hunk_index {
        (
          @rabbita.none,
          {
            ..model,
            github_inline_error: "Save or discard the current line draft before choosing another hunk.",
          },
        )
      } else if model.github_inline_review is Some(review) &&
        index >= 0 &&
        review.files.any(file => {
          file.path == model.github_inline_path &&
          index < git_diff_hunks(file.patch).length()
        }) {
        let moving = index != model.github_inline_hunk_index
        (
          @rabbita.none,
          {
            ..model,
            github_inline_hunk_index: index,
            github_inline_hunk: if moving {
              ""
            } else {
              model.github_inline_hunk
            },
            github_inline_side: if moving {
              ""
            } else {
              model.github_inline_side
            },
            github_inline_line: if moving {
              0
            } else {
              model.github_inline_line
            },
            github_inline_draft: if moving {
              ""
            } else {
              model.github_inline_draft
            },
            github_inline_record: if moving {
              None
            } else {
              model.github_inline_record
            },
            github_inline_saved: if moving {
              false
            } else {
              model.github_inline_saved
            },
            github_inline_error: "",
          },
        )
      } else {
        (@rabbita.none, model)
      }
    SelectGitHubInlineLine(hunk, side, line) =>
      if model.github_inline_saving || model.github_inline_saving_draft {
        (@rabbita.none, model)
      } else if model.github_inline_draft.trim() != "" &&
        !model.github_inline_saved &&
        (
          hunk != model.github_inline_hunk ||
          side != model.github_inline_side ||
          line != model.github_inline_line
        ) {
        (
          @rabbita.none,
          {
            ..model,
            github_inline_error: "Save or discard the current line draft before choosing another line.",
          },
        )
      } else if model.github_inline_review is Some(review) &&
        review.files.any(file => {
          file.path == model.github_inline_path &&
          file.commentable &&
          git_diff_hunks(file.patch).any(rows => rows.any(row => row == hunk))
        }) &&
        ["left", "right"].contains(side) &&
        line > 0 {
        let moving = hunk != model.github_inline_hunk ||
          side != model.github_inline_side ||
          line != model.github_inline_line
        (
          @rabbita.none,
          {
            ..model,
            github_inline_hunk: hunk,
            github_inline_side: side,
            github_inline_line: line,
            github_inline_draft: if moving {
              ""
            } else {
              model.github_inline_draft
            },
            github_inline_record: if moving {
              None
            } else {
              model.github_inline_record
            },
            github_inline_saved: if moving {
              false
            } else {
              model.github_inline_saved
            },
            github_inline_error: "",
            github_inline_published_url: "",
          },
        )
      } else {
        (@rabbita.none, model)
      }
    SetGitHubInlineDraft(value) =>
      if model.github_inline_saving || model.github_inline_saving_draft {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            github_inline_draft: value,
            github_inline_saved: false,
            github_inline_error: "",
            github_inline_published_url: "",
          },
        )
      }
    DiscardGitHubInlineDraft =>
      if model.github_inline_saving || model.github_inline_saving_draft {
        (@rabbita.none, model)
      } else if model.github_inline_record is Some(draft) &&
        model.github_context is Some(context) {
        (
          save_github_inline_draft_cmd(
            dispatch,
            model.github_inline_workspace_id,
            context.repository,
            draft,
            true,
          ),
          {
            ..model,
            github_inline_saving_draft: true,
            github_inline_error: "",
          },
        )
      } else if model.github_inline_record is Some(_) {
        (
          @rabbita.none,
          {
            ..model,
            github_inline_error: "The saved draft could not be found for this MoonBook. Refresh repository changes.",
          },
        )
      } else {
        (
          @rabbita.none,
          {
            ..model,
            github_inline_draft: "",
            github_inline_saved: false,
            github_inline_error: "",
          },
        )
      }
    SaveGitHubInlineDraft => {
      guard model.github_context is Some(context) &&
        model.github_inline_workspace_id == mooncode_git_workspace_id(model) &&
        !model.github_inline_saving &&
        !model.github_inline_saving_draft &&
        model.github_inline_draft.trim() != "" &&
        model.github_inline_draft.length() <= 4000 else {
        return (@rabbita.none, model)
      }
      if model.github_inline_review is Some(_) &&
        (model.github_inline_hunk == "" || model.github_inline_line <= 0) {
        return (@rabbita.none, model)
      }
      let mut draft = model.github_inline_record
      if model.github_inline_review is Some(review) {
        for file in review.files {
          if file.path == model.github_inline_path &&
            model.github_inline_hunk != "" &&
            model.github_inline_line > 0 {
            draft = Some({
              number: review.number,
              head_oid: review.head_oid,
              base_oid: review.base_oid,
              path: file.path,
              digest: file.digest,
              hunk: model.github_inline_hunk,
              side: model.github_inline_side,
              line: model.github_inline_line,
              body: model.github_inline_draft,
            })
            break
          }
        }
      }
      guard draft is Some(value) else { return (@rabbita.none, model) }
      let value = { ..value, body: model.github_inline_draft, }
      (
        save_github_inline_draft_cmd(
          dispatch,
          model.github_inline_workspace_id,
          context.repository,
          value,
          false,
        ),
        {
          ..model,
          github_inline_record: Some(value),
          github_inline_saving_draft: true,
          github_inline_error: "",
        },
      )
    }
    SavedGitHubInlineDraft(workspace_id, number, head, discard, result) => {
      guard workspace_id == model.github_inline_workspace_id &&
        number == model.github_inline_number &&
        model.github_inline_record is Some(record) &&
        record.head_oid == head else {
        return (@rabbita.none, model)
      }
      let updated_context = match model.github_context {
        Some(context) => {
          let drafts = context.inline_drafts.filter(item => {
            !github_inline_same_draft_anchor(item, record)
          })
          if !discard {
            drafts.push(record)
          }
          Some({ ..context, inline_drafts: drafts, })
        }
        None => None
      }
      match result {
        Ok(_) if discard =>
          (
            @rabbita.none,
            {
              ..model,
              github_context: updated_context,
              github_inline_saving_draft: false,
              github_inline_draft: "",
              github_inline_record: None,
              github_inline_saved: false,
              github_inline_error: "",
            },
          )
        Ok(_) =>
          (
            @rabbita.none,
            {
              ..model,
              github_context: updated_context,
              github_inline_saving_draft: false,
              github_inline_saved: true,
              github_inline_error: "",
            },
          )
        Err(error) =>
          (
            @rabbita.none,
            {
              ..model,
              github_inline_saving_draft: false,
              github_inline_error: error,
            },
          )
      }
    }
    PublishGitHubInlineComment => {
      let workspace_id = mooncode_git_workspace_id(model)
      guard model.github_inline_review is Some(review) &&
        model.git_projection is Some(projection) &&
        model.github_inline_workspace_id == workspace_id &&
        review.head_oid == projection.head &&
        review.branch == projection.branch &&
        !model.github_inline_saving &&
        !model.github_inline_saving_draft &&
        model.github_inline_line > 0 &&
        model.github_inline_hunk != "" &&
        model.github_inline_draft.trim() != "" &&
        model.github_inline_draft.length() <= 4000 &&
        model.github_inline_published_url == "" else {
        return (@rabbita.none, model)
      }
      let mut selected_file : GitHubInlineFileProjection? = None
      for file in review.files {
        if file.path == model.github_inline_path {
          selected_file = Some(file)
          break
        }
      }
      guard selected_file is Some(file) else { return (@rabbita.none, model) }
      (
        publish_github_inline_comment_cmd(
          dispatch,
          workspace_id,
          review,
          file,
          model.github_inline_hunk,
          model.github_inline_side,
          model.github_inline_line,
          model.github_inline_draft,
        ),
        { ..model, github_inline_saving: true, github_inline_error: "", },
      )
    }
    PublishedGitHubInlineComment(workspace_id, number, head, path, result) => {
      guard workspace_id == model.github_inline_workspace_id &&
        number == model.github_inline_number &&
        path == model.github_inline_path &&
        model.github_inline_review is Some(review) &&
        review.head_oid == head else {
        return (@rabbita.none, model)
      }
      match result {
        Ok(url) => {
          let cleanup_started = model.github_inline_saved &&
            model.github_inline_record is Some(_) &&
            model.github_context is Some(_)
          let cleanup = match
            (model.github_inline_record, model.github_context) {
            (Some(draft), Some(context)) if model.github_inline_saved =>
              save_github_inline_draft_cmd(
                dispatch,
                workspace_id,
                context.repository,
                draft,
                true,
              )
            _ => @rabbita.none
          }
          (
            cleanup,
            {
              ..model,
              github_inline_saving: false,
              github_inline_draft: "",
              github_inline_saving_draft: cleanup_started,
              github_inline_published_url: url,
              github_inline_error: "",
            },
          )
        }
        Err(error) =>
          (
            @rabbita.none,
            {
              ..model,
              github_inline_saving: false,
              github_inline_error: error,
            },
          )
      }
    }
    SetGitChangeQuery(query) =>
      (@rabbita.none, { ..model, git_change_query: query, })
    SetGitChangeFilter(filter) =>
      (
        @rabbita.none,
        {
          ..model,
          git_change_filter: if ["all", "pending", "reviewed", "needs_changes"].contains(
              filter,
            ) {
            filter
          } else {
            "all"
          },
        },
      )
    OpenGitDiff(path) => {
      if model.git_review_saving {
        return (@rabbita.none, model)
      }
      if model.git_review_note.trim() != "" &&
        model.git_diff_path != "" &&
        model.git_diff_path != path {
        return (
          @rabbita.none,
          {
            ..model,
            git_review_error: "Save or discard the current review note before opening another file.",
          },
        )
      }
      let workspace_id = mooncode_git_workspace_id(model)
      guard workspace_id != "" &&
        model.git_projection_workspace_id == workspace_id &&
        model.git_projection is Some(projection) &&
        projection.state == "ready" &&
        projection.changes.any(change => change.path == path) else {
        return (@rabbita.none, model)
      }
      (
        fetch_git_diff_cmd(dispatch, workspace_id, path, projection.head),
        {
          ..model,
          git_diff_workspace_id: workspace_id,
          git_diff_path: path,
          git_diff: None,
          git_diff_loading: true,
          git_diff_error: "",
          git_diff_hunk_index: 0,
          git_diff_selected_side: "",
          git_diff_selected_line: 0,
          git_review: None,
          git_review_note: "",
          git_review_loading: false,
          git_review_saving: false,
          git_review_error: "",
        },
      )
    }
    RefreshGitDiff => {
      if model.git_review_saving {
        return (@rabbita.none, model)
      }
      let workspace_id = mooncode_git_workspace_id(model)
      let path = model.git_diff_path
      guard workspace_id != "" &&
        path != "" &&
        model.git_diff_workspace_id == workspace_id &&
        model.git_projection is Some(projection) &&
        projection.state == "ready" &&
        projection.changes.any(change => change.path == path) else {
        return (@rabbita.none, model)
      }
      (
        fetch_git_diff_cmd(dispatch, workspace_id, path, projection.head),
        {
          ..model,
          git_diff: None,
          git_diff_loading: true,
          git_diff_error: "",
          git_review: None,
          git_review_loading: false,
          git_review_saving: false,
          git_review_error: "",
          git_diff_selected_side: "",
          git_diff_selected_line: 0,
        },
      )
    }
    LoadedGitDiff(workspace_id, path, head, result) => {
      guard model.git_diff_workspace_id == workspace_id &&
        model.git_diff_path == path &&
        model.git_diff_loading &&
        mooncode_git_workspace_id(model) == workspace_id &&
        model.git_projection is Some(projection) &&
        projection.head == head &&
        projection.changes.any(change => change.path == path) else {
        return (@rabbita.none, model)
      }
      match result {
        Ok(diff) =>
          if diff.path == path && diff.head == head {
            (
              if diff.digest != "" {
                fetch_git_review_cmd(dispatch, workspace_id, path, diff.digest)
              } else {
                @rabbita.none
              },
              {
                ..model,
                git_diff: Some(diff),
                git_diff_loading: false,
                git_diff_error: "",
                git_diff_hunk_index: 0,
                git_diff_selected_side: "",
                git_diff_selected_line: 0,
                git_review: None,
                git_review_loading: diff.digest != "",
                git_review_error: "",
              },
            )
          } else {
            (
              @rabbita.none,
              {
                ..model,
                git_diff: None,
                git_diff_loading: false,
                git_diff_error: "File diff is stale. Refresh changes and retry.",
              },
            )
          }
        Err(error) =>
          (
            @rabbita.none,
            {
              ..model,
              git_diff: None,
              git_diff_loading: false,
              git_diff_error: error,
            },
          )
      }
    }
    SelectGitDiffHunk(index) => {
      guard index >= 0 &&
        model.git_diff_workspace_id == mooncode_git_workspace_id(model) &&
        model.git_diff is Some(diff) &&
        (diff.state == "ready" || diff.state == "binary") &&
        diff.path == model.git_diff_path &&
        index < git_diff_hunks(diff.body).length() else {
        return (@rabbita.none, model)
      }
      (
        @rabbita.none,
        {
          ..model,
          git_diff_hunk_index: index,
          git_diff_selected_side: "",
          git_diff_selected_line: 0,
        },
      )
    }
    SelectGitDiffLine(side, line) => {
      guard model.git_diff is Some(diff) &&
        diff.state == "ready" &&
        model.git_diff_workspace_id == mooncode_git_workspace_id(model) &&
        model.git_diff_path == diff.path &&
        (side == "left" || side == "right") &&
        line > 0 else {
        return (@rabbita.none, model)
      }
      (
        @rabbita.none,
        { ..model, git_diff_selected_side: side, git_diff_selected_line: line, },
      )
    }
    LoadedGitReview(workspace_id, path, digest, result) => {
      guard model.git_diff_workspace_id == workspace_id &&
        model.git_diff_path == path &&
        model.git_diff is Some(diff) &&
        diff.digest == digest &&
        mooncode_git_workspace_id(model) == workspace_id else {
        return (@rabbita.none, model)
      }
      match result {
        Ok(review) if review.path == path &&
          review.digest == digest &&
          review.head == diff.head &&
          review.diff_state == diff.state =>
          (
            @rabbita.none,
            {
              ..model,
              git_review: Some(review),
              git_review_loading: false,
              git_review_error: "",
            },
          )
        Ok(_) =>
          (
            @rabbita.none,
            {
              ..model,
              git_review: None,
              git_review_loading: false,
              git_review_error: "Review changed. Refresh the file diff.",
            },
          )
        Err(error) =>
          (
            @rabbita.none,
            {
              ..model,
              git_review: None,
              git_review_loading: false,
              git_review_error: error,
            },
          )
      }
    }
    LoadedGitReviewProgress(workspace_id, generation, head, result) => {
      guard workspace_id == mooncode_git_workspace_id(model) &&
        model.git_projection_workspace_id == workspace_id &&
        model.git_projection_generation == generation &&
        model.git_projection is Some(projection) &&
        projection.head == head else {
        return (@rabbita.none, model)
      }
      match result {
        Ok(progress) if progress.state == "ready" &&
          progress.head == head &&
          progress.total == projection.changes.length() =>
          (@rabbita.none, { ..model, git_review_progress: Some(progress), })
        _ => (@rabbita.none, { ..model, git_review_progress: None, })
      }
    }
    SetGitReviewNote(note) =>
      (
        @rabbita.none,
        {
          ..model,
          git_review_note: note,
          git_review_error: if note == "" ||
            model.git_review_error.has_prefix("Write a note") {
            ""
          } else {
            model.git_review_error
          },
        },
      )
    SaveGitReview(action) => {
      guard model.git_diff is Some(diff) &&
        diff.state == "ready" &&
        diff.digest != "" &&
        model.git_diff_path == diff.path &&
        model.git_diff_workspace_id == mooncode_git_workspace_id(model) &&
        !model.git_review_saving &&
        ["reviewed", "needs_changes", "comment"].contains(action) else {
        return (@rabbita.none, model)
      }
      let note = model.git_review_note.trim().to_owned()
      if (action == "needs_changes" || action == "comment") && note == "" {
        return (
          @rabbita.none,
          {
            ..model,
            git_review_error: "Write a note before saving this review.",
          },
        )
      }
      if note.length() > 4000 {
        return (
          @rabbita.none,
          {
            ..model,
            git_review_error: "Review notes must be 4,000 characters or fewer.",
          },
        )
      }
      let hunks = git_diff_hunks(diff.body)
      let hunk = if action == "comment" &&
        model.git_diff_hunk_index < hunks.length() &&
        !hunks[model.git_diff_hunk_index].is_empty() &&
        hunks[model.git_diff_hunk_index][0].has_prefix("@@") {
        hunks[model.git_diff_hunk_index][0]
      } else {
        ""
      }
      (
        save_git_review_cmd(
          dispatch,
          model.git_diff_workspace_id,
          diff,
          action,
          note,
          hunk,
          if action == "comment" {
            model.git_diff_selected_side
          } else {
            ""
          },
          if action == "comment" {
            model.git_diff_selected_line
          } else {
            0
          },
        ),
        { ..model, git_review_saving: true, git_review_error: "", },
      )
    }
    SavedGitReview(workspace_id, path, digest, result) => {
      guard model.git_diff_workspace_id == workspace_id &&
        model.git_diff_path == path &&
        model.git_diff is Some(diff) &&
        diff.digest == digest else {
        return (@rabbita.none, model)
      }
      match result {
        Ok(_) =>
          (
            @rabbita.batch([
              fetch_git_review_cmd(dispatch, workspace_id, path, digest),
              fetch_git_review_progress_cmd(
                dispatch,
                workspace_id,
                model.git_projection_generation,
                diff.head,
              ),
            ]),
            {
              ..model,
              git_review_saving: false,
              git_review_loading: true,
              git_review_note: "",
              git_review_error: "",
            },
          )
        Err(error) =>
          (
            @rabbita.none,
            {
              ..model,
              git_review_saving: false,
              git_review: None,
              git_review_progress: None,
              git_review_error: if error.contains("409") {
                "The file changed. Refresh its diff; your note is still here."
              } else {
                error
              },
            },
          )
      }
    }
    CloseGitDiff =>
      if model.git_review_saving {
        (@rabbita.none, model)
      } else if model.git_review_note.trim() != "" {
        (
          @rabbita.none,
          {
            ..model,
            git_review_error: "Save or discard the current review note before closing the diff.",
          },
        )
      } else {
        (
          @rabbita.none,
          {
            ..model,
            git_diff_workspace_id: "",
            git_diff_path: "",
            git_diff: None,
            git_diff_loading: false,
            git_diff_error: "",
            git_diff_hunk_index: 0,
            git_diff_selected_side: "",
            git_diff_selected_line: 0,
            git_review: None,
            git_review_progress: None,
            git_review_note: "",
            git_review_loading: false,
            git_review_saving: false,
            git_review_error: "",
          },
        )
      }
    OpenGitChange(path) => {
      guard model.git_projection is Some(projection) &&
        projection.changes.any(change => change.path == path) &&
        model.git_projection_workspace_id == mooncode_git_workspace_id(model) else {
        return (@rabbita.none, model)
      }
      let (command, next) = source_pane_action(
        dispatch,
        RequestSource(path),
        model,
      )
      (command, { ..next, source_pane: { ..next.source_pane, open: true, }, })
    }
    RefreshGitRepositoryProjection(workspace_id) =>
      if workspace_id == "" || workspace_id != mooncode_git_workspace_id(model) {
        (@rabbita.none, model)
      } else if model.git_review_saving {
        (@rabbita.none, model)
      } else if model.git_review_note.trim() != "" {
        (
          @rabbita.none,
          {
            ..model,
            git_review_error: "Save or discard the current review note before refreshing changes.",
          },
        )
      } else {
        (
          fetch_git_repository_projection_cmd(
            dispatch,
            workspace_id,
            model.git_projection_generation + 1,
          ),
          {
            ..model,
            git_projection_workspace_id: workspace_id,
            git_projection_generation: model.git_projection_generation + 1,
            git_projection_loading: true,
            git_projection_error: "",
            git_diff_path: "",
            git_diff: None,
            git_diff_loading: false,
            git_diff_error: "",
            git_diff_hunk_index: 0,
            git_diff_selected_side: "",
            git_diff_selected_line: 0,
            git_review: None,
            git_review_progress: None,
            git_review_note: "",
            git_review_loading: false,
            git_review_saving: false,
            git_review_error: "",
            github_context: None,
            github_context_loading: false,
            github_context_error: "",
          },
        )
      }
    LoadedGitRepositoryProjection(workspace_id, generation, result) => {
      guard workspace_id == mooncode_git_workspace_id(model) &&
        workspace_id == model.git_projection_workspace_id &&
        generation == model.git_projection_generation else {
        return (@rabbita.none, model)
      }
      match result {
        Ok(projection) =>
          (
            @rabbita.batch([
              if projection.state == "ready" && projection.has_remote {
                fetch_github_context_cmd(
                  dispatch,
                  workspace_id,
                  projection.head,
                  projection.branch,
                )
              } else {
                @rabbita.none
              },
              if projection.state == "ready" {
                fetch_git_review_progress_cmd(
                  dispatch,
                  workspace_id,
                  generation,
                  projection.head,
                )
              } else {
                @rabbita.none
              },
            ]),
            {
              ..model,
              git_projection: Some(projection),
              git_projection_loading: false,
              git_projection_error: "",
              git_diff_path: "",
              git_diff: None,
              git_diff_loading: false,
              git_diff_error: "",
              git_diff_hunk_index: 0,
              git_diff_selected_side: "",
              git_diff_selected_line: 0,
              git_review: None,
              git_review_progress: None,
              git_review_note: "",
              git_review_loading: false,
              git_review_saving: false,
              git_review_error: "",
              github_context: None,
              github_context_loading: projection.state == "ready" &&
              projection.has_remote,
              github_context_error: "",
            },
          )
        Err(error) =>
          (
            @rabbita.none,
            {
              ..model,
              git_projection: None,
              git_review_progress: None,
              git_projection_loading: false,
              git_projection_error: error,
              github_context: None,
              github_context_loading: false,
              github_context_error: "",
            },
          )
      }
    }
    LoadedGitHubContext(workspace_id, head, branch, result) => {
      guard workspace_id == mooncode_git_workspace_id(model) &&
        model.git_projection_workspace_id == workspace_id &&
        model.git_projection is Some(projection) &&
        projection.head == head &&
        projection.branch == branch else {
        return (@rabbita.none, model)
      }
      match result {
        Ok(context) if context.branch == projection.branch ||
          context.state == "no_github_remote" ||
          context.state == "not_repository" ||
          context.state == "unavailable" =>
          (
            @rabbita.none,
            {
              ..model,
              github_context: Some(context),
              github_context_loading: false,
              github_context_error: "",
            },
          )
        Ok(_) =>
          (
            @rabbita.none,
            {
              ..model,
              github_context: None,
              github_context_loading: false,
              github_context_error: "GitHub context changed. Refresh repository changes.",
            },
          )
        Err(error) =>
          (
            @rabbita.none,
            {
              ..model,
              github_context: None,
              github_context_loading: false,
              github_context_error: error,
            },
          )
      }
    }
    BeginGitHubComment(number) => {
      let workspace_id = mooncode_git_workspace_id(model)
      guard model.github_context is Some(context) &&
        model.git_projection is Some(projection) &&
        model.git_projection_workspace_id == workspace_id &&
        context.state == "ready" &&
        context.branch == projection.branch else {
        return (@rabbita.none, model)
      }
      if model.github_comment_draft.trim() != "" &&
        (
          model.github_comment_workspace_id != workspace_id ||
          model.github_comment_number != number
        ) {
        return (
          @rabbita.none,
          {
            ..model,
            github_comment_error: "Publish or discard the current PR draft before choosing another PR.",
          },
        )
      }
      let mut selected : GitHubPullProjection? = None
      for candidate in context.pull_requests {
        if candidate.number == number {
          selected = Some(candidate)
          break
        }
      }
      guard selected is Some(pull) &&
        pull.head_matches &&
        pull.head_oid == projection.head else {
        return (
          @rabbita.none,
          {
            ..model,
            github_comment_error: "The PR head differs from local HEAD. Refresh changes.",
          },
        )
      }
      let mut saved_draft : GitHubCommentDraftProjection? = None
      for candidate in context.drafts {
        if candidate.number == number {
          saved_draft = Some(candidate)
          break
        }
      }
      let preserve_current = model.github_comment_workspace_id == workspace_id &&
        model.github_comment_number == number
      (
        @rabbita.none,
        {
          ..model,
          github_comment_workspace_id: workspace_id,
          github_comment_number: number,
          github_comment_head: if preserve_current {
            model.github_comment_head
          } else if saved_draft is Some(draft) {
            draft.head_oid
          } else {
            projection.head
          },
          github_comment_draft: if preserve_current {
            model.github_comment_draft
          } else if saved_draft is Some(draft) {
            draft.body
          } else {
            ""
          },
          github_comment_saved: if preserve_current {
            model.github_comment_saved
          } else {
            saved_draft is Some(_)
          },
          github_comment_error: "",
          github_comment_published_url: "",
        },
      )
    }
    OpenGitHubSavedDraft(number) => {
      let workspace_id = mooncode_git_workspace_id(model)
      guard workspace_id != "" &&
        model.github_context is Some(context) &&
        context.repository != "" else {
        return (@rabbita.none, model)
      }
      if model.github_comment_draft.trim() != "" &&
        (
          model.github_comment_workspace_id != workspace_id ||
          model.github_comment_number != number
        ) {
        return (
          @rabbita.none,
          {
            ..model,
            github_comment_error: "Publish or discard the current PR draft before opening another.",
          },
        )
      }
      let mut selected : GitHubCommentDraftProjection? = None
      for draft in context.drafts {
        if draft.number == number {
          selected = Some(draft)
          break
        }
      }
      guard selected is Some(draft) else { return (@rabbita.none, model) }
      (
        @rabbita.none,
        {
          ..model,
          github_comment_workspace_id: workspace_id,
          github_comment_number: number,
          github_comment_head: draft.head_oid,
          github_comment_draft: draft.body,
          github_comment_saved: true,
          github_comment_error: "",
          github_comment_published_url: "",
        },
      )
    }
    SetGitHubCommentDraft(value) =>
      if model.github_comment_number == 0 ||
        model.github_comment_saving ||
        model.github_comment_saving_draft {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            github_comment_draft: value,
            github_comment_saved: false,
            github_comment_error: "",
          },
        )
      }
    SaveGitHubCommentDraft => {
      let workspace_id = mooncode_git_workspace_id(model)
      guard model.github_comment_workspace_id == workspace_id &&
        model.github_comment_number > 0 &&
        model.github_comment_draft.trim() != "" &&
        model.github_comment_draft.length() <= 4000 &&
        !model.github_comment_saving &&
        !model.github_comment_saving_draft &&
        model.github_context is Some(context) &&
        context.repository != "" else {
        return (@rabbita.none, model)
      }
      (
        save_github_comment_draft_cmd(
          dispatch,
          workspace_id,
          context.repository,
          model.github_comment_number,
          model.github_comment_head,
          model.github_comment_draft,
          false,
        ),
        {
          ..model,
          github_comment_saving_draft: true,
          github_comment_error: "",
        },
      )
    }
    DiscardGitHubComment => {
      let workspace_id = mooncode_git_workspace_id(model)
      guard !model.github_comment_saving &&
        !model.github_comment_saving_draft &&
        model.github_comment_workspace_id == workspace_id &&
        model.github_comment_number > 0 &&
        model.github_context is Some(context) else {
        return (@rabbita.none, model)
      }
      (
        save_github_comment_draft_cmd(
          dispatch,
          workspace_id,
          context.repository,
          model.github_comment_number,
          model.github_comment_head,
          "",
          true,
        ),
        {
          ..model,
          github_comment_saving_draft: true,
          github_comment_error: "",
        },
      )
    }
    SavedGitHubCommentDraft(workspace_id, number, head, discard, result) => {
      guard model.github_comment_workspace_id == workspace_id &&
        model.github_comment_number == number &&
        model.github_comment_head == head else {
        return (@rabbita.none, model)
      }
      match result {
        Ok(_) if discard && model.github_comment_published_url == "" =>
          (
            @rabbita.none,
            {
              ..model,
              github_comment_workspace_id: "",
              github_comment_number: 0,
              github_comment_head: "",
              github_comment_draft: "",
              github_comment_saved: false,
              github_comment_saving_draft: false,
              github_comment_error: "",
            },
          )
        Ok(_) =>
          (
            @rabbita.none,
            {
              ..model,
              github_comment_draft: if discard {
                ""
              } else {
                model.github_comment_draft
              },
              github_comment_saved: !discard,
              github_comment_saving_draft: false,
              github_comment_error: "",
            },
          )
        Err(error) =>
          (
            @rabbita.none,
            {
              ..model,
              github_comment_saving_draft: false,
              github_comment_error: error,
            },
          )
      }
    }
    PublishGitHubComment => {
      let workspace_id = mooncode_git_workspace_id(model)
      guard workspace_id != "" &&
        model.github_comment_workspace_id == workspace_id &&
        model.github_comment_number > 0 &&
        !model.github_comment_saving &&
        !model.github_comment_saving_draft &&
        model.github_comment_draft.trim() != "" &&
        model.github_comment_draft.length() <= 4000 &&
        model.github_context is Some(context) &&
        model.git_projection is Some(projection) &&
        context.state == "ready" &&
        context.branch == projection.branch &&
        model.github_comment_head == projection.head &&
        context.pull_requests.any(pull => {
          pull.number == model.github_comment_number &&
          pull.head_matches &&
          pull.head_oid == projection.head
        }) else {
        return (
          @rabbita.none,
          {
            ..model,
            github_comment_error: "The PR draft is stale or too long. Refresh changes; your draft remains here.",
          },
        )
      }
      (
        publish_github_comment_cmd(
          dispatch,
          workspace_id,
          context.repository,
          context.branch,
          model.github_comment_number,
          projection.head,
          model.github_comment_draft.trim().to_owned(),
        ),
        { ..model, github_comment_saving: true, github_comment_error: "", },
      )
    }
    PublishedGitHubComment(workspace_id, number, head, result) => {
      guard model.github_comment_workspace_id == workspace_id &&
        model.github_comment_number == number &&
        model.github_comment_head == head else {
        return (@rabbita.none, model)
      }
      match result {
        Ok(url) => {
          let cleanup_available = model.github_context is Some(context) &&
            context.repository != ""
          (
            match model.github_context {
              Some(context) if context.repository != "" =>
                save_github_comment_draft_cmd(
                  dispatch,
                  workspace_id,
                  context.repository,
                  number,
                  head,
                  "",
                  true,
                )
              _ => @rabbita.none
            },
            {
              ..model,
              github_comment_saving: false,
              github_comment_saving_draft: cleanup_available,
              github_comment_error: if cleanup_available {
                ""
              } else {
                "Comment posted; the local draft could not be removed. Keep the GitHub link before retrying cleanup."
              },
              github_comment_published_url: url,
            },
          )
        }
        Err(error) =>
          (
            @rabbita.none,
            {
              ..model,
              github_comment_saving: false,
              github_comment_error: error,
            },
          )
      }
    }
    SelectMoonCodeSession(_)
    | NewMoonCodeSession
    | SetMoonCodePrompt(_)
    | PickMoonCodeImages(_)
    | MoonCodeImagesPicked(_)
    | RemoveMoonCodeImage(_)
    | SetMoonCodeModel(_)
    | SetMoonCodeReasoningEffort(_)
    | SendMoonCodeMessage(_)
    | SendMoonCodeGuidance(_)
    | RetryMoonCodeTurn(_, _)
    | CancelMoonCodeWork(_, _)
    | DecideMoonCodeTool(_, _)
    | ToggleMoonCodeSandboxFile(_, _)
    | PromoteMoonCodeSandboxReceipt(_)
    | CompletedMoonCodeSandboxPromotion(_, _)
    | SetMoonCodeSessionQuery(_)
    | BeginMoonCodeSessionRename(_)
    | SetMoonCodeSessionTitleDraft(_)
    | CancelMoonCodeSessionRename
    | SaveMoonCodeSessionRename(_)
    | ArchiveMoonCodeSession(_)
    | RestoreMoonCodeSession(_)
    | RequestDeleteMoonCodeSession(_)
    | CancelDeleteMoonCodeSession
    | ConfirmDeleteMoonCodeSession(_) =>
      update_mooncode_session_actions(dispatch, msg, model)
    CopyMoonCodeText(item_id, text) =>
      (
        @rabbita.batch([
          copy_text_to_clipboard_cmd(text),
          @rabbita.delay(dispatch(ClearMoonCodeCopy(item_id)), 1500),
        ]),
        { ..model, mooncode_copied_item_id: item_id, },
      )
    ClearMoonCodeCopy(item_id) =>
      if model.mooncode_copied_item_id == item_id {
        (@rabbita.none, { ..model, mooncode_copied_item_id: "", })
      } else {
        (@rabbita.none, model)
      }
    ManageMoonClaw(action) =>
      (
        manage_moonclaw_cmd(dispatch, action),
        {
          ..model,
          moonclaw_installing: action == "install",
          moonclaw_operation: action,
          moonclaw_operation_status: "",
          moonclaw_operation_failed: false,
          moonclaw_install_feedback: if action == "install" {
            if moonclaw_repair_available(model.moonclaw_daemon) {
              "Repairing the MoonClaw installation…"
            } else {
              "Downloading, verifying, and installing MoonClaw…"
            }
          } else {
            ""
          },
          mooncode_composer_status: if action == "install" {
            if moonclaw_repair_available(model.moonclaw_daemon) {
              "Repairing MoonClaw…"
            } else {
              "Downloading, verifying, and installing MoonClaw…"
            }
          } else {
            "Starting MoonClaw…"
          },
        },
      )
    StartMoonClawAuth(provider) =>
      (
        start_moonclaw_auth_cmd(dispatch, provider),
        {
          ..model,
          moonclaw_auth_pending: provider,
          moonclaw_auth_status: "",
          moonclaw_auth_feedback: "",
          moonclaw_auth_failed: false,
          moonclaw_setup_started: true,
        },
      )
    CheckMoonClawSetup =>
      (
        @rabbita.batch([
          fetch_moonclaw_auth_cmd(dispatch),
          fetch_moonclaw_daemon_cmd(dispatch),
        ]),
        {
          ..model,
          moonclaw_auth_pending: "check",
          moonclaw_auth_status: "",
          moonclaw_auth_feedback: "Checking Code assistance setup…",
          moonclaw_auth_failed: false,
        },
      )
    SetMoonClawOpenRouterKey(value) =>
      (@rabbita.none, { ..model, moonclaw_openrouter_key: value, })
    SaveMoonClawOpenRouterKey =>
      if model.moonclaw_openrouter_key.trim().to_owned() == "" {
        (
          @rabbita.none,
          {
            ..model,
            moonclaw_auth_status: "api_key_required",
            moonclaw_auth_feedback: "OpenRouter API key is required.",
            moonclaw_auth_failed: true,
          },
        )
      } else {
        (
          save_moonclaw_openrouter_key_cmd(
            dispatch,
            model.moonclaw_openrouter_key.trim().to_owned(),
          ),
          {
            ..model,
            moonclaw_auth_pending: "openrouter",
            moonclaw_auth_status: "",
            moonclaw_auth_feedback: "",
            moonclaw_auth_failed: false,
            moonclaw_setup_started: true,
          },
        )
      }
    RefreshMoonCodeMetadata(_) | ResumeMoonCodeWatch(_, _) =>
      update_mooncode_transport_actions(dispatch, msg, model)
    _ => (@rabbita.none, model)
  }
}
