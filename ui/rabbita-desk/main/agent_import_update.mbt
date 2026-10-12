///|
fn agent_import_begin(
  state : AgentImportState,
  operation : AgentImportOperation,
) -> AgentImportState {
  let request = state.request + 1
  {
    ..state,
    request,
    pending: Some({ request, operation, }),
    session: { ..state.session, error: "", },
  }
}

///|
/// Picking and staging never import. Only the explicit import action writes a
/// Book; recovery is read-only and opening needs a separately verified result.
fn reduce_agent_import(
  state : AgentImportState,
  message : AgentImportMsg,
) -> (AgentImportState, AgentImportEffect) {
  match message {
    BindAgentImport(active, library, context) => {
      if state.active == active &&
        state.session.library == library &&
        state.context == context {
        return (state, NoAgentImportEffect)
      }
      let next = agent_import_invalidate(state)
      let saved = next.suspended.copy()
      let session = if next.session.library == library {
        next.session
      } else {
        if next.session.operation_id != "" {
          saved.push(next.session)
        }
        next.suspended
        .filter(item => item.library == library)
        .last()
        .unwrap_or(init_agent_import_session(library))
      }
      let suspended = saved.filter(item => {
        item.library != session.library ||
        item.operation_id != session.operation_id
      })
      ({ ..next, active, context, session, suspended, }, NoAgentImportEffect)
    }
    ChoosePackage(id) | ChooseExactPackage(id) => {
      if !agent_import_ready(state) ||
        (state.session.import_started && state.session.status != "imported") ||
        !portable_book_id_valid(id) {
        return (state, NoAgentImportEffect)
      }
      let next = agent_import_begin(
        {
          ..state,
          generation: state.generation + 1,
          session: {
            ..init_agent_import_session(state.session.library),
            operation_id: id,
            exact_required: message is ChooseExactPackage(_),
          },
          package_file: None,
        },
        PickingPackage,
      )
      (next, PickAgentPackage(next.generation, next.request))
    }
    PackagePicked(generation, request, result) => {
      guard state.active &&
        !state.library_changing &&
        generation == state.generation &&
        state.pending is Some({ request: current, operation: PickingPackage, }) &&
        current == request else {
        return (state, NoAgentImportEffect)
      }
      let file = match result {
        Ok([file]) => file
        Ok([]) =>
          return (
            {
              ..state,
              pending: None,
              session: init_agent_import_session(state.session.library),
            },
            NoAgentImportEffect,
          )
        _ =>
          return (
            {
              ..state,
              pending: None,
              session: {
                ..init_agent_import_session(state.session.library),
                error: match result {
                  Err(error) => error
                  _ => "Choose one .moonbook-agent package."
                },
              },
            },
            NoAgentImportEffect,
          )
      }
      if !file.name.has_suffix(".moonbook-agent") ||
        file.name.contains("/") ||
        !portable_book_path_valid(file.name) ||
        !file.content.has_prefix("data:") {
        return (
          {
            ..state,
            pending: None,
            session: {
              ..init_agent_import_session(state.session.library),
              error: "Choose a readable .moonbook-agent package.",
            },
          },
          NoAgentImportEffect,
        )
      }
      if state.session.exact_required {
        return (
          {
            ..state,
            pending: None,
            package_file: Some(file),
            session: {
              ..state.session,
              filename: file.name,
              status: "awaiting-binding",
            },
          },
          NoAgentImportEffect,
        )
      }
      let next = agent_import_begin(
        { ..state, session: { ..state.session, filename: file.name, }, },
        StagingPackage,
      )
      (next, StageAgentPackage(next.generation, next.request, file))
    }
    ChooseBinding => {
      if !agent_import_ready(state) ||
        state.session.status != "awaiting-binding" ||
        !state.session.exact_required ||
        state.package_file is None {
        return (state, NoAgentImportEffect)
      }
      let next = agent_import_begin(state, PickingBinding)
      (next, PickAgentBinding(next.generation, next.request))
    }
    BindingPicked(generation, request, result) => {
      guard state.active &&
        !state.library_changing &&
        generation == state.generation &&
        state.pending is Some({ request: current, operation: PickingBinding, }) &&
        current == request &&
        state.package_file is Some(package_file) else {
        return (state, NoAgentImportEffect)
      }
      let binding = match result {
        Ok([file]) if file.content.length() <= 131072 =>
          @json.parse(file.content) catch {
            _ => Json::null()
          }
        _ => Json::null()
      }
      let digest = handoff_text(binding, "binding_digest")
      if handoff_text(binding, "contract") !=
        "moontown.portable-listing-binding.v1" ||
        !portable_book_sha_valid(digest) {
        return (
          {
            ..state,
            pending: None,
            session: {
              ..state.session,
              error: match result {
                Ok([]) =>
                  "Binding selection cancelled. The package has not been imported."
                Err(error) => error
                _ =>
                  "Choose the original Town .binding.json file received with this package. A transfer receipt is a different file."
              },
            },
          },
          NoAgentImportEffect,
        )
      }
      let next = agent_import_begin(
        {
          ..state,
          package_file: None,
          session: { ..state.session, binding_digest: digest, status: "empty", },
        },
        StagingPackage,
      )
      (
        next,
        StageExactAgentPackage(
          next.generation,
          next.request,
          package_file,
          binding,
        ),
      )
    }
    SetImportDestination(destination) => {
      if !agent_import_ready(state) ||
        state.session.status != "inspected" ||
        state.session.import_started {
        return (state, NoAgentImportEffect)
      }
      (
        { ..state, session: { ..state.session, destination, error: "", }, },
        NoAgentImportEffect,
      )
    }
    ImportInspectedPackage => {
      if !agent_import_can_write(state) {
        return (state, NoAgentImportEffect)
      }
      let next = agent_import_begin(
        {
          ..state,
          session: {
            ..state.session,
            status: "importing",
            import_started: true,
          },
        },
        ImportingPackage,
      )
      (next, WriteAgentImport(next.generation, next.request))
    }
    CheckImport => {
      if !agent_import_ready(state) || state.session.operation_id == "" {
        return (state, NoAgentImportEffect)
      }
      let next = agent_import_begin(state, CheckingImport)
      (next, ReadAgentImport(next.generation, next.request))
    }
    CancelPackage => {
      if state.session.import_started && state.session.status != "imported" {
        return (state, NoAgentImportEffect)
      }
      (
        {
          ..state,
          generation: state.generation + 1,
          pending: None,
          package_file: None,
          session: init_agent_import_session(state.session.library),
        },
        NoAgentImportEffect,
      )
    }
    KeepAttemptAndStartNew => {
      if !agent_import_ready(state) || state.session.operation_id == "" {
        return (state, NoAgentImportEffect)
      }
      let suspended = state.suspended.copy()
      suspended.push(state.session)
      (
        {
          ..state,
          generation: state.generation + 1,
          suspended,
          package_file: None,
          session: init_agent_import_session(state.session.library),
        },
        NoAgentImportEffect,
      )
    }
    SelectSavedImport(id) => {
      if !agent_import_ready(state) {
        return (state, NoAgentImportEffect)
      }
      guard state.suspended
        .filter(item => {
          item.library == state.session.library && item.operation_id == id
        })
        .get(0)
        is Some(saved) else {
        return (state, NoAgentImportEffect)
      }
      let suspended = state.suspended.filter(item => {
        item.library != state.session.library || item.operation_id != id
      })
      if state.session.operation_id != "" {
        suspended.push(state.session)
      }
      (
        {
          ..state,
          generation: state.generation + 1,
          suspended,
          session: {
            ..saved,
            status: "uncertain",
            error: "Check this saved operation before continuing.",
          },
        },
        NoAgentImportEffect,
      )
    }
    OpenImportedPackage => {
      if agent_import_ready(state) && state.session.status == "imported" {
        if state.session.reply is Some({ created: Some(_), .. }) {
          let next = agent_import_begin(state, CheckingBeforeOpen)
          return (next, ReadAgentImport(next.generation, next.request))
        }
      }
      (state, NoAgentImportEffect)
    }
    ImportResponse(generation, request, result) => {
      guard state.active &&
        !state.library_changing &&
        generation == state.generation &&
        state.pending is Some({ request: current, operation, }) &&
        operation != PickingPackage &&
        operation != PickingBinding &&
        current == request else {
        return (state, NoAgentImportEffect)
      }
      let reply = match result {
        Ok(json) => agent_import_decode_reply(json, state.session)
        Err(_) => None
      }
      match reply {
        Some(reply) =>
          (
            {
              ..state,
              pending: None,
              session: {
                ..state.session,
                status: reply.status,
                // A verified inspected reply with no bound destination proves
                // that the host has not consumed the import reservation.
                import_started: reply.destination_folder != "",
                reviewed_sha: reply.source.package_sha256,
                destination: if reply.destination_folder == "" {
                  state.session.destination
                } else {
                  reply.destination_folder
                },
                reply: Some(reply),
                error: if reply.status == "inspected" ||
                  reply.status == "imported" {
                  ""
                } else {
                  reply.message
                },
              },
            },
            if operation == CheckingBeforeOpen && reply.status == "imported" {
              match reply.created {
                Some(created) => OpenAgentImport(created)
                None => NoAgentImportEffect
              }
            } else {
              NoAgentImportEffect
            },
          )
        None =>
          (
            {
              ..state,
              pending: None,
              session: {
                ..state.session,
                status: "uncertain",
                error: match result {
                  Err(error) => error
                  _ =>
                    "The host response did not match this package and destination."
                },
              },
            },
            NoAgentImportEffect,
          )
      }
    }
    ImportTimedOut(generation, request) => {
      guard generation == state.generation &&
        state.pending is Some({ request: current, .. }) &&
        current == request else {
        return (state, NoAgentImportEffect)
      }
      (agent_import_invalidate(state), NoAgentImportEffect)
    }
  }
}
