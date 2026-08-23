///|
fn mooncode_sandbox_short_digest(value : String) -> String {
  if value.length() <= 16 {
    value
  } else {
    value[:12].to_owned() + "…" + value[value.length() - 4:].to_owned()
  }
}

///|
fn mooncode_sandbox_size_label(value : Int64?) -> String {
  match value {
    Some(bytes) if bytes >= 1_048_576L => "\{bytes / 1_048_576L} MiB"
    Some(bytes) if bytes >= 1_024L => "\{bytes / 1_024L} KiB"
    Some(bytes) => "\{bytes} B"
    None => "not retained"
  }
}

///|
fn mooncode_sandbox_change_label(change : String) -> String {
  match change {
    "Added" => "Added"
    "Modified" => "Modified"
    "Removed" => "Removed"
    _ => "Unsupported"
  }
}

///|
fn mooncode_sandbox_limits_label(
  limits : @mooncode_core.MoonCodeSandboxLimits,
) -> String {
  "\{limits.wall_clock_ms} ms wall · " +
  "\{limits.cpu_seconds} s CPU · " +
  "\{limits.memory_mib} MiB memory · " +
  "\{limits.disk_mib} MiB disk · " +
  "\{limits.processes} processes · " +
  "\{limits.output_bytes} B output"
}

///|
fn mooncode_sandbox_review_selected(
  model : Model,
  receipt : @mooncode_core.MoonCodeSandboxReceipt,
) -> Array[String] {
  if model.mooncode_sandbox_review_key == receipt.review_key() {
    model.mooncode_sandbox_selected_paths.filter(path => {
      receipt.changes.any(change => {
        change.promotable && change.relative_path == path
      })
    })
  } else {
    []
  }
}

///|
fn mooncode_sandbox_unavailable_reason(
  receipt : @mooncode_core.MoonCodeSandboxReceipt,
) -> String {
  if receipt.enforcement != "Enforced" {
    "Promotion requires an enforced sandbox receipt. This run was \{receipt.enforcement.to_lower()}."
  } else if !receipt.cleanup_verified {
    "Promotion is disabled because descendant cleanup was not verified."
  } else if receipt.unverified_limits.length() > 0 {
    "Promotion is disabled because these limits were not independently verified: " +
    receipt.unverified_limits.join(", ") +
    "."
  } else if receipt.retention_id is None {
    "Promotion is disabled because the sandbox did not retain an opaque scratch snapshot."
  } else if !receipt.changes.any(change => change.promotable) {
    "This receipt contains no retained regular files that can be promoted."
  } else {
    ""
  }
}

