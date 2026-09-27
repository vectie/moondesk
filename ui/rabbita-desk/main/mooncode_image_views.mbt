///|
fn mooncode_selected_model_accepts_images(model : Model) -> Bool {
  model.mooncode_image_models.contains(
    mooncode_selected_runtime_model(model, selected_mooncode_session(model)),
  )
}

///|
fn render_mooncode_image_tray(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  if model.mooncode_images.is_empty() {
    return @html.nothing
  }
  let chips : Array[@rabbita.Html] = []
  for index in 0..<model.mooncode_images.length() {
    let image = model.mooncode_images[index]
    let media_type = mooncode_transcript_part_string(image, "media_type")
    let data = mooncode_transcript_part_string(image, "data_base64")
    let name = mooncode_transcript_part_string(image, "name")
    let label = if name == "" { "Image \{index + 1}" } else { name }
    chips.push(
      div(class="mooncode-image-chip", [
        img(
          src="data:\{media_type};base64,\{data}",
          alt="",
          attrs=@html.Attrs::build(),
        ),
        span(label),
        button(
          class="mooncode-image-remove",
          attrs=@html.Attrs::build()
            .aria_label("Remove \{label}")
            .data_set("i18n", "code.remove_image")
            .data_set("i18n-aria-label", "code.remove_image_aria")
            .data_set(
              "i18n-params",
              Json::object({ "name": label.to_json() }).stringify(),
            )
            .data_set("testid", "mooncode-remove-image"),
          on_click=dispatch(RemoveMoonCodeImage(index)),
          disabled=model.mooncode_image_submit_pending,
          "Remove",
        ),
      ]),
    )
  }
  div(
    class="mooncode-image-tray",
    attrs=@html.Attrs::build()
      .data_set("testid", "mooncode-image-tray")
      .aria_label("Images attached to Code request")
      .data_set("i18n-aria-label", "code.image_tray_aria"),
    [
      if mooncode_selected_model_accepts_images(model) {
        @html.nothing
      } else {
        p(
          class="mooncode-image-compatibility",
          attrs=@html.Attrs::build()
            .role("status")
            .data_set("i18n", "code.image_compatibility"),
          "This model has not declared image input. Choose a vision-capable model before sending.",
        )
      },
      p(
        class="mooncode-image-help",
        attrs=@html.Attrs::build().data_set("i18n", "code.image_help"),
        "PNG, JPEG, or WebP · up to 4 images · 8 MB each",
      ),
      div(class="mooncode-image-chips", chips),
    ],
  )
}
