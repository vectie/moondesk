///|
extern "js" fn source_literal_live_origin() -> String =
  #| () => globalThis.process?.env?.MOONDESK_LITERAL_HOST_ORIGIN || ''

///|
extern "js" fn source_literal_live_workspace() -> String =
  #| () => globalThis.process?.env?.MOONDESK_LITERAL_WORKSPACE || ''

///|
extern "js" fn source_literal_live_fetch(origin : String) -> @js.Value =
  #| origin => {
  #|   const previous = globalThis.fetch;
  #|   globalThis.fetch = (url, options = {}) => previous(new URL(url, origin), { ...options, headers: { ...options.headers, Origin: origin } });
  #|   return previous;
  #| }

///|
extern "js" fn source_literal_live_tick() -> @js.Promise =
  #| () => new Promise(resolve => setTimeout(resolve, 20))

///|
fn source_literal_live_send(cell : Ref[Model], action : SourcePaneMsg) -> Unit {
  let scheduler : RequestedSelectionTestScheduler = {
    hooks: { url_request: None, url_changed: None, },
  }
  fn dispatch(message : Msg) -> @rabbita.Cmd {
    if message is SourcePane(action) {
      let (command, next) = source_pane_action(dispatch, action, cell.val)
      cell.val = next
      @cmd.Scheduler::add(scheduler, command)
    }
    @rabbita.none
  }
  ignore(dispatch(SourcePane(action)))
}

///|
/// Run with an isolated native Desk host and MOONDESK_LITERAL_HOST_ORIGIN /
/// MOONDESK_LITERAL_WORKSPACE. The fixture src/main.mbt is modified and saved.
#skip("Requires an isolated running native Desk fixture host; see docs/literal-search.md")
test "source literal live host saves and reopens controller replacement" {
  @js.async_test(async fn() {
    let origin = source_literal_live_origin()
    let workspace = source_literal_live_workspace()
    assert_true(origin.has_prefix("http://127.0.0.1:"))
    assert_true(workspace != "")
    let previous = source_literal_live_fetch(origin)
    defer source_save_http_restore(previous)
    let cell = Ref({
      ..init_model(),
      source_pane: init_source_pane(workspace, ""),
    })
    source_literal_live_send(cell, RequestSource("src/main.mbt"))
    for attempt in 0..<250 {
      if !(cell.val.source_pane.content is Loading) {
        break
      }
      assert_true(attempt < 249, msg="Host source preview timed out")
      ignore(source_literal_live_tick().wait())
    }
    let initial = "😀 cat CAT cat\nliteral [.*] cat\n"
    assert_eq(cell.val.source_pane.draft, initial)
    source_literal_live_send(cell, FindQuery("cat"))
    assert_eq(source_literal_summary(cell.val.source_pane), "0/3 matches")
    source_literal_live_send(cell, FindCaseSensitive(false))
    assert_eq(source_literal_summary(cell.val.source_pane), "0/4 matches")
    source_literal_live_send(cell, FindNext)
    source_literal_live_send(cell, FindNext)
    source_literal_live_send(cell, FindPrevious)
    assert_eq(source_literal_summary(cell.val.source_pane), "1/4 matches")
    source_literal_live_send(cell, FindReplacement("dog"))
    source_literal_live_send(cell, ReplaceNext)
    let after_next = "😀 dog CAT cat\nliteral [.*] cat\n"
    assert_eq(cell.val.source_pane.draft, after_next)
    source_literal_live_send(cell, FindReplacement("fox"))
    source_literal_live_send(cell, ReplaceAll)
    let after_all = "😀 dog fox fox\nliteral [.*] fox\n"
    assert_eq(cell.val.source_pane.draft, after_all)
    source_literal_live_send(cell, UndoEdit)
    assert_eq(cell.val.source_pane.draft, after_next)
    source_literal_live_send(cell, RedoEdit)
    assert_eq(cell.val.source_pane.draft, after_all)
    source_literal_live_send(cell, Save)
    for attempt in 0..<250 {
      if !cell.val.source_pane.saving {
        break
      }
      assert_true(attempt < 249, msg="Host source save timed out")
      ignore(source_literal_live_tick().wait())
    }
    assert_eq(cell.val.source_pane.status, "Saved")
    assert_false(source_pane_dirty(cell.val.source_pane))
    source_literal_live_send(cell, CloseBuffer("src/main.mbt"))
    assert_true(cell.val.source_pane.content is Empty)
    source_literal_live_send(cell, RequestSource("src/main.mbt"))
    for attempt in 0..<250 {
      if !(cell.val.source_pane.content is Loading) {
        break
      }
      assert_true(attempt < 249, msg="Host source reopen timed out")
      ignore(source_literal_live_tick().wait())
    }
    assert_eq(cell.val.source_pane.draft, after_all)
    assert_false(source_pane_dirty(cell.val.source_pane))
    source_literal_live_send(cell, FindQuery("[.*]"))
    assert_eq(source_literal_summary(cell.val.source_pane), "0/1 matches")
  })
}
