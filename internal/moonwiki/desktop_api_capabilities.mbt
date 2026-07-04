///|
async fn handle_desktop_api_capabilities(
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  send_json(conn, method_, desktop_api_capabilities_json())
}

///|
fn desktop_api_capabilities_json() -> Json {
  api_contract_response(
    {
      "component": "moondesk-desktop-api",
      "kind": "moondesk-desktop-api-capabilities.v1",
      "version": 1,
      "route_contract_endpoint": @desk.desktop_capabilities_route(),
      "required_endpoints": json_from_string_array(
        @desk.desktop_api_required_endpoints(),
      ),
      "desktop_route_contracts": Json::array(desktop_api_route_contract_jsons()),
      "portable_api_snapshot_routes": json_from_string_array(
        @desk.desktop_portable_api_snapshot_routes(),
      ),
      "portable_api_workspace_content_routes": json_from_string_array(
        @desk.desktop_portable_api_workspace_content_routes(),
      ),
      "portable_api_supported_route_patterns": json_from_string_array(
        @desk.desktop_portable_api_supported_route_patterns(),
      ),
    },
    ok=true,
    status="ready",
    message="Moondesk desktop API route contract is published",
    next_action="use_desktop_route_contract",
  )
}

///|
fn desktop_api_route_contract_jsons() -> Array[Json] {
  let contracts : Array[Json] = []
  for contract in @desk.desktop_api_route_contracts() {
    contracts.push(contract.to_json())
  }
  contracts
}
