///|
test "work handoff native claim endpoint encodes paths without changing identities" {
  assert_eq(
    @mooncode.moonclaw_native_runtime_claim_endpoint(
      "session /书", "/books/书 with spaces/",
    ),
    "/v1/code/sessions/session%20%2F%E4%B9%A6/runtime-claim?book_root=%2Fbooks%2F%E4%B9%A6%20with%20spaces%2F",
  )
  assert_eq(
    @mooncode.desktop_work_handoff_endpoint(),
    "/api/mooncode/work-handoff",
  )
}
