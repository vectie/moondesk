///|
fn pack_status_label(status : String) -> String {
  match status {
    "configured" => "Ready"
    "workflow_only" => "Workflow only"
    "configuration_required" => "Setup required"
    "configuration_invalid" => "Configuration issue"
    _ => "Unavailable"
  }
}

///|
fn pack_status_class(status : String) -> String {
  match status {
    "configured" => "ready"
    "workflow_only" => "workflow"
    "configuration_required" => "setup"
    "configuration_invalid" => "blocked"
    _ => "blocked"
  }
}

///|
fn pack_default_description(pack : PackAppRecord) -> String {
  if pack.description.trim() != "" {
    pack.description
  } else {
    "An installed \{pack.kind} with \{pack.workflow_count} workflow(s), \{pack.tool_count} tool(s), and \{pack.entrypoint_count} app surface(s)."
  }
}

///|
fn pack_presentation_value(value : String?) -> String {
  match value {
    Some(value) => value.trim().to_owned()
    None => ""
  }
}

///|
fn pack_templates(pack : PackAppRecord) -> Array[PackTemplateRecord] {
  match pack.templates {
    Some(templates) => templates
    None => []
  }
}

///|
fn template_maturity_label(maturity : String) -> String {
  match maturity {
    "production" => "Production"
    "live-qualified" => "Live qualified"
    "local-qualified" => "Local qualified"
    "fixture" => "Fixture"
    _ => "Unqualified"
  }
}

///|
fn template_maturity_class(maturity : String) -> String {
  match maturity {
    "production" => "ready"
    "live-qualified" => "ready"
    "local-qualified" => "local"
    _ => "fixture"
  }
}

///|
fn template_launch_url(
  pack : PackAppRecord,
  template : PackTemplateRecord,
) -> String {
  if pack.status != "configured" || pack.launch_url == "" {
    return ""
  }
  let separator = if pack.launch_url.contains("?") { "&" } else { "?" }
  pack.launch_url +
  separator +
  "template=" +
  template.template_id +
  "&template_version=" +
  template.version +
  "&template_catalog=" +
  template.catalog_id +
  "&template_catalog_version=" +
  template.catalog_version +
  "&template_catalog_digest=" +
  template.catalog_digest +
  "&template_source_digest=" +
  template.source_digest
}

///|
fn template_cost_label(template : PackTemplateRecord) -> String {
  match template.ceilings.cost.status {
    "known" => "Known cost ceiling"
    "estimate" => "Estimated cost ceiling"
    "not_applicable" => "No provider cost"
    _ => "Provider-dependent cost"
  }
}

///|
fn template_effect_label(template : PackTemplateRecord) -> String {
  if template.ceilings.external_effect {
    "External effects require authority"
  } else {
    "No external effect"
  }
}

///|
fn render_template_action(
  pack : PackAppRecord,
  template : PackTemplateRecord,
) -> @rabbita.Html {
  let launch_url = template_launch_url(pack, template)
  if launch_url != "" {
    a(
      class="primary-button link-button template-start-action",
      href=launch_url,
      attrs=@html.Attrs::build()
        .data_set("testid", "template-start")
        .data_set("template-id", template.template_id)
        .data_set("owner-product", template.owner_product)
        .aria_label(
          if template.recovery.blocked {
            "Inspect " + template.title + " in " + pack.display_name
          } else if template.maturity == "fixture" {
            "Preview " + template.title + " in " + pack.display_name
          } else {
            "Review " + template.title + " in " + pack.display_name
          },
        ),
      if template.recovery.blocked {
        "Inspect template"
      } else if template.maturity == "fixture" {
        "Preview in " + pack.display_name
      } else {
        "Review in " + pack.display_name
      },
    )
  } else {
    div(
      class="template-recovery",
      attrs=@html.Attrs::build().role("status").aria_live("polite"),
      [
      button(
        class="primary-button template-start-action",
        attrs=@html.Attrs::build()
          .data_set("testid", "template-start-disabled")
          .data_set("template-id", template.template_id),
        disabled=true,
        "Owner unavailable",
      ),
        small(pack.configuration_message + " Refresh after the owner service is available."),
      ],
    )
  }
}

