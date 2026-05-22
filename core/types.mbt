///|
pub(all) enum WorkspaceKind {
  MoonBook
  LooseFolder
  TownRoot
} derive(Show, Eq, ToJson, FromJson)

///|
pub(all) enum WorkspaceStatus {
  Ready
  Missing
  NeedsAttention
  Unknown
} derive(Show, Eq, ToJson, FromJson)

///|
pub(all) enum EntryKind {
  Markdown
  Html
  Json
  Image
  Directory
  Artifact
  Text
  Unknown
} derive(Show, Eq, ToJson, FromJson)

///|
pub(all) enum SourceLayer {
  Wiki
  RawEvidence
  GeneratedSite
  BookOutput
  Review
  History
  RunArtifact
  Inbox
  Config
  Workspace
} derive(Show, Eq, ToJson, FromJson)

///|
pub(all) enum PreviewRenderer {
  Markdown
  Html
  Json
  Image
  Text
  ArtifactSummary
  DirectoryListing
  Unsupported
} derive(Show, Eq, ToJson, FromJson)

///|
pub(all) enum SubmissionCadence {
  OneShot
  StandingWatch(String)
} derive(Show, Eq, ToJson, FromJson)

///|
pub(all) enum SourcePolicy {
  BookOnly
  WebFirst
  ProvidedFilesOnly
  Mixed
} derive(Show, Eq, ToJson, FromJson)

///|
pub struct DeskWorkspace {
  id : String
  name : String
  root_path : String
  kind : WorkspaceKind
  status : WorkspaceStatus
  last_seen_at : String?
} derive(Show, Eq, ToJson, FromJson)

///|
pub struct DeskFileEntry {
  id : String
  workspace_id : String
  path : String
  display_name : String
  kind : EntryKind
  source_layer : SourceLayer
  readable : Bool
  writable : Bool
  size_bytes : Int?
  modified_at : String?
} derive(Show, Eq, ToJson, FromJson)

///|
pub struct DeskPreview {
  entry_id : String
  renderer : PreviewRenderer
  title : String
  body : String
  metadata : Map[String, String]
  warnings : Array[String]
} derive(Show, Eq, ToJson, FromJson)

///|
pub struct DeskTaskSubmission {
  id : String
  target_book_id : String
  title : String
  prompt : String
  context_entries : Array[String]
  cadence : SubmissionCadence
  quality_threshold : Int
  source_policy : SourcePolicy
  created_at : String
} derive(Show, Eq, ToJson, FromJson)

///|
pub struct DeskRunArtifact {
  id : String
  path : String
  title : String
  kind : EntryKind
} derive(Show, Eq, ToJson, FromJson)

///|
pub struct DeskRunProjection {
  run_id : String
  book_id : String
  goal_id : String?
  status : String
  phase : String
  summary : String
  artifacts : Array[DeskRunArtifact]
  started_at : String?
  updated_at : String?
} derive(Show, Eq, ToJson, FromJson)
