///|
fn pdf_watch_moontown_template_request_status_ready(status : String) -> Bool {
  status == "pending" || status == "retry" || status == "installed"
}

///|
async fn moontown_standing_goal_registration_ready(
  receipt_path : String,
  receipt : Json,
  book_id : String,
) -> Bool {
  @fs.exists(receipt_path) &&
  json_bool(receipt, "ok", default=false) &&
  json_string(receipt, "status", default="") == "registered" &&
  json_string(receipt, "target_book_id", default="") == book_id &&
  json_string(receipt, "daemon_job", default="") == "standing-goal-dispatch"
}

///|
fn pdf_watch_base_type_provenance_valid(provenance : Json) -> Bool {
  json_string(provenance, "base_type", default="") == "research-book" &&
  json_string(provenance, "moonbook_owner", default="") == "MoonBook" &&
  json_string(provenance, "moontown_template_id", default="") ==
  "pdf-evidence-watch" &&
  json_string(provenance, "creation_palette_source", default="").contains(
    "moontown://templates/books/templates.json",
  ) &&
  json_string(provenance, "moondesk_pattern_contract", default="") ==
  "research-book + source adapter + extractor + analysis skill + standing watch" &&
  json_string_array_items(provenance, "moonbook_layout_refs").contains(
    "moonbook://layout/book.json",
  ) &&
  json_string_array_items(provenance, "template_registry_refs").contains(
    "moontown://templates/books/templates.json",
  )
}

///|
fn pdf_watch_base_type_selection_valid_for_book(
  book_json : Json,
  selection : Json,
) -> Bool {
  let pattern_id = pdf_watch_pattern_id_from_book_json(book_json)
  let provenance = json_object_field_or_empty(selection, "base_type_provenance")
  json_string(selection, "kind", default="") == "moondesk-base-type-selection" &&
  json_string(selection, "book_id", default="") ==
  json_string(book_json, "id", default="") &&
  json_string(selection, "base_type", default="") == "research-book" &&
  json_string(selection, "pattern_id", default="") == pattern_id &&
  json_string(selection, "selected_from", default="").contains(
    "/api/books/base-types",
  ) &&
  json_string(selection, "base_type_owner", default="") == "MoonBook" &&
  json_string(selection, "handoff_target", default="") == "MoonTown" &&
  json_bool(selection, "selected_from_catalog", default=false) &&
  json_bool(selection, "supported_pattern", default=false) &&
  json_string(selection, "build_contract", default="") ==
  "research-book + source adapter + extractor + analysis skill + standing watch" &&
  pdf_watch_base_type_provenance_valid(provenance) &&
  json_string_array_items(selection, "required_roots").contains("book.json") &&
  json_string_array_items(selection, "required_roots").contains("wiki/") &&
  json_string_array_items(selection, "template_registry_refs").contains(
    "moontown://templates/books/templates.json",
  ) &&
  json_string_array_items(selection, "moonbook_layout_refs").contains(
    "moonbook://layout/book.json",
  )
}

///|
fn record_contract_check(
  checks : Array[String],
  missing : Array[String],
  label : String,
  ok : Bool,
) -> Unit {
  if ok {
    checks.push(label)
  } else {
    missing.push(label)
  }
}

///|
fn json_record_with_id_exists(records : Array[Json], id : String) -> Bool {
  for record in records {
    if json_string(record, "id", default="") == id {
      return true
    }
  }
  false
}

///|
fn json_record_by_id(records : Array[Json], id : String) -> Json? {
  for record in records {
    if json_string(record, "id", default="") == id {
      return Some(record)
    }
  }
  None
}

///|
fn json_record_with_target_book_exists(
  records : Array[Json],
  book_id : String,
) -> Bool {
  for record in records {
    if json_string(record, "target_book_id", default="") == book_id {
      return true
    }
  }
  false
}
