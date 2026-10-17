///|
priv struct TableLookup {
  table : @jsontable.Table
  matched : Int32
  unmatched : Int32
  unused_lookup : Int32
}

///|
fn lookup_columns(
  table : @jsontable.Table,
  key : Int32,
  side : String,
) -> Result[Unit, String] {
  if key < 0 || key >= table.columns.length() {
    return Err("Choose a valid \{side} key column")
  }
  let names : Map[String, Bool] = Map([])
  for name in table.columns {
    if names.contains(name) {
      return Err(
        "\{side} has duplicate column name: \{name}. Rename duplicate headers before enriching.",
      )
    }
    names[name] = true
  }
  Ok(())
}

///|
// A many-to-one left lookup keeps every source record, including repeated keys.
// Match on displayed text; export literal text so identifiers stay unchanged.
fn enrich_table(
  source : @jsontable.Table,
  lookup : @jsontable.Table,
  source_key : Int32,
  lookup_key : Int32,
) -> Result[TableLookup, String] {
  for
    (table, key, side) in [
      (source, source_key, "Source"),
      (lookup, lookup_key, "Lookup"),
    ] {
    if lookup_columns(table, key, side) is Err(message) {
      return Err(message)
    }
  }
  let width = 3 + source.columns.length() + lookup.columns.length()
  if width > 1000 ||
    (source.rows.length().to_int64() + 1L) * width.to_int64() > 1000000L {
    return Err(
      "Enrichment exceeds the one-million-cell or 1,000-column output limit. Use smaller saved tables.",
    )
  }
  let source_rows = source.text_rows()
  let lookup_rows = lookup.text_rows()
  let keys = match comparison_keys(lookup_rows, lookup_key, "Lookup") {
    Ok(keys) => keys
    Err(message) => return Err(message)
  }
  let used : Map[Int32, Bool] = Map([])
  let columns = ["Match", "Source record", "Lookup record"] +
    source.columns.map(name => "Source: " + name) +
    lookup.columns.map(name => "Lookup: " + name)
  let rows : Array[Array[@leafscene.CellValue]] = []
  let mut matched = 0
  for index, source_row in source_rows {
    let value = source_row[source_key]
    let match_row = if value.trim().is_empty() { None } else { keys.get(value) }
    let row : Array[@leafscene.CellValue] = [
      Text(if match_row is Some(_) { "Matched" } else { "Unmatched" }),
      Number((index + 1).to_string()),
      match_row
      .map(i => @leafscene.Number((i + 1).to_string()))
      .unwrap_or(Empty),
    ]
    for value in source_row {
      row.push(Text(value))
    }
    match match_row {
      Some(i) => {
        matched += 1
        used[i] = true
        for value in lookup_rows[i] {
          row.push(Text(value))
        }
      }
      None =>
        for _ in lookup.columns {
          row.push(Empty)
        }
    }
    rows.push(row)
  }
  Ok({
    table: { columns, rows, },
    matched,
    unmatched: source.rows.length() - matched,
    unused_lookup: lookup.rows.length() - used.length(),
  })
}
