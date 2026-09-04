///|
/// The native host owns the MoonClaw credential. The browser sees only this
/// same-origin SSE proxy and keeps a small bounded queue for Rabbita polling.
#cfg(target="js")
extern "js" fn browser_start_wiki_chat_stream(
  url : String,
  task_id : String,
  initial_cursor : String,
) =
  #| (url, taskId, initialCursor) => {
  #|   const previous = window.__moondeskWikiChatStream;
  #|   if (previous?.source instanceof EventSource) previous.source.close();
  #|   const MAX_QUEUED_EVENTS = 512;
  #|   const MAX_RECONNECT_ATTEMPTS = 8;
  #|   const baseUrl = String(url).split('?')[0];
  #|   const state = { source: null, taskId, cursor: initialCursor || 'start', events: [], error: '', reconnects: 0, reconnectTimer: 0 };
  #|   window.__moondeskWikiChatStream = state;
  #|   const push = (event) => {
  #|     if (window.__moondeskWikiChatStream !== state) return;
  #|     try {
  #|       const value = JSON.parse(String(event.data || ''));
  #|       const cursor = String(event.lastEventId || value.cursor || '');
  #|       if (cursor) state.cursor = cursor;
  #|       state.events.push(value);
  #|       if (state.events.length > MAX_QUEUED_EVENTS && state.source instanceof EventSource) {
  #|         state.source.close();
  #|         state.source = null;
  #|         if (!state.reconnectTimer) state.reconnectTimer = window.setTimeout(connect, 250);
  #|       }
  #|     } catch (_) {
  #|       state.error = 'MoonClaw returned an invalid event';
  #|     }
  #|   };
  #|   const connect = () => {
  #|     if (window.__moondeskWikiChatStream !== state || state.error) return;
  #|     state.reconnectTimer = 0;
  #|     const source = new EventSource(baseUrl + '?cursor=' + encodeURIComponent(state.cursor), { withCredentials: false });
  #|     state.source = source;
  #|     source.addEventListener('moonclaw-task-stream.v2', push);
  #|     source.onopen = () => { state.reconnects = 0; };
  #|     source.onerror = () => {
  #|       if (window.__moondeskWikiChatStream !== state) return;
  #|       source.close();
  #|       if (state.source === source) state.source = null;
  #|       state.reconnects += 1;
  #|       if (state.reconnects > MAX_RECONNECT_ATTEMPTS) {
  #|         state.error = 'MoonClaw task stream disconnected';
  #|         return;
  #|       }
  #|       const delay = Math.min(2000, 100 * (2 ** Math.min(state.reconnects, 4)));
  #|       state.reconnectTimer = window.setTimeout(connect, delay);
  #|     };
  #|   };
  #|   connect();
  #| }

///|
#cfg(target="js")
extern "js" fn browser_take_wiki_chat_events(task_id : String) -> String =
  #| (taskId) => {
  #|   const state = window.__moondeskWikiChatStream;
  #|   if (!state || state.taskId !== taskId) return JSON.stringify({ events: [], cursor: 'start', error: '' });
  #|   const events = state.events.splice(0, state.events.length);
  #|   if (!state.source && !state.error && !state.reconnectTimer) {
  #|     state.reconnects = 0;
  #|   }
  #|   return JSON.stringify({ events, cursor: state.cursor || 'start', error: state.error || '' });
  #| }

///|
#cfg(target="js")
extern "js" fn browser_stop_wiki_chat_stream() =
  #| () => {
  #|   const state = window.__moondeskWikiChatStream;
  #|   if (state?.source instanceof EventSource) state.source.close();
  #|   if (state?.reconnectTimer) window.clearTimeout(state.reconnectTimer);
  #|   if (state) delete window.__moondeskWikiChatStream;
  #| }

///|
struct WikiChatStreamEnvelope {
  events : Array[Json]
  cursor : String
  error : String
} derive(FromJson)

///|
const WikiChatStreamStartPollDelayMs : Int = 100

///|
const WikiChatStreamPollDelayMs : Int = 200

///|
fn start_wiki_chat_stream_cmd(
  dispatch : Dispatch[Msg],
  task_id : String,
  cursor : String,
) -> @rabbita.Cmd {
  let url = @desk.moonclaw_task_events_url(task_id, cursor="")
  @rabbita.batch([
    @cmd.custom_cmd(
      _ => browser_start_wiki_chat_stream(url, task_id, cursor),
      kind=AfterRender,
    ),
    @rabbita.delay(
      dispatch(PollWikiChatStream(task_id)),
      WikiChatStreamStartPollDelayMs,
    ),
  ])
}

///|
fn poll_wiki_chat_stream_cmd(
  dispatch : Dispatch[Msg],
  task_id : String,
) -> @rabbita.Cmd {
  @rabbita.perform(
    fn(text) {
      let envelope : WikiChatStreamEnvelope = @json.from_json(@json.parse(text)) catch {
        _ =>
          {
            events: [],
            cursor: "start",
            error: "MoonClaw returned an invalid event envelope",
          }
      }
      if envelope.error == "" {
        dispatch(
          LoadedWikiChatEvents(task_id, envelope.cursor, Ok(envelope.events)),
        )
      } else {
        dispatch(
          LoadedWikiChatEvents(task_id, envelope.cursor, Err(envelope.error)),
        )
      }
    },
    fn() { browser_take_wiki_chat_events(task_id) },
  )
}

///|
fn stop_wiki_chat_stream_cmd() -> @rabbita.Cmd {
  @cmd.custom_cmd(_ => browser_stop_wiki_chat_stream(), kind=AfterRender)
}
