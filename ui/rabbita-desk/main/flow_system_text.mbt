///|
/// Translate system status fragments before composing them with user IDs.
extern "js" fn flow_system_text(value : String) -> String =
  #| value => globalThis.window?.MoonSuiteI18n?.text?.(value) || value
