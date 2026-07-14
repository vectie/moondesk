///|
struct MoonCodeBrowserWatchEnvelope {
  ok : Bool
  aborted : Bool
  body : String
  error : String
} derive(FromJson)

///|
#cfg(target="js")
extern "js" fn browser_watch_mooncode_session(
  url : String,
  generation : Int,
  session_id : String,
) -> @js.Promise =
  #| async (url, generation, sessionId) => {
  #|   const previous = window.__moondeskMoonCodeWatch;
  #|   if (previous?.controller instanceof AbortController) {
  #|     previous.controller.abort();
  #|   }
  #|   const controller = new AbortController();
  #|   const state = { controller, generation, sessionId };
  #|   window.__moondeskMoonCodeWatch = state;
  #|   let timedOut = false;
  #|   const timeout = setTimeout(() => {
  #|     timedOut = true;
  #|     controller.abort();
  #|   }, 20000);
  #|   try {
  #|     const response = await fetch(url, {
  #|       method: 'GET',
  #|       headers: { accept: 'application/json' },
  #|       cache: 'no-store',
  #|       signal: controller.signal,
  #|     });
  #|     const body = await response.text();
  #|     return JSON.stringify({
  #|       ok: response.ok,
  #|       aborted: false,
  #|       body,
  #|       error: response.ok
  #|         ? ''
  #|         : `MoonCode watch failed with HTTP ${response.status}`,
  #|     });
  #|   } catch (error) {
  #|     const replaced = window.__moondeskMoonCodeWatch !== state;
  #|     const aborted = error?.name === 'AbortError' && replaced;
  #|     const message = aborted
  #|       ? 'MoonCode watch replaced'
  #|       : timedOut
  #|         ? 'MoonCode watch timed out'
  #|         : `MoonCode watch disconnected: ${String(error)}`;
  #|     return JSON.stringify({ ok: false, aborted, body: '', error: message });
  #|   } finally {
  #|     clearTimeout(timeout);
  #|     if (window.__moondeskMoonCodeWatch === state) {
  #|       delete window.__moondeskMoonCodeWatch;
  #|     }
  #|   }
  #| }

///|
#cfg(target="js")
extern "js" fn browser_stop_mooncode_watch() =
  #| () => {
  #|   const current = window.__moondeskMoonCodeWatch;
  #|   if (current?.controller instanceof AbortController) {
  #|     delete window.__moondeskMoonCodeWatch;
  #|     current.controller.abort();
  #|   }
  #| }

///|
fn mooncode_watch_cmd(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Cmd {
  let session_id = model.selected_mooncode_session_id
  if model.workspace_mode != MoonCode || session_id == "" {
    return @rabbita.none
  }
  let revision = model.mooncode_watch_revision
  let generation = model.mooncode_watch_generation
  let sequence = model.mooncode_watch_sequence
  let url = @desk.mooncode_session_watch_url(session_id, revision, sequence)
  @rabbita.perform(
    fn(result) { dispatch(LoadedMoonCodeWatch(generation, session_id, result)) },
    async fn() noraise {
      let text : String = browser_watch_mooncode_session(
          url, generation, session_id,
        )
        .wait()
        .cast() catch {
          error => return Err("MoonCode watch failed: \{error}")
        }
      let envelope : MoonCodeBrowserWatchEnvelope = @json.from_json(
        @json.parse(text),
      ) catch {
        error => return Err("Invalid MoonCode watch transport: \{error}")
      }
      if envelope.aborted {
        return Err("MoonCode watch replaced")
      }
      if !envelope.ok {
        return Err(envelope.error)
      }
      let response : MoonCodeWatchResponse = @json.from_json(
        @json.parse(envelope.body),
      ) catch {
        error => return Err("Invalid MoonCode watch response: \{error}")
      }
      Ok(response)
    },
  )
}

///|
fn stop_mooncode_watch_cmd() -> @rabbita.Cmd {
  @cmd.custom_cmd(_ => browser_stop_mooncode_watch(), kind=AfterRender)
}

///|
fn schedule_mooncode_watch_resume(
  dispatch : Dispatch[Msg],
  generation : Int,
  session_id : String,
  after_ms : Int,
) -> @rabbita.Cmd {
  @rabbita.delay(
    dispatch(ResumeMoonCodeWatch(generation, session_id)),
    if after_ms < 100 {
      100
    } else {
      after_ms
    },
  )
}
