///|
pub extend ConfinedWriteResult with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ConfinedWriteResult with Eq::{not_equal, equal}

///|
pub extend ConfinedBytesWriteResult with @moonbitlang/core/debug.Debug::{
  to_repr,
}

///|
pub extend ConfinedBytesWriteResult with Eq::{not_equal, equal}
