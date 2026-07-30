///|
async fn open_workspace_office(
  workspace : @desk.DeskWorkspace,
  path : String,
) -> Result[(String, OfficeDocumentModel), String] {
  let relative = decode_query_value(path)
  let (absolute, clean) = match
    resolve_workspace_existing_path(workspace.root_path, relative) {
    Some(value) => value
    None =>
      return Err("Office path is missing or outside the selected workspace")
  }
  if is_directory(absolute) {
    return Err("Office path does not name a file")
  }
  let bytes = @fs.read_file(absolute).binary().to_fixedarray() catch {
      _ => return Err("Office document could not be read")
    }
  match office_document_open_bytes(clean, bytes) {
    Ok(document) => Ok((clean, document))
    Err(error) => Err(error)
  }
}

///|
fn office_kind_json(kind : OfficeDocumentKind) -> Json {
  match kind {
    Docx => "docx"
    Xlsx => "xlsx"
    Pptx => "pptx"
  }
}

///|
fn office_supported_json(model : OfficeSupportedModel) -> Json {
  match model {
    Word(paragraphs) =>
      {
        "paragraphs": paragraphs.map(paragraph => {
          (
            {
              "runs": paragraph.runs.map(run => {
                (
                  {
                    "text": run.text,
                    "bold": run.bold,
                    "italic": run.italic,
                    "underline": run.underline,
                  } : Json)
              }),
            } : Json)
        }),
      }
    Spreadsheet(sheets) =>
      {
        "sheets": sheets.map(sheet => {
          (
            {
              "part": sheet.part,
              "name": sheet.name,
              "cells": sheet.cells.map(cell => {
                (
                  {
                    "reference": cell.reference,
                    "value": cell.value,
                    "formula": match cell.formula {
                      Some(value) => Json::string(value)
                      None => Json::null()
                    },
                  } : Json)
              }),
            } : Json)
        }),
      }
    Presentation(slides) =>
      {
        "slides": slides.map(slide => {
          (
            {
              "part": slide.part,
              "objects": slide.objects.map(object => {
                (
                  {
                    "text": object.text,
                    "x": match object.x {
                      Some(value) => Json::number(value.to_double())
                      None => Json::null()
                    },
                    "y": match object.y {
                      Some(value) => Json::number(value.to_double())
                      None => Json::null()
                    },
                    "width": match object.width {
                      Some(value) => Json::number(value.to_double())
                      None => Json::null()
                    },
                    "height": match object.height {
                      Some(value) => Json::number(value.to_double())
                      None => Json::null()
                    },
                  } : Json)
              }),
            } : Json)
        }),
      }
  }
}

///|
fn office_document_json(
  path : String,
  document : OfficeDocumentModel,
  baseline : BytesView,
) -> Json {
  {
    "ok": true,
    "path": path,
    "kind": office_kind_json(document.kind),
    "model": office_supported_json(document.supported),
    "warnings": document.warnings,
    "baseline": @base64.encode(baseline),
  }
}

///|
async fn handle_workspace_office_open(
  workspace_root : String,
  workspace_id : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let workspace = match find_workspace(workspace_root, workspace_id) {
    Some(value) => value
    None => {
      send_api_error(conn, method_, 404, "Not Found", "Unknown workspace")
      return
    }
  }
  let path = query_value(request_path, "path").unwrap_or("")
  match open_workspace_office(workspace, path) {
    Ok((clean, document)) => {
      let absolute = @pathx.join(workspace.root_path, clean)
      let baseline = @fs.read_file(absolute).binary()
      send_json(
        conn,
        method_,
        office_document_json(clean, document, baseline.view()),
      )
    }
    Err(error) => send_api_error(conn, method_, 400, "Bad Request", error)
  }
}

///|
async fn handle_workspace_office_export(
  workspace_root : String,
  workspace_id : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let workspace = match find_workspace(workspace_root, workspace_id) {
    Some(value) => value
    None => {
      send_api_error(conn, method_, 404, "Not Found", "Unknown workspace")
      return
    }
  }
  let relative = decode_query_value(
    query_value(request_path, "path").unwrap_or(""),
  )
  match resolve_workspace_existing_path(workspace.root_path, relative) {
    Some((absolute, clean)) =>
      if office_document_kind(clean) is Some(_) &&
        @fs.exists(absolute) &&
        !is_directory(absolute) {
        let bytes = @fs.read_file(absolute).binary()
        if office_document_open_bytes(clean, bytes.to_fixedarray()) is Ok(_) {
          send_file(conn, method_, absolute, 200, "OK")
        } else {
          send_api_error(
            conn, method_, 415, "Unsupported Media Type", "Saved file is not a supported Office package",
          )
        }
      } else {
        send_api_error(
          conn, method_, 404, "Not Found", "Office document not found",
        )
      }
    None =>
      send_api_error(
        conn, method_, 400, "Bad Request", "Office path is outside the selected workspace",
      )
  }
}

