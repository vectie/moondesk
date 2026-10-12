///|
// Repeated named parameters preserve exact headers, independent of column order.
fn unpivot_measures(request : String) -> Array[String] {
  let names : Array[String] = []
  if request.find("?") is Some(start) {
    for part in request[start + 1:].split("&") {
      let entry = part.to_owned()
      if entry.find("=") is Some(split) && entry[:split] == "measure" {
        names.push(decode_query_value(entry[split + 1:].to_owned()))
      }
    }
  }
  names
}

///|
fn unpivot_table(
  source : WorkspaceTableSource,
  measures : Array[String],
) -> Result[@jsontable.Table, String] {
  if measures.is_empty() {
    return Err("Choose at least one measurement column")
  }
  let seen : Map[String, Bool] = Map([])
  for name in source.table.columns {
    if seen.contains(name) {
      return Err(
        "Duplicate source header: " + name + ". Rename it before reshaping.",
      )
    }
    seen[name] = true
  }
  let selected : Map[String, Bool] = Map([])
  for name in measures {
    if !seen.contains(name) {
      return Err(
        "Measurement column is missing: " +
        name +
        ". Choose current columns again.",
      )
    }
    if selected.contains(name) {
      return Err("Measurement column was selected twice: " + name)
    }
    selected[name] = true
  }
  let ids : Array[Int] = []
  let values : Array[Int] = []
  for i, name in source.table.columns {
    if selected.contains(name) {
      values.push(i)
    } else {
      ids.push(i)
    }
  }
  let width = ids.length() + 5
  let height = source.table.rows.length().to_int64() *
    values.length().to_int64() +
    1L
  if width > 1000 || height > 100000L || height * width.to_int64() > 1000000L {
    return Err(
      "Reshaped output exceeds 99,999 records, 1,000 columns or one million cells including headers. Select fewer measurements or a smaller table.",
    )
  }
  let rows : Array[Array[@leafscene.CellValue]] = []
  for record, row in source.table.text_rows() {
    for index in values {
      let output : Array[@leafscene.CellValue] = [
        Text(source.path),
        Text(source.selected_sheet.unwrap_or("")),
        Number((record + 1).to_string()),
      ]
      for id in ids {
        output.push(Text(row[id]))
      }
      output.push(Text(source.table.columns[index]))
      output.push(Text(row[index]))
      rows.push(output)
    }
  }
  Ok({
    columns: ["Source path", "Source worksheet", "Source record"] +
    ids.map(i => "Field: " + source.table.columns[i]) +
    ["Measurement", "Value"],
    rows,
  })
}
