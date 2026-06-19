///|
struct MoonCodeBoundary {
} derive(FromJson)

///|
struct MoonCodeWorkspaceModeInfo {
} derive(FromJson)

///|
struct MoonCodeSessionProtocol {
  transport_target : String
  preferred_stream : String
  stream_endpoint : String
  stream_state_endpoint : String
  runtime_event_ingest_endpoint : String
  command_queue_endpoint : String
  runtime_claim_endpoint : String
  runtime_replay_endpoint : String
  action_plan_endpoint : String
  native_runtime_loop_options : Json
  commands : Array[String]
} derive(FromJson)

///|
struct MoonCodeToolSpec {
  id : String
  owner : String
  lane : String
  approval : String
  purpose : String
  outputs : Array[String]
} derive(FromJson)

///|
struct MoonCodeCommandSpec {
  action : String
  dispatch : String
  approval : String
  expected_lanes : Array[String]
  tool_hints : Array[String]
} derive(FromJson)

///|
struct MoonCodeRuntimeComponent {
  id : String
  owner : String
  reference : String
  purpose : String
  moondesk_role : String
} derive(FromJson)

///|
struct MoonCodeNamespaceRole {
  id : String
  name : String
  responsibility : String
} derive(FromJson)

///|
struct MoonCodeCommandCommand {
  command : String
  required_fields : Array[String]
} derive(FromJson)

///|
struct MoonCodeCommandProtocol {
  transport : String
  input_commands : Array[MoonCodeCommandCommand]
  output_events : Array[String]
  ordering_rule : String
} derive(FromJson)

///|
struct MoonCodeSessionStoreContract {
  owner : String
  shape : String
  resume_modes : Array[String]
  moondesk_projection : String
} derive(FromJson)

///|
struct MoonCodeEvalContract {
  required_harnesses : Array[String]
  harness_contract_endpoint : String
  reference_paths : Array[String]
  minimum_evidence : Array[String]
  native_eval_report : MoonCodeNativeEvalReportContract
  current_gap : String
} derive(FromJson)

///|
struct MoonCodeNativeEvalReportContract {
  owner : String
  endpoint : String
  transport : String
  status_values : Array[String]
  normalization_rule : String
} derive(FromJson)

///|
struct MoonCodeToolRuntimeContract {
  id : String
  lane : String
  approval : String
  input_fields : Array[Json]
  output_events : Array[String]
  mutates_files : Bool
  requires_review : Bool
  executable_boundary : String
  safety_policy : String
} derive(FromJson)

///|
struct MoonCodeToolContractConstraints {
  path_rule : String
  diff_rule : String
  test_rule : String
  approval_rule : String
  extraction_rule : String
} derive(FromJson)

///|
struct MoonCodeToolContract {
  execution_owner : String
  approval_owner : String
  artifact_owner : String
  supported_tools : Array[String]
  tools : Array[MoonCodeToolRuntimeContract]
  constraints : MoonCodeToolContractConstraints
} derive(FromJson)

///|
struct MoonCodeToolCallCommandContract {
  protocol : String
  owner : String
  runtime_owner : String
  reference : String
  accepted_shapes : Array[String]
  supported_tools : Array[String]
  argument_rule : String
  unknown_tool_policy : String
} derive(FromJson)

///|
struct MoonCodeRuntimeContract {
  reference : String
  target_component : String
  standalone_component : String
  namespace_roles : Array[MoonCodeNamespaceRole]
  status : String
  components : Array[MoonCodeRuntimeComponent]
  command_protocol : MoonCodeCommandProtocol
  session_store : MoonCodeSessionStoreContract
  tool_contract : MoonCodeToolContract
  eval_contract : MoonCodeEvalContract
} derive(FromJson)

///|
struct MoonCodeEngineCheck {
  label : String
  status : String
  evidence : String
} derive(FromJson)

///|
struct MoonCodeEngineStatus {
  ok : Bool
  status : String
  runtime_mode : String
  native_runtime_ready : Bool
  runtime_status : String
  moonclaw_root : String
  message : String
  supported_endpoints : Array[String]
  checks : Array[MoonCodeEngineCheck]
} derive(FromJson)

///|
struct MoonCodeStandalone {
  future_package : String
  core_package : String
  projection_package : String
  host_package : String
} derive(FromJson)

///|
struct MoonCodeStandaloneRole {
  id : String
  package_path : String
  owner : String
  responsibility : String
} derive(FromJson)

///|
struct MoonCodeStandaloneBoundary {
  protocol : String
  core_package : String
  moondesk_projection_package : String
  moonwiki_host_package : String
  runtime_package : String
  roles : Array[MoonCodeStandaloneRole]
  rules : Array[String]
} derive(FromJson)

///|
struct MoonCodeCapabilities {
  component : String
  version : Int
  session_protocol : MoonCodeSessionProtocol
  runtime_contract : MoonCodeRuntimeContract
  tool_call_contract : MoonCodeToolCallCommandContract
  standalone_boundary : MoonCodeStandaloneBoundary
  engine_status : MoonCodeEngineStatus
  command_specs : Array[MoonCodeCommandSpec]
  tool_specs : Array[MoonCodeToolSpec]
  book_outputs : Array[String]
  standalone : MoonCodeStandalone
} derive(FromJson)
