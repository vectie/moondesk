///|
fn moonflow_composition_item_by_id(
  items : ArrayView[MoonFlowCompositionItem],
  item_id : String,
) -> MoonFlowCompositionItem? {
  for item in items {
    if item.work_item_id == item_id {
      return Some(item)
    }
  }
  None
}

///|
fn moonflow_composition_depth(
  items : ArrayView[MoonFlowCompositionItem],
  item_id : String,
  trail : Array[String],
) -> Int {
  if trail.contains(item_id) {
    return 0
  }
  match moonflow_composition_item_by_id(items, item_id) {
    None => 0
    Some(item) => {
      let next_trail = trail.copy()
      next_trail.push(item_id)
      let mut depth = 0
      for dependency in item.depends_on {
        let candidate = moonflow_composition_depth(
          items, dependency, next_trail,
        ) + 1
        if candidate > depth {
          depth = candidate
        }
      }
      depth
    }
  }
}

///|
fn moonflow_composition_dependents(
  composition : MoonFlowComposition,
  item_id : String,
) -> Array[String] {
  composition.items.filter(item => {
    composition.selected_item_ids.contains(item.work_item_id) &&
    item.depends_on.contains(item_id)
  }).map(item => item.work_item_id)
}

///|
fn moonflow_composition_can_toggle(
  composition : MoonFlowComposition,
  item : MoonFlowCompositionItem,
) -> Bool {
  if !composition.selected_item_ids.contains(item.work_item_id) {
    item.depends_on.all(dependency => {
      composition.selected_item_ids.contains(dependency)
    })
  } else {
    moonflow_composition_dependents(composition, item.work_item_id).is_empty()
  }
}

///|
fn moonflow_composition_products(
  composition : MoonFlowComposition,
) -> Array[String] {
  let products : Array[String] = []
  for item in composition.items {
    if !products.contains(item.product_id) {
      products.push(item.product_id)
    }
  }
  products
}

///|
fn moonflow_product_selected(
  composition : MoonFlowComposition,
  product_id : String,
) -> Bool {
  composition.items.any(item => {
    item.product_id == product_id &&
    composition.selected_item_ids.contains(item.work_item_id)
  })
}

///|
fn render_moonflow_canvas_node(
  dispatch : Dispatch[Msg],
  composition : MoonFlowComposition,
  item : MoonFlowCompositionItem,
) -> @rabbita.Html {
  let selected = composition.selected_item_ids.contains(item.work_item_id)
  let can_toggle = moonflow_composition_can_toggle(composition, item)
  let dependents = moonflow_composition_dependents(
    composition, item.work_item_id,
  )
  article(
    class="flow-canvas-node " + (if selected { "included" } else { "excluded" }),
    attrs=@html.Attrs::build()
      .data_set("work-item-id", item.work_item_id)
      .data_set("product-id", item.product_id),
    [
      div(class="flow-canvas-node-head", [
        span(class="flow-canvas-product", item.product_id),
        span(
          class="flow-item-status " + (if selected { "ready" } else { "blocked" }),
          if selected { "included" } else { "excluded" },
        ),
      ]),
      strong(item.work_item_id),
      small(item.operation + " · " + item.requested_authority),
      if item.depends_on.is_empty() {
        small(class="flow-canvas-root", "Starts this branch")
      } else {
        div(
          class="flow-canvas-connections",
          item.depends_on.map(dependency => span("← " + dependency)),
        )
      },
      button(
        class="secondary-button compact-button flow-node-toggle",
        attrs=@html.Attrs::build()
          .aria_pressed(if selected { "true" } else { "false" })
          .aria_label(
            (if selected { "Exclude " } else { "Include " }) +
            item.product_id + " work item " + item.work_item_id,
          ),
        disabled=!can_toggle,
        on_click=dispatch(ToggleMoonFlowCompositionItem(item.work_item_id)),
        if selected { "Exclude from job" } else { "Include in job" },
      ),
      if can_toggle {
        @html.nothing
      } else if selected {
        small(
          class="flow-canvas-lock",
          "Required by " + dependents.join(", "),
        )
      } else {
        small(
          class="flow-canvas-lock",
          "Include dependencies first: " + item.depends_on.join(", "),
        )
      },
    ],
  )
}

///|
fn render_moonflow_canvas_columns(
  dispatch : Dispatch[Msg],
  composition : MoonFlowComposition,
) -> Array[@rabbita.Html] {
  let max_depth = composition.items.fold(init=0, fn(maximum, item) {
    let depth = moonflow_composition_depth(
      composition.items, item.work_item_id, [],
    )
    if depth > maximum { depth } else { maximum }
  })
  let columns : Array[@rabbita.Html] = []
  for depth = 0; depth <= max_depth; depth = depth + 1 {
    let at_depth = composition.items.filter(item => {
      moonflow_composition_depth(composition.items, item.work_item_id, []) == depth
    })
    columns.push(
      section(class="flow-canvas-column", [
        header([
          span("Stage \{depth + 1}"),
          small("\{at_depth.length()} node(s)"),
        ]),
        div(
          class="flow-canvas-column-nodes",
          at_depth.map(item => {
            render_moonflow_canvas_node(dispatch, composition, item)
          }),
        ),
      ]),
    )
  }
  columns
}

