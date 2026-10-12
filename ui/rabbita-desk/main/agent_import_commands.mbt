///|
#cfg(target="js")
extern "js" fn browser_pick_agent_package() -> @js.Promise =
  #| async () => {
  #|   const input = document.createElement('input');
  #|   input.type = 'file'; input.accept = '.moonbook-agent'; input.hidden = true;
  #|   document.body.appendChild(input);
  #|   let focusListener;
  #|   try {
  #|     const files = await new Promise(resolve => {
  #|       let settled = false;
  #|       const finish = value => { if (!settled) { settled = true; resolve(value); } };
  #|       input.onchange = () => finish(Array.from(input.files || []));
  #|       input.oncancel = () => finish([]);
  #|       focusListener = () => setTimeout(() => finish(Array.from(input.files || [])), 300);
  #|       window.addEventListener('focus', focusListener, { once: true });
  #|       input.click();
  #|     });
  #|     const file = files[0];
  #|     if (!file) return JSON.stringify({ ok: true, files: [] });
  #|     if (!file.name.endsWith('.moonbook-agent')) throw new Error('Choose a .moonbook-agent package.');
  #|     if (file.size <= 0 || file.size > 64 * 1024 * 1024) throw new Error('Package must be between 1 byte and 64 MiB.');
  #|     const content = await new Promise((resolve, reject) => {
  #|       const reader = new FileReader();
  #|       reader.onerror = () => reject(new Error('Could not read the package.'));
  #|       reader.onload = () => resolve(String(reader.result || ''));
  #|       reader.readAsDataURL(file);
  #|     });
  #|     return JSON.stringify({ ok: true, files: [{
  #|       id: `agent-package:${file.name}:${file.size}:${file.lastModified}`,
  #|       name: file.name, relative_path: '', media_type: 'application/octet-stream',
  #|       content, source: 'agent-package-picker'
  #|     }] });
  #|   } catch (error) {
  #|     return JSON.stringify({ ok: false, files: [], error: String(error?.message || error) });
  #|   } finally {
  #|     if (focusListener) window.removeEventListener('focus', focusListener);
  #|     input.remove();
  #|   }
  #| }

///|
fn agent_import_url(library : String, id : String) -> String {
  @desk.agent_import_url(id, library)
}

///|
fn choose_agent_package_click(
  dispatch : Dispatch[Msg],
  exact? : Bool = false,
) -> @rabbita.Cmd {
  @cmd.custom_cmd(scheduler => {
    scheduler.add(
      dispatch(
        AgentImport(
          if exact {
            ChooseExactPackage(portable_book_new_id())
          } else {
            ChoosePackage(portable_book_new_id())
          },
        ),
      ),
    )
  })
}

