///|
fn[T : Show] compatibility_show(value : T) -> String raise {
  let text = Show::to_string(value)
  let output = StringBuilder()
  Show::output(value, output)
  assert_eq(output.to_string(), text)
  text
}

///|
fn legacy_show_rows() -> Array[String] raise {
  let rows : Array[String] = []
  let errors : Array[FlateErrorCode] = [
    UnexpectedEOF,
    InvalidBlockType,
    InvalidLengthLiteral,
    InvalidDistance,
    StreamFinished,
    NoStreamHandler,
    InvalidHeader,
    NoCallback,
    InvalidUTF8,
    ExtraFieldTooLong,
    InvalidDate,
    FilenameTooLong,
    StreamFinishing,
    InvalidZipData,
    UnknownCompressionMethod,
  ]
  for error in errors {
    rows.push(compatibility_show(error))
  }
  let bytes : FixedArray[Byte] = [0, 10, 65, 233, 255]
  let fields : Map[Int32, FixedArray[Byte]] = Map([(7, bytes), (1, [])])
  let attrs : ZipAttributes = {
    os: Some(3),
    attrs: Some(420),
    comment: Some("quote\" slash\\ newline\né"),
    extra: Some(fields),
  }
  rows.push(compatibility_show(DeflateOptions::default()))
  rows.push(
    compatibility_show(DeflateOptions::{
      level: 9,
      mem: 7,
      dictionary: Some(bytes),
    }),
  )
  rows.push(compatibility_show(InflateOptions::default()))
  rows.push(
    compatibility_show(InflateOptions::{
      size: Some(123),
      dictionary: Some([]),
    }),
  )
  rows.push(compatibility_show(GzipOptions::default()))
  rows.push(
    compatibility_show(GzipOptions::{
      level: 1,
      mem: 2,
      mtime: Some(-1),
      filename: Some("a\n\"\\é"),
      comment: Some("comment"),
      extra: Some(bytes),
    }),
  )
  rows.push(compatibility_show(ZlibOptions::default()))
  rows.push(
    compatibility_show(ZlibOptions::{
      level: 0,
      mem: 12,
      dictionary: Some(bytes),
    }),
  )
  rows.push(
    compatibility_show(ZipAttributes::{
      os: None,
      attrs: None,
      comment: None,
      extra: None,
    }),
  )
  rows.push(compatibility_show(attrs))
  rows.push(compatibility_show(ZipEntryOptions::default()))
  rows.push(
    compatibility_show(ZipEntryOptions::{
      level: 0,
      mtime: Some(0),
      attrs: Some(attrs),
    }),
  )
  rows.push(compatibility_show(ZipOptions::default()))
  rows.push(
    compatibility_show(ZipOptions::{
      level: 9,
      mtime: Some(1),
      comment: Some("c\n\"\\é"),
    }),
  )
  rows.push(
    compatibility_show(UnzipFileInfo::{
      name: "a\n\"\\é",
      size: 2,
      original_size: 3,
      compression: 8,
      mtime: -1,
      attrs: 420,
      comment: "",
      extra: fields,
    }),
  )
  rows.push(
    compatibility_show(UnzipFileInfo::{
      name: "",
      size: 0,
      original_size: 0,
      compression: 0,
      mtime: 0,
      attrs: 0,
      comment: "x",
      extra: Map([]),
    }),
  )
  rows
}

///|
test "legacy Show output and to_string remain identical" {
  let rows = legacy_show_rows()
  assert_eq(rows, [
    "UnexpectedEOF", "InvalidBlockType", "InvalidLengthLiteral", "InvalidDistance",
    "StreamFinished", "NoStreamHandler", "InvalidHeader", "NoCallback", "InvalidUTF8",
    "ExtraFieldTooLong", "InvalidDate", "FilenameTooLong", "StreamFinishing", "InvalidZipData",
    "UnknownCompressionMethod", "{level: 6, mem: 4, dictionary: None}", "{level: 9, mem: 7, dictionary: Some([b'\\x00', b'\\x0A', b'\\x41', b'\\xE9', b'\\xFF'])}",
    "{size: None, dictionary: None}", "{size: Some(123), dictionary: Some([])}",
    "{level: 6, mem: 4, mtime: None, filename: None, comment: None, extra: None}",
    "{level: 1, mem: 2, mtime: Some(-1), filename: Some(a\n\"\\é), comment: Some(comment), extra: Some([b'\\x00', b'\\x0A', b'\\x41', b'\\xE9', b'\\xFF'])}",
    "{level: 6, mem: 4, dictionary: None}", "{level: 0, mem: 12, dictionary: Some([b'\\x00', b'\\x0A', b'\\x41', b'\\xE9', b'\\xFF'])}",
    "{os: None, attrs: None, comment: None, extra: None}", "{os: Some(3), attrs: Some(420), comment: Some(quote\" slash\\ newline\né), extra: Some({7: [b'\\x00', b'\\x0A', b'\\x41', b'\\xE9', b'\\xFF'], 1: []})}",
    "{level: 6, mtime: None, attrs: None}", "{level: 0, mtime: Some(0), attrs: Some({os: Some(3), attrs: Some(420), comment: Some(quote\" slash\\ newline\né), extra: Some({7: [b'\\x00', b'\\x0A', b'\\x41', b'\\xE9', b'\\xFF'], 1: []})})}",
    "{level: 6, mtime: None, comment: None}", "{level: 9, mtime: Some(1), comment: Some(c\n\"\\é)}",
    "{name: a\n\"\\é, size: 2, original_size: 3, compression: 8, mtime: -1, attrs: 420, comment: , extra: {7: [b'\\x00', b'\\x0A', b'\\x41', b'\\xE9', b'\\xFF'], 1: []}}",
    "{name: , size: 0, original_size: 0, compression: 0, mtime: 0, attrs: 0, comment: x, extra: {}}",
  ])
}
