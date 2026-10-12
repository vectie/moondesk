///|
fn moonflow_plan_field_errors(editor : MoonFlowPlanEditor) -> Array[String] {
  let errors : Array[String] = []
  let ids = editor.fields.map(item => item.work_item_id)
  let ready : Array[String] = []
  if editor.fields.is_empty() {
    errors.push("Plan: retain at least one step before preparing")
  }
  let seen_ids : Array[String] = []
  if editor.fields.length() > 256 {
    errors.push("Plan: at most 256 work items can be prepared in this view")
  }
  for item in editor.fields {
    if (
        item.source_item_id is Some(_) &&
        !moonflow_plan_safe_id(item.work_item_id)
      ) ||
      seen_ids.contains(item.work_item_id) {
      errors.push("Plan: unsafe or duplicate work item ID " + item.work_item_id)
    }
    seen_ids.push(item.work_item_id)
    let timeout = item.timeout.trim().to_owned()
    if timeout == "" ||
      timeout.length() > 8 ||
      !timeout.all(char => char.is_ascii_digit()) {
      errors.push(
        item.work_item_id + " · timeout: use a whole number of milliseconds",
      )
    } else {
      let value = @string.parse_int(timeout) catch { _ => 0 }
      if value < 1 || value > 86400000 {
        errors.push(
          item.work_item_id + " · timeout: choose 1 to 86400000 milliseconds",
        )
      }
    }
    for
      pair in [
        ("input artifacts", item.inputs),
        ("dependencies", item.dependencies),
        ("acceptance criteria", item.criteria),
      ] {
      let (field, text) = pair
      let values = moonflow_plan_lines(text)
      let seen : Array[String] = []
      if field != "dependencies" && values.is_empty() {
        errors.push(
          item.work_item_id + " · " + field + ": add at least one entry",
        )
      }
      if text.length() > 65536 {
        errors.push(
          item.work_item_id + " · " + field + ": this field exceeds 64 KiB",
        )
      }
      for value in values {
        if seen.contains(value) {
          errors.push(
            item.work_item_id +
            " · " +
            field +
            ": duplicate entry “" +
            value +
            "”",
          )
        } else {
          seen.push(value)
        }
        if field == "dependencies" &&
          (!ids.contains(value) || value == item.work_item_id) {
          errors.push(
            item.work_item_id +
            " · dependencies: “" +
            value +
            "” must name a different declared item",
          )
        }
        if field == "input artifacts" &&
          (
            value.has_prefix("/") ||
            value.contains("\\") ||
            value
            .split("/")
            .any(part => part == ".." || part == "." || part == "") ||
            value.contains("\u0000")
          ) {
          errors.push(
            item.work_item_id +
            " · input artifacts: “" +
            value +
            "” must be a contained workspace-relative file path",
          )
        }
      }
    }
  }
  // A bounded topological pass identifies every item still participating in
  // or blocked by a cycle without recursive traversal of user input.
  for _ in 0..<editor.fields.length() {
    for item in editor.fields {
      if !ready.contains(item.work_item_id) &&
        moonflow_plan_lines(item.dependencies).all(id => ready.contains(id)) {
        ready.push(item.work_item_id)
      }
    }
  }
  if errors.is_empty() && ready.length() != ids.length() {
    errors.push(
      "Dependencies: cycle blocks " +
      ids.filter(id => !ready.contains(id)).join(", ") +
      ". Remove a dependency to make the plan acyclic",
    )
  }
  errors
}
