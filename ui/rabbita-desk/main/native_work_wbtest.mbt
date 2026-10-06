///|
fn native_work_test_item() -> NativeWorkStatus {
  {
    id: "town-work-0123456789abcdef0123456789abcdef",
    kind: "engineering",
    book_id: "book-native",
    criterion_id: "criterion-one",
    state: "blocked",
    control_state: "cancel_unknown",
    blocked_reason: "owner_unavailable",
    blocker_help: "Refresh observation to check the saved command.",
    session_id: "session-exact",
    command_id: "command-exact",
    engineering_status: "pending_application",
    output: "first line\n<script>not executable</script>\nlast line",
    generation: 3,
    observed_at_ms: 1790985600000UL,
    retry_after_ms: 1790985660000UL,
  }
}

///|
fn native_work_test_json(
  revision : Int,
  items : Array[NativeWorkStatus],
) -> Json {
  let envelope : NativeWorkEnvelope = {
    schema: "moontown.native-work.status.v1",
    revision,
    items,
  }
  ToJson::to_json(envelope)
}

///|
fn native_work_test_ready() -> NativeWorkState {
  let (loading, _) = reduce_native_work(
    init_native_work(),
    BindNative(true, "library", "selected-book"),
  )
  let (ready, _) = reduce_native_work(
    loading,
    NativeReceived(
      loading.generation,
      loading.request,
      Ok(native_work_test_json(7, [native_work_test_item()])),
    ),
  )
  ready
}

///|
test "native work decoder requires status schema revision exact IDs and complete DTO" {
  let item = native_work_test_item()
  assert_true(native_work_decode(native_work_test_json(7, [item])) is Some(_))
  assert_true(native_work_decode(native_work_test_json(-1, [item])) is None)
  assert_true(
    native_work_decode(native_work_test_json(7, [item, item])) is None,
  )
  assert_true(
    native_work_decode(
      native_work_test_json(7, [{ ..item, id: "../../config", }]),
    )
    is None,
  )
  assert_true(
    native_work_decode(native_work_test_json(7, [{ ..item, generation: -1, }]))
    is None,
  )
  assert_true(
    native_work_decode({ "schema": "old-schema", "revision": 0, "items": [] })
    is None,
  )
  assert_true(
    native_work_decode({
      "schema": "moontown.native-work.status.v1",
      "revision": 0,
      "items": [{ "id": item.id }],
    })
    is None,
  )
  assert_false(
    native_work_id_valid("town-work-0123456789ABCDEF0123456789abcdef"),
  )
  assert_false(native_work_id_valid(item.id + "/sync"))
}

///|
test "native work navigation and reload are saved GET effects only" {
  let (loading, effect) = reduce_native_work(
    init_native_work(),
    BindNative(true, "library", "book-one"),
  )
  assert_eq(effect, ReadNativeSaved(1, 1))
  assert_true(loading.pending is Some({ operation: ReadSaved, .. }))
  let (same, effect) = reduce_native_work(
    loading,
    BindNative(true, "library", "book-one"),
  )
  assert_eq(same, loading)
  assert_eq(effect, NoNativeEffect)
  let (ready, _) = reduce_native_work(
    loading,
    NativeReceived(1, 1, Ok(native_work_test_json(7, []))),
  )
  let (reloading, effect) = reduce_native_work(ready, ReloadSavedNative)
  assert_eq(effect, ReadNativeSaved(1, 2))
  assert_true(reloading.loaded)
  assert_true(reloading.items.is_empty())
}

///|
test "native work controls carry exact owner ID and revision with no browser target" {
  let ready = native_work_test_ready()
  let id = native_work_test_item().id
  for action in [RefreshObservation, CancelRemaining, SyncResults] {
    let (pending, effect) = reduce_native_work(ready, ActOnNative(id, action))
    assert_eq(
      effect,
      PostNativeControl(ready.generation, ready.request + 1, id, action, 7),
    )
    assert_true(native_work_action_disabled(pending, id))
    let (duplicate, duplicate_effect) = reduce_native_work(
      pending,
      ActOnNative(id, action),
    )
    assert_eq(duplicate, pending)
    assert_eq(duplicate_effect, NoNativeEffect)
    let (_, reload_effect) = reduce_native_work(pending, ReloadSavedNative)
    assert_eq(reload_effect, NoNativeEffect)
  }
  json_inspect(native_work_mutation_body(7), content={ "expected_revision": 7 })
  assert_eq(native_work_action_path(RefreshObservation), "refresh")
  assert_eq(native_work_action_path(CancelRemaining), "cancel")
  assert_eq(native_work_action_path(SyncResults), "sync")
}

