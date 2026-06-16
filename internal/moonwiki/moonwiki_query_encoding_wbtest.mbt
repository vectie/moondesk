///|
fn encode_query_value(text : String) -> String {
  let pieces : Array[String] = []
  for ch in text {
    if query_safe_char(ch) {
      pieces.push(String::from_array([ch]))
    } else {
      append_percent_encoded_char(pieces, ch)
    }
  }
  pieces.join("")
}

///|
fn query_safe_char(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') ||
  (ch >= 'A' && ch <= 'Z') ||
  (ch >= '0' && ch <= '9') ||
  ch == '-' ||
  ch == '_' ||
  ch == '.' ||
  ch == '~'
}

///|
fn append_percent_encoded_char(pieces : Array[String], ch : Char) -> Unit {
  let code = ch.to_int()
  if code <= 0x7F {
    pieces.push(percent_encoded_byte(code))
  } else if code <= 0x7FF {
    pieces.push(percent_encoded_byte(0xC0 + code / 64))
    pieces.push(percent_encoded_byte(0x80 + code % 64))
  } else if code <= 0xFFFF {
    pieces.push(percent_encoded_byte(0xE0 + code / 4096))
    pieces.push(percent_encoded_byte(0x80 + code / 64 % 64))
    pieces.push(percent_encoded_byte(0x80 + code % 64))
  } else {
    pieces.push(percent_encoded_byte(0xF0 + code / 262144))
    pieces.push(percent_encoded_byte(0x80 + code / 4096 % 64))
    pieces.push(percent_encoded_byte(0x80 + code / 64 % 64))
    pieces.push(percent_encoded_byte(0x80 + code % 64))
  }
}

///|
fn percent_encoded_byte(value : Int) -> String {
  let digits = "0123456789ABCDEF"
  "%" +
  digits[value / 16:value / 16 + 1].to_owned() +
  digits[value % 16:value % 16 + 1].to_owned()
}
