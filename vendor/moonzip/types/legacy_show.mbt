///|
/// Retain the original derived Show text without deprecated container Show.
fn[T] legacy_show_option(value : T?, render : (T) -> String) -> String {
  match value {
    None => "None"
    Some(value) => "Some(" + render(value) + ")"
  }
}

///|
fn legacy_show_bytes(values : FixedArray[Byte]) -> String {
  let out = StringBuilder()
  out.write_string("[")
  for i, value in values {
    if i > 0 {
      out.write_string(", ")
    }
    out.write_string(Show::to_string(value))
  }
  out.write_string("]")
  out.to_string()
}

///|
fn legacy_show_fields(fields : Map[Int32, FixedArray[Byte]]) -> String {
  let out = StringBuilder()
  out.write_string("{")
  let mut first = true
  for key, value in fields {
    if !first {
      out.write_string(", ")
    }
    first = false
    out.write_string(key.to_string() + ": " + legacy_show_bytes(value))
  }
  out.write_string("}")
  out.to_string()
}

///|
pub impl Show for FlateErrorCode with fn to_string(self) {
  match self {
    UnexpectedEOF => "UnexpectedEOF"
    InvalidBlockType => "InvalidBlockType"
    InvalidLengthLiteral => "InvalidLengthLiteral"
    InvalidDistance => "InvalidDistance"
    StreamFinished => "StreamFinished"
    NoStreamHandler => "NoStreamHandler"
    InvalidHeader => "InvalidHeader"
    NoCallback => "NoCallback"
    InvalidUTF8 => "InvalidUTF8"
    ExtraFieldTooLong => "ExtraFieldTooLong"
    InvalidDate => "InvalidDate"
    FilenameTooLong => "FilenameTooLong"
    StreamFinishing => "StreamFinishing"
    InvalidZipData => "InvalidZipData"
    UnknownCompressionMethod => "UnknownCompressionMethod"
  }
}

///|
pub impl Show for DeflateOptions with fn to_string(self) {
  "{level: " +
  self.level.to_string() +
  ", mem: " +
  self.mem.to_string() +
  ", dictionary: " +
  legacy_show_option(self.dictionary, legacy_show_bytes) +
  "}"
}

///|
pub impl Show for InflateOptions with fn to_string(self) {
  "{size: " +
  legacy_show_option(self.size, n => n.to_string()) +
  ", dictionary: " +
  legacy_show_option(self.dictionary, legacy_show_bytes) +
  "}"
}

///|
pub impl Show for GzipOptions with fn to_string(self) {
  "{level: " +
  self.level.to_string() +
  ", mem: " +
  self.mem.to_string() +
  ", mtime: " +
  legacy_show_option(self.mtime, n => n.to_string()) +
  ", filename: " +
  legacy_show_option(self.filename, s => s) +
  ", comment: " +
  legacy_show_option(self.comment, s => s) +
  ", extra: " +
  legacy_show_option(self.extra, legacy_show_bytes) +
  "}"
}

///|
pub impl Show for ZlibOptions with fn to_string(self) {
  "{level: " +
  self.level.to_string() +
  ", mem: " +
  self.mem.to_string() +
  ", dictionary: " +
  legacy_show_option(self.dictionary, legacy_show_bytes) +
  "}"
}

///|
pub impl Show for ZipAttributes with fn to_string(self) {
  "{os: " +
  legacy_show_option(self.os, n => n.to_string()) +
  ", attrs: " +
  legacy_show_option(self.attrs, n => n.to_string()) +
  ", comment: " +
  legacy_show_option(self.comment, s => s) +
  ", extra: " +
  legacy_show_option(self.extra, legacy_show_fields) +
  "}"
}

///|
pub impl Show for ZipEntryOptions with fn to_string(self) {
  "{level: " +
  self.level.to_string() +
  ", mtime: " +
  legacy_show_option(self.mtime, n => n.to_string()) +
  ", attrs: " +
  legacy_show_option(self.attrs, x => Show::to_string(x)) +
  "}"
}

///|
pub impl Show for ZipOptions with fn to_string(self) {
  "{level: " +
  self.level.to_string() +
  ", mtime: " +
  legacy_show_option(self.mtime, n => n.to_string()) +
  ", comment: " +
  legacy_show_option(self.comment, s => s) +
  "}"
}

///|
pub impl Show for UnzipFileInfo with fn to_string(self) {
  "{name: " +
  self.name +
  ", size: " +
  self.size.to_string() +
  ", original_size: " +
  self.original_size.to_string() +
  ", compression: " +
  self.compression.to_string() +
  ", mtime: " +
  self.mtime.to_string() +
  ", attrs: " +
  self.attrs.to_string() +
  ", comment: " +
  self.comment +
  ", extra: " +
  legacy_show_fields(self.extra) +
  "}"
}
