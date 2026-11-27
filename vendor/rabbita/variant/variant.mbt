///|
#derive(Show, Eq, Compare, Hash)
pub(all) enum Variant {
  Boolean(Bool)
  Integer(Int)
  Floating(Double)
  String(String)
}