///|
fn apply_workspace_office_edit(
  document : OfficeDocumentModel,
  payload : Json,
) -> Result[OfficeDocumentModel, String] {
  let operation = json_string(payload, "operation", default="")
  match operation {
    "docx-paragraph" => {
      let text = json_string(payload, "text", default="")
      let bold = @mooncore.json_bool(payload, "bold", default=false)
      let italic = @mooncore.json_bool(payload, "italic", default=false)
      let underline = @mooncore.json_bool(payload, "underline", default=false)
      guard document.supported is Word(paragraphs) else {
        return Err("Not a DOCX document")
      }
      let index = json_int(payload, "paragraph", default=-1)
      let run_index = json_int(payload, "run", default=0)
      if index < 0 || index >= paragraphs.length() {
        return Err("DOCX paragraph is outside the supported model")
      }
      if run_index < 0 || run_index >= paragraphs[index].runs.length() {
        return Err("DOCX run is outside the supported model")
      }
      office_document_set_docx_run(document, index, run_index, {
        text,
        bold,
        italic,
        underline,
      })
    }
    "xlsx-cell" =>
      office_document_set_xlsx_cell(
        document,
        json_string(payload, "sheet_part", default=""),
        json_string(payload, "reference", default=""),
        json_string(payload, "value", default=""),
        json_string_opt(payload, "formula"),
      )
    "pptx-object" =>
      office_document_set_pptx_object(
        document,
        json_string(payload, "slide_part", default=""),
        json_int(payload, "object", default=-1),
        {
          text: json_string(payload, "text", default=""),
          x: Some(json_int(payload, "x", default=0)),
          y: Some(json_int(payload, "y", default=0)),
          width: Some(json_int(payload, "width", default=0)),
          height: Some(json_int(payload, "height", default=0)),
        },
      )
    _ => Err("Unsupported Office edit operation")
  }
}

///|
async fn save_workspace_office(
  workspace : @desk.DeskWorkspace,
  path : String,
  baseline : String,
  payload : Json,
) -> Result[Json, Json] {
  let (clean, document) = match open_workspace_office(workspace, path) {
    Ok(value) => value
    Err(error) =>
      return Err({ "code": 400, "reason": "Bad Request", "error": error })
  }
  let expected = @base64.decode(baseline) catch {
    _ =>
      return Err({
        "code": 400,
        "reason": "Bad Request",
        "error": "Office save baseline is not valid base64",
      })
  }
  let edited = match apply_workspace_office_edit(document, payload) {
    Ok(value) => value
    Err(error) =>
      return Err({
        "code": 422,
        "reason": "Unprocessable Content",
        "error": error,
      })
  }
  let saved_fixed = office_document_save_bytes(edited)
  let saved = Bytes::from_array(saved_fixed.view())
  let authority_root = workspace_authority_root(workspace.root_path, clean)
  let authority_relative = workspace_authority_relative(clean)
  match
    @fsx.compare_and_write_confined_bytes(
      authority_root,
      authority_relative,
      expected,
      saved.view(),
    ) {
    SavedBytes => Ok(office_document_json(clean, edited, saved.view()))
    ConflictBytes(current) =>
      Err({
        "code": 409,
        "reason": "Conflict",
        "error": "Office document changed after this editor was opened",
        "current_baseline": @base64.encode(current),
      })
    InvalidBytesTarget =>
      Err({
        "code": 400,
        "reason": "Bad Request",
        "error": "Office path is outside the selected workspace",
      })
    BytesWriteFailed =>
      Err({
        "code": 500,
        "reason": "Internal Server Error",
        "error": "Office save failed; the editor draft is preserved",
      })
  }
}

///|
async fn handle_workspace_office_save(
  workspace_root : String,
  workspace_id : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let workspace = match find_workspace(workspace_root, workspace_id) {
    Some(value) => value
    None => {
      send_api_error(conn, method_, 404, "Not Found", "Unknown workspace")
      return
    }
  }
  let payload = match read_json_body(body) {
    Some(value) => value
    None => {
      send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
      return
    }
  }
  match
    save_workspace_office(
      workspace,
      json_string(payload, "path", default=""),
      json_string(payload, "baseline", default=""),
      payload,
    ) {
    Ok(saved) => send_json(conn, method_, saved)
    Err(error) =>
      send_api_json_error(
        conn,
        method_,
        json_int(error, "code", default=400),
        json_string(error, "reason", default="Bad Request"),
        error,
      )
  }
}
