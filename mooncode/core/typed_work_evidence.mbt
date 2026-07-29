///|
priv enum EvidenceKind {
  Edit
  Test
  PackageManifest
  ReviewAccept
  ReviewReject
  PackageBuilt
  PackageVerified
  Artifact
  AssistantSummary
  Approval
  Tool
} derive(Debug, Eq)

///|
priv enum EvidenceState {
  Recorded
  Applied
  Passed
  Reverted
  Cancelled
  Pending
  Approved
  Accepted
  Rejected
  Failed
  Stale
} derive(Debug, Eq)

///|
priv enum WorkStatus {
  Queued
  Running
  Done
  Failed
  Cancelled
} derive(Debug, Eq)

///|
pub(all) struct MoonCodeEvidence {
  item_id : String
  command_id : String
  kind : String
  state : String
  title : String
  detail : String
  path : String
  diff : String
  command : String
  output : String
  exit_code : Int
  truncated : Bool
  approval : MoonCodeApproval?
} derive(Debug, Eq)

///|
pub(all) struct MoonCodeWork {
  item_id : String
  status : String
  summary : String
  detail : String
  evidence : Array[MoonCodeEvidence]
  priv raw : Json
} derive(Debug, Eq)

///|
priv struct MoonCodeWorkCodec {
  value : MoonCodeWork
} derive(Debug, Eq)

///|
fn work_string(
  fields : Map[String, Json],
  key : String,
  default : String,
) -> String {
  match fields.get(key) {
    Some(String(value)) => value
    _ => default
  }
}

///|
fn work_int(fields : Map[String, Json], key : String, default : Int) -> Int {
  match fields.get(key) {
    Some(Number(value, ..)) => value.to_int()
    _ => default
  }
}

///|
fn work_bool(fields : Map[String, Json], key : String, default : Bool) -> Bool {
  match fields.get(key) {
    Some(True) => true
    Some(False) => false
    _ => default
  }
}

///|
fn work_status(value : String) -> WorkStatus {
  match value {
    "running" => Running
    "done" => Done
    "failed" => Failed
    "cancelled" => Cancelled
    _ => Queued
  }
}

///|
fn WorkStatus::canonical(self : WorkStatus) -> String {
  match self {
    Queued => "queued"
    Running => "running"
    Done => "done"
    Failed => "failed"
    Cancelled => "cancelled"
  }
}

///|
fn EvidenceKind::canonical(self : EvidenceKind) -> String {
  match self {
    Edit => "edit"
    Test => "test"
    PackageManifest => "package_manifest"
    ReviewAccept => "review_accept"
    ReviewReject => "review_reject"
    PackageBuilt => "package_built"
    PackageVerified => "package_verified"
    Artifact => "artifact"
    AssistantSummary => "assistant_summary"
    Approval => "approval"
    Tool => "tool"
  }
}

///|
fn EvidenceState::canonical(self : EvidenceState) -> String {
  match self {
    Recorded => "recorded"
    Applied => "applied"
    Passed => "passed"
    Reverted => "reverted"
    Cancelled => "cancelled"
    Pending => "pending"
    Approved => "approved"
    Accepted => "accepted"
    Rejected => "rejected"
    Failed => "failed"
    Stale => "stale"
  }
}

///|
fn evidence_kind(source_kind : String, raw_kind : String) -> EvidenceKind? {
  match source_kind {
    "package_manifest" | "package_index" => Some(PackageManifest)
    "receipt.accept" => Some(ReviewAccept)
    "receipt.reject" => Some(ReviewReject)
    "package_built" | "runtime.package_built" => Some(PackageBuilt)
    "package_verified" | "runtime.package_verified" => Some(PackageVerified)
    "assistant" | "finish" => Some(AssistantSummary)
    "test_result" => Some(Test)
    _ =>
      match raw_kind {
        "edit" => Some(Edit)
        "test" => Some(Test)
        "artifact" => Some(Artifact)
        "approval" => Some(Approval)
        "tool" => Some(Tool)
        _ => None
      }
  }
}

///|
fn evidence_state(
  value : String,
  kind : EvidenceKind,
  exit_code : Int,
) -> Result[EvidenceState, String] {
  if exit_code > 0 {
    return Ok(Failed)
  }
  match value {
    "applied" => Ok(Applied)
    "passed" => Ok(Passed)
    "reverted" => Ok(Reverted)
    "cancelled" => Ok(Cancelled)
    "pending" => Ok(Pending)
    "accepted" => Ok(Accepted)
    "approved" => Ok(Approved)
    "recorded" => Ok(Recorded)
    "rejected" => Ok(Rejected)
    "failed" => Ok(Failed)
    "stale" => Ok(Stale)
    "" =>
      Ok(
        match kind {
          ReviewAccept => Accepted
          ReviewReject => Rejected
          _ => Recorded
        },
      )
    other => Err("unsupported MoonCode evidence state: \{other}")
  }
}

