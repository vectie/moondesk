///|
async fn book_pattern_records_for_workspace(
  workspace_root : String,
) -> Array[Json] {
  let mut records = book_pattern_records()
  for record in book_pattern_records_from_template_registry(workspace_root) {
    records = upsert_record_by_id(records, record)
  }
  records
}