///|
fn render_template_card(
  pack : PackAppRecord,
  template : PackTemplateRecord,
) -> @rabbita.Html {
  article(
    class="pack-template-card " + template_maturity_class(template.maturity),
    attrs=@html.Attrs::build()
      .data_set("testid", "pack-template-card")
      .data_set("template-id", template.template_id)
      .data_set("template-class", template.template_class)
      .data_set("template-maturity", template.maturity)
      .data_set("owner-product", template.owner_product),
    [
      header(class="template-card-header", [
        span(class="template-icon", attrs=@html.Attrs::build().aria_hidden("true"), template.icon),
        div([
          h3(template.title),
          small(pack.display_name + " · " + template.primary_user),
        ]),
        span(
          class="template-maturity " + template_maturity_class(template.maturity),
          template_maturity_label(template.maturity),
        ),
      ]),
      p(class="template-summary", template.summary),
      p(class="template-completion", [
        strong("Done when "),
        span(template.completion_statement),
      ]),
      div(class="template-guardrails", [
        span(template_cost_label(template)),
        span(template_effect_label(template)),
        span(
          if template.ceilings.review.required {
            "Review: " + template.ceilings.review.authority
          } else {
            "No review gate"
          },
        ),
      ]),
      if template.recovery.blocked {
        p(
          class="template-blocker",
          attrs=@html.Attrs::build().role("status").aria_live("polite"),
          template.recovery.reason,
        )
      } else {
        @html.nothing
      },
      div(class="template-card-actions", [
        render_template_action(pack, template),
        small(
          class="template-open-boundary",
          "Opening the owner does not create an instance or start execution.",
        ),
        details(class="template-details", [
          summary("Requirements and recovery"),
          div([
            p([strong("First action: "), span(template.primary_action)]),
            p(
              "\{template.requirements.operations.length()} typed operation(s) · \{template.requirements.schemas.length()} schema(s)",
            ),
            p([strong("Licensing: "), span(template.ceilings.licensing.note)]),
            p([
              strong("Migration: "),
              span(
                template.migration_policy.strategy +
                " · " +
                template.migration_policy.note,
              ),
            ]),
            p([
              strong("Qualification: "),
              span(
                "\{template.qualification_evidence_refs.length()} digest-bound evidence reference(s)",
              ),
            ]),
            p([strong("Preview: "), span(template.preview_ref)]),
            p([strong("If blocked: "), span(template.recovery.next_action)]),
            code(
              template.template_id +
              "@" +
              template.version +
              " · catalog " +
              template.catalog_digest +
              " · source " +
              template.source_digest,
            ),
          ]),
        ]),
      ]),
    ],
  )
}

///|
fn render_template_catalog(model : Model) -> @rabbita.Html {
  let cards : Array[@rabbita.Html] = []
  for pack in model.pack_apps {
    for template in pack_templates(pack) {
      cards.push(render_template_card(pack, template))
    }
  }
  if cards.is_empty() {
    @html.nothing
  } else {
    section(
      class="pack-template-section",
      attrs=@html.Attrs::build()
        .data_set("testid", "pack-template-catalog")
        .aria_label("New from template"),
      [
        header(class="pack-section-heading", [
          div([
            p(class="eyebrow", "Start with a proven shape"),
            h2("New from template"),
            p(
              "Choose an outcome. MoonDesk shows the limits and opens the owning product; the owner confirms inputs before creating an instance.",
            ),
          ]),
          span("\{cards.length()} available"),
        ]),
        div(class="pack-template-grid", cards),
      ],
    )
  }
}

///|
fn pack_area_value(value : String?) -> String {
  match value {
    Some(value) => value.trim().to_owned()
    None => ""
  }
}

///|
fn pack_has_declared_area(pack : PackAppRecord) -> Bool {
  pack_area_value(pack.area_id) != "" &&
  pack_area_value(pack.area_category) != "" &&
  pack_area_value(pack.area_label) != ""
}

///|
fn render_pack_area(pack : PackAppRecord) -> @rabbita.Html {
  if pack_has_declared_area(pack) {
    span(
      class="pack-area-label",
      attrs=@html.Attrs::build()
        .data_set("testid", "pack-area")
        .data_set("area-id", pack_area_value(pack.area_id))
        .data_set("area-category", pack_area_value(pack.area_category)),
      pack_area_value(pack.area_label),
    )
  } else {
    @html.nothing
  }
}

///|
fn render_pack_primary_action(pack : PackAppRecord) -> @rabbita.Html {
  if pack.status == "configured" && pack.launch_url != "" {
    a(
      class="primary-button link-button pack-open-action",
      href=pack.launch_url,
      attrs=@html.Attrs::build()
        .data_set("testid", "pack-open")
        .data_set("pack-id", pack.pack_id)
        .aria_label("Open " + pack.display_name),
      match pack.primary_action_label {
        Some(label) if label.trim() != "" => label
        _ => "Open pack"
      },
    )
  } else {
    button(
      class="primary-button pack-open-action",
      attrs=@html.Attrs::build()
        .data_set("testid", "pack-open-disabled")
        .data_set("pack-id", pack.pack_id),
      disabled=true,
      if pack.status == "workflow_only" {
        "No standalone app"
      } else {
        "Open unavailable"
      },
    )
  }
}

