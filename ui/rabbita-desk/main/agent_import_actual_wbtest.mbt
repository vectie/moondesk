///|
/// Opt-in acceptance input produced by the native receive test. This is test
/// code only; no filesystem or Node access is included in the browser product.
#cfg(target="js")
extern "js" fn agent_import_actual_evidence_text() -> String =
  #| () => {
  #|   if (typeof process === 'undefined') return '';
  #|   const path = process.env.MOONDESK_AGENT_IMPORT_UI_EVIDENCE;
  #|   if (!path) return '';
  #|   return process.getBuiltinModule('fs').readFileSync(path, 'utf8');
  #| }

///|
test "actual native receive JSON passes frontend inspection verification and fenced Open" {
  let text = agent_import_actual_evidence_text()
  if text == "" {
    return
  }
  let proof = @json.parse(text)
  guard proof is { "staged": staged, "imported": imported, .. } else {
    fail(
      "Native receive evidence must contain unchanged staged and imported responses",
    )
  }
  let library = handoff_text(staged, "expected_library")
  let id = handoff_text(staged, "operation_id")
  let filename = handoff_text(staged, "filename")
  let stage : AgentImportState = {
    ..init_agent_import(),
    active: true,
    generation: 1,
    request: 1,
    suspended: [],
    session: {
      ..init_agent_import_session(library),
      operation_id: id,
      filename,
    },
    pending: Some({ request: 1, operation: StagingPackage, }),
  }
  let (inspected, effect) = reduce_agent_import(
    stage,
    ImportResponse(1, 1, Ok(staged)),
  )
  assert_true(effect is NoAgentImportEffect)
  assert_eq(inspected.session.status, "inspected")
  assert_eq(inspected.session.error, "")
  let destination = handoff_text(imported, "destination_folder")
  let (ready, _) = reduce_agent_import(
    inspected,
    SetImportDestination(destination),
  )
  assert_true(agent_import_can_write(ready))
  let (importing, effect) = reduce_agent_import(ready, ImportInspectedPackage)
  assert_true(effect is WriteAgentImport(_, _))
  let (complete, effect) = reduce_agent_import(
    importing,
    ImportResponse(importing.generation, importing.request, Ok(imported)),
  )
  assert_true(effect is NoAgentImportEffect)
  assert_eq(complete.session.status, "imported")
  assert_eq(complete.session.error, "")
  let (opening, effect) = reduce_agent_import(complete, OpenImportedPackage)
  assert_true(effect is ReadAgentImport(_, _))
  let dispatch : Dispatch[Msg] = _ => @rabbita.none
  let model = {
    ..init_model(),
    workspace_mode: Desk,
    workspace_library_path: library,
    agent_import: opening,
  }
  let (_, opened) = update_agent_import(
    dispatch,
    ImportResponse(opening.generation, opening.request, Ok(imported)),
    model,
  )
  assert_eq(opened.selected_workspace_id, @desk.stable_id("book", destination))
  assert_eq(opened.requested_workspace_id, opened.selected_workspace_id)
  assert_eq(opened.selected_path, "wiki/index.md")
  assert_eq(opened.agent_import.session.operation_id, id)
  assert_eq(opened.agent_import.session.library, library)
}
