///|
fn portable_book_begin(
  state : PortableBookState,
  operation : PortableBookOperation,
) -> (PortableBookState, PortableBookEffect) {
  let request = state.request + 1
  let next = {
    ..state,
    request,
    pending: Some({ request, operation, }),
    error: "",
  }
  let effect = match operation {
    Catalog => ReadPortableCatalog(state.generation, request)
    Entries(directory) =>
      ReadPortableEntries(state.generation, request, directory)
    ChooseHumanResult => PickAcceptedHumanResult(state.generation, request)
    PreparePackage(id) if !state.output_groups.is_empty() =>
      PreparePortableGroupedPackage(
        state.generation,
        request,
        id,
        state.version,
        state.paths,
        state.output_groups,
        state.accepted_human_result.map(source => source.raw_base64),
      )
    PreparePackage(id) =>
      match state.accepted_human_result {
        Some(source) =>
          PreparePortablePackageWithHumanResult(
            state.generation,
            request,
            id,
            state.version,
            state.paths,
            source.raw_base64,
          )
        None =>
          PreparePortablePackage(
            state.generation,
            request,
            id,
            state.version,
            state.paths,
          )
      }
    InspectPackage(id) => InspectPortablePackage(state.generation, request, id)
  }
  (next, effect)
}

///|
fn portable_book_changed_inputs(state : PortableBookState) -> PortableBookState {
  {
    ..state,
    prepared: None,
    operation_id: "",
    recovery_checked: false,
    error: "",
    notice: if state.operation_id != "" {
      "Inputs changed. An earlier package may still be retained. Prepare explicitly to create a new package."
    } else {
      ""
    },
  }
}