///|
fn render_pack_card(
  dispatch : Dispatch[Msg],
  model : Model,
  pack : PackAppRecord,
) -> @rabbita.Html {
  article(
    class="pack-product-card " + pack_status_class(pack.status),
    attrs=@html.Attrs::build()
      .data_set("testid", "pack-product-card")
      .data_set("pack-id", pack.pack_id)
      .data_set("pack-status", pack.status)
      .data_set("area-id", pack_area_value(pack.area_id))
      .data_set("area-category", pack_area_value(pack.area_category)),
    [
      header(class="pack-card-header", [
        div(class="pack-card-identity", [
          span(
            class="pack-mark",
            if pack_presentation_value(pack.presentation_icon) == "" {
              pack.pack_id
            } else {
              pack_presentation_value(pack.presentation_icon)
            },
          ),
          div([
            h2(pack.display_name),
            render_pack_area(pack),
            small("v" + pack.version + " · " + pack.kind),
          ]),
        ]),
        span(
          class="pack-state-label " + pack_status_class(pack.status),
          pack_status_label(pack.status),
        ),
      ]),
      p(class="pack-description", pack_default_description(pack)),
      ul(class="pack-capability-counts", [
        li([strong(pack.workflow_count.to_string()), span("workflows")]),
        li([strong(pack.tool_count.to_string()), span("tools")]),
        li([strong(pack.entrypoint_count.to_string()), span("app surfaces")]),
      ]),
      p(
        class="pack-configuration-message",
        attrs=@html.Attrs::build().role("status"),
        pack.configuration_message,
      ),
      div(class="pack-card-actions", [
        render_pack_primary_action(pack),
        details(class="pack-advanced-actions", [
          summary("Advanced controls"),
          div(class="pack-advanced-body", [
            button(
              class="secondary-button",
              disabled=model.selected_workspace_id == "",
              on_click=dispatch(SelectWorkspaceMode(MoonFlow)),
              "Inspect current composition",
            ),
            small(
              if model.selected_workspace_id == "" {
                "Select a MoonBook before inspecting an executable composition."
              } else {
                "Composition belongs to the selected MoonBook; this pack keeps its domain contracts."
              },
            ),
          ]),
        ]),
      ]),
    ],
  )
}

///|
fn render_pack_home(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  main_(
    class="pack-home-main",
    attrs=main_content_attrs(PackHome).data_set("testid", "pack-home"),
    [
      section(class="pack-home-hero", [
        div([
          p(class="eyebrow", "MoonSuite applications"),
          h1("What do you want to create?"),
          p(
            class="lead",
            "Start from a reviewed template or open an application directly. Domain decisions stay with the product that owns them.",
          ),
        ]),
        div(class="pack-home-summary", [
          strong("\{model.pack_apps.length()} installed"),
          span(model.pack_apps_status),
          button(
            class="secondary-button compact-button",
            attrs=@html.Attrs::build().data_set("testid", "pack-home-refresh"),
            on_click=dispatch(RefreshAll),
            "Refresh",
          ),
        ]),
      ]),
      render_template_catalog(model),
      if model.pack_apps.is_empty() {
        section(class="pack-home-empty", [
          strong("No domain packs are installed"),
          p(
            "Install a pack into this MoonSuite workspace. MoonDesk will discover its manifest without importing domain code.",
          ),
          button(
            class="secondary-button",
            on_click=dispatch(SelectWorkspaceMode(Desk)),
            "Browse MoonBooks",
          ),
        ])
      } else {
        section(class="pack-app-section", [
          header(class="pack-section-heading", [
            div([h2("Applications"), p("Open an owner workspace without starting a template.")]),
            span("\{model.pack_apps.length()} installed"),
          ]),
          section(
            class="pack-product-grid",
            attrs=@html.Attrs::build().aria_label("Installed MoonSuite packs"),
            model.pack_apps.map(pack => render_pack_card(dispatch, model, pack)),
          ),
        ])
      },
      render_collaboration_surface(dispatch, model),
      details(class="pack-runtime-details", [
        summary("How packs run"),
        div(class="pack-runtime-strip", [
          div([strong("Pack"), small("domain UI + contracts")]),
          span("→"),
          div([strong("MoonDesk"), small("operator control")]),
          span("→"),
          div([strong("MoonFlow"), small("durable execution")]),
          span("→"),
          div([strong("MoonClaw"), small("single agent runtime")]),
        ]),
        p(
          "Each pack owns its domain screens, schemas, policies, providers, and workflows. MoonDesk supplies generic launch, authority, evidence, review, and composition controls.",
        ),
      ]),
    ],
  )
}
