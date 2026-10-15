///|
fn moonflow_plan_safe_id(id : String) -> Bool {
  !id.is_empty() &&
  id != "." &&
  !id.contains("..") &&
  id.length() <= 128 &&
  id.all(char => {
    char.is_ascii_alphabetic() ||
    char.is_ascii_digit() ||
    char == '-' ||
    char == '_' ||
    char == '.'
  })
}

///|
fn moonflow_plan_validate_templates(
  composition : MoonFlowComposition,
  fields : Array[MoonFlowPlanFields],
) -> Unit raise {
  let source_ids = composition.items.map(item => item.work_item_id)
  let seen : Array[String] = []
  guard fields.length() <= 256 else { fail("Too many saved work items") }
  for item in fields {
    guard !seen.contains(item.work_item_id) else {
      fail("Duplicate work item ID")
    }
    seen.push(item.work_item_id)
    match item.source_item_id {
      Some(template) => {
        guard moonflow_plan_safe_id(item.work_item_id) &&
          !source_ids.contains(item.work_item_id) &&
          source_ids.contains(template) else {
          fail(
            "Duplicate must name an original source operation and a safe new ID",
          )
        }
      }
      None => {
        guard source_ids.contains(item.work_item_id) else {
          fail("Unknown source work item")
        }
      }
    }
  }
}

///|
fn moonflow_plan_duplicate(
  composition : MoonFlowComposition,
  editor : MoonFlowPlanEditor,
  id : String,
) -> MoonFlowPlanEditor {
  guard editor.fields.length() < 256 else { return editor }
  guard editor.fields.filter(item => item.work_item_id == id).get(0)
    is Some(item) else {
    return editor
  }
  let template = item.source_item_id.unwrap_or(item.work_item_id)
  // Legacy source labels need not satisfy the tighter new-item ID rule.
  let prefix = if moonflow_plan_safe_id(template) {
    template[:96].to_owned()
  } else {
    "step"
  }
  let occupied = editor.fields.map(item => item.work_item_id) +
    composition.items.map(item => item.work_item_id)
  let mut next = prefix + "-copy-1"
  let mut index = 1
  while occupied.contains(next) {
    index += 1
    next = prefix + "-copy-" + index.to_string()
  }
  let fields = editor.fields.copy()
  fields.push({ ..item, work_item_id: next, source_item_id: Some(template), })
  {
    ..moonflow_plan_update_field(editor, "", "", ""),
    fields,
    notice: "Added " +
    next +
    " from declared operation " +
    template +
    ". Edit its inputs and dependencies, then prepare and review. No acceptance is inherited.",
  }
}