///|
fn agent_import_effect_cmd(
  dispatch : Dispatch[Msg],
  state : AgentImportState,
  effect : AgentImportEffect,
) -> @rabbita.Cmd {
  let session = state.session
  let (generation, request, command) = match effect {
    NoAgentImportEffect | OpenAgentImport(_) => return @rabbita.none
    PickAgentPackage(generation, request) =>
      return @rabbita.perform(
        result => {
          dispatch(AgentImport(PackagePicked(generation, request, result)))
        },
        async fn() noraise {
          let text : String = browser_pick_agent_package().wait().cast() catch {
              _ => return Err("Could not choose a package.")
            }
          parse_browser_import_batch(text)
        },
      )
    PickAgentBinding(generation, request) =>
      return @rabbita.perform(
        result => {
          dispatch(AgentImport(BindingPicked(generation, request, result)))
        },
        async fn() noraise {
          let text : String = browser_pick_agent_binding().wait().cast() catch {
              _ => return Err("Could not choose the Town binding file.")
            }
          parse_browser_import_batch(text)
        },
      )
    StageExactAgentPackage(generation, request, file, binding) =>
      (
        generation,
        request,
        @http.post(agent_import_url(session.library, ""))
        .with_json(
          (
            {
              "expected_library": session.library,
              "operation_id": session.operation_id,
              "filename": file.name,
              "data_url": file.content,
              "town_binding": binding,
            } : Json),
        )
        .expect_json(result => {
          dispatch(
            AgentImport(
              ImportResponse(
                generation,
                request,
                http_result(
                  result, "Could not inspect this package and Town binding. Check they are the unchanged matching files.",
                ),
              ),
            ),
          )
        }),
      )
    StageAgentPackage(generation, request, file) =>
      (
        generation,
        request,
        @http.post(agent_import_url(session.library, ""))
        .with_json(
          (
            {
              "expected_library": session.library,
              "operation_id": session.operation_id,
              "filename": file.name,
              "data_url": file.content,
            } : Json),
        )
        .expect_json(result => {
          dispatch(
            AgentImport(
              ImportResponse(
                generation,
                request,
                http_result(
                  result, "The package inspection response was not received.",
                ),
              ),
            ),
          )
        }),
      )
    WriteAgentImport(generation, request) => {
      guard session.reply is Some(reply) else { return @rabbita.none }
      (
        generation,
        request,
        @http.post(agent_import_url(session.library, session.operation_id))
        .with_json(
          (
            {
              "expected_library": session.library,
              "operation_id": session.operation_id,
              "destination_folder": session.destination,
              "package_sha256": reply.source.package_sha256,
              "binding_digest": if session.exact_required {
                session.binding_digest.to_json()
              } else {
                Json::null()
              },
            } : Json),
        )
        .expect_json(result => {
          dispatch(
            AgentImport(
              ImportResponse(
                generation,
                request,
                http_result(
                  result, "The import response was not received. Check import before continuing.",
                ),
              ),
            ),
          )
        }),
      )
    }
    ReadAgentImport(generation, request) =>
      (
        generation,
        request,
        @http.get(agent_import_url(session.library, session.operation_id)).expect_json(result => {
            dispatch(
              AgentImport(
                ImportResponse(
                  generation,
                  request,
                  http_result(
                    result, "Could not check the retained import. No new import was started.",
                  ),
                ),
              ),
            )
          },
        ),
      )
  }
  @rabbita.batch([
    command,
    @rabbita.delay(
      dispatch(AgentImport(ImportTimedOut(generation, request))),
      30000,
    ),
  ])
}

///|
fn update_agent_import(
  dispatch : Dispatch[Msg],
  message : AgentImportMsg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  let (agent_import, effect) = reduce_agent_import(model.agent_import, message)
  let next = { ..model, agent_import, }
  if effect is OpenAgentImport(created) &&
    agent_import.active &&
    !agent_import.library_changing &&
    agent_import.session.library == model.workspace_library_path {
    // No unscoped ImportedMoonBook callback: validate the current operation,
    // library and generation first, then reuse the existing safe open helper.
    return open_created_or_imported_workspace(
      dispatch,
      next,
      created,
      status="loading imported MoonBook",
      new_book_name=model.new_book_name,
      new_book_id=model.new_book_id,
      new_book_status=model.new_book_status,
      import_book_status="imported \{created.book_id}",
      host_status="imported MoonBook \{created.name}",
    )
  }
  let command = agent_import_effect_cmd(dispatch, agent_import, effect)
  (
    if agent_import_recovery_json(agent_import) !=
      agent_import_recovery_json(model.agent_import) {
      agent_import_persist_then(agent_import, command)
    } else {
      command
    },
    next,
  )
}

///|
fn sync_agent_import_context(
  dispatch : Dispatch[Msg],
  model : Model,
) -> (@rabbita.Cmd, Model) {
  update_agent_import(
    dispatch,
    BindAgentImport(
      !work_handoff_active(model) &&
      !model.agent_import.library_changing &&
      model.workspace_mode == Desk,
      model.workspace_library_path,
      model.selected_workspace_id +
      "\n" +
      model.current_directory +
      "\n" +
      model.selected_path,
    ),
    model,
  )
}

///|
fn agent_import_library_transition(message : Msg, model : Model) -> Model {
  let changing = match message {
    PickLibraryFolder => true
    LibraryFolderPicked(Ok(path)) => path != ""
    LibraryFolderPicked(Err(_)) | SelectedLibrary(_) => false
    _ => return model
  }
  if changing == model.agent_import.library_changing {
    return model
  }
  {
    ..model,
    agent_import: {
      ..agent_import_invalidate(model.agent_import),
      library_changing: changing,
      active: false,
    },
  }
}
