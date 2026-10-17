///|
fn mooncode_knowledge_embeddings_path(book_root : String) -> String {
  moonsuite_product_artifact_for_workspace_root(
    book_root, "moonclaw", "knowledge-embeddings.json",
  )
}

///|
async fn mooncode_knowledge_embeddings_public(book_root : String) -> Json {
  let config = read_json_file_or_object(
    mooncode_knowledge_embeddings_path(book_root),
  )
  let url = json_string(config, "url", default="")
  let model = json_string(config, "model", default="")
  {
    "url": url,
    "model": model,
    "configured": url != "" && model != "",
    "has_token": json_string(config, "token", default="") != "",
  }
}

///|
async fn mooncode_knowledge_embeddings_save(
  book_root : String,
  payload : Json,
) -> Result[Json, String] {
  let path = mooncode_knowledge_embeddings_path(book_root)
  let previous = read_json_file_or_object(path)
  let url = json_string(payload, "url", default="").trim().to_owned()
  let model = json_string(payload, "model", default="").trim().to_owned()
  if url != "" &&
    ((!url.has_prefix("http://") && !url.has_prefix("https://")) || model == "") {
    return Err(
      "Enter an embeddings HTTP endpoint and model, or clear the endpoint to turn semantic search off",
    )
  }
  let supplied = json_string(payload, "token", default="")
  let token = if supplied == "" {
    json_string(previous, "token", default="")
  } else {
    supplied
  }
  let before = mooncode_knowledge_embeddings_public(book_root)
  let config : Json = { "url": url, "model": model, "token": token }
  mooncode_setup_write(path, config.stringify(indent=2))
  Ok({
    "kind": "embeddings",
    "configuration": mooncode_knowledge_embeddings_public(book_root),
    "previous": before,
  })
}

///|
async fn mooncode_knowledge_runtime_request(
  workspace_root : String,
  book_root : String,
  payload : Json,
) -> Result[Json, String] {
  let daemon = ensure_moonclaw_daemon_running(
    workspace_root,
    action="knowledge-retrieval",
  )
  if !json_bool(daemon, "running", default=false) {
    return Err("MoonClaw is unavailable; using ranked text retrieval")
  }
  let fields = match payload {
    Object(fields) => fields
    _ => Map([])
  }
  fields["book_root"] = ToJson::to_json(book_root)
  moonclaw_post_json(daemon, "/v1/mooncode/knowledge", Json::object(fields))
}

///|
async fn mooncode_knowledge_enrich(
  workspace_root : String,
  book_root : String,
  chunks : Array[Json],
) -> Json {
  let config = mooncode_knowledge_embeddings_public(book_root)
  if !json_bool(config, "configured", default=false) {
    return {
      "chunks": Json::array(chunks),
      "embedding_key": "",
      "semantic_error": "",
    }
  }
  let result = mooncode_knowledge_runtime_request(workspace_root, book_root, {
    "action": "embed",
    "texts": chunks.map(chunk => json_string(chunk, "text", default="")),
  })
  let payload = match result {
    Ok(value) => value
    Err(message) =>
      return {
        "chunks": Json::array(chunks),
        "embedding_key": "",
        "semantic_error": message,
      }
  }
  let vectors = json_array_items(payload, "vectors")
  if !json_bool(payload, "ok", default=false) ||
    vectors.length() != chunks.length() {
    return {
      "chunks": Json::array(chunks),
      "embedding_key": "",
      "semantic_error": json_string(
        payload,
        "message",
        default="Embedding indexing was incomplete; text search is available",
      ),
    }
  }
  for index in 0..<chunks.length() {
    let fields = match chunks[index] {
      Object(fields) => fields
      _ => Map([])
    }
    fields["embedding"] = vectors[index]
    chunks[index] = Json::object(fields)
  }
  {
    "chunks": Json::array(chunks),
    "embedding_key": json_string(payload, "embedding_key", default=""),
    "semantic_error": "",
  }
}
