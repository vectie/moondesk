///|
async fn book_base_type_records_for_workspace(
  workspace_root : String,
) -> Array[Json] {
  book_base_type_records_from_patterns(
    book_pattern_records_for_workspace(workspace_root),
  )
}

///|
fn book_base_type_records_from_patterns(patterns : Array[Json]) -> Array[Json] {
  let base_types : Array[String] = []
  for pattern in patterns {
    let base_type = json_string(pattern, "base_type", default="research-book")
      .trim()
      .to_owned()
    if base_type != "" && !base_types.contains(base_type) {
      base_types.push(base_type)
    }
  }
  if base_types.length() == 0 {
    base_types.push("research-book")
  }
  let records : Array[Json] = []
  for base_type in base_types {
    let supported_patterns : Array[String] = []
    let template_refs : Array[String] = []
    for pattern in patterns {
      if json_string(pattern, "base_type", default="research-book") == base_type {
        let id = json_string(pattern, "id", default="")
        if id != "" && !supported_patterns.contains(id) {
          supported_patterns.push(id)
        }
        for
          template_ref in json_string_array_items(
            pattern, "template_registry_refs",
          ) {
          if template_ref != "" && !template_refs.contains(template_ref) {
            template_refs.push(template_ref)
          }
        }
      }
    }
    records.push(
      book_base_type_record(
        base_type,
        supported_patterns~,
        template_registry_refs=template_refs,
      ),
    )
  }
  records
}

///|
fn book_base_type_record(
  base_type : String,
  supported_patterns~ : Array[String],
  template_registry_refs~ : Array[String],
) -> Json {
  {
    "id": base_type,
    "title": book_base_type_title(base_type),
    "description": book_base_type_description(base_type),
    "owner": "MoonBook",
    "source": "moontown-template-registry.v1 + moonbook-layout.v1",
    "creation_palette_source": "moontown://templates/books/templates.json",
    "moonbook_layout_refs": json_from_string_array(moonbook_layout_refs()),
    "template_registry_refs": json_from_string_array(template_registry_refs),
    "supported_patterns": json_from_string_array(supported_patterns),
    "required_roots": json_from_string_array(
      book_base_type_required_roots(base_type),
    ),
  }
}

///|
fn book_base_type_title(base_type : String) -> String {
  match base_type {
    "research-book" => "Research Book"
    "toolbook" => "ToolBook"
    _ => base_type_to_title(base_type)
  }
}

///|
fn book_base_type_description(base_type : String) -> String {
  match base_type {
    "research-book" =>
      "Durable MoonBook base for source-backed research, wiki memory, source evidence, review queues, generated sites, and standing-watch workflows."
    "toolbook" =>
      "Durable MoonBook base for a generated web tool, analysis reports, review artifacts, app assets, and Moontown-exposed tool surfaces."
    _ =>
      "Durable MoonBook base discovered from the current Moontown template registry."
  }
}

///|
fn book_base_type_required_roots(base_type : String) -> Array[String] {
  match base_type {
    "toolbook" =>
      [
        "book.json", "raw/", "wiki/", "skills/", "schemas/", "app/", "site/generated/",
      ]
    _ =>
      ["book.json", "raw/", "wiki/", "skills/", "schemas/", "site/generated/"]
  }
}

///|
fn base_type_to_title(base_type : String) -> String {
  let words : Array[String] = []
  for part in base_type.split("-") {
    let part = part.trim().to_owned()
    if part == "" {
      continue
    }
    words.push(capitalize_ascii(part))
  }
  if words.length() == 0 {
    base_type
  } else {
    words.join(" ")
  }
}

///|
fn capitalize_ascii(text : String) -> String {
  if text.length() == 0 {
    return text
  }
  let first = text[:1].to_upper().to_owned()
  if text.length() == 1 {
    first
  } else {
    first + text[1:].to_owned()
  }
}

///|
fn moonbook_layout_refs() -> Array[String] {
  [
    "moonbook://layout/book.json", "moonbook://layout/raw", "moonbook://layout/wiki",
    "moonbook://layout/skills", "moonbook://layout/schemas", "moonbook://layout/site/generated",
  ]
}

///|
fn pdf_watch_base_type_provenance_json() -> Json {
  {
    "base_type": "research-book",
    "source": "moontown-template-registry.v1 + moonbook-layout.v1",
    "creation_palette_source": "moontown://templates/books/templates.json",
    "moonbook_owner": "MoonBook",
    "moontown_template_id": "pdf-evidence-watch",
    "moondesk_pattern_contract": "research-book + source adapter + extractor + analysis skill + standing watch",
    "moonbook_layout_refs": json_from_string_array(moonbook_layout_refs()),
    "template_registry_refs": json_from_string_array(
      book_pattern_template_registry_refs("pdf-evidence-watch"),
    ),
  }
}