///|
fn render_mooncode_sandbox_receipt(
  dispatch : Dispatch[Msg],
  model : Model,
  receipt : @mooncode_core.MoonCodeSandboxReceipt,
) -> @rabbita.Html {
  let selected = mooncode_sandbox_review_selected(model, receipt)
  let key = receipt.review_key()
  let pending = model.mooncode_sandbox_review_key == key &&
    model.mooncode_sandbox_promotion_pending
  let locked = model.mooncode_sandbox_locked_review_keys.contains(key)
  let unavailable = mooncode_sandbox_unavailable_reason(receipt)
  let status = if model.mooncode_sandbox_review_key == key {
    model.mooncode_sandbox_promotion_status
  } else {
    ""
  }
  let change_rows : Array[@rabbita.Html] = []
  for change in receipt.changes {
    let checked = selected.contains(change.relative_path)
    change_rows.push(
      div(
        class="mooncode-sandbox-change " + change.change.to_lower(),
        attrs=@html.Attrs::build()
          .data_set("testid", "sandbox-change")
          .data_set("path", change.relative_path)
          .data_set("change", change.change),
        [
          button(
            class="mooncode-sandbox-file-toggle" +
              (if checked { " selected" } else { "" }),
            attrs=@html.Attrs::build()
              .aria_pressed(if checked { "true" } else { "false" })
              .aria_label(
                if change.promotable {
                  (if checked { "Remove " } else { "Select " }) +
                  change.relative_path +
                  " for promotion"
                } else {
                  change.relative_path + " cannot be promoted"
                },
              )
              .data_set("testid", "sandbox-file-toggle"),
            disabled=!change.promotable ||
              !receipt.promotion_ready() ||
              pending ||
              locked,
            on_click=dispatch(
              ToggleMoonCodeSandboxFile(receipt, change.relative_path),
            ),
            if checked {
              "Selected"
            } else {
              "Select"
            },
          ),
          div(class="mooncode-sandbox-change-copy", [
            div(class="mooncode-sandbox-change-heading", [
              code(change.relative_path),
              span(
                class="mooncode-sandbox-change-kind " + change.change.to_lower(),
                mooncode_sandbox_change_label(change.change),
              ),
            ]),
            small(
              mooncode_sandbox_size_label(change.after_size_bytes) +
              (match change.after_fingerprint {
                Some(digest) =>
                  " · after " + mooncode_sandbox_short_digest(digest)
                None => ""
              }),
            ),
          ]),
        ],
      ),
    )
  }
  let artifact_rows : Array[@rabbita.Html] = []
  for artifact in receipt.artifacts {
    artifact_rows.push(li(code(artifact)))
  }
  section(
    class="mooncode-sandbox-receipt",
    attrs=@html.Attrs::build()
      .aria_label("Execution sandbox receipt and promotion review")
      .data_set("testid", "sandbox-receipt")
      .data_set("backend", receipt.backend)
      .data_set("enforcement", receipt.enforcement)
      .data_set(
        "cleanup-verified",
        if receipt.cleanup_verified {
          "true"
        } else {
          "false"
        },
      ),
    [
      div(class="mooncode-sandbox-receipt-header", [
        div([
          p(class="eyebrow", "ExecutionSandbox receipt"),
          h3("Review retained changes"),
        ]),
        span(
          class="mooncode-sandbox-enforcement " + receipt.enforcement.to_lower(),
          receipt.enforcement +
          (if receipt.cleanup_verified { " · cleanup verified" } else { "" }),
        ),
      ]),
      div(class="mooncode-sandbox-facts", [
        div([
          span(class="mooncode-sandbox-fact-label", "Backend"),
          p(receipt.backend),
        ]),
        div([
          span(class="mooncode-sandbox-fact-label", "Network"),
          p(receipt.network),
        ]),
        div([
          span(class="mooncode-sandbox-fact-label", "Limits"),
          p(mooncode_sandbox_limits_label(receipt.limits)),
        ]),
        if receipt.unverified_limits.length() == 0 {
          @html.nothing
        } else {
          div([
            span(class="mooncode-sandbox-fact-label", "Unverified limits"),
            p(receipt.unverified_limits.join(", ")),
          ])
        },
        div([
          span(class="mooncode-sandbox-fact-label", "Profile digest"),
          p(code(receipt.profile_digest)),
        ]),
        div([
          span(class="mooncode-sandbox-fact-label", "Retention"),
          p(
            match receipt.retention_id {
              Some(value) =>
                "Opaque token " + mooncode_sandbox_short_digest(value)
              None => "Not retained"
            },
          ),
        ]),
      ]),
      if unavailable == "" {
        p(
          class="mooncode-sandbox-review-guidance",
          "Select exactly one reviewed file. Its canonical destination parent directory must already exist. MoonFort performs the promotion; MoonDesk never creates the parent or writes the file directly.",
        )
      } else {
        p(
          class="mooncode-sandbox-review-guidance unavailable",
          attrs=@html.Attrs::build().role("alert"),
          unavailable,
        )
      },
      div(
        class="mooncode-sandbox-change-list",
        attrs=@html.Attrs::build().aria_label("Structured file changes"),
        change_rows,
      ),
      if artifact_rows.length() == 0 {
        @html.nothing
      } else {
        @html.node(
          "details",
          @html.Attrs::build().class("mooncode-sandbox-artifacts"),
          [
            @html.node("summary", @html.Attrs::build(), [
              span("Artifacts · \{artifact_rows.length()}"),
            ]),
            ul(artifact_rows),
          ],
        )
      },
      div(class="mooncode-sandbox-promotion-actions", [
        span(
          class="mooncode-sandbox-selection-count",
          if selected.length() == 1 {
            "One file selected"
          } else {
            "No file selected"
          },
        ),
        button(
          class="mooncode-inline-action approve",
          attrs=@html.Attrs::build()
            .aria_label("Promote one reviewed sandbox file into this MoonBook")
            .data_set("testid", "sandbox-promote"),
          disabled=selected.length() != 1 ||
            !receipt.promotion_ready() ||
            pending ||
            locked,
          on_click=dispatch(PromoteMoonCodeSandboxReceipt(receipt)),
          if pending {
            "Promoting…"
          } else if locked {
            "Promotion locked"
          } else {
            "Promote reviewed file"
          },
        ),
      ]),
      if status == "" {
        @html.nothing
      } else {
        p(
          class="mooncode-sandbox-promotion-status",
          attrs=@html.Attrs::build()
            .role(if locked { "alert" } else { "status" })
            .aria_live("polite")
            .data_set("testid", "sandbox-promotion-status"),
          status,
        )
      },
    ],
  )
}
