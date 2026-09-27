///|
fn mooncode_test_png_image() -> Json {
  {
    "type": "image",
    "media_type": "image/png",
    "data_base64": "iVBORw0KGgo=",
    "name": "screen.png",
  }
}

///|
test "Code image-only prompt remains a typed ordered command" {
  let submission = mooncode_prompt_with_images(
    {
      "action": "prompt",
      "client_turn_id": "turn-image",
      "message": "",
      "model": "moongate/vision",
    },
    "",
    [mooncode_test_png_image()],
  )
  let encoded = typed_mooncode_command_body(submission)
  assert_true(encoded is Ok(_))
  match encoded {
    Ok(body) =>
      match body {
        Object(fields) =>
          match fields.get("content_parts") {
            Some(Array(parts)) => assert_eq(parts.length(), 1)
            _ => fail("content_parts missing from image-only Code command")
          }
        _ => fail("Code command must be an object")
      }
    Err(_) => ()
  }
}

///|
#warnings("-alert_unstable")
test "Code image tray stays visible and removable" {
  let model = { ..init_model(), mooncode_images: [mooncode_test_png_image()], }
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_mooncode_image_tray(fn(_msg) { @rabbita.none }, model),
    ),
  )
  assert_true(markup.contains("mooncode-image-tray"))
  assert_true(markup.contains("screen.png"))
  assert_true(markup.contains("mooncode-remove-image"))
  let (_, removed) = update_mooncode_session_actions(
    fn(_msg) { @rabbita.none },
    RemoveMoonCodeImage(0),
    model,
  )
  assert_true(removed.mooncode_images.is_empty())
}

///|
#warnings("-alert_unstable")
test "Code composer exposes a directly clickable image file input" {
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_mooncode_center(fn(_msg) { @rabbita.none }, init_model()),
    ),
  )
  assert_true(markup.contains("mooncode-image-file-input"))
  assert_true(markup.contains("type=\"file\""))
  assert_true(markup.contains("image/png,image/jpeg,image/webp"))
  assert_true(markup.contains("multiple"))
}

///|
test "top-level Code handler routes image intake and removal" {
  let image = mooncode_test_png_image()
  let (_, attached) = update_mooncode_actions(
    fn(_msg) { @rabbita.none },
    MoonCodeImagesPicked(Ok([image])),
    init_model(),
  )
  assert_eq(attached.mooncode_images.length(), 1)
  let (_, removed) = update_mooncode_actions(
    fn(_msg) { @rabbita.none },
    RemoveMoonCodeImage(0),
    attached,
  )
  assert_true(removed.mooncode_images.is_empty())
}

///|
test "Code image model support requires declared catalog modality" {
  let parsed : MoonClawModel = @json.from_json({
    "name": "moongate/vision",
    "input_modalities": ["text", "image"],
  }) catch {
    _ => fail("model modality metadata should decode")
  }
  assert_true(parsed.input_modalities.unwrap_or([]).contains("image"))
  let model = {
    ..init_model(),
    mooncode_model: "moongate/vision",
    mooncode_models: ["moongate/vision"],
    mooncode_image_models: ["moongate/vision"],
    mooncode_images: [mooncode_test_png_image()],
  }
  assert_true(mooncode_selected_model_accepts_images(model))
  assert_false(
    mooncode_selected_model_accepts_images({
      ..model,
      mooncode_image_models: [],
    }),
  )
}

///|
#warnings("-alert_unstable")
test "canonical Code image uses a bounded same-origin media reference" {
  let parts : Array[Json] = [
    { "type": "text", "text": "Inspect this " },
    {
      "type": "image",
      "media_type": "image/png",
      "image_index": 1,
      "name": "screen.png",
    },
    { "type": "text", "text": "screenshot" },
  ]
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_mooncode_ordered_user_content("session-1", "cmd-1", parts),
    ),
  )
  assert_true(markup.contains("/api/mooncode/sessions/session-1/media/cmd-1/1"))
  assert_false(markup.contains("data:image"))
  assert_true(markup.contains("Inspect this "))
  assert_true(markup.contains("screenshot"))
}

///|
test "failed Code image submission restores the draft and attachments" {
  let model = {
    ..init_model(),
    mooncode_prompt: "",
    mooncode_images: [mooncode_test_png_image()],
    mooncode_draft_revision: 7,
    mooncode_image_submit_pending: true,
    mooncode_image_submit_revision: 7,
    mooncode_image_submit_prompt: "Inspect the screenshot",
  }
  let (_, retryable) = update_mooncode_session_results(
    fn(_msg) { @rabbita.none },
    CompletedMoonCodeCommand(Err("model does not support images")),
    model,
  )
  assert_eq(retryable.mooncode_prompt, "Inspect the screenshot")
  assert_eq(retryable.mooncode_images.length(), 1)
  assert_false(retryable.mooncode_image_submit_pending)
}
