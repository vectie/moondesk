///|
struct GitHubCheckoutProjection {
  contract : String
  repository : String
  number : Int
  head_oid : String
  workspace : @desk.DeskWorkspace
} derive(FromJson)

///|
fn github_checkout_head_valid(head : String) -> Bool {
  head.length() == 40 &&
  head
  .to_array()
  .all(char => (char >= '0' && char <= '9') || (char >= 'a' && char <= 'f'))
}

///|
fn checkout_github_pull_cmd(
  dispatch : Dispatch[Msg],
  workspace_id : String,
  repository : String,
  number : Int,
  head_oid : String,
) -> @rabbita.Cmd {
  let url = @desk.desktop_api_url([
    "api", "workspaces", workspace_id, "git", "github", "checkout",
  ])
  let body : Json = {
    "repository": repository,
    "number": number,
    "head_oid": head_oid,
  }
  @http.post(url)
  .with_json(body)
  .expect_json(result => {
    let decoded : Result[GitHubCheckoutProjection, String] = match result {
      Ok(payload) =>
        Ok(@json.from_json(payload)) catch {
          _ => Err("PR checkout response is unreadable")
        }
      Err(error) => Err(error.to_string())
    }
    dispatch(CheckedOutGitHubPull(workspace_id, number, head_oid, decoded))
  })
}
