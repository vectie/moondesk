///|
test "knowledge retrieval ranks exact phrases and retains source citations" {
  let records : Array[Json] = [
    {
      "id": "a",
      "title": "Architecture",
      "path": "docs/design.md",
      "chunks": Json::array(
        mooncode_knowledge_chunks(
          "Authentication uses session cookies.\nThe API reads the session on each request.",
        ),
      ),
      "enabled": true,
    },
    {
      "id": "b",
      "title": "Other",
      "path": "other.md",
      "chunks": Json::array(
        mooncode_knowledge_chunks(
          "Authentication and cookies are discussed separately.",
        ),
      ),
      "enabled": true,
    },
    {
      "id": "c",
      "title": "Paused",
      "chunks": Json::array(mooncode_knowledge_chunks("session cookies")),
      "enabled": false,
    },
  ]
  let hits = mooncode_knowledge_search(records, "session cookies")
  assert_eq(hits.length(), 2)
  assert_eq(json_string(hits[0], "source_id", default=""), "a")
  assert_eq(json_int(hits[0], "start_line", default=0), 1)
  assert_true(
    json_string(hits[0], "citation", default="").contains("Architecture"),
  )
  assert_eq(mooncode_knowledge_search(records, "unrelated-phrase").length(), 0)
}

///|
test "knowledge chunks preserve line locations across document boundaries" {
  let lines : Array[String] = []
  for index in 0..<45 {
    lines.push("Line " + index.to_string())
  }
  let text = lines.join("\n")
  let chunks = mooncode_knowledge_chunks(text)
  assert_eq(chunks.length(), 3)
  assert_eq(json_int(chunks[1], "start_line", default=0), 21)
  assert_eq(json_int(chunks[2], "end_line", default=0), 45)
}
