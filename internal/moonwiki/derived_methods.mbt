///|
pub extend OfficeDocumentKind with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend OfficeDocumentKind with Eq::{not_equal, equal}

///|
pub extend DocxRun with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend DocxRun with Eq::{not_equal, equal}

///|
pub extend DocxParagraph with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend DocxParagraph with Eq::{not_equal, equal}

///|
pub extend XlsxCell with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend XlsxCell with Eq::{not_equal, equal}

///|
pub extend XlsxSheet with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend XlsxSheet with Eq::{not_equal, equal}

///|
pub extend PptxTextObject with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend PptxTextObject with Eq::{not_equal, equal}

///|
pub extend PptxSlide with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend PptxSlide with Eq::{not_equal, equal}

///|
pub extend OfficeSupportedModel with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend OfficeSupportedModel with Eq::{not_equal, equal}

///|
pub extend WorkspaceContext with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend WorkspaceContext with Eq::{not_equal, equal}

///|
pub extend AgentPassportInventory with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend AgentPassportInventory with Eq::{not_equal, equal}

///|
pub extend OfficeDocumentModel with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend GitChangeProjection with ToJson::{to_json}

///|
pub extend GitRepositoryProjection with ToJson::{to_json}

///|
pub extend GitDiffProjection with ToJson::{to_json}
