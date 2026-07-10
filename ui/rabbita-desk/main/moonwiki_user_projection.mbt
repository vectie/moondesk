///|
fn wiki_task_state(status : String) -> String {
  let value = status.trim().to_lower()
  if value.contains("fail") ||
    value.contains("error") ||
    value.contains("block") ||
    value.contains("reject") {
    "Needs attention"
  } else if value.contains("review") || value.contains("ready") {
    "Ready for review"
  } else if value.contains("run") ||
    value.contains("work") ||
    value.contains("active") ||
    value.contains("progress") {
    "Working"
  } else if value.contains("queue") ||
    value.contains("wait") ||
    value.contains("stage") ||
    value.contains("pending") ||
    value.contains("draft") {
    "Waiting"
  } else if value == "" {
    "Waiting"
  } else {
    "Completed"
  }
}

///|
fn wiki_task_tone(status : String) -> String {
  match wiki_task_state(status) {
    "Needs attention" => "attention"
    "Ready for review" => "review"
    "Working" => "working"
    "Completed" => "complete"
    _ => "waiting"
  }
}

///|
fn wiki_request_status_label(status : String) -> String {
  let value = status.trim().to_lower()
  if value == "" || value == "draft" {
    "Ready when you are."
  } else if value.contains("describe") {
    "Describe what you want this book to build."
  } else if value.contains("select a book") {
    "Select a book before starting."
  } else if value.contains("stag") || value.contains("queue") {
    "Waiting to start."
  } else if value.contains("fail") ||
    value.contains("error") ||
    value.contains("unavailable") {
    "Could not start this task. Your request is still here."
  } else {
    "Task created."
  }
}

///|
fn wiki_automation_status_label(status : String) -> String {
  let value = status.trim().to_lower()
  if value == "" || value.contains("idle") {
    "Ready to create."
  } else if value.contains("created") {
    "Automation created."
  } else if value.contains("fail") ||
    value.contains("error") ||
    value.contains("unavailable") {
    "Could not create the automation."
  } else {
    status
  }
}

///|
fn wiki_inbox_status_label(status : String) -> String {
  let value = status.trim().to_lower()
  if value == "" || value == "draft" {
    "Ready to save."
  } else if value.contains("sav") && !value.contains("could") {
    "Saved to Inbox."
  } else if value.contains("import") {
    "Added to Inbox."
  } else if value.contains("fail") ||
    value.contains("error") ||
    value.contains("could") ||
    value.contains("must") {
    "Could not save. Your draft is still here."
  } else {
    status
  }
}

///|
fn wiki_editor_status_label(model : Model) -> String {
  let value = model.markdown_editor_status.trim().to_lower()
  if value.contains("saving") {
    "Saving..."
  } else if value.contains("saved") {
    "Saved"
  } else if value.contains("editing") {
    "Unsaved changes"
  } else if model.markdown_editor_path != "" {
    "Could not save. Your draft is still here."
  } else {
    ""
  }
}

///|
fn wiki_search_type_label(hit : SearchHit) -> String {
  match hit.source_layer {
    Wiki => "Page"
    Inbox => "Inbox note"
    RawEvidence => "Original source"
    Review => "Review"
    History => "History"
    GeneratedSite => "Published page"
    RunArtifact => "Result"
    _ =>
      match hit.kind {
        Markdown => "Document"
        Html => "Published page"
        Image => "Image"
        Json => "Data"
        Directory => "Folder"
        _ => "File"
      }
  }
}

///|
fn wiki_review_status_label(status : String) -> String {
  let value = status.trim().to_lower()
  if value.contains("accept") {
    "Accepted"
  } else if value.contains("reject") {
    "Rejected"
  } else {
    "Needs review"
  }
}

///|
fn wiki_review_detail(item : ReviewItem) -> String {
  let detail = item.detail.trim().to_owned()
  if detail == "" || detail == item.path || detail.contains(item.path) {
    "Review this proposed change before it becomes accepted knowledge."
  } else {
    detail
  }
}

///|
fn wiki_review_feedback(status : String) -> String {
  let value = status.trim().to_lower()
  if value == "" || value.contains("idle") {
    "Add an optional note before making a decision."
  } else if value.contains("recording") {
    "Saving your decision..."
  } else if value.contains("accepted") {
    "Change accepted and recorded."
  } else if value.contains("rejected") {
    "Change rejected and recorded."
  } else if value.contains("error") ||
    value.contains("unknown") ||
    value.contains("not book") {
    "Could not record this decision."
  } else {
    status
  }
}

///|
fn wiki_review_feedback_visible(status : String) -> Bool {
  let value = status.trim().to_lower()
  value != "" && !value.contains("idle")
}
