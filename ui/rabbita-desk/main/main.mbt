///|
using @html {
  a,
  aside,
  article,
  button,
  code,
  details,
  div,
  h1,
  h2,
  h3,
  header,
  iframe,
  img,
  input,
  li,
  main_,
  p,
  pre,
  section,
  small,
  span,
  strong,
  summary,
  textarea,
  ul,
}

///|
using @rabbita {type Emit}

///|
type Dispatch[A] = Emit[A]

///|
#cfg(target="js")
extern "js" fn browser_initial_activity() -> String =
  #| () => {
  #|   const params = new URLSearchParams(globalThis.location?.search || "");
  #|   const explicit = params.get("activity");
  #|   if (explicit) {
  #|     try {
  #|       const prev = JSON.parse(globalThis.localStorage?.getItem("moondesk.last_context.v1") || "{}");
  #|       globalThis.localStorage?.setItem("moondesk.last_context.v1", JSON.stringify({ ...prev, activity: explicit }));
  #|     } catch {}
  #|     return explicit;
  #|   }
  #|   if (!params.has("workspace") && !params.has("path") && !params.has("session")) {
  #|     try {
  #|       const saved = JSON.parse(globalThis.localStorage?.getItem("moondesk.last_context.v1") || "{}");
  #|       if (saved?.activity) return String(saved.activity);
  #|     } catch {}
  #|   }
  #|   return "";
  #| }

///|
#cfg(target="js")
extern "js" fn browser_initial_workspace() -> String =
  #| () => {
  #|   const params = new URLSearchParams(globalThis.location?.search || "");
  #|   const explicit = params.get("workspace");
  #|   if (explicit) {
  #|     try {
  #|       const prev = JSON.parse(globalThis.localStorage?.getItem("moondesk.last_context.v1") || "{}");
  #|       globalThis.localStorage?.setItem("moondesk.last_context.v1", JSON.stringify({ ...prev, workspace: explicit }));
  #|     } catch {}
  #|     return explicit;
  #|   }
  #|   if (!params.has("workspace") && !params.has("path") && !params.has("session") && !params.has("activity")) {
  #|     try {
  #|       const saved = JSON.parse(globalThis.localStorage?.getItem("moondesk.last_context.v1") || "{}");
  #|       if (saved?.workspace) return String(saved.workspace);
  #|     } catch {}
  #|   }
  #|   return "";
  #| }

///|
#cfg(target="js")
extern "js" fn browser_initial_path() -> String =
  #| () => {
  #|   const params = new URLSearchParams(globalThis.location?.search || "");
  #|   const explicit = params.get("path");
  #|   if (explicit) {
  #|     try {
  #|       const prev = JSON.parse(globalThis.localStorage?.getItem("moondesk.last_context.v1") || "{}");
  #|       globalThis.localStorage?.setItem("moondesk.last_context.v1", JSON.stringify({ ...prev, path: explicit }));
  #|     } catch {}
  #|     return explicit;
  #|   }
  #|   if (!params.has("workspace") && !params.has("path") && !params.has("session") && !params.has("activity")) {
  #|     try {
  #|       const saved = JSON.parse(globalThis.localStorage?.getItem("moondesk.last_context.v1") || "{}");
  #|       if (saved?.path) return String(saved.path);
  #|     } catch {}
  #|   }
  #|   return "";
  #| }

///|
#cfg(target="js")
extern "js" fn browser_initial_mooncode_session() -> String =
  #| () => {
  #|   const params = new URLSearchParams(globalThis.location?.search || "");
  #|   const explicit = params.get("session");
  #|   if (explicit) return explicit;
  #|   if (!params.has("workspace") && !params.has("path") && !params.has("session") && !params.has("activity")) {
  #|     try {
  #|       const saved = JSON.parse(globalThis.localStorage?.getItem("moondesk.last_context.v1") || "{}");
  #|       if (saved?.session) return String(saved.session);
  #|     } catch {}
  #|   }
  #|   return "";
  #| }

///|
#cfg(target="js")
extern "js" fn browser_set_activity(slug : String) =
  #| (slug) => {
  #|   if (!globalThis.location || !globalThis.history) return;
  #|   const url = new URL(globalThis.location.href);
  #|   url.searchParams.set("activity", slug);
  #|   globalThis.history.replaceState(null, "", url.toString());
  #|   try {
  #|     const prev = JSON.parse(globalThis.localStorage?.getItem("moondesk.last_context.v1") || "{}");
  #|     globalThis.localStorage?.setItem("moondesk.last_context.v1", JSON.stringify({ ...prev, activity: String(slug || "") }));
  #|   } catch {}
  #| }

///|
#cfg(target="js")
extern "js" fn browser_set_mooncode_context(
  workspace_id : String,
  session_id : String,
) =
  #| (workspaceId, sessionId) => {
  #|   if (!globalThis.location || !globalThis.history) return;
  #|   const url = new URL(globalThis.location.href);
  #|   if (workspaceId) url.searchParams.set("workspace", workspaceId);
  #|   else url.searchParams.delete("workspace");
  #|   if (sessionId) url.searchParams.set("session", sessionId);
  #|   else url.searchParams.delete("session");
  #|   globalThis.history.replaceState(null, "", url.toString());
  #|   try {
  #|     const prev = JSON.parse(globalThis.localStorage?.getItem("moondesk.last_context.v1") || "{}");
  #|     globalThis.localStorage?.setItem("moondesk.last_context.v1", JSON.stringify({ ...prev, workspace: String(workspaceId || ""), session: String(sessionId || "") }));
  #|   } catch {}
  #| }

///|
#cfg(target="js")
extern "js" fn browser_set_workspace_context(
  workspace_id : String,
  path : String,
) =
  #| (workspaceId, path) => {
  #|   if (!globalThis.location || !globalThis.history) return;
  #|   const url = new URL(globalThis.location.href);
  #|   if (workspaceId) url.searchParams.set("workspace", workspaceId);
  #|   else url.searchParams.delete("workspace");
  #|   if (path) url.searchParams.set("path", path);
  #|   else url.searchParams.delete("path");
  #|   globalThis.history.replaceState(null, "", url.toString());
  #|   try {
  #|     const prev = JSON.parse(globalThis.localStorage?.getItem("moondesk.last_context.v1") || "{}");
  #|     globalThis.localStorage?.setItem("moondesk.last_context.v1", JSON.stringify({ ...prev, workspace: String(workspaceId || ""), path: String(path || "") }));
  #|   } catch {}
  #| }

///|
priv struct AppModel(Model)

///|
impl Eq for AppModel with fn equal(_, _) {
  false
}

///|
fn main {
  let app = @rabbita.new(() => {
    let (model, dispatch) = @rabbita.create_state_with_init(
      init=dispatch => {
        (AppModel(init_model()), @rabbita.delay(dispatch(Bootstrap), 0))
      },
      update=(model, msg, dispatch) => {
        let (cmd, next) = update(dispatch, msg, model.0)
        (AppModel(next), cmd)
      },
    )
    model.map(model => render_app(dispatch, model.0))
  })
  app.mount("app")
}
