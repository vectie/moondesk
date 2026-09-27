///|
pub extend TownSnapshotRef with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend TownSnapshotRef with Eq::{not_equal, equal}

///|
pub extend TownSnapshotRef with ToJson::{to_json}

///|
pub extend TownSnapshotRef with @moonbitlang/core/json.FromJson::{from_json}

///|
pub extend OperatorRequestDraft with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend OperatorRequestDraft with Eq::{not_equal, equal}

///|
pub extend OperatorRequestDraft with ToJson::{to_json}

///|
pub extend OperatorRequestDraft with @moonbitlang/core/json.FromJson::{
  from_json,
}
