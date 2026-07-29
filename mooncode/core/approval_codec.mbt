///|
/// An approval snapshot decoded from canonical conversation evidence.
pub(all) enum MoonCodeApproval {
  Pending(
    session_id~ : String,
    approval_id~ : String,
    target_command_id~ : String,
    tool_call_id~ : String,
    arguments~ : String
  )
  Approved(
    session_id~ : String,
    approval_id~ : String,
    target_command_id~ : String,
    tool_call_id~ : String,
    arguments~ : String
  )
  Rejected(
    session_id~ : String,
    approval_id~ : String,
    target_command_id~ : String,
    tool_call_id~ : String,
    arguments~ : String
  )
} derive(Debug, Eq)

///|
fn approval_required_string(
  fields : Map[String, Json],
  key : String,
) -> Result[String, MoonCodeFailure] {
  match fields.get(key) {
    Some(String(value)) if value != "" => Ok(value)
    Some(String(_)) => Err(Malformed("\{key} must not be empty"))
    Some(_) => Err(Malformed("\{key} must be a string"))
    None => Err(Malformed("\{key} is required"))
  }
}

///|
fn decode_mooncode_approval(
  payload : Json,
  session_id : String,
  turn_command_id : String,
) -> Result[MoonCodeApproval, MoonCodeFailure] {
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
  let approval = match approval_required_string(fields, "state") {
    Ok("pending") =>
      MoonCodeApproval::Pending(
        session_id~,
        approval_id~,
        target_command_id~,
        tool_call_id~,
        arguments~,
      )
    Ok("approved") =>
      MoonCodeApproval::Approved(
        session_id~,
        approval_id~,
        target_command_id~,
        tool_call_id~,
        arguments~,
      )
    Ok("rejected") =>
      MoonCodeApproval::Rejected(
        session_id~,
        approval_id~,
        target_command_id~,
        tool_call_id~,
        arguments~,
      )
    Ok(value) => return Err(Malformed("unsupported approval state: \{value}"))
    Err(error) => return Err(error)
  }
  Ok(approval)
}
