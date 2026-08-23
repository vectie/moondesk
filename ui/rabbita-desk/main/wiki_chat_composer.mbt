/// Shared composer behavior for MoonDesk's user-facing chat surfaces.
///
/// The parser deliberately understands only a trailing, whitespace-delimited
/// `@` token. Callers keep their own result rows and reducer state, while this
/// helper provides the same trigger grammar and stale-result boundary for Wiki
/// chat and MoonCode.

///|
struct ComposerTrigger {
  query : String
  draft_without_token : String
}

///|
fn ComposerTrigger::parse(text : String) -> ComposerTrigger? {
  let length = text.length()
  if length == 0 {
    return None
  }
  let mut start = length - 1
  while start >= 0 && !composer_whitespace(text[start]) {
    start = start - 1
  }
  let token_start = start + 1
  if token_start >= length || text[token_start] != '@' {
    return None
  }
  if token_start > 0 && !composer_whitespace(text[token_start - 1]) {
    return None
  }
  Some({
    query: text[token_start + 1:].to_owned(),
    draft_without_token: text[:token_start].to_owned(),
  })
}

///|
fn composer_whitespace(value : UInt16) -> Bool {
  value == ' ' || value == '\n' || value == '\r' || value == '\t'
}

///|
fn composer_trigger_query(text : String) -> String? {
  match ComposerTrigger::parse(text) {
    Some(trigger) => Some(trigger.query)
    None => None
  }
}

///|
const WikiChatFileSearchDebounceMs : Int = 180

///|
const WikiChatFileSearchLimit : Int = 24

///|
fn wiki_chat_file_search_status_for_count(count : Int) -> String {
  if count == 0 {
    "No matching files"
  } else if count == 1 {
    "1 matching file"
  } else {
    "{count} matching files"
  }
}

///|
#cfg(target="js")
extern "js" fn wiki_chat_set_drag_data(event : @dom.DragEvent, path : String) =
  #| (event, path) => {
  #|   const transfer = event?.dataTransfer;
  #|   if (!transfer) return;
  #|   transfer.setData('application/x-moondesk-workspace-path', path);
  #|   transfer.setData('text/plain', path);
  #|   transfer.effectAllowed = 'copy';
  #| }

///|
#cfg(target="js")
extern "js" fn wiki_chat_allow_drop(event : @dom.DragEvent) =
  #| (event) => {
  #|   if (event?.dataTransfer) event.dataTransfer.dropEffect = 'copy';
  #|   event?.preventDefault();
  #| }

///|
#cfg(target="js")
extern "js" fn wiki_chat_read_drag_data(event : @dom.DragEvent) -> String =
  #| (event) => {
  #|   const transfer = event?.dataTransfer;
  #|   if (!transfer) return '';
  #|   return transfer.getData('application/x-moondesk-workspace-path')
  #|     || transfer.getData('text/plain')
  #|     || '';
  #| }

///|
#cfg(target="js")
fn wiki_chat_drag_start_cmd(
  path : String,
  event : @dom.DragEvent,
) -> @rabbita.Cmd {
  wiki_chat_set_drag_data(event, path)
  @rabbita.none
}

///|
#cfg(target="js")
fn wiki_chat_drag_over_cmd(event : @dom.DragEvent) -> @rabbita.Cmd {
  wiki_chat_allow_drop(event)
  @rabbita.none
}

///|
#cfg(target="js")
fn wiki_chat_drop_path(event : @dom.DragEvent) -> String {
  wiki_chat_allow_drop(event)
  wiki_chat_read_drag_data(event)
}
