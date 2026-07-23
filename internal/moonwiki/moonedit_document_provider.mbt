///|
/// Initial MoonEdit document limit: 4 MiB of UTF-8 bytes.
/// DEL (U+007F) is rejected along with C0 controls other than TAB/LF/CR.
let moonedit_max_document_bytes : Int = 4 * 1024 * 1024

///|
priv enum MoonEditDocumentError {
  Oversized(Int, Int)
  InvalidUtf8
  BinaryControl(Int)
}

///|
priv struct MoonEditDocument {
  text : String
  byte_size : Int
  revision : String
}

///|
fn moonedit_hex(bytes : FixedArray[Byte]) -> String {
  let out = StringBuilder::new(size_hint=bytes.length() * 2)
  for byte in bytes {
    out.write_string(byte.to_hex())
  }
  out.to_string()
}

///|
fn moonedit_revision(bytes : Bytes) -> String {
  "sha256:" + moonedit_hex(@crypto.sha256(bytes))
}

///|
fn moonedit_validate_text_controls(
  text : String,
) -> Result[Unit, MoonEditDocumentError] {
  for char in text {
    let codepoint = char.to_int()
    if codepoint == 0x7f ||
      (
        codepoint < 0x20 &&
        codepoint != 0x09 &&
        codepoint != 0x0a &&
        codepoint != 0x0d
      ) {
      return Err(BinaryControl(codepoint))
    }
  }
  Ok(())
}

///|
fn moonedit_decode_document(
  bytes : Bytes,
) -> Result[MoonEditDocument, MoonEditDocumentError] {
  let byte_size = bytes.length()
  if byte_size > moonedit_max_document_bytes {
    return Err(Oversized(byte_size, moonedit_max_document_bytes))
  }
  let text = @encoding/utf8.decode(bytes) catch {
    @encoding/utf8.Malformed(_) => return Err(InvalidUtf8)
  }
  match moonedit_validate_text_controls(text) {
    Err(error) => Err(error)
    Ok(_) => Ok({ text, byte_size, revision: moonedit_revision(bytes) })
  }
}

///|
fn moonedit_validate_document_for_save(
  text : String,
) -> Result[MoonEditDocument, MoonEditDocumentError] {
  let bytes = @encoding/utf8.encode(text)
  let byte_size = bytes.length()
  if byte_size > moonedit_max_document_bytes {
    return Err(Oversized(byte_size, moonedit_max_document_bytes))
  }
  match moonedit_validate_text_controls(text) {
    Err(error) => Err(error)
    Ok(_) => Ok({ text, byte_size, revision: moonedit_revision(bytes) })
  }
}
