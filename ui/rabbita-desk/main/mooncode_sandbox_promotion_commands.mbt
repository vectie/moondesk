///|
fn mooncode_sandbox_promotion_request(
  receipt : @mooncode_core.MoonCodeSandboxReceipt,
  selected_paths : Array[String],
) -> Result[@mooncode_core.MoonCodeSandboxPromotionRequest, String] {
  guard receipt.promotion_ready() && receipt.retention_id is Some(retention_id) else {
    return Err("This sandbox receipt is not eligible for promotion")
  }
  let promotable = receipt.changes
    .filter(change => change.promotable)
    .map(change => change.relative_path)
  guard selected_paths.length() == 1 &&
    selected_paths.all(path => promotable.contains(path)) else {
    return Err("Select exactly one retained file from this exact receipt")
  }
  @mooncode_core.validate_mooncode_sandbox_promotion_request({
    retention_id,
    approval_digest: receipt.approval_digest,
    command_digest: receipt.command_digest,
    items: selected_paths.map(path => {
      source_relative: path,
      destination_relative: path,
    }),
  })
}

///|
fn mooncode_sandbox_promotion_cmd(
  dispatch : Dispatch[Msg],
  receipt : @mooncode_core.MoonCodeSandboxReceipt,
  selected_paths : Array[String],
) -> @rabbita.Cmd {
  let key = receipt.review_key()
  let request = match
    mooncode_sandbox_promotion_request(receipt, selected_paths) {
    Ok(value) => value
    Err(error) =>
      return dispatch(CompletedMoonCodeSandboxPromotion(key, Err(error)))
  }
  @http.post(@desk.mooncode_sandbox_promotion_url())
  .with_json(request.to_json())
  .expect_json(result => {
    let decoded = match result {
      Ok(payload) => {
        let response : @mooncode_core.MoonCodeSandboxPromotionResult = @json.from_json(
          payload,
        ) catch {
          _ =>
            return dispatch(
              CompletedMoonCodeSandboxPromotion(
                key,
                Err("MoonDesk returned an invalid promotion receipt"),
              ),
            )
        }
        @mooncode_core.validate_mooncode_sandbox_promotion_result(
          response, request,
        )
      }
      Err(error) => Err("Promotion was refused: \{error}")
    }
    dispatch(CompletedMoonCodeSandboxPromotion(key, decoded))
  })
}
