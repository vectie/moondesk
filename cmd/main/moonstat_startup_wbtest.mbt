///|
test "moonstat startup messages describe panels and standalone fallback" {
  assert_eq(
    moonstat_startup_ready_message("http://127.0.0.1:15721"),
    "MoonGate available at http://127.0.0.1:15721; usage/statistics panels enabled",
  )
  assert_eq(
    moonstat_startup_unavailable_message(
      "http://127.0.0.1:15721", "request error: connection refused",
    ),
    "MoonGate unavailable at http://127.0.0.1:15721; continuing as standalone MoonDesk: request error: connection refused",
  )
}
