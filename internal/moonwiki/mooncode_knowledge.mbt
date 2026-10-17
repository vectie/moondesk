///|
fn mooncode_knowledge_path(book_root : String) -> String {
  @pathx.join(book_root, "book/knowledge/library.json")
}

///|
fn mooncode_knowledge_chunks(text : String) -> Array[Json] {
  let chunks : Array[Json] = []
  let lines = text.split("\n").collect()
  let mut start = 0
  while start < lines.length() {
    let end = if start + 20 < lines.length() {
      start + 20
    } else {
      lines.length()
    }
    let content = lines[start:end].map(line => line.to_owned()).join("\n")
    if !content.trim().is_empty() {
      chunks.push({ "start_line": start + 1, "end_line": end, "text": content })
    }
    start = end
  }
  chunks
}

///|
fn mooncode_knowledge_search(
  records : Array[Json],
  query : String,
) -> Array[Json] {
  let query = query.trim().to_owned().to_lower()
  if query == "" {
    return []
  }
  let terms = query
    .split(" ")
    .filter(term => term != "")
    .map(term => term.to_owned())
    .collect()
  let hits : Array[Json] = []
  for record in records {
    if !json_bool(record, "enabled", default=true) {
      continue
    }
    let path = json_string(record, "path", default="")
    let title = json_string(record, "title", default=path)
    for chunk in json_array_items(record, "chunks") {
      let content = json_string(chunk, "text", default="")
      let lowered = content.to_lower()
      let mut score = if lowered.contains(query) { 8 } else { 0 }
      for term in terms {
        if lowered.contains(term) {
          score += 2
        }
        if title.to_lower().contains(term) {
          score += 1
        }
      }
      if score == 0 {
        continue
      }
      let start = json_int(chunk, "start_line", default=1)
      let end = json_int(chunk, "end_line", default=start)
      hits.push({
        "source_id": json_string(record, "id", default=""),
        "path": path,
        "title": title,
        "start_line": start,
        "end_line": end,
        "text": content,
        "score": score,
        "citation": "[" + title + ", extracted lines \{start}–\{end}]",
      })
    }
  }
  hits.sort_by((a, b) => {
    json_int(b, "score", default=0).compare(json_int(a, "score", default=0))
  })
  if hits.length() > 12 {
    hits[:12].to_owned()
  } else {
    hits
  }
}

///|
fn mooncode_knowledge_office_text(model : OfficeSupportedModel) -> String {
  match model {
    Word(paragraphs) =>
      paragraphs
      .map(paragraph => paragraph.runs.map(run => run.text).join(""))
      .join("\n")
    Spreadsheet(sheets) =>
      sheets
      .map(sheet => {
        "# " +
        sheet.name +
        "\n" +
        sheet.cells.map(cell => cell.reference + ": " + cell.value).join("\n")
      })
      .join("\n\n")
    Presentation(slides) =>
      slides
      .map(slide => {
        "# " +
        slide.part +
        "\n" +
        slide.objects.map(object => object.text).join("\n")
      })
      .join("\n\n")
  }
}

///|
async fn mooncode_knowledge_extract(
  workspace : @desk.DeskWorkspace,
  path : String,
) -> Result[String, String] {
  let (absolute, relative) = match
    resolve_workspace_existing_path(workspace.root_path, path) {
    Some(pair) => pair
    None => return Err("Choose an existing file in this book")
  }
  if office_document_kind(relative) is Some(_) {
    match open_workspace_office(workspace, relative) {
      Ok((_, document)) =>
        Ok(mooncode_knowledge_office_text(document.supported))
      Err(message) => Err(message)
    }
  } else if relative.to_lower().has_suffix(".pdf") {
    Err("Import extracted PDF text, or choose a text or Office document")
  } else {
    let text = @fsx.read_file(absolute) catch {
      _ => return Err("This file could not be read as text")
    }
    Ok(text)
  }
}

///|
async fn handle_mooncode_knowledge(
  workspace_root : String,
  workspace_id : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let workspace = match find_workspace(workspace_root, workspace_id) {
    Some(value) => value
    None => {
      send_api_error(
        conn, method_, 404, "Not Found", "Select a book for its knowledge library",
      )
      return
    }
  }
  let state_path = mooncode_knowledge_path(workspace.root_path)
  if method_ is Get {
    send_json(conn, method_, {
      "records": Json::array(read_json_array_file(state_path)),
      "embeddings": mooncode_knowledge_embeddings_public(workspace.root_path),
    })
    return
  }
  if !(method_ is Post) {
    send_method_not_allowed_with_methods(conn, method_, ["GET", "POST"])
    return
  }
  let payload = match read_json_body(body) {
    Some(value) => value
    None => {
      send_api_error(
        conn, method_, 400, "Bad Request", "Invalid knowledge request",
      )
      return
    }
  }
  mooncode_setup_mutex.acquire()
  defer mooncode_setup_mutex.release()
  let records = read_json_array_file(state_path)
  let action = json_string(payload, "action", default="")
  if action == "search" {
    let query = json_string(payload, "query", default="")
    let config = mooncode_knowledge_embeddings_public(workspace.root_path)
    let mut semantic_error = ""
    if json_bool(config, "configured", default=false) {
      match
        mooncode_knowledge_runtime_request(
          workspace_root,
          workspace.root_path,
          { "action": "search", "query": query },
        ) {
        Ok(result) => {
          send_json(conn, method_, result)
          return
        }
        Err(message) => semantic_error = message
      }
    }
    send_json(conn, method_, {
      "hits": Json::array(mooncode_knowledge_search(records, query)),
      "retrieval": "ranked-text",
      "semantic_error": semantic_error,
    })
    return
  }
  let id = json_string(payload, "id", default="")
  let mut next = records.filter(record => {
    json_string(record, "id", default="") != id
  })
  if action == "index" || action == "save-text" {
    let path = json_string(payload, "path", default="")
    let content = if action == "index" {
      match mooncode_knowledge_extract(workspace, path) {
        Ok(text) => text
        Err(message) => {
          send_api_error(conn, method_, 400, "Bad Request", message)
          return
        }
      }
    } else {
      json_string(payload, "text", default="")
    }
    if content.trim().is_empty() {
      send_api_error(
        conn, method_, 400, "Bad Request", "Add searchable text before saving",
      )
      return
    }
    let id = if id == "" {
      @desk.stable_id(
        "knowledge",
        path + json_string(payload, "title", default=""),
      )
    } else {
      id
    }
    next = records.filter(record => json_string(record, "id", default="") != id)
    let enriched = mooncode_knowledge_enrich(
      workspace_root,
      workspace.root_path,
      mooncode_knowledge_chunks(content),
    )
    next.push({
      "id": id,
      "path": path,
      "title": json_string(payload, "title", default=path),
      "extracted_text": content,
      "chunks": Json::array(json_array_items(enriched, "chunks")),
      "enabled": json_bool(payload, "enabled", default=true),
      "indexed_at": @async.now().to_string(),
      "embedding_key": json_string(enriched, "embedding_key", default=""),
      "semantic_error": json_string(enriched, "semantic_error", default=""),
    })
  } else if action != "remove" {
    send_api_error(
      conn, method_, 400, "Bad Request", "Choose a knowledge action",
    )
    return
  }
  mooncode_setup_write(state_path, Json::array(next).stringify(indent=2))
  send_json(conn, method_, {
    "records": Json::array(next),
    "embeddings": mooncode_knowledge_embeddings_public(workspace.root_path),
  })
}
