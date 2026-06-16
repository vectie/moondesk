///|
fn append_mooncode_command_event(
  session : Json,
  action~ : String,
  status~ : String,
  detail~ : String,
  created_at~ : String,
  path? : String = "",
  command_packet? : Json = Json::object({}),
) -> Json {
  let event_id = json_string(
    command_packet,
    "command_id",
    default=@desk.stable_id(
      "mooncode-command",
      action + ":" + status + ":" + created_at + ":" + detail,
    ),
  )
  @mooncode.append_command_event(
    session,
    action~,
    status~,
    detail~,
    created_at~,
    path~,
    command_packet~,
    event_id~,
  )
}
