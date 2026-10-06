///|
fn native_work_effect_cmd(
  dispatch : Dispatch[Msg],
  effect : NativeWorkEffect,
) -> @rabbita.Cmd {
  let (command, generation, request) = match effect {
    NoNativeEffect => return @rabbita.none
    ReadNativeSaved(generation, request) =>
      (
        @http.get(@desk.town_endpoint_url("native-work")).expect_json(result => {
          dispatch(
            NativeWork(
              NativeReceived(
                generation,
                request,
                http_result(result, "Saved status could not be read."),
              ),
            ),
          )
        }),
        generation,
        request,
      )
    PostNativeControl(generation, request, id, action, revision) =>
      (
        @http.post(
          @desk.town_native_work_url(id, action=native_work_action_path(action)),
        )
        .with_json(native_work_mutation_body(revision))
        .expect_json(result => {
          dispatch(
            NativeWork(
              NativeReceived(
                generation,
                request,
                http_result(result, "The action response was not received."),
              ),
            ),
          )
        }),
        generation,
        request,
      )
  }
  @rabbita.batch([
    command,
    @rabbita.delay(
      dispatch(NativeWork(NativeTimedOut(generation, request))),
      30000,
    ),
  ])
}

///|
fn update_native_work(
  dispatch : Dispatch[Msg],
  message : NativeWorkMsg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  let (native_work, effect) = reduce_native_work(model.native_work, message)
  (native_work_effect_cmd(dispatch, effect), { ..model, native_work, })
}

///|
/// Root navigation boundary invalidates all earlier request identities.
fn sync_native_work_context(
  dispatch : Dispatch[Msg],
  model : Model,
) -> (@rabbita.Cmd, Model) {
  let active = !work_handoff_active(model) &&
    (
      model.workspace_mode == RequestsWorkspace ||
      (model.workspace_mode == MoonWiki && model.activity == Town)
    )
  update_native_work(
    dispatch,
    BindNative(
      active,
      model.workspace_library_path,
      model.selected_workspace_id,
    ),
    model,
  )
}
