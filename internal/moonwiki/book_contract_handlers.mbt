///|
async fn handle_book_contract_verify(
  workspace_root : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let book_id = decode_query_value(
      query_value(request_path, "book_id").unwrap_or(""),
    )
    .trim()
    .to_owned()
  if book_id == "" {
    send_api_error(conn, method_, 400, "Bad Request", "book_id is required")
    return
  }
  let context = workspace_context(workspace_root)
  let book_root = context.book_root(book_id)
  let book_json_path = @pathx.join(book_root, "book.json")
  if !@fs.exists(book_json_path) {
    send_api_error(conn, method_, 404, "Not Found", "Book not found")
    return
  }
  let book_json = read_json_file_or_object(book_json_path)
  let pattern_id = pdf_watch_pattern_id_from_book_json(book_json)
  send_json(
    conn,
    method_,
    book_contract_verification(
      context.suite_root,
      book_root,
      book_id,
      pattern_id,
    ),
  )
}
