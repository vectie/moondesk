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
          ) +
          1
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
  composition.items
  .filter(item => {
    composition.selected_item_ids.contains(item.work_item_id) &&
    item.depends_on.contains(item_id)
  })
  .map(item => item.work_item_id)
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
fn flow_px(value : Double) -> String {
  value.to_int().to_string() + "px"
}

///|
fn flow_coord(value : Double) -> String {
  value.to_int().to_string()
}

///|
fn flow_zoom_text(zoom : Double) -> String {
  let scaled = (zoom * 100.0 + 0.5).to_int()
  let whole = scaled / 100
  let frac = scaled % 100
  if frac == 0 {
    whole.to_string()
  } else if frac % 10 == 0 {
    "\{whole}.\{frac / 10}"
  } else if frac < 10 {
    "\{whole}.0\{frac}"
  } else {
    "\{whole}.\{frac}"
  }
}

///|
fn flow_zoom_percent(model : Model) -> String {
  (model.flow_zoom * 100.0 + 0.5).to_int().to_string() + "%"
}

///|
fn render_flow_canvas_node(
  dispatch : Dispatch[Msg],
  model : Model,
  composition : MoonFlowComposition,
  item : MoonFlowCompositionItem,
) -> @rabbita.Html {
  let selected = composition.selected_item_ids.contains(item.work_item_id)
  let can_toggle = moonflow_composition_can_toggle(composition, item)
  let (x, y) = flow_item_position(
    model,
    composition.items[:],
    item.work_item_id,
  )
  let dragging = model.flow_drag_node_id == item.work_item_id
  let state_class = if selected { "included" } else { "excluded" }
  article(
    class="flow-node " + state_class + (if dragging { " dragging" } else { "" }),
    style=["left: " + flow_px(x), "top: " + flow_px(y)],
    attrs=@html.Attrs::build()
      .data_set("work-item-id", item.work_item_id)
      .data_set("product-id", item.product_id),
    [
      div(
        class="flow-node-grip",
        title="Drag to move this node",
        attrs=@html.Attrs::build()
          .aria_label("Move node " + item.work_item_id)
          .draggable("true")
          .on_mousedown(fn(event) {
            dispatch(
              FlowNodeDragStart(
                item.work_item_id,
                event.get_client_x(),
                event.get_client_y(),
              ),
            )
          })
          .on_dragstart(fn(event) {
            event.stop_propagation()
            dispatch(
              FlowNodeDragStart(
                item.work_item_id,
                event.get_client_x(),
                event.get_client_y(),
              ),
            )
          })
          .on_dragend(fn(_event) { dispatch(FlowPanEnd) }),
        [span("⠿")],
      ),
      div(class="flow-node-head", [
        span(class="flow-canvas-product", item.product_id),
        span(
          class="flow-item-status " + state_class,
          if selected {
            "Included"
          } else {
            "Excluded"
          },
        ),
      ]),
      strong(item.work_item_id),
      small(item.operation + " · " + item.requested_authority),
      button(
        class="secondary-button compact-button flow-node-toggle",
        attrs=@html.Attrs::build()
          .aria_pressed(if selected { "true" } else { "false" })
          .aria_label(
            (if selected { "Exclude " } else { "Include " }) +
            item.product_id +
            " work item " +
            item.work_item_id,
          ),
        disabled=!can_toggle,
        on_click=dispatch(ToggleMoonFlowCompositionItem(item.work_item_id)),
        if selected {
          "Exclude"
        } else {
          "Include"
        },
      ),
    ],
  )
}

///|
fn render_flow_canvas_edges(
  model : Model,
  composition : MoonFlowComposition,
) -> @rabbita.Html {
  let paths : Array[@svg.Svg] = []
  for item in composition.items {
    if item.depends_on.is_empty() {
      continue
    }
    let (tx, ty) = flow_item_position(
      model,
      composition.items[:],
      item.work_item_id,
    )
    let target_x = tx
    let target_y = ty + flow_node_height / 2.0
    for dependency in item.depends_on {
      let (sx, sy) = flow_item_position(model, composition.items[:], dependency)
      let source_x = sx + flow_node_width
      let source_y = sy + flow_node_height / 2.0
      let bend = 96.0
      let d = "M " +
        flow_coord(source_x) +
        " " +
        flow_coord(source_y) +
        " C " +
        flow_coord(source_x + bend) +
        " " +
        flow_coord(source_y) +
        ", " +
        flow_coord(target_x - bend) +
        " " +
        flow_coord(target_y) +
        ", " +
        flow_coord(target_x) +
        " " +
        flow_coord(target_y)
      let active = composition.selected_item_ids.contains(item.work_item_id) &&
        composition.selected_item_ids.contains(dependency)
      paths.push(
        @svg.path(
          class="flow-edge " + (if active { "active" } else { "muted" }),
          d~,
          fill="none",
        ),
      )
    }
  }
  @svg.svg(class="flow-edge-layer", width=4800, height=3200, paths)
}