///|
fn render_moonflow_product_palette(
  model : Model,
  composition : MoonFlowComposition,
) -> @rabbita.Html {
  let declared = moonflow_composition_products(composition)
  let rows : Array[@rabbita.Html] = []
  for product in model.moonsuite_products {
    let id = product.name.to_lower()
    let in_graph = declared.any(value => value.to_lower() == id)
    let selected = declared.any(value => {
      value.to_lower() == id && moonflow_product_selected(composition, value)
    })
    rows.push(
      li([
        div([strong(product.name), small(product.status)]),
        span(
          class="flow-palette-state " + (if selected { "included" } else { "" }),
          if selected {
            "In this job"
          } else if in_graph {
            "Available, excluded"
          } else {
            "Not declared by this pack"
          },
        ),
      ]),
    )
  }
  for product_id in declared {
    let registered = model.moonsuite_products.any(product => {
      product.name.to_lower() == product_id.to_lower()
    })
    if !registered {
      let selected = moonflow_product_selected(composition, product_id)
      rows.push(
        li([
          div([strong(product_id), small("adapter not installed")]),
          span(
            class="flow-palette-state " + (if selected { "included" } else { "" }),
            if selected {
              "In job · adapter missing"
            } else {
              "Declared · adapter missing"
            },
          ),
        ]),
      )
    }
  }
  aside(class="flow-product-palette", [
    div(class="flow-section-heading", [
      h3("Products"),
      small("\{composition.selected_item_ids.length()} / \{composition.items.length()} nodes"),
    ]),
    p(
      "The pack declares what each node can do. You decide which declared nodes enter the next run.",
    ),
    ul(rows),
  ])
}

///|
fn render_moonflow_control_plane() -> @rabbita.Html {
  section(class="flow-control-plane", [
    div([strong("MoonDesk"), small("canvas + operator control")]),
    span("→"),
    div([strong("MoonFlow"), small("durable graph executor")]),
    span("→"),
    div([strong("MoonClaw"), small("single agent runtime")]),
  ])
}

///|
fn render_moonflow_composition_canvas(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  match model.moonflow_composition {
    None =>
      section(class="flow-composer-empty", [
        div([strong("Composition canvas"), small(model.moonflow_composition_status)]),
        p(
          "Add a typed Work graph to this MoonBook. MoonDesk will visualize every product and connection here without absorbing its domain logic.",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(SelectWorkspaceMode(MoonWiki)),
          "Open executable document",
        ),
      ])
    Some(composition) => {
      let zoom_class = "zoom-" + model.moonflow_canvas_zoom.to_string()
      section(
        class="flow-composer",
        attrs=@html.Attrs::build().data_set("testid", "moonflow-composition-canvas"),
        [
          header(class="flow-composer-head", [
            div([
              p(class="eyebrow", "Suite composition"),
              h2("Job canvas"),
              p(
                "Select products, inspect typed connections, then save a digest-bound composition for the next run.",
              ),
            ]),
            div(class="flow-canvas-toolbar", [
              button(
                class="secondary-button compact-button",
                attrs=@html.Attrs::build().aria_label("Zoom out composition canvas"),
                disabled=model.moonflow_canvas_zoom <= 75,
                on_click=dispatch(SetMoonFlowCanvasZoom(model.moonflow_canvas_zoom - 25)),
                "−",
              ),
              span("\{model.moonflow_canvas_zoom}%"),
              button(
                class="secondary-button compact-button",
                attrs=@html.Attrs::build().aria_label("Zoom in composition canvas"),
                disabled=model.moonflow_canvas_zoom >= 125,
                on_click=dispatch(SetMoonFlowCanvasZoom(model.moonflow_canvas_zoom + 25)),
                "+",
              ),
              button(
                class="primary-button compact-button",
                disabled=model.moonflow_composition_saving ||
                  composition.selected_item_ids.is_empty(),
                on_click=dispatch(SaveMoonFlowComposition),
                if model.moonflow_composition_saving {
                  "Saving…"
                } else {
                  "Save composition"
                },
              ),
            ]),
          ]),
          render_moonflow_control_plane(),
          div(class="flow-composer-layout", [
            render_moonflow_product_palette(model, composition),
            div(
              class="flow-canvas-viewport",
              attrs=@html.Attrs::build()
                .tabindex(0)
                .role("region")
                .aria_label("Scrollable MoonSuite job composition canvas"),
              [
                div(
                  class="flow-canvas-surface " + zoom_class,
                  render_moonflow_canvas_columns(dispatch, composition),
                ),
              ],
            ),
          ]),
          div(class="flow-composer-foot", [
            small(
              attrs=@html.Attrs::build().role("status").aria_live("polite"),
              model.moonflow_composition_status,
            ),
            button(
              class="quiet-button",
              on_click=dispatch(SelectWorkspaceMode(MoonWiki)),
              "Edit node contracts and connections in MoonWiki",
            ),
          ]),
          details(class="flow-canvas-list-alternative", [
            summary("Accessible connection list"),
            ul(
              composition.items.map(item => {
                li(
                  item.product_id + " / " + item.work_item_id +
                  (if item.depends_on.is_empty() {
                    " starts a branch"
                  } else {
                    " depends on " + item.depends_on.join(", ")
                  }),
                )
              }),
            ),
          ]),
        ],
      )
    }
  }
}
