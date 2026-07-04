///|
fn desktop_api_request_method_name(method_ : @http.RequestMethod) -> String {
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
fn desktop_api_route_allows_method(
  endpoint : String,
  method_ : @http.RequestMethod,
) -> Bool {
  @desk.desktop_api_route_accepts_method(
    endpoint,
    desktop_api_request_method_name(method_),
  )
}

///|
fn desktop_api_route_accepts_read(
  endpoint : String,
  method_ : @http.RequestMethod,
) -> Bool {
  is_read_method(method_) && desktop_api_route_allows_method(endpoint, method_)
}

///|
fn desktop_api_route_accepts_post(
  endpoint : String,
  method_ : @http.RequestMethod,
) -> Bool {
  method_ is Post && desktop_api_route_allows_method(endpoint, method_)
}

///|
fn desktop_api_route_allowed_methods(endpoint : String) -> Array[String] {
  @desk.desktop_api_route_allowed_methods(endpoint)
}

///|
async fn send_desktop_api_method_not_allowed(
  conn : @http.ServerConnection,
  method_ : @http.RequestMethod,
  endpoint : String,
) -> Unit {
  send_method_not_allowed_with_methods(
    conn,
    method_,
    desktop_api_route_allowed_methods(endpoint),
  )
}
