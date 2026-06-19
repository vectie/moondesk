///|
pub struct TownSnapshotRef {
  town_json_path : String
  daemon_json_path : String
  standing_goals_path : String
  watcher_dir : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub struct OperatorRequestDraft {
  title : String
  prompt : String
  target_book_id : String
  cadence_ticks : Int
  source_policy : @moondesk_core.SourcePolicy
  review_policy : String
  context_entries : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn snapshot_paths(root_path : String) -> TownSnapshotRef {
  {
    town_json_path: root_path + "/.moontown/town.json",
    daemon_json_path: root_path + "/.moontown/daemon.json",
    standing_goals_path: root_path + "/.moontown/standing-goals.json",
    watcher_dir: root_path + "/.moontown/watchers",
  }
}

///|
pub fn request_id(title : String) -> String {
  @moondesk_core.stable_id("operator", title)
}

///|
pub fn normalize_request(draft : OperatorRequestDraft) -> OperatorRequestDraft {
  {
    ..draft,
    cadence_ticks: if draft.cadence_ticks < 1 {
      1
    } else {
      draft.cadence_ticks
    },
    review_policy: @moondesk_core.normalize_review_policy(draft.review_policy),
  }
}
