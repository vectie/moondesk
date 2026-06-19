///|
fn default_book_pattern_method() -> String {
  "# PDF Evidence Watch Method\n\nScreen PDFs for source quality, extract claims that change the current book baseline, and queue Bookkeeper review before accepted knowledge is published."
}

fn apply_selected_book_pattern(model : Model, pattern_id : String) -> Model {
  let selected_id = if pattern_id == "" {
    first_pattern_for_base_type(model.book_patterns, model.selected_book_base_type)
  } else {
    pattern_id
  }
  match book_pattern_record_from_model(model, selected_id) {
    Some(pattern) if book_pattern_creation_backend_supported(
      pattern.creation_backend,
    ) =>
    {
      let topic = if pattern.default_topic == "" {
        "my domain"
      } else {
        pattern.default_topic
      }
      let book_id = trimmed_or(
        model.book_pattern_book_id,
        "research-" + sanitize_ui_id(topic) + "-pdf-watch",
      )
      let websites = if pattern.default_websites.length() == 0 {
        model.book_pattern_websites
      } else {
        pattern.default_websites.join("\n")
      }
      let skills = if pattern.skills.length() == 0 {
        model.book_pattern_skill_pack
      } else {
        pattern.skills.join("\n")
      }
    {
      ..model,
        selected_book_base_type: pattern.base_type,
        selected_book_pattern_id: pattern.id,
        book_pattern_book_id: book_id,
        book_pattern_topic: topic,
        book_pattern_purpose: trimmed_or(
          pattern.description,
          "Create a reusable MoonBook from the selected book pattern.",
        ),
        book_pattern_websites: websites,
        book_pattern_cadence_minutes: pattern.default_cadence_minutes.to_string(),
        book_pattern_source_policy: trimmed_or(
          pattern.default_source_policy,
          "web-first",
        ),
      book_pattern_notify_rule: "accepted_new_knowledge",
        book_pattern_skill_pack: skills,
      book_pattern_analysis_method: default_book_pattern_method(),
      book_pattern_status: "ready to publish selected book pattern",
    }
    }
    _ =>
    {
      ..model,
      selected_book_base_type: book_pattern_base_type_from_model(
        model,
          selected_id,
        default=model.selected_book_base_type,
      ),
        selected_book_pattern_id: selected_id,
        book_pattern_status: "selected registry pattern `\{selected_id}`; this build can publish only patterns with a supported creation backend",
    }
  }
}

///|
fn sanitize_ui_id(value : String) -> String {
  let mut out = ""
  for ch in value.trim() {
    if (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9') {
      out = out + ch.to_string()
    } else if ch >= 'A' && ch <= 'Z' {
      out = out + ch.to_string().to_lower()
    } else if out != "" && !out.has_suffix("-") {
      out = out + "-"
    }
  }
  out.trim(chars=['-']).to_owned()
}

///|
fn selected_book_id_for_validation(model : Model) -> String {
  if model.book_pattern_last_book_id != "" {
    model.book_pattern_last_book_id
  } else if model.book_pattern_book_id.trim() != "" {
    model.book_pattern_book_id.trim().to_owned()
  } else if model.selected_workspace_id.has_prefix("book-") {
    model.selected_workspace_id["book-".length():].to_owned()
  } else {
    ""
  }
}

///|
fn selected_book_id_for_portable_export(model : Model) -> String {
  if model.selected_workspace_id.has_prefix("book-") {
    model.selected_workspace_id["book-".length():].to_owned()
  } else {
    selected_book_id_for_validation(model)
  }
}

///|
fn apply_selected_book_base_type(model : Model, base_type : String) -> Model {
  let selected = if base_type == "" { "research-book" } else { base_type }
  let pattern_id = if pattern_matches_base_type(
    model.selected_book_pattern_id,
    selected,
    model.book_patterns,
  ) {
    model.selected_book_pattern_id
  } else {
    first_pattern_for_base_type(model.book_patterns, selected)
  }
  apply_selected_book_pattern(
    { ..model, selected_book_base_type: selected },
    pattern_id,
  )
}

///|
fn pattern_matches_base_type(
  pattern_id : String,
  base_type : String,
  patterns : Array[BookPatternRecord],
) -> Bool {
  for pattern in patterns {
    if pattern.id == pattern_id && pattern.base_type == base_type {
      return true
    }
  }
  false
}

///|
fn first_pattern_for_base_type(
  patterns : Array[BookPatternRecord],
  base_type : String,
) -> String {
  for pattern in patterns {
    if pattern.base_type == base_type {
      return pattern.id
    }
  }
  ""
}

///|
fn selected_book_pattern_title(model : Model) -> String {
  for pattern in model.book_patterns {
    if pattern.id == model.selected_book_pattern_id {
      return pattern.title
    }
  }
  ignore(model)
  "Book Pattern"
}

///|
fn book_pattern_record_from_model(
  model : Model,
  pattern_id : String,
) -> BookPatternRecord? {
  for pattern in model.book_patterns {
    if pattern.id == pattern_id {
      return Some(pattern)
    }
  }
  None
}

///|
fn book_pattern_base_type_from_model(
  model : Model,
  pattern_id : String,
  default~ : String,
) -> String {
  for pattern in model.book_patterns {
    if pattern.id == pattern_id {
      return pattern.base_type
    }
  }
  default
}

///|
fn book_pattern_creation_backend_supported(backend : String) -> Bool {
  backend == "builtin-pdf-evidence-watch"
}

///|
fn book_pattern_creator_supported(model : Model) -> Bool {
  match book_pattern_record_from_model(model, model.selected_book_pattern_id) {
    Some(pattern) =>
      pattern.base_type == model.selected_book_base_type &&
      book_pattern_creation_backend_supported(pattern.creation_backend)
    None => false
  }
}
