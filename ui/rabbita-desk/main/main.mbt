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
using @rabbita {type Emit}

///|
type Dispatch[A] = Emit[A]

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
extern "js" fn browser_initial_mooncode_runtime_mode() -> String =
  #| () => {
  #|   const params = new URLSearchParams(globalThis.location?.search || "");
  #|   return params.get("mooncodeRuntime") || params.get("mooncode_runtime") || "";
  #| }

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
  let (_, cell) = @rabbita.cell_with_emit(
    model=init_model(),
    update~,
    view=(dispatch, model) => render_app(dispatch, model),
    subscriptions=app_subscriptions,
  )
  @rabbita.new(cell).mount("app")
}
