# JSON Lines tasks for a saved creator

Open Pack Home → specialist builder and reopen an unchanged saved creator with a task form. Choose **Import local JSON Lines task records** to use exported annotations, text records or API results as creator inputs.

The supported source is UTF-8 `.jsonl`/`.ndjson`: one nonempty flat JSON object per physical line. Every record must have the same 1–32 fields, all values must be strings, and field names must be nonblank and distinct (including after whitespace trimming). Field order may differ. The limit is 100 records and 512 KiB for both input and resulting table. One trailing newline and a leading UTF-8 BOM are accepted. Empty lines, duplicate decoded keys, nested objects, arrays, numbers, booleans and null are refused rather than silently coerced or flattened. Correct those records explicitly in the originating tool.

Try `samples/creator-jsonl/tasks.jsonl` with a creator task form such as `Explain {{topic}} for {{audience}}`. Map `topic` to `subject` and `audience` to `reader`. Click **Inspect CSV tasks**. Correct the intentionally blank subject in the third task using the ordinary row editor, then select the row and review its exact brief. **Prepare selected CSV task in chat** uses existing Book checks and unsent-work guards. It does not send or execute a task.

JSON string escapes decode into literal task text: leading zeroes, formulas, Unicode, embedded newlines and template-like text are preserved. Imported records become the existing editable CSV table; CSV row 2 corresponds to JSONL line 1. No field is auto-mapped. Unmapped fields remain in the table. The displayed filename gains `.csv` to make this conversion explicit.

Save a task checkpoint, clear the table and restore the checkpoint against the exact same saved creator. Mappings and applied corrections persist; inspect and select again before preparing. Checkpoints preserve decoded table values, not original JSON spelling, whitespace or key order. Keep the original JSONL file if exact input bytes are needed. Task-only files and observed responses remain separate under existing checkpoint rules.

This is local authoring, not an API connection, automatic batch run or success receipt. Review task data before sharing checkpoint files. The automated mounted-control tests cover actual controller and event flow with a minimal DOM adapter, not browser rendering or native installed integration.
