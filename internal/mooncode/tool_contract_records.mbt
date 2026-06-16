///|
fn tool_contract_entry(
  id~ : String,
  lane~ : String,
  approval~ : String,
  mutates_files~ : Bool,
  requires_review~ : Bool,
  input_fields~ : Array[Json],
  output_events~ : Array[String],
  safety_policy~ : String,
) -> Json {
  {
    "id": id,
    "owner": "moonclaw",
    "lane": lane,
    "approval": approval,
    "input_fields": Json::array(input_fields),
    "output_events": string_array_json(output_events),
    "mutates_files": mutates_files,
    "requires_review": requires_review,
    "executable_boundary": "MoonClaw executes; Moondesk renders and records review intent; MoonBook stores accepted artifacts.",
    "safety_policy": safety_policy,
  }
}

///|
fn tool_field(
  name : String,
  type_ : String,
  required~ : Bool,
  description : String,
) -> Json {
  {
    "name": name,
    "type": type_,
    "required": required,
    "description": description,
  }
}
