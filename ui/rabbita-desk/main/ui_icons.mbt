///|
/// Decorative glyph. The containing control supplies its accessible name.
fn ui_icon(name : String) -> @rabbita.Html {
  span(
    class="moon-icon",
    attrs=@html.Attrs::build().data_set("icon", name).aria_hidden("true"),
    "",
  )
}
