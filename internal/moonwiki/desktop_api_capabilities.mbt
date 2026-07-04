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
    @desk.desktop_api_capability_contract().to_json(),
    ok=true,
    status="ready",
    message="Moondesk desktop API route contract is published",
    next_action="use_desktop_route_contract",
  )
}
