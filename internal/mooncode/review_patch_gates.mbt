///|
// MoonCode patch review gate guidance shared by patch and hunk projections.

///|
fn patch_review_gate_status(
  review_state : String,
  execution_state : String,
  runtime_proof_count : Int,
) -> String {
  if review_state == "partial" || execution_state == "partial" {
    "partial"
  } else if review_state == "rejected" {
    "blocked"
  } else if execution_state == "applied" || execution_state == "reverted" {
    "runtime-proven"
  } else if review_state == "applied" ||
    review_state == "reverted" ||
    (runtime_proof_count == 0 && review_state == "accepted") {
    "runtime-needed"
  } else if review_state == "pending" {
    "needs-review"
  } else {
    "ready"
  }
}

///|
fn patch_review_next_action(
  review_state : String,
  execution_state : String,
  runtime_proof_count : Int,
) -> String {
  if review_state == "partial" || execution_state == "partial" {
    "review-or-apply-remaining"
  } else if review_state == "rejected" {
    "none"
  } else if execution_state == "applied" {
    "run_tests"
  } else if execution_state == "reverted" {
    "review"
  } else if review_state == "pending" {
    "accept-or-reject"
  } else if review_state == "accepted" {
    "apply_patch"
  } else if review_state == "applied" || review_state == "reverted" {
    if runtime_proof_count > 0 {
      "run_tests"
    } else {
      "await-runtime-proof"
    }
  } else {
    "review"
  }
}

///|
fn patch_review_blocked_reason(
  review_state : String,
  execution_state : String,
  runtime_proof_count : Int,
) -> String {
  if review_state == "partial" || execution_state == "partial" {
    "Only some hunks for this patch target have review or runtime proof; finish the remaining hunk-level decisions before package or commit."
  } else if review_state == "rejected" {
    "Operator rejected this patch target; accept it again before applying or packaging."
  } else if execution_state == "applied" {
    "Runtime applied this patch target; run tests before package or commit."
  } else if execution_state == "reverted" {
    "Runtime reverted this patch target; review the diff before applying again."
  } else if review_state == "applied" || review_state == "reverted" {
    if runtime_proof_count > 0 {
      "Runtime proof is present; run tests before package or commit."
    } else {
      "Operator requested patch execution; MoonClaw or standalone MoonCode must emit runtime proof."
    }
  } else if review_state == "accepted" {
    "Accepted by operator and ready for MoonClaw or standalone MoonCode to apply."
  } else {
    ""
  }
}
