///|
fn desk_label_test_entry(
  path~ : String = "inbox",
  name~ : String = "Inbox",
  kind~ : @desk.EntryKind = Directory,
  layer~ : @desk.SourceLayer = Inbox,
) -> @desk.DeskFileEntry {
  @desk.file_entry_detail(
    workspace_id="book-demo",
    path~,
    display_name=name,
    kind~,
    source_layer=layer,
  )
}

///|
test "Desk localizes canonical section identities, not authored names" {
  let inbox = @desk.file_entry_detail(
    workspace_id="book-demo",
    path="inbox",
    display_name="Inbox",
    kind=Directory,
    source_layer=Inbox,
  )
  assert_eq(desk_system_entry_i18n_key(inbox), Some("desk.section_inbox"))
  assert_eq(
    desk_system_entry_i18n_key(desk_label_test_entry(path="notes/Inbox")),
    None,
  )
  assert_eq(desk_system_entry_i18n_key(desk_label_test_entry(kind=Text)), None)
  assert_eq(
    desk_system_entry_i18n_key(desk_label_test_entry(layer=Workspace)),
    None,
  )
  assert_eq(
    desk_system_entry_i18n_key(desk_label_test_entry(name="My inbox")),
    None,
  )
  let ordinary = @desk.file_entry(
    workspace_id="book-demo",
    path="Skills",
    is_directory=true,
  )
  assert_eq(desk_system_entry_i18n_key(ordinary), None)
  let review = @desk.file_entry_detail(
    workspace_id="book-demo",
    path="wiki/reviews",
    display_name="Review Queue",
    kind=Directory,
    source_layer=Review,
  )
  assert_eq(
    desk_system_entry_i18n_key(review),
    Some("desk.section_review_queue"),
  )
  assert_eq(
    desk_outline_label_i18n_key("Inbox", "inbox", [inbox]),
    Some("desk.section_inbox"),
  )
  assert_eq(desk_outline_label_i18n_key("Skills", "Skills", [ordinary]), None)
}

///|
test "Desk rows and details mark aliases but retain original paths" {
  let inbox = @desk.file_entry_detail(
    workspace_id="book-demo",
    path="inbox",
    display_name="Inbox",
    kind=Directory,
    source_layer=Inbox,
  )
  let model = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    entries: [inbox, @desk.file_entry(workspace_id="book-demo", path="Skills")],
    selected_path: "inbox",
    desk_entries_state: None,
  }
  let markup = desk_entries_test_markup(model)
  assert_true(markup.contains("data-i18n=\"desk.section_inbox\""))
  assert_true(markup.contains("data-path=\"inbox\""))
  assert_true(markup.contains("data-i18n-preserve=\"title\""))
  assert_true(markup.contains("data-i18n-scope=\"content\">Skills</strong>"))
  assert_true(!markup.contains("data-i18n=\"desk.section_skills\""))
  assert_eq(inbox.path, "inbox")
  assert_eq(inbox.display_name, "Inbox")
}
