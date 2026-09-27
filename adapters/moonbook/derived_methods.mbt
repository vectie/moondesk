///|
pub extend MoonBookSection with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend MoonBookSection with Eq::{not_equal, equal}

///|
pub extend MoonBookSection with ToJson::{to_json}

///|
pub extend MoonBookSection with @moonbitlang/core/json.FromJson::{from_json}
