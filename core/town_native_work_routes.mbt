///|
pub fn town_native_work_route(action~ : String = "") -> String {
  town_route("native-work") +
  "/<work-id>" +
  (if action == "" { "" } else { "/" + url_component(action) })
}

///|
pub fn town_native_work_url(work_id : String, action~ : String = "") -> String {
  desktop_api_path(["api", "town", "native-work", work_id]) +
  (if action == "" { "" } else { "/" + url_component(action) })
}
