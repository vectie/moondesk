///|
pub extend DeskRoot with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend DeskRoot with Eq::{not_equal, equal}

///|
pub extend DeskRoot with ToJson::{to_json}

///|
pub extend DeskRoot with @moonbitlang/core/json.FromJson::{from_json}

///|
pub extend HostConfig with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend HostConfig with Eq::{not_equal, equal}

///|
pub extend HostConfig with ToJson::{to_json}

///|
pub extend HostConfig with @moonbitlang/core/json.FromJson::{from_json}
