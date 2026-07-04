///|
fn desktop_capability_route_methods(contract : Json) -> Array[String] {
  json_string_array_items(contract, "methods")
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
test "desktop api capabilities exclude retired town control route" {
  let capability = desktop_api_capabilities_json()
  let endpoints = json_string_array_items(capability, "required_endpoints")
  assert_true(endpoints.contains(@desk.desktop_capabilities_route()))
  assert_true(endpoints.contains(@desk.town_route("dispatch")))
  assert_false(endpoints.contains(@desk.town_route("control")))
  assert_eq(endpoints.length(), @desk.desktop_api_required_endpoints().length())
}
