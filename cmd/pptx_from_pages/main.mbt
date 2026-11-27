///|
/// Pure MoonBit CLI for building a `.pptx` from `.page` YAML files, `讲稿数据.json`,
/// and a template `.pptx` using `vectie/moonleaf/pptx`.

///|
fn lex_compare(a : String, b : String) -> Int32 {
  let ca = a.to_array()
  let cb = b.to_array()
  let len = if ca.length() < cb.length() { ca.length() } else { cb.length() }
  for i in 0..<len {
    if ca[i] < cb[i] {
      return -1
    }
    if ca[i] > cb[i] {
      return 1
    }
  }
  if ca.length() < cb.length() {
    -1
  } else if ca.length() > cb.length() {
    1
  } else {
    0
  }
}

///|
fn bytes_to_fixed(b : Bytes) -> FixedArray[Byte] {
  FixedArray::makei(b.length(), fn(i) { b[i] })
}

///|
fn fixed_to_bytes(arr : FixedArray[Byte]) -> Bytes {
  Bytes::from_array(arr)
}

///|
fn load_notes(notes_json_path : String, count : Int32) -> Array[String] {
  let out : Array[String] = Array::make(count, "")
  if !@nativefs.path_exists(notes_json_path) {
    return out
  }
  let text = @nativefs.read_file_to_string(notes_json_path) catch {
    _ => return out
  }
  let parsed = @json.parse(text) catch { _ => return out }
  guard parsed is Array(items) else { return out }
  for item in items {
    match item {
      { "page": Number(p, ..), "script": String(s), .. } => {
        let idx = p.to_int() - 1
        if idx >= 0 && idx < count {
          out[idx] = s
        }
      }
      _ => ()
    }
  }
  out
}

///|
fn collect_media(ppt_dir : String) -> Map[String, FixedArray[Byte]] {
  let media : Map[String, FixedArray[Byte]] = Map([])
  let media_dir = ppt_dir + "/media"
  if !@nativefs.path_exists(media_dir) {
    return media
  }
  let entries = @nativefs.read_dir(media_dir) catch { _ => return media }
  for name in entries {
    let full = media_dir + "/" + name
    let is_f = @nativefs.is_file(full) catch { _ => false }
    if is_f {
      let data = @nativefs.read_file_to_bytes(full) catch { _ => continue }
      media["media/" + name] = bytes_to_fixed(data)
    }
  }
  media
}

///|
fn run() -> Unit raise {
  let args = @env.args()
  guard args.length() >= 4 else {
    println(
      "usage: pptx_from_pages <template.pptx> <ppt_dir> <out1.pptx> [<out2.pptx> ...]",
    )
    return
  }
  let template_path = args[1]
  let ppt_dir = args[2]
  let tpl_bytes = bytes_to_fixed(@nativefs.read_file_to_bytes(template_path))
  let pages_dir = ppt_dir + "/pages"
  let raw_entries = @nativefs.read_dir(pages_dir)
  let page_files : Array[String] = []
  for name in raw_entries {
    if name.has_suffix(".page") {
      page_files.push(name)
    }
  }
  page_files.sort_by(lex_compare)
  let pages : Array[String] = []
  for name in page_files {
    let content = @nativefs.read_file_to_string(pages_dir + "/" + name)
    pages.push(content)
  }
  let notes = load_notes(ppt_dir + "/讲稿数据.json", pages.length())
  let media = collect_media(ppt_dir)
  let built = @pptx.build_presentation_from_pages(
    tpl_bytes, pages, notes, media,
  )
  let out_bytes = fixed_to_bytes(built)
  for i in 3..<args.length() {
    let out_path = args[i]
    @nativefs.write_bytes_to_file(out_path, out_bytes)
    println("Wrote: \{out_path} (\{out_bytes.length()} bytes)")
  }
}

///|
fn main {
  run() catch {
    err => println("error: \{err}")
  }
}
