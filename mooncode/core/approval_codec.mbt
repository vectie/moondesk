///|
pub(all) enum MoonCodeApprovalState {
  Pending
  Approved
  Rejected
} derive(Debug, Eq)

///|
pub(all) enum MoonCodeApprovalDecision {
  Approve
  Reject
} derive(Debug, Eq)

///|
/// A runtime-owned approval snapshot decoded from canonical conversation
/// evidence. Its identity cannot be fabricated outside this package.
pub struct MoonCodeApproval {
  session_id : String
  approval_id : String
  target_command_id : String
  tool_call_id : String
  arguments : String
  state : MoonCodeApprovalState
} derive(Debug, Eq)

///|
pub enum MoonCodeApprovalDecodeFailure {
  Malformed(String)
  UnsupportedState(String)
} derive(Debug, Eq)

///|
pub enum MoonCodeApprovalDecisionFailure {
  Stale
  WrongSessionOwnership(expected~ : String, actual~ : String)
} derive(Debug, Eq)

///|
fn approval_decision_string(decision : MoonCodeApprovalDecision) -> String {
  match decision {
    Approve => "approve_tool"
    Reject => "reject_tool"
  }
}

///|
pub fn MoonCodeApproval::approval_id(self : MoonCodeApproval) -> String {
  self.approval_id
}

///|
pub fn MoonCodeApproval::state(
  self : MoonCodeApproval,
) -> MoonCodeApprovalState {
  self.state
}

///|
pub fn MoonCodeApproval::arguments(self : MoonCodeApproval) -> String {
  self.arguments
}

///|
fn approval_required_string(
  fields : Map[String, Json],
  key : String,
) -> Result[String, MoonCodeApprovalDecodeFailure] {
  match fields.get(key) {
    Some(String(value)) if value != "" => Ok(value)
    Some(String(_)) => Err(Malformed("\{key} must not be empty"))
    Some(_) => Err(Malformed("\{key} must be a string"))
    None => Err(Malformed("\{key} is required"))
  }
}

///|
fn approval_state(
  fields : Map[String, Json],
) -> Result[MoonCodeApprovalState, MoonCodeApprovalDecodeFailure] {
  let raw = match approval_required_string(fields, "state") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  match raw {
    "pending" => Ok(Pending)
    "approved" => Ok(Approved)
    "rejected" => Ok(Rejected)
    value => Err(UnsupportedState(value))
  }
}

///|
pub fn decode_mooncode_approval(
  payload : Json,
  session_id : String,
  turn_command_id : String,
) -> Result[MoonCodeApproval, MoonCodeApprovalDecodeFailure] {
  guard payload is Object(fields) else {
    return Err(Malformed("approval evidence must be an object"))
  }
  match fields.get("kind") {
    Some(String("approval")) => ()
    Some(String(value)) =>
      return Err(Malformed("unsupported evidence kind: \{value}"))
    Some(_) => return Err(Malformed("kind must be a string"))
    None => return Err(Malformed("kind is required"))
  }
  let approval_id = match approval_required_string(fields, "approval_id") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let target_command_id = match
    approval_required_string(fields, "target_command_id") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if target_command_id != turn_command_id {
    return Err(Malformed("target_command_id does not own the enclosing turn"))
  }
  let tool_call_id = match approval_required_string(fields, "tool_call_id") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let arguments = match approval_required_string(fields, "arguments") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let state = match approval_state(fields) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  Ok({
    session_id,
    approval_id,
    target_command_id,
    tool_call_id,
    arguments,
    state,
  })
}

///|
/// Encode the existing operator command wire from a current runtime snapshot.
/// Endpoint/session context is checked locally and is never encoded.
pub fn MoonCodeApproval::decision_wire(
  self : MoonCodeApproval,
  decision : MoonCodeApprovalDecision,
  endpoint_session_id : String,
) -> Result[Json, MoonCodeApprovalDecisionFailure] {
  if !(self.state is Pending) {
    Err(Stale)
  } else if self.session_id != endpoint_session_id {
    Err(
      WrongSessionOwnership(
        expected=self.session_id,
        actual=endpoint_session_id,
      ),
    )
  } else {
    Ok({
      "action": approval_decision_string(decision),
      "approval_id": self.approval_id,
      "target_command_id": self.target_command_id,
      "tool_call_id": self.tool_call_id,
    })
  }
}
