///|
fn native_work_begin_read(
  state : NativeWorkState,
) -> (NativeWorkState, NativeWorkEffect) {
  let request = state.request + 1
  (
    {
      ..state,
      request,
      pending: Some({ request, operation: ReadSaved, }),
      error: "",
    },
    ReadNativeSaved(state.generation, request),
  )
}

///|
fn native_work_failed(
  state : NativeWorkState,
  operation : NativeWorkOperation,
  message : String,
) -> (NativeWorkState, NativeWorkEffect) {
  let next = { ..state, pending: None, revision: None, }
  match operation {
    ReadSaved => ({ ..next, error: message, }, NoNativeEffect)
    ControlNative(_, _) =>
      native_work_begin_read({
        ..next,
        notice: message +
        " The action could not be confirmed. Saved status is being reloaded. Inspect the saved state and cancellation status before explicitly trying again; no action was automatically retried.",
      })
  }
}

///|
/// Pure reducer: no transport, dispatch, Book selection or credential access.
fn reduce_native_work(
  state : NativeWorkState,
  message : NativeWorkMsg,
) -> (NativeWorkState, NativeWorkEffect) {
  match message {
    BindNative(active, library, book) => {
      if state.active == active &&
        state.library == library &&
        state.book == book {
        return (state, NoNativeEffect)
      }
      let changed_library = state.library != library
      let next = {
        ..state,
        active,
        library,
        book,
        generation: state.generation + 1,
        pending: None,
        revision: None,
        items: if changed_library {
          []
        } else {
          state.items
        },
        loaded: if changed_library {
          false
        } else {
          state.loaded
        },
        error: "",
        notice: if state.pending is Some({ operation: ControlNative(_, _), .. }) {
          "An action was in progress when you navigated away. Reload saved status and inspect cancellation status before trying again."
        } else if changed_library {
          ""
        } else {
          state.notice
        },
      }
      if active {
        native_work_begin_read(next)
      } else {
        (next, NoNativeEffect)
      }
    }
    ReloadSavedNative =>
      if !state.active || state.pending is Some(_) {
        (state, NoNativeEffect)
      } else {
        native_work_begin_read(state)
      }
    ActOnNative(id, action) => {
      if native_work_action_disabled(state, id) {
        return (state, NoNativeEffect)
      }
      guard state.revision is Some(revision) else {
        return (state, NoNativeEffect)
      }
      let request = state.request + 1
      (
        {
          ..state,
          request,
          pending: Some({ request, operation: ControlNative(id, action), }),
          error: "",
          notice: "",
        },
        PostNativeControl(state.generation, request, id, action, revision),
      )
    }
    NativeReceived(generation, request, result) => {
      guard state.active &&
        generation == state.generation &&
        state.pending is Some(pending) &&
        pending.request == request else {
        return (state, NoNativeEffect)
      }
      let decoded = match result {
        Ok(json) => native_work_decode(json)
        Err(_) => None
      }
      guard decoded is Some(envelope) else {
        return native_work_failed(
          state,
          pending.operation,
          native_work_public_error(result),
        )
      }
      if state.revision is Some(revision) && envelope.revision < revision {
        return native_work_failed(
          state,
          pending.operation,
          "Town returned an older saved revision. Reload saved status before taking an action.",
        )
      }
      (
        {
          ..state,
          revision: Some(envelope.revision),
          items: envelope.items,
          pending: None,
          loaded: true,
          error: "",
          notice: match pending.operation {
            ReadSaved => state.notice
            ControlNative(_, action) =>
              native_work_action_label(action) +
              " returned saved status. Review the state and blockers below; a successful response does not mean the work is complete."
          },
        },
        NoNativeEffect,
      )
    }
    NativeTimedOut(generation, request) => {
      guard state.active &&
        generation == state.generation &&
        state.pending is Some(pending) &&
        pending.request == request else {
        return (state, NoNativeEffect)
      }
      native_work_failed(
        state,
        pending.operation,
        "Saved status did not arrive. Reload saved status to check again.",
      )
    }
  }
}
