///|
fn book_base_type_buttons(
  dispatch : Dispatch[Msg],
  model : Model,
) -> Array[@rabbita.Html] {
  if model.book_base_types.length() == 0 {
    [
      button(
        class=book_base_type_button_class(model, "research-book"),
        title="MoonBook base type for source-backed research books",
        on_click=dispatch(SelectBookBaseType("research-book")),
        "Research Book",
      ),
    ]
  } else {
    model.book_base_types.map(base => {
      button(
        class=book_base_type_button_class(model, base.id),
        title=book_base_type_tooltip(base),
        on_click=dispatch(SelectBookBaseType(base.id)),
        base.title,
      )
    })
  }
}

///|
fn book_base_type_tooltip(base : BookBaseTypeRecord) -> String {
  [
    base.description,
    "Owner: " + base.owner,
    "Source: " + base.source,
    "Creation palette: " + base.creation_palette_source,
    "MoonBook refs: " + base.moonbook_layout_refs.join(", "),
    "Template refs: " + base.template_registry_refs.join(", "),
    "Patterns: " + base.supported_patterns.join(", "),
    "Roots: " + base.required_roots.join(", "),
  ].join("\n")
}

///|
fn book_base_type_button_class(model : Model, base_type : String) -> String {
  if model.selected_book_base_type == base_type {
    "option-chip active"
  } else {
    "option-chip"
  }
}

///|
fn book_pattern_buttons(
  dispatch : Dispatch[Msg],
  model : Model,
) -> Array[@rabbita.Html] {
  if model.book_patterns.length() == 0 {
    [span(class="status-line", "Loading book-pattern registry")]
  } else {
    let buttons : Array[@rabbita.Html] = []
    for pattern in model.book_patterns {
      if pattern.base_type == model.selected_book_base_type {
        buttons.push(
          button(
            class=book_pattern_button_class(model, pattern.id),
            title=book_pattern_tooltip(pattern),
            on_click=dispatch(SelectBookPattern(pattern.id)),
            pattern.title,
          ),
        )
      }
    }
    buttons
  }
}

///|
fn book_pattern_tooltip(pattern : BookPatternRecord) -> String {
  let standing_watch = if pattern.standing_watch { "yes" } else { "no" }
  [
    pattern.base_type + " / " + pattern.output,
    pattern.description,
    "Default topic: " + pattern.default_topic,
    "Cadence: \{pattern.default_cadence_minutes} minutes",
    "Source policy: " + pattern.default_source_policy,
    "Sites: \{pattern.default_websites.length()}",
    "Skills: " + pattern.skills.join(", "),
    "Standing watch: " + standing_watch,
    "Creation backend: " + pattern.creation_backend,
  ].join("\n")
}

///|
fn book_pattern_button_class(model : Model, pattern_id : String) -> String {
  if model.selected_book_pattern_id == pattern_id {
    "option-chip active"
  } else {
    "option-chip"
  }
}

///|
fn book_pattern_wizard_step_class(done : Bool) -> String {
  if done {
    "wizard-step done"
  } else {
    "wizard-step"
  }
}

///|
fn render_book_pattern_wizard(model : Model) -> @rabbita.Html {
  let websites = text_lines(model.book_pattern_websites)
  let skills = text_lines(model.book_pattern_skill_pack)
  let method_ready = !model.book_pattern_analysis_method.trim().is_empty()
  let book_ready = book_pattern_creator_supported(model)
  let cadence = @string.parse_int(model.book_pattern_cadence_minutes) catch {
    _ => 0
  }
  let watch_ready = websites.length() > 0 && cadence > 0
  let notify_ready = !model.book_pattern_notify_rule.trim().is_empty()
  div(class="book-wizard", [
    div(class="book-wizard-header", [
      strong(selected_book_pattern_title(model)),
      span(class="record-kind", model.selected_book_base_type + " pattern"),
    ]),
    ul(class="wizard-steps", [
      li(class=book_pattern_wizard_step_class(book_ready), [
        span(class="wizard-index", "1"),
        span(
          if book_ready {
            "Choose " +
            model.selected_book_base_type +
            " + " +
            model.selected_book_pattern_id
          } else {
            "Select a pattern with a supported creation backend"
          },
        ),
      ]),
      li(class=book_pattern_wizard_step_class(websites.length() > 0), [
        span(class="wizard-index", "2"),
        span("\{websites.length()} source website(s)"),
      ]),
      li(class=book_pattern_wizard_step_class(method_ready), [
        span(class="wizard-index", "3"),
        span("Write wiki/methods/my-analysis-method.md"),
      ]),
      li(class=book_pattern_wizard_step_class(skills.length() > 0), [
        span(class="wizard-index", "4"),
        span("Select " + skills.length().to_string() + " skill(s)"),
      ]),
      li(class=book_pattern_wizard_step_class(watch_ready), [
        span(class="wizard-index", "5"),
        span(
          "Enable standing watch every " +
          model.book_pattern_cadence_minutes +
          " minutes",
        ),
      ]),
      li(class=book_pattern_wizard_step_class(notify_ready), [
        span(class="wizard-index", "6"),
        span("Notify on " + model.book_pattern_notify_rule),
      ]),
      li(
        class=book_pattern_wizard_step_class(
          model.book_pattern_last_book_id != "",
        ),
        [span(class="wizard-index", "7"), span("Publish book to Moontown")],
      ),
    ]),
    pre(
      class="source-block compact builder-config-preview",
      code(book_pattern_config_preview(model)),
    ),
  ])
}

///|
fn book_pattern_config_preview(model : Model) -> String {
  let websites = text_lines(model.book_pattern_websites)
  let skills = text_lines(model.book_pattern_skill_pack)
  let standing_watch = match
    book_pattern_record_from_model(model, model.selected_book_pattern_id) {
    Some(pattern) => pattern.standing_watch
    None => false
  }
  (
    {
      "id": trimmed_or(
        model.book_pattern_book_id,
        "research-my-domain-pdf-watch",
      ),
      "type": model.selected_book_base_type,
      "specialization": model.selected_book_pattern_id,
      "pattern_components": {
        "source_adapter": "websites",
        "extractor": "pdf-full-text",
        "analysis_skill": "pdf-analysis",
        "standing_watch": standing_watch,
      },
      "watch": {
        "cadence_minutes": @string.parse_int(model.book_pattern_cadence_minutes) catch {
          _ => 30
        },
        "source_policy": trimmed_or(
          model.book_pattern_source_policy,
          "web-first",
        ),
        "websites": json_string_array(websites),
        "file_types": json_string_array(["pdf"]),
        "dedupe_by": json_string_array(["url", "title", "sha256"]),
      },
      "analysis": {
        "method_page": "wiki/methods/my-analysis-method.md",
        "notify_on": json_string_array([
          trimmed_or(model.book_pattern_notify_rule, "accepted_new_knowledge"),
        ]),
        "skill_pack": json_string_array(skills),
      },
      "targets": { "kind": "generic-pdf-evidence", "target_scope": "generic" },
    } : Json).stringify(indent=2)
}
