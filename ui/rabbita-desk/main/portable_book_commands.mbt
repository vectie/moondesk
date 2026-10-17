///|
fn portable_book_effect_cmd(
  dispatch : Dispatch[Msg],
  state : PortableBookState,
  effect : PortableBookEffect,
) -> @rabbita.Cmd {
  let (generation, request, command) = match effect {
    NoPortableEffect => return @rabbita.none
    PickAcceptedHumanResult(generation, request) =>
      (
        generation,
        request,
        @rabbita.perform(
          result => {
            dispatch(
              PortableBook(
                AcceptedHumanResultPicked(generation, request, result),
              ),
            )
          },
          pick_portable_book_human_result,
        ),
      )
    ReadPortableEntries(generation, request, directory) =>
      (
        generation,
        request,
        @http.get(
          portable_book_entries_url(state.workspace, state.library, directory),
        ).expect_json(result => {
          dispatch(
            PortableBook(
              FilesReceived(
                generation,
                request,
                http_result(result, "Could not read Book files."),
              ),
            ),
          )
        }),
      )
    ReadPortableCatalog(generation, request) =>
      (
        generation,
        request,
        @http.get(portable_book_read_url(state.workspace, state.library, "")).expect_json(result => {
            dispatch(
              PortableBook(
                Received(
                  generation,
                  request,
                  http_result(result, "Could not read local export capability."),
                ),
              ),
            )
          },
        ),
      )
    InspectPortablePackage(generation, request, id) =>
      (
        generation,
        request,
        @http.get(portable_book_read_url(state.workspace, state.library, id)).expect_json(result => {
            dispatch(
              PortableBook(
                Received(
                  generation,
                  request,
                  http_result(result, "Could not inspect the saved package."),
                ),
              ),
            )
          },
        ),
      )
    PreparePortablePackage(generation, request, id, version, paths) =>
      (
        generation,
        request,
        @http.post(
          @desk.workspace_endpoint_url(state.workspace, "agent-export"),
        )
        .with_json(
          portable_book_prepare_body(state.library, id, version, paths),
        )
        .expect_json(result => {
          dispatch(
            PortableBook(
              Received(
                generation,
                request,
                http_result(
                  result, "The preparation response was not received.",
                ),
              ),
            ),
          )
        }),
      )
    PreparePortableGroupedPackage(
      generation,
      request,
      id,
      version,
      paths,
      groups,
      source
    ) =>
      (
        generation,
        request,
        @http.post(
          @desk.workspace_endpoint_url(state.workspace, "agent-export"),
        )
        .with_json(
          portable_book_grouped_body(
            state.library,
            id,
            version,
            paths,
            groups,
            source,
          ),
        )
        .expect_json(result => {
          dispatch(
            PortableBook(
              Received(
                generation,
                request,
                http_result(
                  result, "The preparation response was not received.",
                ),
              ),
            ),
          )
        }),
      )
    PreparePortablePackageWithHumanResult(
      generation,
      request,
      id,
      version,
      paths,
      source
    ) =>
      (
        generation,
        request,
        @http.post(
          @desk.workspace_endpoint_url(state.workspace, "agent-export"),
        )
        .with_json(
          portable_book_prepare_body(
            state.library,
            id,
            version,
            paths,
            accepted_human_result_base64=source,
          ),
        )
        .expect_json(result => {
          dispatch(
            PortableBook(
              Received(
                generation,
                request,
                http_result(
                  result, "The preparation response was not received.",
                ),
              ),
            ),
          )
        }),
      )
  }
  @rabbita.batch([
    command,
    @rabbita.delay(dispatch(PortableBook(TimedOut(generation, request))), 30000),
  ])
}

///|
fn update_portable_book(
  dispatch : Dispatch[Msg],
  message : PortableBookMsg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  let (portable_book, effect) = reduce_portable_book(
    model.portable_book,
    message,
  )
  (
    portable_book_effect_cmd(dispatch, portable_book, effect),
    { ..model, portable_book, },
  )
}

///|
fn sync_portable_book_context(
  dispatch : Dispatch[Msg],
  model : Model,
) -> (@rabbita.Cmd, Model) {
  update_portable_book(
    dispatch,
    BindPortable(
      !work_handoff_active(model) &&
      !model.portable_book.library_changing &&
      model.workspace_mode == PublishWorkspace,
      model.workspace_library_path,
      model.selected_workspace_id,
    ),
    model,
  )
}

///|
fn portable_book_read_url(
  workspace : String,
  library : String,
  id : String,
) -> String {
  let segments = ["api", "workspaces", workspace, "agent-export"]
  if id != "" {
    segments.push(id)
  }
  @desk.desktop_api_url(segments, query=[("expected_library", library)])
}

///|
fn portable_book_prepare_body(
  library : String,
  id : String,
  version : String,
  paths : Array[String],
  accepted_human_result_base64? : String,
) -> Json {
  let fields : Map[String, Json] = {
    "expected_library": ToJson::to_json(library),
    "operation_id": ToJson::to_json(id),
    "version": ToJson::to_json(version),
    "paths": json_string_array(paths),
  }
  if accepted_human_result_base64 is Some(source) {
    fields["accepted_human_result_base64"] = Json::string(source)
  }
  Json::object(fields)
}

///|
fn portable_book_entries_url(
  workspace : String,
  library : String,
  directory : String,
) -> String {
  @desk.desktop_api_url(["api", "workspaces", workspace, "entries"], query=[
    ("path", directory),
    ("expected_library", library),
  ])
}

///|
fn portable_book_library_transition(message : Msg, model : Model) -> Model {
  let changing = match message {
    PickLibraryFolder => true
    LibraryFolderPicked(Ok(path)) => path != ""
    LibraryFolderPicked(Err(_)) | SelectedLibrary(_) => false
    _ => return model
  }
  let state = model.portable_book
  if changing == state.library_changing {
    return model
  }
  {
    ..model,
    portable_book: {
      ..state,
      library_changing: changing,
      generation: state.generation + 1,
      pending: None,
      available: false,
      loaded: false,
      prepared: None,
      accepted_human_result: None,
    },
  }
}

///|
#cfg(target="js")
extern "js" fn portable_book_new_id() -> String =
  #| () => {
  #|   if (!globalThis.crypto?.getRandomValues) return '';
  #|   const bytes = new Uint8Array(16); globalThis.crypto.getRandomValues(bytes);
  #|   return Array.from(bytes, b => b.toString(16).padStart(2, '0')).join('');
  #| }

///|
/// Randomness is created only for an explicit click, never during rendering.
fn prepare_portable_book_click(dispatch : Dispatch[Msg]) -> @rabbita.Cmd {
  @cmd.custom_cmd(scheduler => {
    scheduler.add(dispatch(PortableBook(Prepare(portable_book_new_id()))))
  })
}
