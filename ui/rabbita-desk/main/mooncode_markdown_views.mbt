// MoonCode Markdown is enhanced by a route runtime. Keeping parsing out of the
// Rabbita executable avoids shipping the CommonMark compiler on every route.

///|
fn mooncode_markdown_nodes(
  _dispatch : Dispatch[Msg],
  _copied_item_id : String,
  source : String,
) -> Array[@rabbita.Html] {
  if source == "" {
    []
  } else {
    [
      pre(
        class="mooncode-markdown-source",
        attrs=@html.Attrs::build()
          .data_set("testid", "mooncode-markdown-source")
          .aria_label("Rendering Markdown"),
        source,
      ),
    ]
  }
}
