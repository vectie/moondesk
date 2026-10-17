///|
// Object records cannot represent duplicate keys without discarding a column.
fn table_record_headers(columns : Array[String]) -> Result[Unit, String] {
  let seen : Map[String, Bool] = Map([])
  for column in columns {
    if seen.contains(column) {
      return Err(
        "JSON/JSONL export needs unique headers. Rename duplicate header " +
        column.to_json().stringify() +
        " in a separate saved source, or use CSV/XLSX.",
      )
    }
    seen[column] = true
  }
  Ok(())
}

///|
// Serialize the typed table projection, never infer types from text. Retain
// valid numeric lexemes rather than rounding them through a Double serializer.
fn table_record_cell(value : @leafscene.CellValue) -> Result[String, String] {
  match value {
    Empty => Ok("null")
    Text(text) | Error(text) => Ok(text.to_json().stringify())
    Boolean(value) => Ok(if value { "true" } else { "false" })
    Number(text) => {
      let token = text.trim().to_owned()
      let parsed = @json.parse(token) catch {
        _ => return Err("Invalid number")
      }
      match parsed {
        Number(value, ..) if !value.is_inf() && !value.is_nan() => Ok(token)
        _ => Err("Number must be finite JSON-style numeric text")
      }
    }
    Formula(cached=Some(text), ..) => Ok(text.to_json().stringify())
    Formula(cached=None, ..) => Ok("null")
  }
}

///|
fn table_export_records(
  table : @jsontable.Table,
  jsonl~ : Bool = false,
) -> Result[String, String] {
  match table_record_headers(table.columns) {
    Err(message) => return Err(message)
    Ok(_) => ()
  }
  let out = StringBuilder()
  if !jsonl {
    out.write_char('[')
  }
  for row_index, row in table.rows {
    if row.length() != table.columns.length() {
      return Err("Record \{row_index + 1} does not match the table headers")
    }
    if !jsonl && row_index > 0 {
      out.write_char(',')
    }
    out.write_char('{')
    for column_index, column in table.columns {
      if column_index > 0 {
        out.write_char(',')
      }
      out.write_string(column.to_json().stringify())
      out.write_char(':')
      match table_record_cell(row[column_index]) {
        Ok(value) => out.write_string(value)
        Err(message) =>
          return Err(
            "Record \{row_index + 1}, column \{column_index + 1}: \{message}. Source unchanged.",
          )
      }
    }
    out.write_char('}')
    if jsonl {
      out.write_char('\n')
    }
  }
  if !jsonl {
    out.write_string("]\n")
  }
  Ok(out.to_string())
}
