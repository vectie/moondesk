///|
priv struct TableAppend {
  table : @jsontable.Table
  shared_columns : Array[String]
  first_only : Array[String]
  second_only : Array[String]
}

///|
// Combine partitions by column name, never by position or inferred row identity.
fn append_tables(
  first : WorkspaceTableSource,
  second : WorkspaceTableSource,
) -> Result[TableAppend, String] {
  let names : Array[String] = []
  let indexes : Map[String, Int32] = Map([])
  let shared_columns : Array[String] = []
  let first_only : Array[String] = []
  let second_only : Array[String] = []
  for (source, side) in [(first, "First table"), (second, "Second table")] {
    let seen : Map[String, Bool] = Map([])
    for name in source.table.columns {
      if seen.contains(name) {
        return Err(
          "\{side} has duplicate column name: \{name}. Rename duplicate headers before combining.",
        )
      }
      seen[name] = true
      if !indexes.contains(name) {
        indexes[name] = names.length()
        names.push(name)
      }
    }
  }
  for name in first.table.columns {
    if second.table.columns.contains(name) {
      shared_columns.push(name)
    } else {
      first_only.push(name)
    }
  }
  for name in second.table.columns {
    if !first.table.columns.contains(name) {
      second_only.push(name)
    }
  }
  let width = names.length() + 3
  let height = first.table.rows.length().to_int64() +
    second.table.rows.length().to_int64() +
    1L
  if width > 1000 || height > 100000L || height * width.to_int64() > 1000000L {
    return Err(
      "Combined table exceeds 99,999 data records, 1,000 columns or one million cells including headers. Use smaller saved tables.",
    )
  }
  let rows : Array[Array[@leafscene.CellValue]] = []
  for source in [first, second] {
    let positions = source.table.columns.map(name => indexes[name] + 3)
    for index, values in source.table.text_rows() {
      let row = Array::make(width, @leafscene.CellValue::Empty)
      row[0] = Text(source.path)
      row[1] = Text(source.selected_sheet.unwrap_or(""))
      row[2] = Number((index + 1).to_string())
      for column, value in values {
        row[positions[column]] = Text(value)
      }
      rows.push(row)
    }
  }
  Ok({
    table: {
      columns: ["Source path", "Source worksheet", "Source record"] +
      names.map(name => "Field: " + name),
      rows,
    },
    shared_columns,
    first_only,
    second_only,
  })
}
