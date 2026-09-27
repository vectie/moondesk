///|
pub extend AppBinding with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend AppBinding with Eq::{not_equal, equal}

///|
pub extend AppBinding with ToJson::{to_json}

///|
pub extend AppBinding with @moonbitlang/core/json.FromJson::{from_json}

///|
pub extend AppRegistry with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend AppRegistry with Eq::{not_equal, equal}

///|
pub extend AppRegistry with ToJson::{to_json}

///|
pub extend AppRegistry with @moonbitlang/core/json.FromJson::{from_json}
