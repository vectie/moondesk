///|
async fn handle_create_book_from_pattern(
  workspace_root : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let payload = match read_json_body(body) {
    Some(json) => json
    None => {
      send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
      return
    }
  }
  match book_pattern_id_from_creation_payload(payload) {
    Some(pattern_id) =>
      create_book_from_supported_pattern(
        workspace_root, payload, method_, conn, pattern_id,
      )
    None => {
      let raw = json_string(payload, "pattern_id", default="").trim().to_owned()
      if raw == "" {
        send_api_error(
          conn, method_, 400, "Bad Request", "pattern_id is required",
        )
      } else {
        send_api_error(
          conn,
          method_,
          400,
          "Bad Request",
          "Unsupported book pattern `\{raw}`.",
        )
      }
    }
  }
}

///|
async fn create_book_from_supported_pattern(
  workspace_root : String,
  payload : Json,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
  pattern_id : String,
) -> Unit {
  match book_pattern_creation_backend(pattern_id) {
    "builtin-pdf-evidence-watch" =>
      create_pdf_evidence_watch_book_from_payload(
        workspace_root,
        payload,
        method_,
        conn,
        pattern_id~,
      )
    "" =>
      send_api_error(
        conn,
        method_,
        400,
        "Bad Request",
        "Book pattern `\{pattern_id}` does not declare a creation backend.",
      )
    backend =>
      send_api_error(
        conn,
        method_,
        400,
        "Bad Request",
        "Book pattern `\{pattern_id}` declares unsupported creation backend `\{backend}`.",
      )
  }
}

///|
fn book_pattern_id_from_creation_payload(payload : Json) -> String? {
  let pattern_id = json_string(payload, "pattern_id", default="")
  if book_pattern_supported(pattern_id) {
    supported_book_pattern_id(pattern_id)
  } else {
    None
  }
}