///|
fn decode_work_codec(
  value : Json,
  session_id : String,
  turn_command_id : String,
) -> Result[MoonCodeWorkCodec, String] {
  guard value is Object(fields) else {
    return Err("conversation turn work must be an object")
  }
  let rows : Array[MoonCodeEvidence] = []
  let lines : Array[String] = []
  match fields.get("steps") {
    Some(Array(steps)) =>
      for step in steps {
        guard step is Object(step_fields) else { continue }
        let summary = work_string(step_fields, "summary", "").trim().to_owned()
        if summary != "" && !lines.contains(summary) {
          lines.push(summary)
        }
        let source_kind = work_string(step_fields, "source_kind", "")
        let command_id = work_string(step_fields, "command_id", "")
        guard step_fields.get("evidence") is Some(Object(evidence_fields)) else {
          continue
        }
        let raw_kind = work_string(evidence_fields, "kind", "")
        guard evidence_kind(source_kind, raw_kind) is Some(kind) else {
          continue
        }
        let exit_code = work_int(evidence_fields, "exit_code", -1)
        let approval = if kind is Approval {
          match
            decode_mooncode_approval(
              Json::object(evidence_fields),
              session_id,
              turn_command_id,
            ) {
            Ok(item) => Some(item)
            Err(Malformed(message)) => return Err(message)
            Err(_) => return Err("approval evidence is invalid")
          }
        } else {
          None
        }
        let state = match
          evidence_state(
            work_string(evidence_fields, "state", ""),
            kind,
            exit_code,
          ) {
          Ok(value) => value
          Err(message) => return Err(message)
        }
        rows.push({
          item_id: work_string(step_fields, "item_id", ""),
          command_id,
          kind: kind.canonical(),
          state: state.canonical(),
          title: work_string(
            step_fields,
            "title",
            if approval is Some(_) {
              "Approval"
            } else {
              "Work evidence"
            },
          ),
          detail: summary,
          path: work_string(evidence_fields, "path", ""),
          diff: work_string(evidence_fields, "diff", ""),
          command: work_string(evidence_fields, "command", ""),
          output: work_string(evidence_fields, "output", ""),
          exit_code,
          truncated: work_bool(evidence_fields, "truncated", false),
          approval,
        })
      }
    Some(_) => return Err("conversation work steps must be an array")
    None => ()
  }
  match fields.get("live") {
    Some(Object(live)) => {
      let summary = work_string(live, "summary", "").trim().to_owned()
      if summary != "" && !lines.contains(summary) {
        lines.push(summary)
      }
    }
    Some(_) => return Err("conversation work live must be an object")
    None => ()
  }
  Ok({
    value: {
      item_id: work_string(fields, "item_id", ""),
      status: work_status(work_string(fields, "status", "queued")).canonical(),
      summary: work_string(fields, "summary", "").trim().to_owned(),
      detail: lines.join("\n"),
      evidence: rows,
      raw: value,
    },
  })
}

///|
fn encode_mooncode_work(work : MoonCodeWork) -> Json {
  work.raw
}

///|
priv enum MoonCodePackageReviewStatus {
  WaitingForManifest
  WaitingForReview
  WaitingForTests
  WaitingForReadiness
  WaitingForAssistant
  Accepted
  Rejected
  Failed
  Stale
} derive(Debug, Eq)

///|
priv struct MoonCodePackageReview {
  command_id : String
  status : MoonCodePackageReviewStatus
  missing_proof : Array[EvidenceKind]
  failed_proof : MoonCodeEvidence?
  evidence : Array[MoonCodeEvidence]
} derive(Debug, Eq)

///|
fn project_package_review_evidence(
  command_id : String,
  evidence : Array[MoonCodeEvidence],
  assistant_present : Bool,
  work_failed? : Bool = false,
) -> MoonCodePackageReview {
  let owned = evidence.filter(item => {
    command_id != "" && item.command_id == command_id
  })
  let mut failed : MoonCodeEvidence? = None
  for item in owned {
    if failed is None && (item.state == "failed" || item.exit_code > 0) {
      failed = Some(item)
    }
  }
  let rejected = owned.any(item => item.kind == ReviewReject.canonical())
  let manifest = owned.any(item => item.kind == PackageManifest.canonical())
  let tested = owned.any(item => {
    item.kind == Test.canonical() &&
    item.state != "failed" &&
    item.exit_code == 0
  })
  let accepted = owned.any(item => item.kind == ReviewAccept.canonical())
  let verified = owned.any(item => item.kind == PackageVerified.canonical())
  let assistant = assistant_present ||
    owned.any(item => item.kind == AssistantSummary.canonical())
  let missing : Array[EvidenceKind] = []
  if !manifest {
    missing.push(PackageManifest)
  }
  if !tested {
    missing.push(Test)
  }
  if !accepted && !rejected {
    missing.push(ReviewAccept)
  }
  if !verified {
    missing.push(PackageVerified)
  }
  if !assistant {
    missing.push(AssistantSummary)
  }
  let status = if command_id == "" ||
    (evidence.length() > 0 && owned.length() == 0) {
    MoonCodePackageReviewStatus::Stale
  } else if work_failed || failed is Some(_) {
    Failed
  } else if rejected {
    Rejected
  } else if !manifest {
    WaitingForManifest
  } else if !tested {
    WaitingForTests
  } else if !accepted {
    WaitingForReview
  } else if !verified {
    WaitingForReadiness
  } else if !assistant {
    WaitingForAssistant
  } else {
    Accepted
  }
  {
    command_id,
    status,
    missing_proof: missing,
    failed_proof: failed,
    evidence: owned,
  }
}

///|
fn project_package_review(turn : MoonCodeTurn) -> MoonCodePackageReview {
  let assistant_present = match turn.assistant {
    Some(message) => message.content.trim() != ""
    None => false
  }
  project_package_review_evidence(
    turn.command_id,
    turn.work.evidence,
    assistant_present,
    work_failed=turn.work.status == "failed",
  )
}
