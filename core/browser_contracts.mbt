///|
pub(all) enum BrowserActor {
  User
  Agent
  Replay
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) enum BrowserOriginClass {
  OpaqueLocalPreview
  ApprovedExternalOrigin(String)
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) enum BrowserNetworkPolicy {
  LocalAssetsOnly
  ApprovedOrigins(Array[String])
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) enum BrowserStorageLifetime {
  Ephemeral
  RunScoped
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) enum BrowserOperation {
  Navigate
  Reload
  Stop
  Click
  TypeText
  PressKey
  SelectOption
  SetViewport
  CaptureScreenshot
  CaptureDiagnostics
} derive(Debug, Eq, ToJson, FromJson)

///|
pub struct BrowserSessionScope {
  session_id : String
  workspace_id : String
  book_revision : String
  code_revision : String
  run_id : String
  authority_envelope_id : String
  origin_class : BrowserOriginClass
  network_policy : BrowserNetworkPolicy
  storage_lifetime : BrowserStorageLifetime
  download_root : String
  upload_sources : Array[String]
  permitted_effects : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub struct BrowserAction {
  action_id : String
  session_id : String
  actor : BrowserActor
  operation : BrowserOperation
  target : String
  value_redacted : String
  expected_observation : String
  code_revision : String
  authority_envelope_id : String
  created_at : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub struct BrowserObservation {
  observation_id : String
  session_id : String
  action_id : String?
  kind : String
  summary : String
  artifact_path : String?
  code_revision : String
  captured_at : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub struct BrowserActionReceipt {
  action_id : String
  session_id : String
  actor : BrowserActor
  operation : BrowserOperation
  outcome : String
  observations : Array[String]
  authority_envelope_id : String
  code_revision : String
  completed_at : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn opaque_local_browser_scope(
  session_id~ : String,
  workspace_id~ : String,
  book_revision? : String = "uncommitted",
  code_revision? : String = "uncommitted",
  run_id? : String = "",
  authority_envelope_id? : String = "local-preview",
) -> BrowserSessionScope {
  {
    session_id,
    workspace_id,
    book_revision,
    code_revision,
    run_id,
    authority_envelope_id,
    origin_class: OpaqueLocalPreview,
    network_policy: LocalAssetsOnly,
    storage_lifetime: Ephemeral,
    download_root: "",
    upload_sources: [],
    permitted_effects: [
      "render_local_artifact", "interact_visible_page", "capture_diagnostics", "capture_screenshot",
    ],
  }
}

///|
pub fn browser_action(
  action_id~ : String,
  session_id~ : String,
  actor~ : BrowserActor,
  operation~ : BrowserOperation,
  target~ : String,
  value_redacted? : String = "",
  expected_observation? : String = "",
  code_revision? : String = "uncommitted",
  authority_envelope_id? : String = "local-preview",
  created_at? : String = "",
) -> BrowserAction {
  {
    action_id,
    session_id,
    actor,
    operation,
    target,
    value_redacted,
    expected_observation,
    code_revision,
    authority_envelope_id,
    created_at,
  }
}

///|
pub fn browser_local_preview_path_allowed(path : StringView) -> Bool {
  let value = path.to_owned()
  value != "" &&
  !value.has_prefix("/") &&
  !value.contains("\\") &&
  !value.contains(":") &&
  !value.split("/").to_array().contains("..") &&
  (
    value == "book/site/generated/index.html" ||
    value.has_prefix("book/site/generated/")
  )
}

///|
pub fn browser_external_navigation_requires_authority(
  target : StringView,
) -> Bool {
  let value = target.to_owned().trim().to_owned().to_lower()
  value.has_prefix("http://") ||
  value.has_prefix("https://") ||
  value.has_prefix("//") ||
  value.has_prefix("mailto:") ||
  value.has_prefix("tel:") ||
  value.has_prefix("file:") ||
  value.has_prefix("data:") ||
  value.has_prefix("blob:")
}

///|
pub fn browser_action_is_secret_safe(action : BrowserAction) -> Bool {
  action.value_redacted == "" || action.value_redacted == "[redacted]"
}

///|
pub fn browser_action_matches_scope(
  action : BrowserAction,
  scope : BrowserSessionScope,
) -> Bool {
  action.session_id == scope.session_id &&
  action.code_revision == scope.code_revision &&
  action.authority_envelope_id == scope.authority_envelope_id &&
  browser_action_is_secret_safe(action)
}
