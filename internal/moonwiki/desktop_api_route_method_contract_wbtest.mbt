///|
test "desktop api route contract drives generic method checks" {
  let workspaces = @desk.workspaces_route()
  assert_true(desktop_api_route_accepts_read(workspaces, Get))
  assert_true(desktop_api_route_accepts_read(workspaces, Head))
  assert_true(desktop_api_route_accepts_post(workspaces, Post))
  assert_false(desktop_api_route_allows_method(workspaces, Put))
  assert_eq(
    desktop_api_route_allowed_methods(workspaces).join(", "),
    "GET, HEAD, POST",
  )
  let trash = @desk.workspace_action_route("trash")
  assert_true(desktop_api_route_accepts_read(trash, Get))
  assert_true(desktop_api_route_accepts_read(trash, Head))
  assert_true(desktop_api_route_accepts_post(trash, Post))
  assert_false(desktop_api_route_allows_method(trash, Delete))
  let dispatch = @desk.town_route("dispatch")
  let github_comment = @desk.workspace_action_route("git/github/comment")
  assert_true(desktop_api_route_accepts_post(github_comment, Post))
  assert_false(desktop_api_route_accepts_read(github_comment, Get))
  let github_draft = @desk.workspace_action_route("git/github/draft")
  assert_true(desktop_api_route_accepts_post(github_draft, Post))
  assert_false(desktop_api_route_accepts_read(github_draft, Get))
  let github_inline = @desk.workspace_action_route("git/github/inline")
  assert_true(desktop_api_route_accepts_read(github_inline, Get))
  assert_true(desktop_api_route_accepts_read(github_inline, Head))
  assert_true(desktop_api_route_accepts_post(github_inline, Post))
  let github_inline_draft = @desk.workspace_action_route(
    "git/github/inline/draft",
  )
  assert_true(desktop_api_route_accepts_post(github_inline_draft, Post))
  assert_false(desktop_api_route_accepts_read(github_inline_draft, Get))
  assert_false(desktop_api_route_accepts_read(dispatch, Get))
  assert_false(desktop_api_route_accepts_read(dispatch, Head))
  assert_true(desktop_api_route_accepts_post(dispatch, Post))
  assert_eq(desktop_api_route_allowed_methods(dispatch).join(", "), "POST")
  let retired_control = @desk.town_route("control")
  assert_false(desktop_api_route_accepts_post(retired_control, Post))
  assert_eq(desktop_api_route_allowed_methods(retired_control).length(), 0)
}
