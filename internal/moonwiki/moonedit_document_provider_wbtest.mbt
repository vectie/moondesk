///|
fn moonedit_expect_document(
  result : Result[MoonEditDocument, MoonEditDocumentError],
  text : String,
  byte_size : Int,
  revision : String,
) -> Unit raise {
  match result {
    Ok(document) => {
      assert_eq(document.text, text)
      assert_eq(document.byte_size, byte_size)
      assert_eq(document.revision, revision)
    }
    Err(_) => abort("unexpected document error")
  }
}

///|
test "moonedit SHA-256 known vectors and lowercase byte hex" {
  assert_eq(moonedit_hex([0x00, 0x0f, 0x10, 0xab, 0xff]), "000f10abff")
  assert_eq(
    moonedit_revision(Bytes::from_array([])),
    "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  )
  assert_eq(
    moonedit_revision(@encoding/utf8.encode("abc")),
    "sha256:ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  )
  assert_eq(
    moonedit_revision(@encoding/utf8.encode("你好")),
    "sha256:670d9743542cae3ea7ebe36af56bd53648b0a1126162e78d81a32934a711302e",
  )
}

///|
test "moonedit decodes ASCII, multibyte, and empty documents" {
  moonedit_expect_document(
    moonedit_decode_document(Bytes::from_array([])),
    "",
    0,
    "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  )
  moonedit_expect_document(
    moonedit_decode_document(@encoding/utf8.encode("abc")),
    "abc",
    3,
    "sha256:ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  )
  moonedit_expect_document(
    moonedit_decode_document(@encoding/utf8.encode("你好")),
    "你好",
    6,
    "sha256:670d9743542cae3ea7ebe36af56bd53648b0a1126162e78d81a32934a711302e",
  )
}

///|
test "moonedit enforces load byte boundary and strict UTF-8" {
  let at_limit = Bytes::make(moonedit_max_document_bytes, b'a')
  match moonedit_decode_document(at_limit) {
    Ok(document) => assert_eq(document.byte_size, moonedit_max_document_bytes)
    Err(_) => abort("boundary rejected")
  }
  match
    moonedit_decode_document(Bytes::make(moonedit_max_document_bytes + 1, b'a')) {
    Err(Oversized(actual, limit)) => {
      assert_eq(actual, moonedit_max_document_bytes + 1)
      assert_eq(limit, moonedit_max_document_bytes)
    }
    _ => abort("expected oversized load")
  }
  let invalid_utf8 = moonedit_decode_document(Bytes::from_array([0xff]))
  assert_true(invalid_utf8 is Err(InvalidUtf8))
  let truncated_utf8 = moonedit_decode_document(Bytes::from_array([0xe2, 0x82]))
  assert_true(truncated_utf8 is Err(InvalidUtf8))
  let overlong_utf8 = moonedit_decode_document(Bytes::from_array([0xc0, 0xaf]))
  assert_true(overlong_utf8 is Err(InvalidUtf8))
}

///|
test "moonedit control policy rejects NUL C0 and DEL but accepts TAB LF CR" {
  assert_true(
    moonedit_validate_text_controls("\u0000") is Err(BinaryControl(0)),
  )
  assert_true(
    moonedit_validate_text_controls("\u0001") is Err(BinaryControl(1)),
  )
  assert_true(
    moonedit_validate_text_controls("\u007f") is Err(BinaryControl(0x7f)),
  )
  assert_true(moonedit_validate_text_controls("a\t\n\rb") is Ok(_))
  match moonedit_decode_document(@encoding/utf8.encode("a\t\n\rb")) {
    Ok(document) => assert_eq(document.text, "a\t\n\rb")
    Err(_) => abort("allowed controls rejected")
  }
}

///|
test "moonedit save limit uses encoded UTF-8 bytes" {
  let multibyte = "你好"
  let encoded = @encoding/utf8.encode(multibyte)
  match moonedit_validate_document_for_save(multibyte) {
    Ok(document) => {
      assert_eq(document.byte_size, encoded.length())
      assert_eq(document.revision, moonedit_revision(encoded))
    }
    Err(_) => abort("valid multibyte save rejected")
  }
  let at_limit = "é".repeat(moonedit_max_document_bytes / 2)
  match moonedit_validate_document_for_save(at_limit) {
    Ok(document) => assert_eq(document.byte_size, moonedit_max_document_bytes)
    Err(_) => abort("encoded-byte boundary rejected")
  }
  match moonedit_validate_document_for_save(at_limit + "é") {
    Err(Oversized(actual, limit)) => {
      assert_eq(actual, moonedit_max_document_bytes + 2)
      assert_eq(limit, moonedit_max_document_bytes)
    }
    _ => abort("expected oversized save")
  }
  assert_true(
    moonedit_validate_document_for_save("ok\u0000") is Err(BinaryControl(0)),
  )
}
