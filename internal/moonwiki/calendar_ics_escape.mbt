///|
fn ics_escape(text : String) -> String {
  text
  .replace_all(old="\\", new="\\\\")
  .replace_all(old="\r", new=" ")
  .replace_all(old="\n", new=" ")
  .replace_all(old=",", new="\\,")
  .replace_all(old=";", new="\\;")
  .to_string()
}
