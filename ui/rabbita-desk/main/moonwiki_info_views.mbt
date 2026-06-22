///|
fn info_row(label : String, value : String) -> @rabbita.Html {
  div(class="info-row", [span(label), code(value)])
}

///|
fn info_chip(label : String, value : String) -> @rabbita.Html {
  span(class="info-chip", [strong(value), small(label)])
}
