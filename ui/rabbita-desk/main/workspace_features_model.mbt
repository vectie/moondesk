///|
fn workspace_feature_msg(
  action : String,
  first? : String = "",
  second? : String = "",
  third? : String = "",
  fourth? : String = "",
) -> Msg {
  WorkspaceFeature(action, first, second, third, fourth)
}
