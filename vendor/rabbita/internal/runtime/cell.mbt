///|
pub(open) trait IsCell {
  step(Self, &Scheduler) -> Unit
  view(Self) -> VNode
  flags(Self) -> Flags
}

///|
struct Flags {
  id : Id
  mut dirty : Bool
  mut attach_count : Int
}

///|
pub fn Flags::new() -> Flags {
  { id: Id::new(), dirty: false, attach_count: 0 }
}

///|
pub fn Flags::mark_dirty(s : Self) -> Unit {
  s.dirty = true
}

///|
pub fn Flags::id(s : Self) -> Id {
  s.id
}

///|
priv struct Link {
  mut val : Instance?
}

///|
fn Link::detach(s : Self) -> Unit {
  s.val = None
}

///|
