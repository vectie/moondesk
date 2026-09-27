///|
pub extend PackStudioInspection with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend PackStudioInspection with Eq::{not_equal, equal}

///|
pub extend PackStudioInspection with ToJson::{to_json}

///|
pub extend PackStudioInspection with @moonbitlang/core/json.FromJson::{
  from_json,
}

///|
pub extend PackScaffoldRequest with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend PackScaffoldRequest with Eq::{not_equal, equal}

///|
pub extend PackScaffoldRequest with ToJson::{to_json}

///|
pub extend PackScaffoldRequest with @moonbitlang/core/json.FromJson::{from_json}

///|
pub extend PackBridgeAdoptionRequest with @moonbitlang/core/debug.Debug::{
  to_repr,
}

///|
pub extend PackBridgeAdoptionRequest with Eq::{not_equal, equal}

///|
pub extend PackBridgeAdoptionRequest with ToJson::{to_json}

///|
pub extend PackBridgeAdoptionRequest with @moonbitlang/core/json.FromJson::{
  from_json,
}

///|
pub extend PackInstallRequest with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend PackInstallRequest with Eq::{not_equal, equal}

///|
pub extend PackInstallRequest with ToJson::{to_json}

///|
pub extend PackInstallRequest with @moonbitlang/core/json.FromJson::{from_json}

///|
pub extend PackVersionRequest with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend PackVersionRequest with Eq::{not_equal, equal}

///|
pub extend PackVersionRequest with ToJson::{to_json}

///|
pub extend PackVersionRequest with @moonbitlang/core/json.FromJson::{from_json}

///|
pub extend PackIdentityRequest with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend PackIdentityRequest with Eq::{not_equal, equal}

///|
pub extend PackIdentityRequest with ToJson::{to_json}

///|
pub extend PackIdentityRequest with @moonbitlang/core/json.FromJson::{from_json}
