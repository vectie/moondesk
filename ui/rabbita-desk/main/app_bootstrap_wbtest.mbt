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
