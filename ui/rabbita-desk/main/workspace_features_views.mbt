///|
fn workspace_features_state_payload(model : Model) -> Json {
  let hits : Array[Json] = model.pages_search.hits.map(hit => {
    "workspace_id": hit.workspace_id,
    "workspace_name": hit.workspace_name,
    "path": hit.path,
    "title": hit.title,
    "kind": wiki_search_type_label(hit),
    "layer": match hit.source_layer {
      Wiki => "wiki"
      RawEvidence => "raw-evidence"
      Inbox => "inbox"
      Review => "review"
      _ => "workspace"
    },
    "snippet": hit.snippet,
  })
  let work : Array[Json] = []
  for request in model.requests {
    work.push({
      "type": "request",
      "title": "Request · " + request.id,
      "detail": request.status,
      "destination": "requests",
    })
  }
  for run in model.runs {
    work.push({
      "type": "run",
      "title": run.summary,
      "detail": run.status + " · " + run.phase,
      "run_id": run.run_id,
      "status": run.status,
      "phase": run.phase,
      "destination": "runs",
    })
    for artifact in run.artifacts {
      work.push({
        "type": "artifact",
        "title": artifact.title,
        "detail": artifact.path + " · " + run.run_id,
        "workspace_id": model.selected_workspace_id,
        "path": artifact.path,
        "run_id": run.run_id,
      })
    }
  }
  for item in model.review_items {
    work.push({
      "type": "review",
      "title": "Review · " + item.title,
      "detail": item.status + " · " + item.path,
      "status": item.status,
      "path": item.path,
      "destination": "review",
    })
  }
  for event in model.events {
    work.push({
      "type": "event",
      "title": event.severity + " · " + event.title,
      "detail": event.detail,
      "severity": event.severity,
      "workspace_id": model.selected_workspace_id,
      "path": event.path,
      "destination": "runs",
    })
  }
  {
    "query": model.pages_search.query,
    "search_status": model.pages_search.status,
    "searching": model.pages_search.surface is Some(Loading),
    "search_state": model.pages_search.surface
    .map(surface_state_key)
    .unwrap_or("idle"),
    "hits": Json::array(hits),
    "work": Json::array(work),
    "recent_paths": Json::array(
      model.recent_paths.map(path => Json::string(path)),
    ),
    "workspace": workspace_name(model),
    "workspace_id": model.selected_workspace_id,
    "workspace_path": workspace_root(model),
    "selected_document": model.selected_path,
    "task_id": model.wiki_agent_task_id,
    "request_status": model.request_status,
    "request_prompt": model.request_prompt,
    "office": workspace_office_state_payload(model.office_editor),
    // The transcript is already present in the visible chat DOM. Keep only a
    // tiny change projection here so a long streamed answer is not copied into
    // a second JSON attribute on every token batch.
    "chat_count": model.wiki_chat_entries.length(),
    "chat_revision": model.wiki_chat_stream_cursor,
    "chat_tail_role": model.wiki_chat_entries
    .last()
    .map(entry => entry.role)
    .unwrap_or(""),
    "chat_tail_bytes": model.wiki_chat_entries
    .last()
    .map(entry => entry.content.length())
    .unwrap_or(0),
  }
}

///|
fn workspace_office_item_payload(item : OfficeEditorItem) -> Json {
  {
    "section": item.section,
    "reference": item.reference,
    "section_index": item.section_index,
    "item_index": item.item_index,
    "text": item.text,
    "formula": item.formula,
    "bold": item.bold,
    "italic": item.italic,
    "underline": item.underline,
    "x": item.x,
    "y": item.y,
    "width": item.width,
    "height": item.height,
  }
}

///|
fn workspace_office_state_payload(state : OfficeEditorState) -> Json {
  match state.document {
    None => { "open": false }
    Some(document) =>
      {
        "open": true,
        "path": document.path,
        "kind": match document.kind {
          OfficeDocx => "docx"
          OfficeXlsx => "xlsx"
          OfficePptx => "pptx"
        },
        "baseline": document.baseline,
        "selected": state.selected,
        "saving": state.saving,
        "status": state.status,
        "warnings": Json::array(
          document.warnings.map(warning => Json::string(warning)),
        ),
        "saved_items": Json::array(
          document.items.map(workspace_office_item_payload),
        ),
        "draft_items": Json::array(
          state.draft_items.map(workspace_office_item_payload),
        ),
      }
  }
}

