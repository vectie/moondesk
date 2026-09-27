///|
test "projection binds app entrypoints without domain imports" {
  let projection : @host.HostActivationProjection = {
    contract: "moonsuite.pack-host-activation.v1",
    pack_id: "fixture",
    product_id: "fixture",
    version: "1.0.0",
    required_runtime_extensions: [],
    book_templates: [],
    tools: [],
    schedules: [],
    app_entrypoints: [
      { id: "fixture.console", path: "apps/console", audience: "operator", },
    ],
    provider_ports: [],
    policies: [],
  }
  let projected = @packapp.bindings(projection)
  guard @packapp.resolve(projected, "fixture.console") is Some(binding) else {
    fail("entrypoint should resolve")
  }
  assert_eq(binding.path, "apps/console")
  assert_eq(binding.audience, "operator")
  let twice = @packapp.reconcile(
    @packapp.reconcile(@packapp.empty_registry(), projection),
    projection,
  )
  assert_eq(twice.entrypoints.length(), 1)
  assert_eq(@packapp.remove_pack(twice, "fixture").entrypoints.length(), 0)
}
