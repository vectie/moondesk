///|
fn moontown_product_root(workspace_root : String) -> String {
  moonsuite_product_dir_for_workspace_root(workspace_root, "moontown")
}

///|
fn town_daemon_path(workspace_root : String) -> String {
  @pathx.join(moontown_product_root(workspace_root), "daemon.json")
}

///|
fn town_standing_goals_path(workspace_root : String) -> String {
  @pathx.join(moontown_product_root(workspace_root), "standing-goals.json")
}

///|
fn town_moonbooks_path(workspace_root : String) -> String {
  @pathx.join(moontown_product_root(workspace_root), "moonbooks.json")
}

///|
fn town_book_template_config_root(workspace_root : String) -> String {
  @pathx.join(moontown_product_root(workspace_root), "book-template-configs")
}

///|
fn town_book_template_request_path(workspace_root : String) -> String {
  @pathx.join(
    moontown_product_root(workspace_root),
    "book-template-requests.json",
  )
}

///|
fn town_book_template_event_path(workspace_root : String) -> String {
  @pathx.join(
    moontown_product_root(workspace_root),
    "book-template-request-events.jsonl",
  )
}

///|
fn town_moondesk_requests_relative_root() -> String {
  ".moonsuite/products/moontown/moondesk-requests"
}

///|
fn town_moondesk_dispatches_relative_root() -> String {
  ".moonsuite/products/moontown/moondesk-dispatches"
}

///|
fn town_moondesk_requests_root(workspace_root : String) -> String {
  moonsuite_product_artifact_for_workspace_root(
    workspace_root, "moontown", "moondesk-requests",
  )
}

///|
fn town_moondesk_dispatches_root(workspace_root : String) -> String {
  moonsuite_product_artifact_for_workspace_root(
    workspace_root, "moontown", "moondesk-dispatches",
  )
}

///|
fn town_moondesk_request_relative_path(name : String) -> String {
  @pathx.join(town_moondesk_requests_relative_root(), name)
}

///|
fn town_moondesk_dispatch_relative_path(name : String) -> String {
  @pathx.join(town_moondesk_dispatches_relative_root(), name)
}

///|
fn town_moondesk_request_path(workspace_root : String, name : String) -> String {
  @pathx.join(town_moondesk_requests_root(workspace_root), name)
}

///|
fn town_moondesk_dispatch_path(
  workspace_root : String,
  name : String,
) -> String {
  @pathx.join(town_moondesk_dispatches_root(workspace_root), name)
}

///|
fn pdf_watch_moontown_publish_receipt_relative_path() -> String {
  "raw/analysis-runs/moontown-template-publish.json"
}

///|
fn pdf_watch_moontown_standing_goal_receipt_relative_path() -> String {
  "raw/analysis-runs/moontown-standing-goal-registration.json"
}
