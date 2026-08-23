///|
pub(all) struct PackStudioInspection {
  source_root : String
  pack_id : String
  version : String
  display_name : String
  product_id : String
  valid : Bool
  install_ready : Bool
  active : Bool
  bridge_ready : Bool
  intake_operation_ids : Array[String]
  authorities : Array[String]
  issues : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct PackScaffoldRequest {
  parent_root : String
  pack_id : String
  display_name : String
  product_id : String
  intake_operation_id : String
  output_schema_id : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct PackBridgeAdoptionRequest {
  source_root : String
  intake_operation_id : String
  output_schema_id : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct PackInstallRequest {
  source_root : String
  granted_authorities : Array[@pack.AuthorityClass]
  runtime_extensions : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct PackVersionRequest {
  pack_id : String
  version : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct PackIdentityRequest {
  pack_id : String
} derive(Debug, Eq, ToJson, FromJson)
