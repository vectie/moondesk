///|
using @html {
  a,
  aside,
  button,
  code,
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
  textarea,
  ul,
}

///|
using @rabbita {type Dispatch}

///|
#cfg(target="js")
extern "js" fn encode_component(text : String) -> String = "(text)=>encodeURIComponent(text)"

///|
#cfg(target="js")
extern "js" fn encode_path(text : String) -> String =
  #| (text) => String(text).split("/").map(encodeURIComponent).join("/")

///|
#cfg(target="js")
extern "js" fn browser_initial_activity() -> String =
  #| () => new URLSearchParams(globalThis.location?.search || "").get("activity") || ""

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
fn main {
  let (dispatch, cell) = @rabbita.cell_with_dispatch(
    model=init_model(),
    update~,
    view=(dispatch, model) => render_app(dispatch, model),
  )
  let app = @rabbita.new(cell)
  app.with_startup(
    @rabbita.batch([
      fetch_workspaces_cmd(dispatch),
      fetch_moonclaw_daemon_cmd(dispatch),
      fetch_moonclaw_models_cmd(dispatch),
      fetch_mooncode_sessions_cmd(dispatch, ""),
      fetch_book_base_types_cmd(dispatch),
      fetch_book_patterns_cmd(dispatch),
      schedule_mooncode_poll(dispatch),
      schedule_import_drop_poll(dispatch),
    ]),
  )
  app.mount("app")
}
