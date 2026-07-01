///|
fn town_daemon_path(workspace_root : String) -> String {
  @pathx.join(moonsuite_product_dir(workspace_root, "moontown"), "daemon.json")
}

///|
fn town_standing_goals_path(workspace_root : String) -> String {
  @pathx.join(
    moonsuite_product_dir(workspace_root, "moontown"),
    "standing-goals.json",
  )
}

///|
fn town_moonbooks_path(workspace_root : String) -> String {
  @pathx.join(
    moonsuite_product_dir(workspace_root, "moontown"),
    "moonbooks.json",
  )
}

///|
fn town_book_template_config_root(workspace_root : String) -> String {
  @pathx.join(
    moonsuite_product_dir(workspace_root, "moontown"),
    "book-template-configs",
  )
}

///|
fn town_book_template_request_path(workspace_root : String) -> String {
  @pathx.join(
    moonsuite_product_dir(workspace_root, "moontown"),
    "book-template-requests.json",
  )
}

///|
fn town_book_template_event_path(workspace_root : String) -> String {
  @pathx.join(
    moonsuite_product_dir(workspace_root, "moontown"),
    "book-template-request-events.jsonl",
  )
}

///|
fn town_moondesk_requests_root(workspace_root : String) -> String {
  @pathx.join(
    moonsuite_product_dir(workspace_root, "moontown"),
    "moondesk-requests",
  )
}

///|
fn pdf_watch_moontown_publish_receipt_relative_path() -> String {
  "raw/analysis-runs/moontown-template-publish.json"
}

///|
fn pdf_watch_moontown_standing_goal_receipt_relative_path() -> String {
  "raw/analysis-runs/moontown-standing-goal-registration.json"
}
