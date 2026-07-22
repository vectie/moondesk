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
  progress,
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
  #| () => new URLSearchParams(globalThis.location?.search || "").get("activity") || ""

///|
#cfg(target="js")
extern "js" fn browser_initial_workspace() -> String =
  #| () => new URLSearchParams(globalThis.location?.search || "").get("workspace") || ""

///|
#cfg(target="js")
extern "js" fn browser_initial_path() -> String =
  #| () => new URLSearchParams(globalThis.location?.search || "").get("path") || ""

///|
#cfg(target="js")
extern "js" fn browser_initial_mooncode_session() -> String =
  #| () => new URLSearchParams(globalThis.location?.search || "").get("session") || ""

///|
#cfg(target="js")
extern "js" fn browser_set_activity(slug : String) =
  #| (slug) => {
  #|   if (!globalThis.location || !globalThis.history) return;
  #|   const url = new URL(globalThis.location.href);
  #|   url.searchParams.set("activity", slug);
  #|   globalThis.history.replaceState(null, "", url.toString());
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
  #| }

///|
fn main {
  let (_, cell) = @rabbita.cell_with_emit(
    model=init_model(),
    update~,
    view=(dispatch, model) => render_app(dispatch, model),
    subscriptions=app_subscriptions,
  )
  let app = @rabbita.new(cell)
  app.mount("app")
}
