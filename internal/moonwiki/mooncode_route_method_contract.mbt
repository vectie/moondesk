///|
fn mooncode_contract_path(endpoint : String) -> String {
  let parts = endpoint.split("?").to_array()
  if parts.length() > 0 {
    parts[0].to_owned()
  } else {
    endpoint
  }
}

///|
fn mooncode_request_method_name(method_ : @http.RequestMethod) -> String {
  match method_ {
    Get => "GET"
    Head => "HEAD"
    Post => "POST"
    Put => "PUT"
    Patch => "PATCH"
    Delete => "DELETE"
    Options => "OPTIONS"
    Connect => "CONNECT"
    Trace => "TRACE"
  }
}

///|
fn mooncode_route_allowed_methods(endpoint : String) -> Array[String] {
  let route_path = mooncode_contract_path(endpoint)
  for contract in @mooncode.desktop_projection_route_contracts() {
    let contract_path = mooncode_contract_path(
      json_string(contract, "path", default=""),
    )
    if contract_path == route_path {
      return json_string_array_items(contract, "methods")
    }
  }
  []
}

///|
fn mooncode_route_accepts_method(
  endpoint : String,
  method_ : @http.RequestMethod,
) -> Bool {
  let method_name = mooncode_request_method_name(method_)
  method_name != "" &&
  mooncode_route_allowed_methods(endpoint).contains(method_name)
}

///|
fn mooncode_route_accepts_read(
  endpoint : String,
  method_ : @http.RequestMethod,
) -> Bool {
  is_read_method(method_) && mooncode_route_accepts_method(endpoint, method_)
}

///|
fn mooncode_route_accepts_post(
  endpoint : String,
  method_ : @http.RequestMethod,
) -> Bool {
  method_ is Post && mooncode_route_accepts_method(endpoint, method_)
}

///|
async fn send_mooncode_method_not_allowed(
  conn : @http.ServerConnection,
  method_ : @http.RequestMethod,
  endpoint : String,
) -> Unit {
  send_method_not_allowed_with_methods(
    conn,
    method_,
    mooncode_route_allowed_methods(endpoint),
  )
}
