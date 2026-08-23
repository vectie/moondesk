///|
pub(all) struct MoonCodeSandboxPromotionItem {
  source_relative : String
  destination_relative : String
} derive(Debug, Eq, ToJson, @json.FromJson)

///|
/// Browser-to-MoonDesk request. The private instance/workspace identity and
/// authentication token are never present in browser state.
pub(all) struct MoonCodeSandboxPromotionRequest {
  retention_id : String
  approval_digest : String
  command_digest : String
  items : Array[MoonCodeSandboxPromotionItem]
} derive(Debug, Eq, ToJson, @json.FromJson)

///|
pub(all) struct MoonCodeSandboxPromotionResult {
  completed : Bool
  retention_id : String
  approval_digest : String
  command_digest : String
  promoted_paths : Array[String]
  destination_outcome : String
  uncertain_paths : Array[String]
  recovery_required : Bool
  error_code : String
} derive(Debug, Eq, ToJson, @json.FromJson)

///|
pub fn MoonCodeSandboxPromotionResult::locks_receipt(
  self : MoonCodeSandboxPromotionResult,
) -> Bool {
  self.destination_outcome != "not-applied" || self.recovery_required
}

///|
pub fn validate_mooncode_sandbox_promotion_request(
  request : MoonCodeSandboxPromotionRequest,
) -> Result[MoonCodeSandboxPromotionRequest, String] {
  guard sandbox_evidence_opaque_id(request.retention_id) &&
    sandbox_evidence_digest(request.approval_digest) &&
    sandbox_evidence_digest(request.command_digest) &&
    request.items.length() == 1 else {
    return Err("sandbox promotion binding is invalid")
  }
  let sources : Array[String] = []
  let destinations : Array[String] = []
  for item in request.items {
    guard mooncode_sandbox_relative_path(item.source_relative) &&
      mooncode_sandbox_relative_path(item.destination_relative) &&
      !sources.contains(item.source_relative) &&
      !destinations.contains(item.destination_relative) else {
      return Err("sandbox promotion paths are unsafe or duplicated")
    }
    sources.push(item.source_relative)
    destinations.push(item.destination_relative)
  }
  Ok(request)
}

///|
pub fn validate_mooncode_sandbox_promotion_result(
  result : MoonCodeSandboxPromotionResult,
  request : MoonCodeSandboxPromotionRequest,
) -> Result[MoonCodeSandboxPromotionResult, String] {
  guard validate_mooncode_sandbox_promotion_request(request) is Ok(_) else {
    return Err("sandbox promotion response did not match the reviewed request")
  }
  let expected = request.items.map(item => item.destination_relative)
  let outcome_valid = match result.destination_outcome {
    "applied-durable" =>
      result.promoted_paths == expected &&
      result.uncertain_paths.is_empty() &&
      !result.recovery_required &&
      (if result.completed {
        result.error_code == ""
      } else {
        result.error_code == "promotion-cleanup-unverified"
      })
    "not-applied" =>
      !result.completed &&
      result.promoted_paths.is_empty() &&
      result.uncertain_paths.is_empty() &&
      (if result.recovery_required {
        result.error_code == "promotion-recovery-required"
      } else {
        result.error_code == "promotion-refused"
      })
    "recovery-required" =>
      !result.completed &&
      result.promoted_paths.is_empty() &&
      result.uncertain_paths == expected &&
      result.recovery_required &&
      result.error_code == "promotion-recovery-required"
    _ => false
  }
  guard result.retention_id == request.retention_id &&
    result.approval_digest == request.approval_digest &&
    result.command_digest == request.command_digest &&
    result.promoted_paths.all(mooncode_sandbox_relative_path) &&
    result.uncertain_paths.all(mooncode_sandbox_relative_path) &&
    outcome_valid else {
    return Err("sandbox promotion response did not match the reviewed request")
  }
  Ok(result)
}