///|
fn render_workspace_feature_overlays(
  _dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  div(
    class="workspace-feature-overlays",
    attrs=@html.Attrs::build()
      .data_set("testid", "workspace-feature-overlays")
      .data_set("state", workspace_features_state_payload(model).stringify()),
    ([] : Array[@rabbita.Html]),
  )
}

///|
#cfg(target="js")
extern "js" fn workspace_features_bind_dispatch(
  handler : (String, String, String, String, String) -> Unit,
) =
  #| (handler) => {
  #|   globalThis.__moondeskWorkspaceFeaturesDispatch = (...args) => {
  #|     // Workspace enhancements react to Rabbita-owned DOM mutations. Hand
  #|     // control back on the next microtask so a message cannot re-enter an
  #|     // in-progress render and be overwritten by that render's old model.
  #|     globalThis.queueMicrotask(() => {
  #|       try {
  #|         handler(...args);
  #|       } catch (error) {
  #|         globalThis.setTimeout(() => { throw error; }, 0);
  #|       }
  #|     });
  #|   };
  #|   globalThis.dispatchEvent(new CustomEvent('moondesk-workspace-features-ready'));
  #| }

///|
fn workspace_features_action(
  dispatch : Dispatch[Msg],
  action : String,
  first : String,
  second : String,
  third : String,
  fourth : String,
) -> @rabbita.Cmd {
  let message = match action {
    "office-discard" => OfficeEditor(OfficeDiscard)
    "office-save" => OfficeEditor(OfficeSave)
    _ => workspace_feature_msg(action, first~, second~, third~, fourth~)
  }
  dispatch(message)
}

///|
fn workspace_features_bridge_cmd(dispatch : Dispatch[Msg]) -> @rabbita.Cmd {
  @cmd.custom_cmd(
    scheduler => {
      workspace_features_bind_dispatch((action, first, second, third, fourth) => {
        scheduler.add(
          workspace_features_action(
            dispatch, action, first, second, third, fourth,
          ),
        )
      })
    },
    kind=AfterRender,
  )
}

///|
fn work_center_summary(model : Model) -> String {
  let active = model.runs
    .filter(run => {
      let status = run.status.to_lower()
      status.contains("run") ||
      status.contains("work") ||
      status.contains("queue")
    })
    .length()
  let artifacts = model.runs.fold(init=0, (count, run) => {
    count + run.artifacts.length()
  })
  let warnings = model.review_items
    .filter(item => {
      item.status.to_lower().contains("pending") ||
      item.status.to_lower().contains("review")
    })
    .length()
  if active > 0 {
    "Working on \{active} task" + (if active == 1 { "" } else { "s" })
  } else if model.runs.length() > 0 {
    "\{model.runs.length()} completed · \{artifacts} result files · \{warnings} for review"
  } else if model.requests.length() > 0 {
    "\{model.requests.length()} request" +
    (if model.requests.length() == 1 { "" } else { "s" }) +
    " waiting"
  } else {
    "No background work"
  }
}

///|
fn render_quiet_work_center(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  details(
    class="quiet-work-center",
    attrs=@html.Attrs::build().data_set("testid", "quiet-work-center"),
    [
      summary(class="quiet-work-summary", [
        strong("Background work"),
        span(work_center_summary(model)),
      ]),
      div(class="quiet-work-details", [
        p(
          "MoonDesk keeps checks and agent work out of the way. Only warnings interrupt you.",
        ),
        div(class="quiet-work-actions", [
          button(
            class="secondary-button",
            on_click=dispatch(
              workspace_feature_msg("open-search", first="open"),
            ),
            "Find work",
          ),
          button(
            class="secondary-button",
            on_click=dispatch(SelectWorkspaceMode(RunsWorkspace)),
            "Open tasks",
          ),
          button(
            class="secondary-button",
            on_click=dispatch(workspace_feature_msg("export")),
            "Export Work Package",
          ),
        ]),
      ]),
    ],
  )
}
