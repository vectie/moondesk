///|
priv struct TableComparison {
  differences : @jsontable.Table
  added : Int32
  removed : Int32
  changed : Int32
  unchanged : Int32
  added_columns : Array[String]
  removed_columns : Array[String]
}

///|
fn comparison_columns(
  table : @jsontable.Table,
  key : Int32,
  side : String,
) -> Result[Map[String, Int32], String] {
  if key < 0 || key >= table.columns.length() {
    return Err("Choose a valid \{side} key column")
  }
  let columns : Map[String, Int32] = Map([])
  for i, name in table.columns {
    if columns.contains(name) {
      return Err(
        "\{side} has duplicate column name: \{name}. Rename duplicate headers before comparing.",
      )
    }
    columns[name] = i
  }
  columns.remove(table.columns[key])
  Ok(columns)
}

///|
fn comparison_keys(
  rows : Array[Array[String]],
  key : Int32,
  side : String,
) -> Result[Map[String, Int32], String] {
  let keys : Map[String, Int32] = Map([])
  for i, row in rows {
    let value = row[key]
    if value.trim().is_empty() {
      return Err(
        "\{side} record \{i + 1} has a blank key. Choose a nonblank unique key column.",
      )
    }
    if keys.get(value) is Some(previous) {
      return Err(
        "\{side} has duplicate key at records \{previous + 1} and \{i + 1}. Choose a unique key column.",
      )
    }
    keys[value] = i
  }
  Ok(keys)
}

///|
// Compare displayed values, so equivalent CSV text and JSON numbers match.
// Missing columns are different from an existing column containing blanks.
fn compare_tables(
  before : @jsontable.Table,
  after : @jsontable.Table,
  before_key : Int32,
  after_key : Int32,
) -> Result[TableComparison, String] {
  let left_columns = match comparison_columns(before, before_key, "Before") {
    Ok(columns) => columns
    Err(message) => return Err(message)
  }
  let right_columns = match comparison_columns(after, after_key, "After") {
    Ok(columns) => columns
    Err(message) => return Err(message)
  }
  let names = left_columns.keys().to_array()
  let added_columns : Array[String] = []
  let removed_columns : Array[String] = []
  for name, _ in right_columns {
    if !left_columns.contains(name) {
      names.push(name)
      added_columns.push(name)
    }
  }
  for name, _ in left_columns {
    if !right_columns.contains(name) {
      removed_columns.push(name)
    }
  }
  let width = 5 + names.length() * 2
  if width > 1000 ||
    (before.rows.length() + after.rows.length()).to_int64() * width.to_int64() >
    1000000L {
    return Err(
      "Comparison exceeds the one-million-cell or 1,000-column output limit. Compare smaller saved tables.",
    )
  }
  let left_rows = before.text_rows()
  let right_rows = after.text_rows()
  let left_keys = match comparison_keys(left_rows, before_key, "Before") {
    Ok(keys) => keys
    Err(message) => return Err(message)
  }
  let right_keys = match comparison_keys(right_rows, after_key, "After") {
    Ok(keys) => keys
    Err(message) => return Err(message)
  }
  let columns = [
    "Change", "Key", "Before record", "After record", "Changed columns",
  ]
  for name in names {
    columns.push(
      "Before: " +
      name +
      (if left_columns.contains(name) { "" } else { " [column absent]" }),
    )
    columns.push(
      "After: " +
      name +
      (if right_columns.contains(name) { "" } else { " [column absent]" }),
    )
  }
  let rows : Array[Array[@leafscene.CellValue]] = []
  let mut added = 0
  let mut removed = 0
  let mut changed = 0
  let mut unchanged = 0
  // Visit old records first, then newly added records in their source order.
  let keys = left_keys.keys().to_array()
  for key, _ in right_keys {
    if !left_keys.contains(key) {
      keys.push(key)
    }
  }
  for key in keys {
    let left = left_keys.get(key)
    let right = right_keys.get(key)
    let values : Array[@leafscene.CellValue] = []
    let changed_names : Array[String] = []
    for name in names {
      let before_value = match (left, left_columns.get(name)) {
        (Some(row), Some(column)) => Some(left_rows[row][column])
        _ => None
      }
      let after_value = match (right, right_columns.get(name)) {
        (Some(row), Some(column)) => Some(right_rows[row][column])
        _ => None
      }
      if before_value != after_value {
        changed_names.push(name)
      }
      // Text cells keep identifiers, leading zeros and formula-looking input.
      values.push(
        before_value
        .map(value => @leafscene.CellValue::Text(value))
        .unwrap_or(@leafscene.Empty),
      )
      values.push(
        after_value
        .map(value => @leafscene.CellValue::Text(value))
        .unwrap_or(@leafscene.Empty),
      )
    }
    let status = match (left, right) {
      (None, Some(_)) => {
        added += 1
        "Added"
      }
      (Some(_), None) => {
        removed += 1
        "Removed"
      }
      _ if !changed_names.is_empty() => {
        changed += 1
        "Changed"
      }
      _ => {
        unchanged += 1
        continue
      }
    }
    let record : Array[@leafscene.CellValue] = [
      Text(status),
      Text(key),
      left.map(i => @leafscene.Number((i + 1).to_string())).unwrap_or(Empty),
      right.map(i => @leafscene.Number((i + 1).to_string())).unwrap_or(Empty),
      Text(changed_names.join(", ")),
    ]
    rows.push(record + values)
  }
  Ok({
    differences: { columns, rows, },
    added,
    removed,
    changed,
    unchanged,
    added_columns,
    removed_columns,
  })
}
