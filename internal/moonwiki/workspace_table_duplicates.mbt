///|
// Duplicate decisions use the filtered rows in saved order, before sorting.
// Encode an array, not joined text, so composite keys cannot collide on separators.
fn table_duplicate_indexes(
  columns : Array[String],
  text_rows : Array[Array[String]],
  indexes : Array[Int32],
  path : String,
) -> Result[Array[Int32], String] {
  let mode = table_query(path, "duplicates")
  if mode == "" || mode == "all" {
    return Ok(indexes)
  }
  if mode != "first" && mode != "last" && mode != "unique" && mode != "repeated" {
    return Err("Choose a supported duplicate-record view")
  }
  let first = table_column(path, "duplicate_key", columns.length())
  let second = table_column(path, "duplicate_key2", columns.length())
  if (table_query(path, "duplicate_key") != "" && first is None) ||
    (table_query(path, "duplicate_key2") != "" && second is None) {
    return Err("Choose valid duplicate key columns or reset the key selection")
  }
  if second is Some(_) && (first is None || first == second) {
    return Err(
      "The second duplicate key must differ from the first; choose both or use all columns",
    )
  }
  let keys : Array[String] = []
  let groups : Map[String, (Int32, Int32, Int32)] = Map([])
  for index in indexes {
    let row = text_rows[index]
    let values = match first {
      None => row
      Some(column) =>
        match second {
          None => [row[column]]
          Some(other) => [row[column], row[other]]
        }
    }
    let key = values.to_json().stringify()
    keys.push(key)
    let (first_index, _, count) = groups.get(key).unwrap_or((index, index, 0))
    groups[key] = (first_index, index, count + 1)
  }
  let selected : Array[Int32] = []
  for position, index in indexes {
    let (first_index, last_index, count) = groups[keys[position]]
    let keep = match mode {
      "first" => index == first_index
      "last" => index == last_index
      "unique" => count == 1
      _ => count > 1
    }
    if keep {
      selected.push(index)
    }
  }
  Ok(selected)
}

///|
fn table_duplicate_controls(columns : Array[String], path : String) -> String {
  let out = StringBuilder()
  out.write_string(
    "<fieldset><legend>Review duplicate records</legend><label>Rows to keep <select name=\"duplicates\">",
  )
  for
    (value, label) in [
      ("all", "All rows"),
      ("first", "First row for each key"),
      ("last", "Last row for each key"),
      ("unique", "Only keys seen once"),
      ("repeated", "All rows with repeated keys"),
    ] {
    let selected = if table_query(path, "duplicates") == value {
      " selected"
    } else {
      ""
    }
    out.write_string("<option value=\"\{value}\"\{selected}>\{label}</option>")
  }
  out.write_string("</select></label> ")
  out.write_string(
    table_select(
      columns,
      "duplicate_key",
      "Match key",
      path,
      empty_label="All columns",
    ),
  )
  out.write_string(
    table_select(columns, "duplicate_key2", "Second key (optional)", path),
  )
  out.write_string(
    "<p>Matching uses exact displayed text, including case and spaces. Numeric 1 and text 1 match; empty cells and empty text match. Filters run first, duplicate selection second, sorting third. First/last refers to saved row order among filtered rows. Downloads and summaries use this same selection; originals stay unchanged.</p></fieldset>",
  )
  out.to_string()
}
