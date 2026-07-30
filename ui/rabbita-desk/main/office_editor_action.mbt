///|
fn office_editor_action(
  dispatch : Dispatch[Msg],
  msg : OfficeEditorMsg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  let office_editor = update_office_editor(model.office_editor, msg)
  let next = { ..model, office_editor, }
  match msg {
    OfficeOpen | OfficeReopen | OfficeReloadConflict =>
      if office_editor.loading {
        (open_office_editor_cmd(dispatch, office_editor), next)
      } else {
        (@rabbita.none, next)
      }
    OfficeSave | OfficeReplaceConflict =>
      if office_editor.saving {
        (save_office_editor_cmd(dispatch, office_editor), next)
      } else {
        (@rabbita.none, next)
      }
    _ => (@rabbita.none, next)
  }
}

///|
fn open_office_editor_cmd(
  dispatch : Dispatch[Msg],
  state : OfficeEditorState,
) -> @rabbita.Cmd {
  @http.get(
    @desk.workspace_endpoint_url(state.workspace_id, "office") +
    "?path=" +
    state.path,
  ).expect_json(result => {
    dispatch(OfficeEditor(OfficeOpened(parse_office_editor_http(result))))
  })
}

///|
fn save_office_editor_cmd(
  dispatch : Dispatch[Msg],
  state : OfficeEditorState,
) -> @rabbita.Cmd {
  let body = office_editor_save_body(state)
  @http.post(@desk.workspace_endpoint_url(state.workspace_id, "office/save"))
  .with_json(body)
  .expect_json(result => {
    match result {
      Ok(payload) =>
        if json_field_int(payload, "code", default=0) == 409 {
          dispatch(
            OfficeEditor(
              OfficeConflict(
                json_field_string(payload, "current_baseline", default=""),
              ),
            ),
          )
        } else {
          dispatch(
            OfficeEditor(OfficeSaved(parse_office_editor_http(Ok(payload)))),
          )
        }
      Err(error) =>
        dispatch(
          OfficeEditor(OfficeSaved(parse_office_editor_http(Err(error)))),
        )
    }
  })
}

///|
fn office_editor_save_body(state : OfficeEditorState) -> Json {
  if state.draft_items.length() == 0 {
    return { "path": state.path, "baseline": state.saved_baseline }
  }
  let item = state.draft_items[state.selected]
  match state.document {
    Some(document) =>
      match document.kind {
        OfficeDocx =>
          {
            "path": state.path,
            "baseline": state.saved_baseline,
            "operation": "docx-paragraph",
            "paragraph": item.section_index,
            "run": item.item_index,
            "text": item.text,
            "bold": item.bold,
            "italic": item.italic,
            "underline": item.underline,
          }
        OfficeXlsx =>
          {
            "path": state.path,
            "baseline": state.saved_baseline,
            "operation": "xlsx-cell",
            "sheet_part": item.section,
            "reference": item.reference,
            "value": item.text,
            "formula": item.formula,
          }
        OfficePptx =>
          {
            "path": state.path,
            "baseline": state.saved_baseline,
            "operation": "pptx-object",
            "slide_part": item.section,
            "object": item.item_index,
            "text": item.text,
            "x": item.x,
            "y": item.y,
            "width": item.width,
            "height": item.height,
          }
      }
    None => { "path": state.path, "baseline": state.saved_baseline }
  }
}

///|
fn parse_office_editor_http(
  result : Result[Json, Error],
) -> Result[OfficeEditorDocument, String] {
  let payload = match result {
    Ok(value) => value
    Err(_) => return Err("Office request failed")
  }
  let path = json_field_string(payload, "path", default="")
  let baseline = json_field_string(payload, "baseline", default="")
  let kind = match json_field_string(payload, "kind", default="") {
    "" => {
      let message = json_field_string(payload, "message", default="")
      if message != "" {
        return Err(message)
      }
      let error = json_field_string(payload, "error", default="")
      if error != "" {
        return Err(error)
      }
      return Err("Unsupported Office response")
    }
    "docx" => OfficeDocx
    "xlsx" => OfficeXlsx
    "pptx" => OfficePptx
    _ => return Err("Unsupported Office response")
  }
  guard payload is { "model": model, .. } else {
    return Err("Office response has no structured model")
  }
  let items : Array[OfficeEditorItem] = []
  let warnings = match payload {
    { "warnings": Array(values), .. } =>
      values.filter_map(value => {
        match value {
          String(text) => Some(text)
          _ => None
        }
      })
    _ => []
  }
  match kind {
    OfficeDocx => {
      guard model is { "paragraphs": Array(paragraphs), .. } else {
        return Err("DOCX response has no paragraphs")
      }
      for paragraph_index, paragraph in paragraphs {
        guard paragraph is { "runs": Array(runs), .. } else { continue }
        for run_index, run in runs {
          items.push(
            office_editor_item_from_json(
              run,
              section="paragraph \{paragraph_index}",
              reference="run \{run_index}",
              section_index=paragraph_index,
              item_index=run_index,
            ),
          )
        }
      }
    }
    OfficeXlsx => {
      guard model is { "sheets": Array(sheets), .. } else {
        return Err("XLSX response has no sheets")
      }
      for sheet in sheets {
        let section = json_field_string(sheet, "part", default="")
        guard sheet is { "cells": Array(cells), .. } else { continue }
        for cell_index, cell in cells {
          items.push(
            office_editor_item_from_json(
              cell,
              section~,
              reference=json_field_string(cell, "reference", default=""),
              section_index=0,
              item_index=cell_index,
            ),
          )
        }
      }
    }
    OfficePptx => {
      guard model is { "slides": Array(slides), .. } else {
        return Err("PPTX response has no slides")
      }
      for slide in slides {
        let section = json_field_string(slide, "part", default="")
        guard slide is { "objects": Array(objects), .. } else { continue }
        for object_index, object in objects {
          items.push(
            office_editor_item_from_json(
              object,
              section~,
              reference="object \{object_index}",
              section_index=0,
              item_index=object_index,
            ),
          )
        }
      }
    }
  }
  Ok({ path, kind, items, warnings, baseline })
}

///|
fn office_editor_item_from_json(
  json : Json,
  section~ : String,
  reference~ : String,
  section_index~ : Int,
  item_index~ : Int,
) -> OfficeEditorItem {
  {
    section,
    reference,
    section_index,
    item_index,
    text: json_field_string(
      json,
      "text",
      default=json_field_string(json, "value", default=""),
    ),
    formula: json_field_string(json, "formula", default=""),
    bold: json_field_bool(json, "bold", default=false),
    italic: json_field_bool(json, "italic", default=false),
    underline: json_field_bool(json, "underline", default=false),
    x: json_field_int(json, "x", default=0),
    y: json_field_int(json, "y", default=0),
    width: json_field_int(json, "width", default=0),
    height: json_field_int(json, "height", default=0),
  }
}
