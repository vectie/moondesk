# Package reports and apps with their assets

In the selected Book's **Experienced Book package** panel:

1. Open **Choose files** and browse to the folder containing the deliverable. For example, `outputs/demo` contains `index.html`, `css/main.css`, and `images/logo.svg`.
2. Enter a **Deliverable name**, then choose **Add named deliverable**. This captures the current folder as its layout root.
3. Choose each file's **Add to <name>** button. Folders are never selected recursively. Nested paths remain relative to the captured folder, so `index.html` can still refer to `css/main.css` and `images/logo.svg`.
4. Optionally choose one included file as a preview or app entrypoint. Click the selected control again to clear it. Removing that file clears those references automatically. These references do not execute an app.
5. Use the existing **Prepare local package** action, inspect all included members and exclusions, then **Download this exact package**. The package also carries the Book's normally included knowledge and identity content, not only the chosen deliverables.

To add another report or app, browse to its folder and create another named deliverable. **Browse its folder** returns to an existing deliverable's root. Two files with the same basename in different subfolders retain both paths. Conflicting destination paths, including case-only collisions, are rejected.

The existing individual **Add:** selections still create standalone outputs. They can be combined with named deliverables and an **accepted human result**. No extra acknowledgment is required for ordinary exports. A named deliverable must have a nonempty name and at least one selected file; remove an unwanted empty deliverable before preparing.

## Limits and recovery

- Up to 16 named deliverables and 128 selected files across named and standalone outputs; the existing 16 MiB per-member limit still applies
- Each group uses an internal stable `group-*` output ID. Display names can be changed before preparation. The Book's existing `portable/outputs/<artifact_id>/` layout and portable output manifest are unchanged
- Unprepared selections are tab-local. Refreshing the package list keeps them; switching Books clears them. A full page reload clears unsaved selections, while saved packages remain available under **Saved local packages**
- A timeout may leave a complete package. Use **Check saved package** to inspect the same preparation. Repeated Prepare clicks cannot start another preparation while one is pending. **Start a new preparation** is explicit
- Downloads retain the inspected package identity. Later edits or a new version require another explicit preparation

## Verified scope

Cloud tests exercise the production Desk reducer, rendered HTML, serialization and native preparation path. A synthetic app with CSS/SVG assets, a report with an SVG chart, a standalone file, and an unsigned accepted-human-result fixture pass through the unchanged actual MoonBook CLI, exact import, current-member verification, and MoonTown's actual read-only catalog/download functions. No sockets, real sharing, authentication, publication, provider calls, browser execution, installed Mac behavior, or cross-machine restore were tested. App/preview references remain inert in the existing Town viewer.