///|
fn render_flow_product_palette(
  model : Model,
  composition : MoonFlowComposition,
) -> @rabbita.Html {
  let declared = moonflow_composition_products(composition)
  let rows : Array[@rabbita.Html] = []
  for product_id in declared {
    let registered = model.moonsuite_products.any(product => {
      product.name.to_lower() == product_id.to_lower()
    })
    let selected = moonflow_product_selected(composition, product_id)
    rows.push(
      li([
        span(class="status-dot " + (if selected { "live" } else { "idle" }), ""),
        div([
          strong(product_id),
          small(
            if !registered {
              "Adapter missing"
            } else if selected {
              "In this job"
            } else {
              "Available, excluded"
            },
          ),
        ]),
      ]),
    )
  }
  details(class="flow-palette-floating", [
    summary(
      "Products · \{composition.selected_item_ids.length()} / \{composition.items.length()} nodes",
    ),
    div(class="flow-palette-body", [
      p(
        "The pack declares what each node can do. You decide which declared nodes enter the next run.",
      ),
      ul(rows),
    ]),
  ])
}

///|
fn render_flow_canvas_chrome(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  div(class="flow-canvas-chrome", [
    div(class="flow-canvas-title", [
      strong("Composition canvas"),
      small(model.moonflow_composition_status),
    ]),
    div(class="flow-canvas-tools", [
      button(
        class="secondary-button compact-button",
        attrs=@html.Attrs::build().aria_label("Zoom out composition canvas"),
        disabled=model.flow_zoom <= flow_zoom_min + 0.001,
        on_click=dispatch(FlowCanvasWheel(0, 0, 1.0)),
        "−",
      ),
      span(class="flow-zoom-readout", flow_zoom_percent(model)),
      button(
        class="secondary-button compact-button",
        attrs=@html.Attrs::build().aria_label("Zoom in composition canvas"),
        disabled=model.flow_zoom >= flow_zoom_max - 0.001,
        on_click=dispatch(FlowCanvasWheel(0, 0, -1.0)),
        "+",
      ),
      button(
        class="secondary-button compact-button",
        title="Reset pan, zoom and node positions",
        on_click=dispatch(FlowCanvasReset),
        "Reset view",
      ),
      match model.moonflow_composition {
        Some(composition) =>
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
          )
        None => @html.nothing
      },
    ]),
  ])
}

///|
fn render_flow_canvas_viewport(
  dispatch : Dispatch[Msg],
  model : Model,
  children : Array[@rabbita.Html],
) -> @rabbita.Html {
  let surface_children : Array[@rabbita.Html] = children
  div(
    class="flow-viewport",
    attrs=@html.Attrs::build()
      .tabindex(0)
      .role("region")
      .aria_label("MoonFlow infinite composition canvas")
      .data_set("testid", "moonflow-composition-canvas")
      .draggable("true")
      .on_wheel(fn(event) {
        event.prevent_default()
        dispatch(
          FlowCanvasWheel(
            event.get_client_x(),
            event.get_client_y(),
            event.get_delta_y(),
          ),
        )
      })
      .on_mousedown(fn(event) {
        dispatch(FlowPanStart(event.get_client_x(), event.get_client_y()))
      })
      .on_dragstart(fn(event) {
        dispatch(FlowPanStart(event.get_client_x(), event.get_client_y()))
      })
      .on_dragover(fn(event) {
        event.prevent_default()
        dispatch(FlowPanMove(event.get_client_x(), event.get_client_y()))
      })
      .on_dragend(fn(_event) { dispatch(FlowPanEnd) })
      .on_mousemove(fn(event) {
        dispatch(FlowPanMove(event.get_client_x(), event.get_client_y()))
      })
      .on_mouseup(fn(_event) { dispatch(FlowPanEnd) })
      .on_mouseleave(fn(_event) { dispatch(FlowPanEnd) }),
    [
      div(
        class="flow-canvas-surface",
        style=[
          "transform: translate(" +
          flow_px(model.flow_pan_x) +
          ", " +
          flow_px(model.flow_pan_y) +
          ") scale(" +
          flow_zoom_text(model.flow_zoom) +
          ")",
        ],
        surface_children,
      ),
    ],
  )
}

///|
fn render_moonflow_composition_canvas(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(class="flow-composer flow-composer-infinite", [
    render_flow_canvas_chrome(dispatch, model),
    match model.moonflow_composition {
      None =>
        div(class="flow-composer-stage", [
          render_flow_canvas_viewport(dispatch, model, [
            div(class="flow-canvas-empty", [
              strong("No executable Work graph yet"),
              p(
                "Add a typed Work graph to this MoonBook. Every product and connection will appear on this canvas.",
              ),
              button(
                class="secondary-button",
                on_click=dispatch(SelectWorkspaceMode(MoonWiki)),
                "Open executable document",
              ),
            ]),
          ]),
        ])
      Some(composition) => {
        let nodes : Array[@rabbita.Html] = [
          render_flow_canvas_edges(model, composition),
        ]
        for item in composition.items {
          nodes.push(
            render_flow_canvas_node(dispatch, model, composition, item),
          )
        }
        div(class="flow-composer-stage", [
          render_flow_canvas_viewport(dispatch, model, nodes),
          render_flow_product_palette(model, composition),
          div(class="flow-canvas-hint", [
            span(
              "Drag empty space to pan · Scroll to zoom · Drag a node handle to rearrange",
            ),
            button(
              class="quiet-button",
              on_click=dispatch(SelectWorkspaceMode(MoonWiki)),
              "Edit node contracts in Wiki",
            ),
          ]),
        ])
      }
    },
  ])
}
