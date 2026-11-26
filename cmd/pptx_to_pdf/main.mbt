///|
/// Render a `.pptx` presentation to print-ready 960pt x 540pt HTML using
/// MoonLeaf's pure MoonBit SVG renderer (`@pptx.preview_json`), then print to PDF.

///|
fn bytes_to_fixed(b : Bytes) -> FixedArray[Byte] {
  FixedArray::makei(b.length(), fn(i) { b[i] })
}

///|
fn run() -> Unit raise {
  let args = @env.args()
  guard args.length() >= 3 else {
    println("usage: pptx_to_pdf <input.pptx> <output.html>")
    return
  }
  let input_path = args[1]
  let html_path = args[2]
  let raw = @nativefs.read_file_to_bytes(input_path)
  let pkg = @opc.open(bytes_to_fixed(raw))
  let preview = @pptx.preview_json(pkg, input_path)
  guard preview is { "slides": Array(slides), .. } else {
    fail("preview_json did not return slides")
  }
  let buf = StringBuilder()
  buf.write_string(
    "<!doctype html><html><head><meta charset=\"utf-8\"><title>Presentation</title><style>" +
    "@page { size: 960pt 540pt; margin: 0; }" +
    "html, body { margin: 0; padding: 0; background: #fff; }" +
    ".slide { width: 960pt; height: 540pt; page-break-after: always; break-after: page; overflow: hidden; }" +
    ".slide:last-child { page-break-after: auto; break-after: auto; }" +
    ".slide svg { width: 100%; height: 100%; display: block; }" +
    "</style></head><body>",
  )
  for idx, slide in slides {
    match slide {
      { "svg": String(svg), .. } => {
        let prefix = "s\{idx}_"
        let scoped = svg
          .replace_all(old="id=\"", new="id=\"\{prefix}")
          .replace_all(old="url(#", new="url(#\{prefix}")
          .replace_all(old="href=\"#", new="href=\"#\{prefix}")
        buf.write_string("<section class=\"slide\">")
        buf.write_string(scoped)
        buf.write_string("</section>")
      }
      _ => ()
    }
  }
  buf.write_string("</body></html>")
  @nativefs.write_string_to_file(html_path, buf.to_string())
  println("Rendered \{slides.length()} slides to \{html_path}")
}

///|
fn main {
  run() catch {
    err => println("error: \{err}")
  }
}