///|
test "native work conflict and lost response reload without repeating any POST" {
  let ready = native_work_test_ready()
  let id = ready.items[0].id
  let responses : Array[Result[Json, String]] = [
    Ok({ "ok": false, "error": "stale revision" }),
    Err("connection lost after owner accepted"),
    Ok({ "schema": "invalid" }),
  ]
  for response in responses {
    let (pending, _) = reduce_native_work(
      ready,
      ActOnNative(id, CancelRemaining),
    )
    let (recovering, effect) = reduce_native_work(
      pending,
      NativeReceived(pending.generation, pending.request, response),
    )
    assert_eq(effect, ReadNativeSaved(pending.generation, pending.request + 1))
    assert_true(recovering.revision is None)
    assert_true(
      recovering.notice.contains("no action was automatically retried"),
    )
    assert_eq(recovering.items[0].control_state, "cancel_unknown")
    let (recovered, effect) = reduce_native_work(
      recovering,
      NativeReceived(
        recovering.generation,
        recovering.request,
        Ok(native_work_test_json(8, ready.items)),
      ),
    )
    assert_eq(effect, NoNativeEffect)
    assert_eq(recovered.revision, Some(8))
    assert_true(recovered.notice.contains("Inspect"))
    assert_eq(recovered.items[0].control_state, "cancel_unknown")
  }
}

///|
test "native work mutation timeout and late responses cannot replace recovery or newer data" {
  let ready = native_work_test_ready()
  let (pending, _) = reduce_native_work(
    ready,
    ActOnNative(ready.items[0].id, SyncResults),
  )
  let (recovering, effect) = reduce_native_work(
    pending,
    NativeTimedOut(pending.generation, pending.request),
  )
  assert_eq(effect, ReadNativeSaved(pending.generation, pending.request + 1))
  let (ignored, effect) = reduce_native_work(
    recovering,
    NativeReceived(
      pending.generation,
      pending.request,
      Ok(native_work_test_json(99, [])),
    ),
  )
  assert_eq(ignored, recovering)
  assert_eq(effect, NoNativeEffect)
  let (recovered, _) = reduce_native_work(
    recovering,
    NativeReceived(
      recovering.generation,
      recovering.request,
      Ok(native_work_test_json(8, ready.items)),
    ),
  )
  let (still_recovered, _) = reduce_native_work(
    recovered,
    NativeTimedOut(pending.generation, pending.request),
  )
  assert_eq(still_recovered, recovered)
}

///|
test "native work GET failure retains saved rows but blocks controls until successful reload" {
  let ready = native_work_test_ready()
  let (loading, _) = reduce_native_work(ready, ReloadSavedNative)
  let (failed, effect) = reduce_native_work(
    loading,
    NativeTimedOut(loading.generation, loading.request),
  )
  assert_eq(effect, NoNativeEffect)
  assert_eq(failed.items, ready.items)
  assert_true(failed.revision is None)
  assert_true(failed.pending is None)
  assert_true(native_work_action_disabled(failed, ready.items[0].id))
  let (_, effect) = reduce_native_work(failed, ReloadSavedNative)
  assert_true(effect is ReadNativeSaved(_, _))
}

///|
test "native work rejects lower saved revisions" {
  let ready = native_work_test_ready()
  let (loading, _) = reduce_native_work(ready, ReloadSavedNative)
  let (failed, effect) = reduce_native_work(
    loading,
    NativeReceived(
      loading.generation,
      loading.request,
      Ok(native_work_test_json(6, [])),
    ),
  )
  assert_eq(effect, NoNativeEffect)
  assert_eq(failed.items, ready.items)
  assert_true(failed.revision is None)
  assert_true(failed.error.contains("older saved revision"))
}

///|
test "native work navigation generation rejects old responses even after returning to same Book" {
  let ready = native_work_test_ready()
  let (pending, _) = reduce_native_work(
    ready,
    ActOnNative(ready.items[0].id, CancelRemaining),
  )
  let (away, _) = reduce_native_work(
    pending,
    BindNative(false, "library", "selected-book"),
  )
  let (back, _) = reduce_native_work(
    away,
    BindNative(true, "library", "selected-book"),
  )
  let (ignored, effect) = reduce_native_work(
    back,
    NativeReceived(
      pending.generation,
      pending.request,
      Ok(native_work_test_json(99, [])),
    ),
  )
  assert_eq(ignored, back)
  assert_eq(effect, NoNativeEffect)
  assert_true(back.notice.contains("action was in progress"))
  let (other_library, _) = reduce_native_work(
    back,
    BindNative(true, "other-library", "other-book"),
  )
  assert_true(other_library.items.is_empty())
  assert_false(other_library.loaded)
}

///|
test "native work terminal results stay explicitly syncable" {
  let ready = native_work_test_ready()
  for status in ["completed", "failed", "cancelled", "unreserved", "blocked"] {
    let item = { ..ready.items[0], state: status, }
    let state = { ..ready, items: [item], }
    assert_false(native_work_action_disabled(state, item.id))
    let (_, effect) = reduce_native_work(
      state,
      ActOnNative(item.id, SyncResults),
    )
    assert_true(effect is PostNativeControl(_, _, _, SyncResults, 7))
  }
}

