///|
fn toolbook_manifest_seed_json(book_id : String) -> Json {
  let tool : Json = {
    "id": "pdf-evidence-tool",
    "title": "PDF Evidence Tool",
    "entrypoints": json_from_string_array([
      "book/site/generated/tool.html", "app/index.html",
    ]),
  }
  let outputs : Json = { "site": "book/site/generated/tool.html", "report": "" }
  {
    "kind": "app-tool-book-manifest",
    "template_id": "app-tool-book",
    "book_id": book_id,
    "tool": tool,
    "outputs": outputs,
    "extensible": true,
    "status": "waiting_for_accepted_run",
  }
}
