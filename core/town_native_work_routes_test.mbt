///|
test "native work desktop contracts are saved read and explicit owner mutation" {
  let base = @core.town_route("native-work")
  assert_eq(@core.desktop_api_route_allowed_methods(base), ["GET"])
  assert_eq(@core.town_native_work_route(), base + "/<work-id>")
  assert_eq(
    @core.desktop_api_route_allowed_methods(@core.town_native_work_route()),
    ["GET"],
  )
  for action in ["refresh", "cancel", "sync"] {
    assert_eq(
      @core.desktop_api_route_allowed_methods(
        @core.town_native_work_route(action~),
      ),
      ["POST"],
    )
    assert_eq(
      @core.town_native_work_url(
        "town-work-0123456789abcdef0123456789abcdef",
        action~,
      ),
      base + "/town-work-0123456789abcdef0123456789abcdef/" + action,
    )
  }
  assert_eq(
    @core.town_native_work_url("escape/slash?"),
    base + "/escape%2Fslash%3F",
  )
  assert_eq(
    @core.desktop_api_route_allowed_methods(
      @core.town_native_work_route(action="pause"),
    ),
    [],
  )
  assert_eq(
    @core.desktop_api_route_allowed_methods(@core.town_route("requests")),
    ["GET", "HEAD", "POST"],
  )
}
