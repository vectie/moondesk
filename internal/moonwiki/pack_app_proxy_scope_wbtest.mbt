///|
test "pack app proxy stays inside the declared app route" {
  let entrypoint = "/apps/moonfish/paiwork"
  assert_eq(pack_app_proxy_scoped_target(entrypoint, []), Some(entrypoint))
  assert_eq(
    pack_app_proxy_scoped_target(entrypoint, [
      "apps", "moonfish", "paiwork", "api", "v1", "bootstrap",
    ]),
    Some("/apps/moonfish/paiwork/api/v1/bootstrap"),
  )
  assert_eq(
    pack_app_proxy_scoped_target(entrypoint, ["apps", "moonfish", "market"]),
    None,
  )
  assert_eq(pack_app_proxy_scoped_target(entrypoint, ["health"]), None)
}

///|
test "html entrypoint permits assets beside the document" {
  assert_eq(
    pack_app_proxy_scoped_target("/apps/example/index.html", [
      "apps", "example", "style.css",
    ]),
    Some("/apps/example/style.css"),
  )
  assert_eq(
    pack_app_proxy_scoped_target("/apps/example/index.html", [
      "apps", "other", "style.css",
    ]),
    None,
  )
}
