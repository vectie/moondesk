///|
fn town_native_work_response_headers(
  allowed? : Array[String] = [],
) -> Map[String, String] {
  let headers = { "Cache-Control": "no-store" }
  if !allowed.is_empty() {
    headers["Allow"] = allowed.join(", ")
  }
  headers
}

///|
fn town_native_work_response_payload(
  result : Result[Json, (Int, String)],
) -> (Int, String, Json) {
  match result {
    Ok(payload) => (200, "OK", payload)
    Err((code, message)) => {
      let reason = match code {
        400 => "Bad Request"
        404 => "Not Found"
        405 => "Method Not Allowed"
        409 => "Conflict"
        413 => "Payload Too Large"
        _ => "Service Unavailable"
      }
      (
        code,
        reason,
        api_contract_response(
          { "error": message },
          ok=false,
          status="error",
          message~,
          next_action="inspect_request",
        ),
      )
    }
  }
}

///|
async fn send_town_native_work_response(
  conn : @http.ServerConnection,
  method_ : @http.RequestMethod,
  result : Result[Json, (Int, String)],
  allowed? : Array[String] = [],
) -> Unit {
  let (code, reason, payload) = town_native_work_response_payload(result)
  send_api_json_error_with_headers(
    conn,
    method_,
    code,
    reason,
    payload,
    town_native_work_response_headers(allowed~),
  )
}

///|
/// Bound the complete owner lookup, capability read, and exchange below the
/// browser's 30-second deadline. Cancellation closes the transport through its
/// existing defer; a timed-out mutation is uncertain and must never be retried.
async fn town_native_work_with_deadline(
  operation : async () -> Result[Json, (Int, String)],
  timeout_ms? : Int = 25000,
) -> Result[Json, (Int, String)] {
  @async.with_timeout(timeout_ms, operation) catch {
    _ => Err(town_native_work_owner_error(503))
  }
}

///|
async fn town_native_work_read_body(
  body : &@io.Reader,
) -> Result[Bytes, (Int, String)] {
  let output = @buffer.Buffer(size_hint=512)
  for ;; {
    let chunk = body.read_some(max_len=4097 - output.length()) catch {
      _ => return Err((400, "Unable to read Town work request body"))
    }
    guard chunk is Some(chunk) else { break }
    if output.length() + chunk.length() > 4096 {
      return Err((413, "Town work request exceeds the 4 KiB limit"))
    }
    output.write_bytes(chunk)
  }
  Ok(output.to_bytes())
}

///|
async fn town_native_work_owner_exchange(
  service_url : String,
  method_ : String,
  path : String,
  body : Json?,
) -> Result[(Int, Json), String] {
  let client = @http.Client(service_url)
  defer client.close()
  let response = if method_ == "POST" {
    guard body is Some(payload) else { return Err("Missing work request") }
    let encoded = @encoding/utf8.encode(payload.stringify())
    client.post(path, encoded, extra_headers={
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Content-Length": encoded.length().to_string(),
    }) catch {
      _ => return Err("Town owner unavailable")
    }
  } else {
    client.get(path) catch {
      _ => return Err("Town owner unavailable")
    }
  }
  // Error bodies may contain private native details; never forward them.
  if response.code < 200 || response.code > 299 {
    return Ok((response.code, Json::null()))
  }
  let text = client.read_all().text() catch {
      _ => return Err("Unreadable Town owner response")
    }
  let payload = @json.parse(text) catch {
    _ => return Err("Invalid Town owner response")
  }
  Ok((response.code, payload))
}

///|
async fn handle_town_native_work(
  workspace_root : String,
  request_path : String,
  method_ : @http.RequestMethod,
  body : &@io.Reader,
  conn : @http.ServerConnection,
) -> Unit {
  let route = match town_native_work_route(request_path) {
    Ok(route) => route
    Err(error) => {
      send_town_native_work_response(conn, method_, Err(error))
      return
    }
  }
  let allowed = town_native_work_allowed_methods(route)
  if !allowed.contains(mooncode_request_method_name(method_)) {
    send_town_native_work_response(
      conn,
      method_,
      Err((405, "Method Not Allowed")),
      allowed~,
    )
    return
  }
  let bytes = if method_ is Post {
    match town_native_work_read_body(body) {
      Ok(value) => value
      Err(error) => {
        send_town_native_work_response(conn, method_, Err(error))
        return
      }
    }
  } else {
    b""
  }
  let owner_url : Ref[String?] = @ref.new(None)
  let result = town_native_work_with_deadline(() => {
    town_native_work_request_with(request_path, method_, bytes, (
      verb,
      path,
      payload,
    ) => {
      let service_url = match owner_url.val {
        Some(url) => url
        None =>
          match moontown_owner_service_url(workspace_root) {
            Ok(url) => {
              owner_url.val = Some(url)
              url
            }
            Err(error) => return Err(error)
          }
      }
      town_native_work_owner_exchange(service_url, verb, path, payload)
    })
  })
  send_town_native_work_response(conn, method_, result)
}
