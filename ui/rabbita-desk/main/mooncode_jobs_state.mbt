///|
struct MoonCodeJobRun {
  run_id : String
  service_id : String
  status : String
  started_at : String
  finished_at : String
  ran_turn_count : Int
  failed_turn_count : Int
  stopped_by : String
  detail : String
} derive(FromJson)

///|
struct MoonCodeJobHistory {
  kind : String
  owner : String
  session_id : String
  job_count : Int
  truncated : Bool
  jobs : Array[MoonCodeJobRun]
} derive(FromJson)

///|
fn mooncode_job_history_valid(history : MoonCodeJobHistory) -> Bool {
  history.kind == "mooncode-job-history.v1" &&
  history.owner == "moonclaw" &&
  history.session_id != "" &&
  history.job_count >= history.jobs.length() &&
  history.jobs.length() <= 50 &&
  (history.truncated || history.job_count == history.jobs.length()) &&
  (!history.truncated || history.job_count > history.jobs.length()) &&
  history.jobs.all(job => job.run_id != "" && job.status != "")
}

///|
fn fetch_mooncode_jobs_cmd(
  dispatch : Dispatch[Msg],
  session_id : String,
) -> @rabbita.Cmd {
  let url = @desk.desktop_api_url([
    "api", "mooncode", "sessions", session_id, "jobs",
  ])
  @http.get(url).expect_json(result => {
    let decoded : Result[MoonCodeJobHistory, String] = match result {
      Ok(payload) =>
        Ok(@json.from_json(payload)) catch {
          _ => Err("Job history response is unreadable")
        }
      Err(error) => Err(error.to_string())
    }
    dispatch(LoadedMoonCodeJobs(session_id, decoded))
  })
}
