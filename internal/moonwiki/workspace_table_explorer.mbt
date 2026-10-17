///|
// The explorer projects existing Leaf readers; it never parses a file format.
fn table_from_sheet(
  sheet : @leafscene.Sheet,
) -> Result[@jsontable.Table, String] {
  let mut height = 0
  let mut width = 0
  for cell in sheet.cells {
    height = height.max(cell.row)
    width = width.max(cell.column)
  }
  if height > 100000 ||
    width > 1000 ||
    height.to_int64() * width.to_int64() > 1000000L {
    return Err("Table exceeds the explorer's one-million-cell limit")
  }
  let rows : Array[Array[@leafscene.CellValue]] = Array::makei(height, _ => {
    Array::make(width, @leafscene.CellValue::Empty)
  })
  for cell in sheet.cells {
    if cell.row > 0 && cell.column > 0 {
      rows[cell.row - 1][cell.column - 1] = match cell.value {
        Formula(cached=Some(value), ..) => @leafscene.CellValue::Text(value)
        Formula(cached=None, ..) => @leafscene.CellValue::Empty
        value => value
      }
    }
  }
  if rows.is_empty() {
    return Ok({ columns: [], rows: [], })
  }
  let header : @jsontable.Table = { columns: [], rows: [rows[0]], }
  let columns = header.text_rows()[0].mapi((i, value) => {
    if value == "" {
      "Column \{i + 1}"
    } else {
      value
    }
  })
  Ok({ columns, rows: rows[1:].to_array(), })
}

///|
fn table_query(path : String, key : String) -> String {
  decode_query_value(query_value(path, key).unwrap_or(""))
}

///|
fn table_column(path : String, key : String, width : Int32) -> Int32? {
  let text = table_query(path, key)
  for i in 0..<width {
    if text == i.to_string() {
      return Some(i)
    }
  }
  None
}

///|
fn table_number(text : String) -> Double? {
  let parsed = @json.parse(text.trim().to_owned()) catch { _ => return None }
  match parsed {
    Number(value, ..) if !value.is_nan() && !value.is_inf() => Some(value)
    _ => None
  }
}

///|
fn explore_table(
  table : @jsontable.Table,
  path : String,
) -> Result[@jsontable.Table, String] {
  let width = table.columns.length()
  let text_column = table_column(path, "text_column", width)
  let needle = table_query(path, "contains").to_lower()
  let number_column = table_column(path, "number_column", width)
  let minimum = table_query(path, "min")
  let maximum = table_query(path, "max")
  let min_value = table_number(minimum)
  let max_value = table_number(maximum)
  if (minimum != "" && min_value is None) ||
    (maximum != "" && max_value is None) {
    return Err(
      "Minimum and maximum must be finite JSON-style numbers (for example 12.5)",
    )
  }
  if needle != "" && text_column is None {
    return Err("Choose a text filter column")
  }
  if (minimum != "" || maximum != "") && number_column is None {
    return Err("Choose a numeric filter column")
  }
  if min_value is Some(a) && max_value is Some(b) && a > b {
    return Err("Minimum must not exceed maximum")
  }
  let text_rows = table.text_rows()
  let mut indexes : Array[Int32] = []
  for i, row in text_rows {
    if text_column is Some(column) && !row[column].to_lower().contains(needle) {
      continue
    }
    if number_column is Some(column) && (minimum != "" || maximum != "") {
      guard table_number(row[column]) is Some(value) else { continue }
      if min_value is Some(min) && value < min {
        continue
      }
      if max_value is Some(max) && value > max {
        continue
      }
    }
    indexes.push(i)
  }
  indexes = match
    table_duplicate_indexes(table.columns, text_rows, indexes, path) {
    Ok(selected) => selected
    Err(message) => return Err(message)
  }
  if table_column(path, "sort", width) is Some(column) {
    let numeric = table_query(path, "sort_type") == "number"
    let descending = table_query(path, "direction") == "desc"
    indexes.sort_by((a, b) => {
      let left = text_rows[a][column]
      let right = text_rows[b][column]
      let comparison = if numeric {
        match (table_number(left), table_number(right)) {
          (Some(a), Some(b)) =>
            if descending {
              b.compare(a)
            } else {
              a.compare(b)
            }
          (Some(_), None) => -1
          (None, Some(_)) => 1
          (None, None) => 0
        }
      } else if descending {
        right.compare(left)
      } else {
        left.compare(right)
      }
      if comparison == 0 {
        a.compare(b)
      } else {
        comparison
      }
    })
  }
  Ok({ columns: table.columns, rows: indexes.map(i => table.rows[i]), })
}

