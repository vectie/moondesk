///|
priv struct PivotReport {
  table : @jsontable.Table
  source_rows : Int32
  numeric_rows : Int32
}

///|
fn pivot_add(
  previous : (Int32, Int32, Double),
  value : Double?,
) -> (Int32, Int32, Double) {
  let (count, numeric, total) = previous
  match value {
    Some(number) => (count + 1, numeric + 1, total + number)
    None => (count + 1, numeric, total)
  }
}

///|
fn pivot_cell(
  stats : (Int32, Int32, Double),
  sum : Bool,
) -> @leafscene.CellValue {
  let (count, numeric, total) = stats
  if !sum {
    Number(count.to_string())
  } else if numeric == 0 {
    Empty
  } else if total.is_inf() || total.is_nan() {
    Text("Overflow")
  } else {
    Number(total.to_string())
  }
}

///|
fn pivot_report(
  table : @jsontable.Table,
  row_name : String,
  column_name : String,
  aggregation : String,
  value_name : String,
) -> Result[PivotReport, String] {
  let names : Map[String, Int32] = Map([])
  for i, name in table.columns {
    if names.contains(name) {
      return Err(
        "Duplicate source header: " +
        name +
        ". Rename it before creating a pivot report.",
      )
    }
    names[name] = i
  }
  guard names.get(row_name) is Some(row_index) else {
    return Err(
      "Choose an existing Row groups column. Previous selection: " + row_name,
    )
  }
  guard names.get(column_name) is Some(column_index) else {
    return Err(
      "Choose an existing Column categories column. Previous selection: " +
      column_name,
    )
  }
  if row_index == column_index {
    return Err("Choose different row-group and column-category columns")
  }
  if aggregation != "count" && aggregation != "sum" {
    return Err("Choose Count records or Sum numeric values")
  }
  let sum = aggregation == "sum"
  let value_index = names.get(value_name)
  if sum && value_index is None {
    return Err(
      "Choose an existing Numeric values column. Previous selection: " +
      value_name,
    )
  }
  let cells : Map[String, Map[String, (Int32, Int32, Double)]] = Map([])
  let row_totals : Map[String, (Int32, Int32, Double)] = Map([])
  let column_totals : Map[String, (Int32, Int32, Double)] = Map([])
  let mut grand = (0, 0, 0.0)
  for row in table.text_rows() {
    let row_key = row[row_index]
    let column_key = row[column_index]
    let value = if sum { table_number(row[value_index.unwrap()]) } else { None }
    let group = cells.get(row_key).unwrap_or(Map([]))
    group[column_key] = pivot_add(
      group.get(column_key).unwrap_or((0, 0, 0.0)),
      value,
    )
    cells[row_key] = group
    row_totals[row_key] = pivot_add(
      row_totals.get(row_key).unwrap_or((0, 0, 0.0)),
      value,
    )
    column_totals[column_key] = pivot_add(
      column_totals.get(column_key).unwrap_or((0, 0, 0.0)),
      value,
    )
    grand = pivot_add(grand, value)
    let width = column_totals.length() + 3
    let height = row_totals.length().to_int64() + 2L
    if width > 1000 || height > 100000L || height * width.to_int64() > 1000000L {
      return Err(
        "Pivot output exceeds 1,000 columns, 100,000 rows or one million cells including headers and totals. Choose less varied grouping columns or a smaller source.",
      )
    }
  }
  let columns = ["Row type", "Row: " + row_name]
  for key, _ in column_totals {
    columns.push("Category: " + key)
  }
  columns.push(if sum { "Total sum: " + value_name } else { "Total records" })
  let rows : Array[Array[@leafscene.CellValue]] = []
  for key, group in cells {
    let row : Array[@leafscene.CellValue] = [Text("Group"), Text(key)]
    for category, _ in column_totals {
      row.push(pivot_cell(group.get(category).unwrap_or((0, 0, 0.0)), sum))
    }
    row.push(pivot_cell(row_totals[key], sum))
    rows.push(row)
  }
  let totals : Array[@leafscene.CellValue] = [Text("Grand total"), Empty]
  for _, stats in column_totals {
    totals.push(pivot_cell(stats, sum))
  }
  totals.push(pivot_cell(grand, sum))
  rows.push(totals)
  let (_, numeric_rows, _) = grand
  Ok({
    table: { columns, rows, },
    source_rows: table.rows.length(),
    numeric_rows,
  })
}
