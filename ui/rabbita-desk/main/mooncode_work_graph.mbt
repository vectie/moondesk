///|
/// Render the canonical graph using the existing evidence cards and file action.
/// Batch branches mean selection, not ordering or inferred dependencies.
fn render_mooncode_work_content(
  dispatch : Dispatch[Msg],
  model : Model,
  row : MoonCodeActivityRow,
) -> @rabbita.Html {
  let nodes = json_field_json_array_items(row.graph, "nodes")
  if nodes.is_empty() {
    return div(class="mooncode-work-content", [
      if row.detail == "" {
        @html.nothing
      } else {
        pre(class="mooncode-activity-detail", row.detail)
      },
      render_mooncode_evidence_list(
        dispatch,
        model,
        row.session_id,
        row.evidence,
      ),
    ])
  }
  let operations : Map[String, Array[Json]] = Map([])
  let resources : Map[String, Array[Json]] = Map([])
  let evidence : Map[String, MoonCodeEvidenceRow] = Map([])
  let shown : Map[String, Bool] = Map([])
  let sources : Map[String, String] = Map([])
  for edge in json_field_json_array_items(row.graph, "edges") {
    if json_field_string(edge, "kind", default="") == "recalls" {
      sources[json_field_string(edge, "to", default="")] = json_field_string(
        edge,
        "from",
        default="",
      )
    }
  }
  for item in row.evidence {
    evidence[item.item_id] = item
  }
  for node in nodes {
    let kind = json_field_string(node, "kind", default="")
    let (index, key) = if kind == "operation" {
      (operations, json_field_string(node, "batch_id", default=""))
    } else if kind == "resource" {
      (resources, json_field_string(node, "operation_id", default=""))
    } else {
      continue
    }
    match index.get(key) {
      Some(items) => items.push(node)
      None => index[key] = [node]
    }
  }
  let groups : Array[@rabbita.Html] = []
  for batch in nodes {
    if json_field_string(batch, "kind", default="") != "batch" {
      continue
    }
    let batch_id = json_field_string(batch, "id", default="")
    let calls : Array[@rabbita.Html] = []
    for operation in operations.get(batch_id).unwrap_or([]) {
      let id = json_field_string(operation, "id", default="")
      let children : Array[@rabbita.Html] = []
      match evidence.get(id) {
        Some(item) => {
          shown[id] = true
          children.push(
            render_mooncode_evidence(dispatch, model, row.session_id, {
              ..item,
              path: "",
            }),
          )
        }
        None => {
          let status = json_field_string(operation, "status", default="")
          children.push(
            p(class="mooncode-graph-operation-title", [
              span(json_field_string(operation, "tool", default="")),
              span(
                attrs=@html.Attrs::build().data_set(
                  "i18n",
                  mooncode_work_status_i18n_key(status),
                ),
                status,
              ),
            ]),
          )
        }
      }
      for resource in resources.get(id).unwrap_or([]) {
        let path = json_field_string(resource, "path", default="")
        let version = json_field_string(resource, "fingerprint", default="")
        if path != "" {
          children.push(
            button(
              class="mooncode-graph-resource",
              attrs=@html.Attrs::build()
                .title(
                  if version == "" {
                    path
                  } else {
                    path + " · " + version
                  },
                )
                .data_set("resource-version", version),
              on_click=dispatch(OpenQuickPath(path)),
              path,
            ),
          )
        }
      }
      if sources.get(id) is Some(source) {
        children.push(
          @html.node(
            "a",
            @html.Attrs::build()
            .class("mooncode-graph-source")
            .href("#" + source)
            .data_set("i18n", "code.result_source"),
            [@html.text("Source result")],
          ),
        )
      }
      calls.push(
        div(
          class="mooncode-graph-operation",
          attrs=@html.Attrs::build().id(id),
          children,
        ),
      )
    }
    groups.push(
      div(class="mooncode-graph-batch", [
        p(class="mooncode-graph-step", [
          span(
            attrs=@html.Attrs::build().data_set("i18n", "code.execution_step"),
            "Step",
          ),
          span(json_field_int(batch, "step", default=0).to_string()),
        ]),
        div(class="mooncode-graph-branches", calls),
      ]),
    )
  }
  groups.push(
    render_mooncode_evidence_list(
      dispatch,
      model,
      row.session_id,
      row.evidence.filter(item => !shown.contains(item.item_id)),
    ),
  )
  div(
    class="mooncode-work-graph",
    attrs=@html.Attrs::build().data_set("testid", "mooncode-work-graph"),
    groups,
  )
}
