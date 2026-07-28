///|
test "bootstrap action runs once" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let (_, bootstrapped) = bootstrap_action(dispatch, init_model())
  assert_true(bootstrapped.bootstrapped)
  assert_true(bootstrapped.loading)
  let (_, unchanged) = bootstrap_action(dispatch, bootstrapped)
  assert_true(unchanged.bootstrapped)
  assert_eq(unchanged.host_status, bootstrapped.host_status)
}

///|
test "cold-start metadata failure preserves one-time bootstrap state" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let (_, next) = update_workspace_results(
    dispatch,
    LoadedWorkspaceMetadata(Err("Invalid workspace metadata")),
    { ..init_model(), bootstrapped: true },
  )
  assert_true(next.bootstrapped)
  assert_eq(next.host_status, "Invalid workspace metadata")
}

///|
test "bootstrap retry refreshes data without resetting one-time setup" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let (_, next) = bootstrap_retry_action(dispatch, {
    ..init_model(),
    bootstrapped: true,
    loading: false,
  })
  assert_true(next.bootstrapped)
  assert_true(next.loading)
  assert_eq(next.host_status, "Connecting to your library")
}

///|
test "metadata refresh failure does not restart an established bootstrap" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let (_, next) = update_workspace_results(
    dispatch,
    LoadedWorkspaceMetadata(Err("Invalid workspace metadata")),
    { ..init_model(), bootstrapped: true, workspace_root_path: "/tmp/library" },
  )
  assert_true(next.bootstrapped)
  assert_eq(next.workspace_root_path, "/tmp/library")
}
