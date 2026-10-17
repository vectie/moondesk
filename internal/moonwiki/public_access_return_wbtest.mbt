///|
test "login return preserves exact work output and human return hints" {
  let path = "/?activity=code&session=S&command=C0&work_task=T&work_run=R&work_output_command=C1&work_output_path=report%20%E4%B9%A6.md&work_output_evidence=E1&return_to=https%3A%2F%2Fproj.example%2F%3Ftask%3DT"
  assert_eq(
    @json.parse(moondesk_operator_login_target(path)),
    ToJson::to_json(path),
  )
  assert_eq(
    @json.parse(moondesk_operator_login_target("/")),
    ToJson::to_json("/"),
  )
}

///|
test "login return never accepts external or non-app paths" {
  for
    path in [
      "//evil.example/", "https://evil.example/", "javascript:alert(1)", "/auth/password",
      "/other?x=1", "/\\evil.example", "/?x=1\n", "/?x=1#fragment",
    ] {
    assert_eq(
      @json.parse(moondesk_operator_login_target(path)),
      ToJson::to_json("/"),
    )
  }
  let path = "/?return_to=https://evil.example/"
  assert_eq(
    @json.parse(moondesk_operator_login_target(path)),
    ToJson::to_json(path),
  )
}

///|
test "login return JSON cannot terminate the inline script" {
  let path = "/?work_output_path=</script><script>alert(1)</script>&q=\""
  let literal = moondesk_operator_login_target(path)
  assert_false(literal.contains("<"))
  assert_false(literal.contains(">"))
  assert_false(literal.contains("&"))
  assert_eq(@json.parse(literal), ToJson::to_json(path))
  let page = moondesk_operator_login_page(return_path=path)
  assert_true(page.contains("location.replace(" + literal + "+location.hash)"))
  assert_eq(page.split("</script>").count(), 2)
  assert_true(page.contains("fetch('/auth/password'"))
  assert_true(page.contains("document.querySelector('#password').value=''"))
}