///|
fn table_explorer_query(path : String) -> String {
  let output = StringBuilder()
  for
    key in [
      "sheet", "text_column", "contains", "number_column", "min", "max", "sort",
      "sort_type", "direction", "group", "sum", "duplicates", "duplicate_key", "duplicate_key2",
    ] {
    if query_value(path, key) is Some(value) {
      output.write_string("&\{key}=\{value}")
    }
  }
  output.to_string()
}

///|
fn table_select(
  columns : Array[String],
  key : String,
  label : String,
  path : String,
  empty_label~ : String = "None",
) -> String {
  let out = StringBuilder()
  out.write_string(
    "<label>\{label} <select name=\"\{key}\"><option value=\"\">\{office_escape_xml(empty_label)}</option>",
  )
  for i, column in columns {
    let selected = if table_query(path, key) == i.to_string() {
      " selected"
    } else {
      ""
    }
    out.write_string(
      "<option value=\"\{i}\"\{selected}>\{i + 1}: \{office_escape_xml(column)}</option>",
    )
  }
  out.write_string("</select></label> ")
  out.to_string()
}

///|
fn table_explorer_controls(
  workspace : String,
  file : String,
  columns : Array[String],
  path : String,
) -> String {
  let out = StringBuilder()
  out.write_string(
    "<style>fieldset{margin:12px 0;padding:14px;border:1px solid #bccfc6}label{display:inline-block;margin:5px}input,select,button{font:inherit;padding:6px;max-width:22rem}button{cursor:pointer}caption{text-align:left;font-weight:bold;margin:12px 0}</style><form method=\"get\"><input type=\"hidden\" name=\"path\" value=\"\{office_escape_xml(file)}\"><fieldset><legend>Filter saved rows</legend>",
  )
  if query_value(path, "sheet") is Some(_) {
    let sheet = office_escape_xml(table_query(path, "sheet"))
    out.write_string(
      "<input type=\"hidden\" name=\"sheet\" value=\"\{sheet}\">",
    )
  }
  out.write_string(table_select(columns, "text_column", "Text column", path))
  let contains = office_escape_xml(table_query(path, "contains"))
  out.write_string(
    "<label>Contains (case-insensitive) <input name=\"contains\" value=\"\{contains}\"></label><br>",
  )
  out.write_string(
    table_select(columns, "number_column", "Numeric column", path),
  )
  for key in ["min", "max"] {
    let label = if key == "min" {
      "Minimum (inclusive)"
    } else {
      "Maximum (inclusive)"
    }
    let value = office_escape_xml(table_query(path, key))
    out.write_string(
      "<label>\{label} <input name=\"\{key}\" value=\"\{value}\" inputmode=\"decimal\"></label>",
    )
  }
  out.write_string("</fieldset>")
  out.write_string(table_duplicate_controls(columns, path))
  out.write_string("<fieldset><legend>Sort and summarize</legend>")
  out.write_string(table_select(columns, "sort", "Sort column", path))
  for
    (key, label, options) in [
      ("sort_type", "Sort as", [("text", "Text"), ("number", "Number")]),
      ("direction", "Direction", [("asc", "Ascending"), ("desc", "Descending")]),
    ] {
    out.write_string("<label>\{label} <select name=\"\{key}\">")
    for (value, name) in options {
      let selected = if table_query(path, key) == value {
        " selected"
      } else {
        ""
      }
      out.write_string("<option value=\"\{value}\"\{selected}>\{name}</option>")
    }
    out.write_string("</select></label>")
  }
  out.write_string("<br>")
  out.write_string(table_select(columns, "group", "Group by", path))
  out.write_string(table_select(columns, "sum", "Sum numeric column", path))
  let sheet_query = match query_value(path, "sheet") {
    Some(value) => "&sheet=" + value
    None => ""
  }
  let reset = office_escape_xml(
    @desk.workspace_json_table_url(workspace, file) + sheet_query,
  )
  out.write_string(
    "</fieldset><button type=\"submit\">Apply exploration</button> <a href=\"\{reset}\">Reset all</a></form><p>Filters combine with AND. Numeric filters exclude blank/non-numeric cells; numeric sort puts them last. Summaries use only matching rows. Formulas use cached values without recalculation.</p>",
  )
  out.to_string()
}