///|
test "native work integration preserves selected Book ordinary requests runs and composer" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let initial = {
    ..init_model(),
    workspace_mode: RequestsWorkspace,
    activity: Town,
    selected_workspace_id: "selected-book",
    workspace_library_path: "library",
    requests: [requests_test_record()],
    request_prompt: "keep my draft",
  }
  let (_, bound) = sync_native_work_context(dispatch, initial)
  let (_, loaded) = update(
    dispatch,
    NativeWork(
      NativeReceived(
        bound.native_work.generation,
        bound.native_work.request,
        Ok(native_work_test_json(7, [native_work_test_item()])),
      ),
    ),
    bound,
  )
  assert_eq(loaded.selected_workspace_id, "selected-book")
  assert_eq(loaded.requests[0].id, initial.requests[0].id)
  assert_eq(loaded.runs.length(), initial.runs.length())
  assert_eq(loaded.request_prompt, "keep my draft")
  let (_, leaving) = update(dispatch, SelectWorkspaceMode(Desk), loaded)
  assert_false(leaving.native_work.active)
  assert_true(leaving.native_work.generation > loaded.native_work.generation)
}

///|
#warnings("-alert_unstable")
test "native work component renders saved evidence exact identity escaped output and limitations" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let ready = native_work_test_ready()
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(render_native_work(dispatch, ready)),
  )
  for
    text in [
      "Saved status across all Books", "not live", "Pause is not supported", "Pause unavailable",
      "does not undo applied edits", "may dispatch or resend", "apply verified results",
      "town-work-0123456789abcdef0123456789abcdef", "session-exact", "command-exact",
      "cancel_unknown", "pending_application", "2026-10-03T00:00:00.000Z", "first line",
      "last line", "native-work-refresh", "native-work-cancel", "native-work-sync",
    ] {
    assert_true(markup.contains(text), msg=text)
  }
  assert_false(markup.contains("<script>not executable</script>"))
  assert_true(markup.contains("&lt;script&gt;not executable&lt;/script&gt;"))
  assert_true(markup.contains("aria-live=\"polite\""))
  let (pending, _) = reduce_native_work(
    ready,
    ActOnNative(ready.items[0].id, SyncResults),
  )
  let pending_markup = @rabbita.render_to_string(
    @rabbita.static_cell(render_native_work(dispatch, pending)),
  )
  assert_eq(pending_markup.split(" disabled").length(), 6)
  assert_true(pending_markup.contains("pending…"))
}

///|
#warnings("-alert_unstable")
test "native work component distinguishes empty saved status and failed reload" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let empty = { ..native_work_test_ready(), items: [], }
  let empty_markup = @rabbita.render_to_string(
    @rabbita.static_cell(render_native_work(dispatch, empty)),
  )
  assert_true(empty_markup.contains("No saved native work."))
  let failed = { ..empty, revision: None, error: "Town unavailable", }
  let failed_markup = @rabbita.render_to_string(
    @rabbita.static_cell(render_native_work(dispatch, failed)),
  )
  assert_false(failed_markup.contains("No saved native work."))
  assert_true(failed_markup.contains("Town unavailable"))
  assert_eq(native_work_timestamp("0"), "No saved check / attempt")
}

///|
test "native work wire integer validation rejects truncation overflow and wrong types" {
  let invalid : Array[Json] = [-1, 0.25, 2147483648.0, "7", true, Json::null()]
  for value in invalid {
    assert_true(native_work_nonnegative_int(value) is None)
    assert_true(
      native_work_decode({
        "schema": "moontown.native-work.status.v1",
        "revision": value,
        "items": [],
      })
      is None,
    )
    let raw = ToJson::to_json(native_work_test_item())
    guard raw is Object(fields) else { fail("expected DTO object") }
    fields["generation"] = value
    assert_true(
      native_work_decode({
        "schema": "moontown.native-work.status.v1",
        "revision": 7,
        "items": [raw],
      })
      is None,
    )
  }
  assert_eq(native_work_nonnegative_int(2147483647), Some(2147483647))
  let raw = ToJson::to_json(native_work_test_item())
  assert_true(
    raw
    is {
      "observed_at_ms": String("1790985600000"),
      "retry_after_ms": String("1790985660000"),
      ..
    },
  )
}

///|
test "native work safe capability and conflict messages survive saved recovery" {
  let ready = native_work_test_ready()
  let (loading, _) = reduce_native_work(ready, ReloadSavedNative)
  let (failed, _) = reduce_native_work(
    loading,
    NativeReceived(
      loading.generation,
      loading.request,
      Ok({ "ok": false, "error": "Town native-work capability is unavailable" }),
    ),
  )
  assert_eq(failed.error, "Town native-work capability is unavailable")
  let (pending, _) = reduce_native_work(
    ready,
    ActOnNative(ready.items[0].id, CancelRemaining),
  )
  let (recovering, effect) = reduce_native_work(
    pending,
    NativeReceived(
      pending.generation,
      pending.request,
      Ok({ "ok": false, "error": "Saved revision changed; reload first" }),
    ),
  )
  assert_true(effect is ReadNativeSaved(_, _))
  assert_true(
    recovering.notice.contains("Saved revision changed; reload first"),
  )
  assert_false(
    native_work_public_error(Err("private native exception")).contains(
      "private native exception",
    ),
  )
  assert_false(
    native_work_public_error(Ok({ "error": "unrecognized raw payload" })).contains(
      "unrecognized raw payload",
    ),
  )
}
