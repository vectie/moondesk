///|
test "managed daemon preserves only explicitly supplied MoonFort references" {
  let execution = "/operator/Moon Fort/executor.json"
  let promotion = "/operator/Moon Fort/promotion.json"
  let environment = moonclaw_daemon_environment_from_values(
    "/Users/test",
    "",
    "",
    moonfort_config=execution,
    moonfort_promotion_config=promotion,
  )
  assert_eq(environment.get("MOONCLAW_MOONFORT_CONFIG"), Some(execution))
  assert_eq(
    environment.get("MOONCLAW_MOONFORT_PROMOTION_CONFIG"),
    Some(promotion),
  )
  assert_eq(environment.length(), 7)
  assert_false(environment.contains("OPENAI_API_KEY"))
  assert_false(environment.contains("OPENROUTER_API_KEY"))
  assert_false(environment.contains("MOONGATE_CONTROL_TOKEN"))
  assert_false(environment.contains("MOONFORT_EXECUTOR_CONFIG"))
  assert_eq(environment["HOME"], "/Users/test")
}

///|
test "managed daemon leaves absent MoonFort references absent and independent" {
  let absent = moonclaw_daemon_environment_from_values("/Users/test", "", "")
  assert_eq(absent.length(), 5)
  assert_false(absent.contains("MOONCLAW_MOONFORT_CONFIG"))
  assert_false(absent.contains("MOONCLAW_MOONFORT_PROMOTION_CONFIG"))
  let execution = moonclaw_daemon_environment_from_values(
    "/Users/test",
    "",
    "",
    moonfort_config="/operator/executor.json",
  )
  assert_eq(execution.length(), 6)
  assert_false(execution.contains("MOONCLAW_MOONFORT_PROMOTION_CONFIG"))
  let promotion = moonclaw_daemon_environment_from_values(
    "/Users/test",
    "",
    "",
    moonfort_promotion_config="/operator/promotion.json",
  )
  assert_eq(promotion.length(), 6)
  assert_false(promotion.contains("MOONCLAW_MOONFORT_CONFIG"))
}

///|
test "managed daemon preserves present invalid references for the existing loader" {
  for value in ["", "relative.json", "  /operator/config.json  "] {
    let environment = moonclaw_daemon_environment_from_values(
      "/Users/test",
      "",
      "",
      moonfort_config=value,
      moonfort_promotion_config=value,
    )
    assert_eq(environment.get("MOONCLAW_MOONFORT_CONFIG"), Some(value))
    assert_eq(
      environment.get("MOONCLAW_MOONFORT_PROMOTION_CONFIG"),
      Some(value),
    )
  }
}
