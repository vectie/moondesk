///|
// One typed projection drives both the visible summary and its downloads.
// Call after filtering/sorting, so group order follows the displayed rows.
fn table_group_summary(
  table : @jsontable.Table,
  path : String,
) -> Result[@jsontable.Table, String] {
  guard table_column(path, "group", table.columns.length()) is Some(group) else {
    return Err("Choose a valid Group by column before exporting a summary")
  }
  let sum = table_column(path, "sum", table.columns.length())
  if table_query(path, "sum") != "" && sum is None {
    return Err("Choose a valid Sum numeric column or select None")
  }
  let groups : Map[String, (Int, Int, Double)] = Map([])
  for row in table.text_rows() {
    let key = row[group]
    let (count, numeric, total) = groups.get(key).unwrap_or((0, 0, 0.0))
    let value = match sum {
      Some(index) => table_number(row[index])
      None => None
    }
    groups[key] = match value {
      Some(value) => (count + 1, numeric + 1, total + value)
      None => (count + 1, numeric, total)
    }
  }
  let columns = ["Group: " + table.columns[group], "Rows"]
  if sum is Some(index) {
    columns.push("Numeric values: " + table.columns[index])
    columns.push("Sum: " + table.columns[index])
  }
  let rows : Array[Array[@leafscene.CellValue]] = []
  for key, (count, numeric, total) in groups {
    let row : Array[@leafscene.CellValue] = [
      Text(key),
      Number(count.to_string()),
    ]
    if sum is Some(_) {
      row.push(Number(numeric.to_string()))
      row.push(
        if numeric == 0 {
          Empty
        } else if total.is_inf() || total.is_nan() {
          Text("Overflow")
        } else {
          Number(total.to_string())
        },
      )
    }
    rows.push(row)
  }
  Ok({ columns, rows, })
}

///|
fn table_explorer_summary(table : @jsontable.Table, path : String) -> String {
  if table_query(path, "group") == "" {
    return ""
  }
  let summary = match table_group_summary(table, path) {
    Ok(summary) => summary
    Err(message) => return "<p role=\"alert\">\{office_escape_xml(message)}</p>"
  }
  let out = StringBuilder()
  out.write_string(
    "<table data-testid=\"group-summary\"><caption>Filtered group summary</caption><thead><tr>",
  )
  for column in summary.columns {
    out.write_string("<th scope=\"col\">\{office_escape_xml(column)}</th>")
  }
  out.write_string("</tr></thead><tbody>")
  for row in summary.text_rows() {
    out.write_string("<tr>")
    for i, value in row {
      let label = if value == "" {
        if i == 0 {
          "(blank)"
        } else {
          "—"
        }
      } else {
        value
      }
      out.write_string("<td>\{office_escape_xml(label)}</td>")
    }
    out.write_string("</tr>")
  }
  out.write_string("</tbody></table>")
  if summary.rows.is_empty() {
    out.write_string(
      "<p>No matching rows. Summary exports contain headers only.</p>",
    )
  }
  out.write_string(
    "<p>Blank group keys remain empty in downloads; missing numeric totals are empty, not zero. Counts and finite totals are numeric cells in XLSX.</p>",
  )
  out.to_string()
}
