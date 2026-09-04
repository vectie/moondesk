///|
#warnings("-unused_field")
struct PackTemplateOperation {
  operation_ref : String
  input_schema_ref : String
  output_schema_ref : String
  required : Bool
} derive(FromJson)

///|
struct PackTemplateRequirements {
  operations : Array[PackTemplateOperation]
  schemas : Array[String]
} derive(FromJson)

///|
#warnings("-unused_field")
struct PackTemplateCostCeiling {
  status : String
  currency : String
  max_minor : Json
  note : String
} derive(FromJson)

///|
#warnings("-unused_field")
struct PackTemplateLicensingCeiling {
  status : String
  classes : Array[String]
  note : String
} derive(FromJson)

///|
#warnings("-unused_field")
struct PackTemplateReviewCeiling {
  required : Bool
  authority : String
  gates : Array[String]
} derive(FromJson)

///|
#warnings("-unused_field")
struct PackTemplateCeilings {
  authorities : Array[String]
  external_effect : Bool
  cost : PackTemplateCostCeiling
  licensing : PackTemplateLicensingCeiling
  review : PackTemplateReviewCeiling
} derive(FromJson)

///|
struct PackTemplateRecovery {
  blocked : Bool
  reason : String
  next_action : String
} derive(FromJson)

///|
#warnings("-unused_field")
struct PackTemplateMigrationPolicy {
  strategy : String
  compatible_from : Array[String]
  note : String
} derive(FromJson)

///|
#warnings("-unused_field")
struct PackTemplateRecord {
  contract_id : String
  template_id : String
  owner_product : String
  version : String
  catalog_id : String
  catalog_version : String
  catalog_digest : String
  source_ref : String
  source_digest : String
  template_class : String
  maturity : String
  title : String
  summary : String
  primary_user : String
  primary_action : String
  completion_statement : String
  icon : String
  migration_policy : PackTemplateMigrationPolicy
  preview_ref : String
  qualification_evidence_refs : Array[Json]
  requirements : PackTemplateRequirements
  ceilings : PackTemplateCeilings
  recovery : PackTemplateRecovery
  owner_payload : Json
} derive(FromJson)

///|
#warnings("-unused_field")
struct PackAppRecord {
  pack_id : String
  version : String
  display_name : String
  description : String
  kind : String
  area_id : String?
  area_category : String?
  area_label : String?
  presentation_icon : String?
  presentation_surface : String?
  primary_action_label : String?
  launch_url : String
  status : String
  entrypoint_count : Int
  workflow_count : Int
  tool_count : Int
  configuration_message : String
  bridge_ready : Bool?
  intake_operation_ids : Array[String]?
  template_count : Int?
  templates : Array[PackTemplateRecord]?
} derive(FromJson)

///|
#warnings("-unused_field")
struct PackAppCatalog {
  app_count : Int
  configured_count : Int
  template_count : Int?
  apps : Array[PackAppRecord]
} derive(FromJson)

///|
struct AgentPassportRecord {
  contract_id : String
  agent_id : String
  workspace_id : String
  book_id : String
  name : String
  summary : String
  version : String
  status : String
  source_kind : String
  capabilities : Array[String]
  example_tasks : Array[String]
  knowledge_count : Int
  skill_count : Int
  schema_count : Int
  tool_count : Int
  app_count : Int
  recurring_work_count : Int
} derive(FromJson)

///|
struct AgentCatalog {
  agent_count : Int
  agents : Array[AgentPassportRecord]
} derive(FromJson)
