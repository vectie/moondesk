# Portable creator task sample

`tasks.csv` is a UTF-8, three-column input file usable with a creator task form.
It includes a missing topic, a quoted comma, leading zeroes and literal template
syntax. No provider, download or installed native host is required for the
source/controller test; interactive use requires a configured Desk host and an
installed ready MoonBook.

1. Create and save a specialist against your installed Book. Use the task
   template `Compare {{topic}} for {{audience}}.` and any representative task.
2. Import `tasks.csv`. Map `topic` to column 2, **Subject**, and `audience` to
   column 1, **Reader**. Column 3 is intentionally unmapped.
3. Inspect, edit CSV row 2, enter `Pricing options` for its missing topic, and
   apply the correction. Save a task checkpoint to file.
4. Reload Desk, reopen the same saved creator and restore that downloaded file.
   Inspect and select row 2. The original topic is blank, its corrected value
   is `Pricing options`, and the task is `Compare Pricing options for Founder.`
5. If you choose to prepare it, ordinary Send remains a separate action.

Create the checkpoint with your own saved creator rather than importing a
fixture with a fabricated local creator ID. The sample's CSV is portable;
checkpoints deliberately require the exact local saved definition. Unmapped
Notes are excluded from the chat brief but included in the checkpoint's original
CSV. Review all columns before sharing the checkpoint file.
