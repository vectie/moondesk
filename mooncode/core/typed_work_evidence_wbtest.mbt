///|
fn typed_wb_evidence(
  command_id : String,
  kind : MoonCodeEvidenceKind,
  state? : MoonCodeEvidenceState = Recorded,
  exit_code? : Int = -1,
) -> MoonCodeEvidence {
  {
    item_id: command_id + ":evidence",
    command_id,
    kind,
    state,
    title: "Evidence",
    detail: "",
    path: "",
    diff: "",
    command: "",
    output: "",
    exit_code,
    truncated: false,
    approval: None,
  }
}

///|
test "typed package review distinguishes stale, missing, failed, reject, readiness, and assistant proof" {
  let command = "package-command"
  let base = [
    typed_wb_evidence(command, PackageBuilt),
    typed_wb_evidence(command, Test, exit_code=0),
    typed_wb_evidence(command, ReviewAccept, state=Accepted),
    typed_wb_evidence(command, PackageVerified),
  ]
  assert_true(
    project_package_review_evidence("other", base, true).status
    is MoonCodePackageReviewStatus::Stale,
  )
  assert_true(
    project_package_review_evidence(command, base, false).status
    is WaitingForManifest,
  )
  let with_manifest = [typed_wb_evidence(command, PackageManifest)] + base
  assert_true(
    project_package_review_evidence(command, with_manifest, false).status
    is WaitingForAssistant,
  )
  assert_true(
    project_package_review_evidence(command, with_manifest[:4].to_array(), true).status
    is WaitingForReadiness,
  )
  assert_true(
    project_package_review_evidence(command, with_manifest, true).status
    is MoonCodePackageReviewStatus::Accepted,
  )
  let failed = base.map(item => {
    if item.kind is Test {
      { ..item, state: Failed, exit_code: 1 }
    } else {
      item
    }
  })
  assert_true(
    project_package_review_evidence(command, failed, true).status
    is MoonCodePackageReviewStatus::Failed,
  )
  let rejected = base.map(item => {
    if item.kind is ReviewAccept {
      { ..item, kind: ReviewReject, state: Rejected }
    } else {
      item
    }
  })
  assert_true(
    project_package_review_evidence(command, rejected, true).status
    is MoonCodePackageReviewStatus::Rejected,
  )
}

///|
test "real emitted package shape lacks manifest and other-command receipt stays stale proof" {
  let command = "package-command"
  let evidence = [
    typed_wb_evidence(command, PackageBuilt),
    typed_wb_evidence(command, Test, exit_code=0),
    typed_wb_evidence(command, PackageVerified),
    typed_wb_evidence("accept-command", ReviewAccept, state=Accepted),
  ]
  let review = project_package_review_evidence(command, evidence, true)
  assert_true(review.status is WaitingForManifest)
  assert_true(review.missing_proof.contains(PackageManifest))
  assert_true(review.missing_proof.contains(ReviewAccept))
  assert_eq(review.evidence.length(), 3)
  assert_true(
    project_package_review_evidence(command, evidence, true, work_failed=true).status
    is MoonCodePackageReviewStatus::Failed,
  )
}
