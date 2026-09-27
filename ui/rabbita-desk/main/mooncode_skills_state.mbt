///|
struct MoonCodeSkillProjection {
  name : String
  description : String
  source : String
  location : String
  authority : String
} derive(FromJson)

///|
struct MoonCodeSkillCatalogProjection {
  kind : String
  owner : String
  book_root : String
  skills : Array[MoonCodeSkillProjection]
  skill_count : Int
  content_included : Bool
} derive(FromJson)

///|
fn fetch_mooncode_skills_cmd(
  dispatch : Dispatch[Msg],
  workspace_id : String,
) -> @rabbita.Cmd {
  let url = @desk.desktop_api_url(["api", "mooncode", "skills", workspace_id])
  @http.get(url).expect_json(result => {
    let decoded : Result[MoonCodeSkillCatalogProjection, String] = match
      result {
      Ok(payload) =>
        Ok(@json.from_json(payload)) catch {
          _ => Err("Skill catalog response is unreadable")
        }
      Err(error) => Err(error.to_string())
    }
    dispatch(LoadedMoonCodeSkills(workspace_id, decoded))
  })
}
