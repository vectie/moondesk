///|
test "every mutating desktop route declares an explicit authority scope" {
  assert_true(@core.desktop_api_mutating_routes_have_authority())
  assert_true(
    @core.desktop_api_route_authority(@core.workspace_import_route())
    is Some("import-staging"),
  )
  assert_true(
    @core.desktop_api_route_authority(@core.workspace_action_route("trash"))
    is Some("trash-restore"),
  )
  assert_true(
    @core.desktop_api_route_authority(@core.workspace_action_route("markdown"))
    is Some("selected-book"),
  )
  for route in @core.desktop_api_route_contracts() {
    if route.methods.any(verb => {
        ["POST", "PUT", "PATCH", "DELETE"].contains(verb)
      }) {
      assert_false(route.authority_scope == "read-only")
      assert_false(route.authority_scope.is_empty())
    }
  }
}