///|
/// Only Prepare emits a write. Binding, browsing, refreshing and recovery read
/// saved data, with every response fenced by the library/Book generation.
fn reduce_portable_book(
  state : PortableBookState,
  message : PortableBookMsg,
) -> (PortableBookState, PortableBookEffect) {
  match message {
    OutputGroup(message) =>
      (reduce_portable_group(state, message), NoPortableEffect)
    BindPortable(active, library, workspace) => {
      if state.active == active &&
        state.library == library &&
        state.workspace == workspace {
        return (state, NoPortableEffect)
      }
      let same_book = state.library == library && state.workspace == workspace
      let next = {
        ..(if same_book { state } else { init_portable_book() }),
        active,
        library_changing: state.library_changing,
        library,
        workspace,
        generation: state.generation + 1,
        pending: None,
        accepted_human_result: None,
        available: false,
        loaded: false,
        recovery_checked: if same_book {
          state.recovery_checked
        } else {
          false
        },
        notice: if same_book &&
          state.pending is Some({ operation: PreparePackage(_), .. }) {
          "Preparation was in progress when you left. Check the saved package; do not assume it failed."
        } else if same_book {
          state.notice
        } else {
          ""
        },
      }
      if active && workspace != "" {
        portable_book_begin(next, Catalog)
      } else {
        (next, NoPortableEffect)
      }
    }
    RefreshCatalog => {
      if !state.active || state.workspace == "" || state.pending is Some(_) {
        return (state, NoPortableEffect)
      }
      portable_book_begin(
        { ..state, available: false, loaded: false, },
        Catalog,
      )
    }
    SetVersion(version) => {
      if !state.active ||
        portable_book_inputs_locked(state) ||
        state.version == version {
        return (state, NoPortableEffect)
      }
      ({ ..portable_book_changed_inputs(state), version, }, NoPortableEffect)
    }
    BrowseFiles(directory) => {
      if !state.active ||
        state.pending is Some(_) ||
        (directory != "" && !portable_book_path_valid(directory)) {
        return (state, NoPortableEffect)
      }
      portable_book_begin(
        { ..state, directory, entries: [], entries_loaded: false, },
        Entries(directory),
      )
    }
    ToggleFile(path) => {
      if !state.active ||
        portable_book_inputs_locked(state) ||
        !portable_book_path_valid(path) ||
        !state.entries.any(entry => {
          entry.workspace_id == state.workspace &&
          entry.path == path &&
          entry.kind != Directory &&
          entry.readable
        }) {
        return (state, NoPortableEffect)
      }
      let paths = if state.paths.contains(path) {
        state.paths.filter(item => item != path)
      } else {
        let selected = state.paths.copy()
        selected.push(path)
        selected
      }
      ({ ..portable_book_changed_inputs(state), paths, }, NoPortableEffect)
    }
    RemoveFile(path) => {
      if !state.active ||
        portable_book_inputs_locked(state) ||
        !state.paths.contains(path) {
        return (state, NoPortableEffect)
      }
      (
        {
          ..portable_book_changed_inputs(state),
          paths: state.paths.filter(item => item != path),
        },
        NoPortableEffect,
      )
    }
    Prepare(id) => {
      if !portable_book_can_prepare(state) || !portable_book_id_valid(id) {
        return (state, NoPortableEffect)
      }
      portable_book_begin(
        {
          ..state,
          operation_id: id,
          recovery_checked: false,
          prepared: None,
          notice: "Preparing a local package. The host may refresh Book metadata, projections and missing keeper files.",
        },
        PreparePackage(id),
      )
    }
    ChooseAcceptedHumanResult => {
      if !state.active || portable_book_inputs_locked(state) {
        return (state, NoPortableEffect)
      }
      // Keep the earlier selection until a replacement is validated. Cancelling
      // or a failed read must not silently change an already reviewed input.
      portable_book_begin(state, ChooseHumanResult)
    }
    RemoveAcceptedHumanResult => {
      if !state.active ||
        portable_book_inputs_locked(state) ||
        state.accepted_human_result is None {
        return (state, NoPortableEffect)
      }
      (
        { ..portable_book_changed_inputs(state), accepted_human_result: None, },
        NoPortableEffect,
      )
    }
    AcceptedHumanResultPicked(generation, request, result) => {
      guard state.active &&
        !state.library_changing &&
        generation == state.generation &&
        state.pending
        is Some({ request: current, operation: ChooseHumanResult, }) &&
        current == request else {
        return (state, NoPortableEffect)
      }
      match result {
        Ok(Some(source)) =>
          (
            {
              ..portable_book_changed_inputs(state),
              pending: None,
              accepted_human_result: Some(source),
              notice: "Accepted human result selected locally. Review the full source observation and text, then choose Prepare to include it.",
            },
            NoPortableEffect,
          )
        Ok(None) => ({ ..state, pending: None, error: "", }, NoPortableEffect)
        Err(error) => ({ ..state, pending: None, error, }, NoPortableEffect)
      }
    }
    InspectSaved(id) => {
      if !state.active ||
        portable_book_inputs_locked(state) ||
        !portable_book_id_valid(id) ||
        !state.exports.any(item => item.export_id == id) {
        return (state, NoPortableEffect)
      }
      portable_book_begin(
        {
          ..state,
          operation_id: id,
          prepared: None,
          paths: [],
          output_groups: [],
          selected_group: "",
          group_name: "",
          accepted_human_result: None,
          recovery_checked: false,
          notice: "Inspecting a saved local package. No package is being prepared.",
        },
        InspectPackage(id),
      )
    }
    CheckPreparation => {
      if !state.active ||
        state.pending is Some(_) ||
        !portable_book_id_valid(state.operation_id) {
        return (state, NoPortableEffect)
      }
      portable_book_begin(
        {
          ..state,
          prepared: None,
          notice: "Checking this exact saved preparation without packing again.",
        },
        InspectPackage(state.operation_id),
      )
    }
    StartNewPreparation => {
      if !state.active ||
        state.pending is Some(_) ||
        (state.prepared is None && !state.recovery_checked) {
        return (state, NoPortableEffect)
      }
      (
        {
          ..state,
          operation_id: "",
          prepared: None,
          recovery_checked: false,
          error: "",
          notice: "Ready for a new preparation. An earlier package may still be retained. Only Prepare creates the next package.",
        },
        NoPortableEffect,
      )
    }
    Received(generation, request, result) => {
      guard state.active &&
        generation == state.generation &&
        state.pending is Some(pending) &&
        pending.request == request else {
        return (state, NoPortableEffect)
      }
      match pending.operation {
        Entries(_) | ChooseHumanResult => (state, NoPortableEffect)
        Catalog => {
          let decoded : PortableBookCatalog? = match result {
            Ok(json) =>
              try @json.from_json(json) catch {
                _ => None
              } noraise {
                value => Some(value)
              }
            Err(_) => None
          }
          match decoded {
            Some(catalog) if catalog.expected_library == state.library &&
              catalog.workspace_id == state.workspace &&
              catalog.exports.all(item => {
                portable_book_id_valid(item.export_id) &&
                portable_book_path_valid(item.path) &&
                portable_book_sha_valid(item.package_sha256) &&
                item.package_size_bytes > 0
              }) =>
              (
                {
                  ..state,
                  pending: None,
                  loaded: true,
                  available: catalog.available,
                  capability_message: catalog.message,
                  exports: catalog.exports,
                  error: "",
                },
                NoPortableEffect,
              )
            _ =>
              (
                {
                  ..state,
                  pending: None,
                  loaded: false,
                  available: false,
                  error: portable_book_error(result),
                },
                NoPortableEffect,
              )
          }
        }
        PreparePackage(id) | InspectPackage(id) => {
          let prepared = match result {
            Ok(json) =>
              portable_book_decode_prepared(
                json,
                state.library,
                state.workspace,
                id,
              )
            Err(_) => None
          }
          match prepared {
            Some(prepared) if pending.operation is InspectPackage(_) ||
              prepared.inspection.version == state.version =>
              (
                {
                  ..state,
                  pending: None,
                  prepared: Some(prepared),
                  version: prepared.inspection.version,
                  recovery_checked: true,
                  error: "",
                  notice: "Verified saved package. Review every included member and exclusion before downloading.",
                },
                NoPortableEffect,
              )
            _ =>
              (
                {
                  ..state,
                  pending: None,
                  prepared: None,
                  recovery_checked: pending.operation is InspectPackage(_),
                  error: portable_book_error(result),
                  notice: "The earlier preparation may still be retained. Recovery checks only read saved data.",
                },
                NoPortableEffect,
              )
          }
        }
      }
    }
    FilesReceived(generation, request, result) => {
      guard state.active &&
        generation == state.generation &&
        state.pending
        is Some({ request: current, operation: Entries(directory), }) &&
        current == request &&
        directory == state.directory else {
        return (state, NoPortableEffect)
      }
      match result {
        Ok(entries) if entries.all(entry => {
            entry.workspace_id == state.workspace &&
            portable_book_path_valid(entry.path)
          }) =>
          (
            {
              ..state,
              pending: None,
              entries,
              entries_loaded: true,
              error: "",
            },
            NoPortableEffect,
          )
        _ =>
          (
            {
              ..state,
              pending: None,
              entries: [],
              entries_loaded: false,
              error: "Could not read files for this Book. Retry the folder.",
            },
            NoPortableEffect,
          )
      }
    }
    TimedOut(generation, request) => {
      guard state.active &&
        generation == state.generation &&
        state.pending is Some(pending) &&
        pending.request == request else {
        return (state, NoPortableEffect)
      }
      (
        {
          ..state,
          pending: None,
          available: if pending.operation is Catalog {
            false
          } else {
            state.available
          },
          prepared: if pending.operation is PreparePackage(_) ||
            pending.operation is InspectPackage(_) {
            None
          } else {
            state.prepared
          },
          error: if pending.operation is ChooseHumanResult {
            "Choosing or checking the accepted human result timed out. Your earlier selection is unchanged. Choose the file again."
          } else {
            "The local request timed out. A preparation may still be retained; check its saved package before starting another."
          },
        },
        NoPortableEffect,
      )
    }
  }
}
