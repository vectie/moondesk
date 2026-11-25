///|
#module("node:module")
extern "js" fn test_dom_loader(path : String) -> @js.Value = "createRequire"

///|
extern "js" fn test_dom_package_path() -> String =
  #| () => process.cwd() + '/package.json'

///|
extern "js" fn test_dom_snapshot(
  loader : @js.Value,
  mount : (String) -> Unit,
) -> String =
  #| (load, mount) => load('#test-dom').renderWithDOM(id => {
  #|   const win = globalThis.window;
  #|   if (win) win.queueMicrotask = () => {};
  #|   const doc = globalThis.document;
  #|   const markers = [];
  #|   if (doc) {
  #|     const origCreateComment = doc.createComment.bind(doc);
  #|     doc.createComment = text => {
  #|       const node = origCreateComment(text);
  #|       if (text === '[' || text === ']') markers.push(node);
  #|       return node;
  #|     };
  #|   }
  #|   mount(id);
  #|   for (const node of markers) node.remove();
  #| }, false)

///|
fn render_test_dom(root : @rabbita.Cell) -> String {
  test_dom_snapshot(test_dom_loader(test_dom_package_path()), fn(id) {
    @rabbita.new(root).mount(id)
  })
}

///|
test "stable DOM projection preserves text attributes controls and SVG" {
  let markup = render_test_dom(
    @rabbita.static_cell(
      div([
        p("A < B & C"),
        input(value="quoted value", checked=true),
        button(disabled=true, "Continue"),
        @svg.svg([]),
      ]),
    ),
  )
  assert_true(markup.contains("A &lt; B &amp; C"))
  assert_true(markup.contains("quoted value"))
  assert_true(markup.contains("Continue"))
  assert_true(markup.contains("<svg"))
}
