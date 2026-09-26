#!/usr/bin/env python3
"""Layer a built MoonDesk UI onto an existing, trusted OCI image export."""

from __future__ import annotations

import argparse
import gzip
import hashlib
import io
import json
import tarfile
from pathlib import Path


def blob(root: Path, contents: bytes, media_type: str) -> dict:
    digest = hashlib.sha256(contents).hexdigest()
    (root / "blobs" / "sha256" / digest).write_bytes(contents)
    return {"mediaType": media_type, "digest": f"sha256:{digest}", "size": len(contents)}


def read_json(root: Path, descriptor: dict) -> dict:
    path = root / "blobs" / "sha256" / descriptor["digest"].split(":", 1)[1]
    return json.loads(path.read_bytes())


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-oci", type=Path, required=True)
    parser.add_argument("--ui-dir", type=Path, required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--target-root", default="opt/moondesk/ui")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--work", type=Path, required=True)
    args = parser.parse_args()
    if not any(args.ui_dir.rglob("index.html")):
        parser.error("UI directory has no index.html")
    target_root = args.target_root.strip("/")
    if not target_root or ".." in target_root.split("/"):
        parser.error("target root must be a bounded image-relative path")
    if args.work.exists():
        parser.error("work directory already exists")
    args.work.mkdir(parents=True)
    with tarfile.open(args.base_oci) as archive:
        archive.extractall(args.work)

    index_path = args.work / "index.json"
    index = json.loads(index_path.read_text())
    if len(index["manifests"]) != 1:
        parser.error("base export must contain one image")
    manifest = read_json(args.work, index["manifests"][0])
    if manifest.get("mediaType") == "application/vnd.oci.image.index.v1+json":
        selected = next(
            (entry for entry in manifest["manifests"]
             if entry.get("platform") == {"architecture": "amd64", "os": "linux"}),
            None,
        )
        if selected is None:
            parser.error("base export has no linux/amd64 image")
        manifest = read_json(args.work, selected)
    config = read_json(args.work, manifest["config"])
    if config.get("architecture") != "amd64" or config.get("os") != "linux":
        parser.error("base image is not linux/amd64")

    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode="w") as layer:
        for source in sorted(args.ui_dir.rglob("*")):
            if not source.is_file() or source.name.startswith("._"):
                continue
            relative = source.relative_to(args.ui_dir)
            entry = tarfile.TarInfo(f"{target_root}/{relative.as_posix()}")
            entry.size = source.stat().st_size
            entry.mode = 0o644
            with source.open("rb") as handle:
                layer.addfile(entry, handle)
    raw = buffer.getvalue()
    manifest["layers"].append(
        blob(args.work, gzip.compress(raw, mtime=0),
             "application/vnd.oci.image.layer.v1.tar+gzip")
    )
    config["rootfs"]["diff_ids"].append(f"sha256:{hashlib.sha256(raw).hexdigest()}")
    manifest["config"] = blob(
        args.work, json.dumps(config, separators=(",", ":")).encode(),
        "application/vnd.oci.image.config.v1+json",
    )
    descriptor = blob(
        args.work, json.dumps(manifest, separators=(",", ":")).encode(),
        "application/vnd.oci.image.manifest.v1+json",
    )
    descriptor["annotations"] = {"org.opencontainers.image.ref.name": args.tag}
    index["manifests"] = [descriptor]
    index_path.write_text(json.dumps(index, separators=(",", ":")))
    with tarfile.open(args.output, "w") as archive:
        archive.add(args.work, arcname=".")
    print(f"image={args.tag} digest={descriptor['digest']}")


if __name__ == "__main__":
    main()
