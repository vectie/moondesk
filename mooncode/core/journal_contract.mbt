///|
/// Shared identity of the authoritative MoonCode session journal contract.
fn journal_contract_id() -> String {
  "moonsuite-conversation-journal.v2"
}

///|
fn journal_read_contract_ids() -> Array[String] {
  [@conversation.journal_contract_id(), journal_contract_id()]
}
