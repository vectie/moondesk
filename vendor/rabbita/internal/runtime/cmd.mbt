///|
using @url {type Url, type UrlRequest}

///|
enum Cmd {
  Effect((&Scheduler) -> Unit, EffectKind)
  Message(Id, () -> Unit)
  Batch(Array[Cmd])
  Empty
}

///|
pub(all) enum EffectKind {
  Immediately
  AfterRender
}

///|
#inline
pub fn message(id : Id, f : () -> Unit) -> Cmd {
  Message(id, f)
}

///|
#inline
pub fn effect(f : (&Scheduler) -> Unit, kind~ : EffectKind) -> Cmd {
  Effect(f, kind)
}

///|
pub let none : Cmd = Cmd::Empty

///|
#inline
pub fn batch(xs : Array[Cmd]) -> Cmd {
  Batch(xs)
}
