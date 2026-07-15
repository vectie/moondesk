///|
/// A generic app surface that MoonDesk can expose without knowing its domain.
pub(all) struct AppBinding {
  pack_id : String
  product_id : String
  entrypoint_id : String
  path : String
  audience : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn bindings(
  projection : @host.HostActivationProjection,
) -> Array[AppBinding] raise {
  if projection.contract != "moonsuite.pack-host-activation.v1" {
    fail("unsupported pack host projection")
  }
  projection.app_entrypoints.map(fn(entrypoint) {
    {
      pack_id: projection.pack_id,
      product_id: projection.product_id,
      entrypoint_id: entrypoint.id,
      path: entrypoint.path,
      audience: entrypoint.audience,
    }
  })
}

///|
pub fn resolve(
  projected : Array[AppBinding],
  entrypoint_id : String,
) -> AppBinding? {
  for binding in projected {
    if binding.entrypoint_id == entrypoint_id {
      return Some(binding)
    }
  }
  None
}
