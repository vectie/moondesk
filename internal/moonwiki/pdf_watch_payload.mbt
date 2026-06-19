///|
fn clamp_int(value : Int, min : Int, max : Int) -> Int {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}

///|
fn standing_goal_record_from_payload(
  payload : Json,
  daemon_tick~ : Int,
) -> Json {
  let title = json_string(payload, "title", default="Moondesk standing watch")
  let id = json_string(payload, "id", default=@desk.stable_id("watch", title))
  let cadence = clamp_int(
    json_int(payload, "cadence_ticks", default=60),
    1,
    525600,
  )
  let review_policy = json_string(
      payload,
      "review_policy",
      default="bookkeeper_review",
    )
    .trim()
    .to_owned()
  let next_due = json_int(payload, "next_due_tick", default=daemon_tick)
  {
    "id": id,
    "title": title,
    "prompt": json_string(payload, "prompt", default=""),
    "target_book_id": json_string(payload, "target_book_id", default=""),
    "cadence_ticks": cadence,
    "next_due_tick": next_due,
    "last_run_tick": match json_int(payload, "last_run_tick", default=-1) {
      -1 => Json::null()
      tick => tick.to_json()
    },
    "enabled": json_bool(payload, "enabled", default=true),
    "source_policy": json_string(payload, "source_policy", default="web-first"),
    "review_policy": if review_policy == "" {
      "bookkeeper_review"
    } else {
      review_policy
    },
  }
}

///|
fn pdf_watch_notify_on_from_payload(payload : Json) -> Array[String] {
  let values = json_string_array_items(payload, "notify_on")
  if values.length() > 0 {
    values
  } else {
    let analysis = json_object_field_or_empty(payload, "analysis")
    let analysis_values = json_string_array_items(analysis, "notify_on")
    if analysis_values.length() > 0 {
      analysis_values
    } else {
      let watch = json_object_field_or_empty(payload, "watch")
      let watch_values = json_string_array_items(watch, "notify_on")
      if watch_values.length() > 0 {
        watch_values
      } else {
        let notify_rule = json_string(
            payload,
            "notify_rule",
            default="accepted_new_knowledge",
          )
          .trim()
          .to_owned()
        if notify_rule == "" {
          ["accepted_new_knowledge"]
        } else {
          [notify_rule]
        }
      }
    }
  }
}

///|
fn pdf_watch_websites_from_payload(payload : Json) -> Array[String] {
  let direct = json_string_array_items(payload, "websites")
  if direct.length() > 0 {
    direct
  } else {
    json_string_array_items(
      json_object_field_or_empty(payload, "watch"),
      "websites",
    )
  }
}

///|
fn pdf_watch_cadence_from_payload(payload : Json) -> Int {
  let watch = json_object_field_or_empty(payload, "watch")
  let direct = json_int(payload, "cadence_minutes", default=-1)
  if direct > 0 {
    clamp_int(direct, 1, 525600)
  } else {
    let nested_minutes = json_int(watch, "cadence_minutes", default=-1)
    if nested_minutes > 0 {
      clamp_int(nested_minutes, 1, 525600)
    } else {
      clamp_int(
        json_int(
          payload,
          "cadence_ticks",
          default=json_int(watch, "cadence_ticks", default=30),
        ),
        1,
        525600,
      )
    }
  }
}

///|
fn pdf_watch_source_policy_from_payload(payload : Json) -> String {
  let direct = json_string(payload, "source_policy", default="")
    .trim()
    .to_owned()
  if direct != "" {
    direct
  } else {
    let watch = json_object_field_or_empty(payload, "watch")
    let nested = json_string(watch, "source_policy", default="web-first")
      .trim()
      .to_owned()
    if nested == "" {
      "web-first"
    } else {
      nested
    }
  }
}

///|
fn pdf_watch_skill_pack_from_payload(
  payload : Json,
  pattern_id : String,
) -> Array[String] {
  let requested = json_string_array_items(payload, "skill_pack")
  let defaults = default_skill_pack_for_pattern(pattern_id)
  let selected : Array[String] = []
  for skill in requested {
    if skill != "" && !selected.contains(skill) {
      selected.push(skill)
    }
  }
  for skill in defaults {
    if !selected.contains(skill) {
      selected.push(skill)
    }
  }
  selected
}

///|
fn default_skill_pack_for_pattern(pattern_id : String) -> Array[String] {
  book_pattern_default_skills(pattern_id)
}
