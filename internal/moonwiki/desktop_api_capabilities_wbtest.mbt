///|
fn desktop_capability_route_methods(contract : Json) -> Array[String] {
  json_string_array_items(contract, "methods")
}

///|
fn assert_capability_string_array(
  capability : Json,
  field : String,
  expected : Array[String],
) -> Unit raise {
  assert_eq(
    json_string_array_items(capability, field).join("\n"),
    expected.join("\n"),
  )
}

///|
test "desktop api capabilities publish core route contracts" {
  let capability = desktop_api_capabilities_json()
  assert_eq(
    json_string(capability, "component", default=""),
    "moondesk-desktop-api",
  )
  assert_eq(
    json_string(capability, "kind", default=""),
    "moondesk-desktop-api-capabilities.v1",
  )
  assert_eq(
    json_string(capability, "route_contract_endpoint", default=""),
    @desk.desktop_capabilities_route(),
  )
  assert_eq(
    json_string(capability, "api_contract", default=""),
    "moonsuite.phase6.v1",
  )
  assert_eq(
    json_string(capability, "next_action", default=""),
    "use_desktop_route_contract",
  )

  let published = json_array_items(capability, "desktop_route_contracts")
  let expected = @desk.desktop_api_route_contracts()
  assert_eq(published.length(), expected.length())
  for contract in expected {
    let matches : Array[Json] = []
    for item in published {
      if json_string(item, "path", default="") == contract.path {
        matches.push(item)
      }
    }
    assert_eq(matches.length(), 1)
    assert_eq(
      desktop_capability_route_methods(matches[0]).join(", "),
      contract.methods.join(", "),
    )
  }
}

///|
test "desktop api capabilities publish portable route contract" {
  let capability = desktop_api_capabilities_json()
  let snapshot_routes = @desk.desktop_portable_api_snapshot_routes()
  let workspace_content_routes = @desk.desktop_portable_api_workspace_content_routes()
  let supported_patterns = @desk.desktop_portable_api_supported_route_patterns()

  assert_capability_string_array(
    capability, "portable_api_snapshot_routes", snapshot_routes,
  )
  assert_capability_string_array(
    capability, "portable_api_workspace_content_routes", workspace_content_routes,
  )
  assert_capability_string_array(
    capability, "portable_api_supported_route_patterns", supported_patterns,
  )

  assert_true(snapshot_routes.contains(@desk.workspaces_route()))
  assert_true(snapshot_routes.contains(@desk.books_route("patterns")))
  assert_true(snapshot_routes.contains(@desk.books_route("base-types")))
  assert_true(snapshot_routes.contains(@desk.books_route("template-registry")))
  assert_true(
    workspace_content_routes.contains(@desk.workspace_action_route("raw")),
  )
  assert_true(workspace_content_routes.contains(@desk.workspace_file_route()))
  assert_true(supported_patterns.contains(@desk.workspace_site_route()))
  assert_false(supported_patterns.contains(@desk.town_route("progress")))
  assert_false(supported_patterns.contains(@desk.town_route("dispatch")))
}

///|
test "desktop api capabilities exclude retired town control route" {
  let capability = desktop_api_capabilities_json()
  let endpoints = json_string_array_items(capability, "required_endpoints")
  assert_true(endpoints.contains(@desk.desktop_capabilities_route()))
  assert_true(endpoints.contains(@desk.town_route("dispatch")))
  assert_false(endpoints.contains(@desk.town_route("control")))
  assert_eq(endpoints.length(), @desk.desktop_api_required_endpoints().length())
}
