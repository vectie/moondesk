#!/usr/bin/env python3
"""Add host-built Moon binaries and their matching glibc to an OCI base image.

Run on the x86_64 build host, then import the resulting OCI archive into
containerd. The input is a single-platform Ubuntu 20.04 OCI export; only the
three executables, generated UI, and their runtime libraries are added. Model
weights and workspace files are never packaged.
"""

from __future__ import annotations

import argparse
import gzip
import hashlib
import io
import json
import subprocess
import tarfile
from pathlib import Path


BINARIES = ("moondesk", "moonclaw", "moongate")
NSS_MODULES = (
    "/lib/x86_64-linux-gnu/libnss_dns.so.2",
    "/lib/x86_64-linux-gnu/libnss_files.so.2",
)
DLOPEN_LIBRARIES = (
    "/lib/x86_64-linux-gnu/libssl.so.1.1",
    "/lib/x86_64-linux-gnu/libcrypto.so.1.1",
)


def ldd_closure(binary: Path) -> set[Path]:
    output = subprocess.run(
        ["ldd", str(binary)], check=True, capture_output=True, text=True
    ).stdout
    libraries = set()
    for line in output.splitlines():
        left, separator, right = line.partition("=>")
        name = (right if separator else left).strip().split(" ")[0]
        if name.startswith("/"):
            libraries.add(Path(name))
    return libraries


def append_blob(root: Path, contents: bytes) -> dict:
    digest = hashlib.sha256(contents).hexdigest()
    (root / "blobs" / "sha256" / digest).write_bytes(contents)
    return {"digest": f"sha256:{digest}", "size": len(contents)}


def read_blob(root: Path, descriptor: dict) -> dict:
    digest = descriptor["digest"].split(":", 1)[1]
    return json.loads((root / "blobs" / "sha256" / digest).read_bytes())


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-oci", type=Path, required=True)
    parser.add_argument("--binary-dir", type=Path, required=True)
    parser.add_argument("--ui-dir", type=Path, required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--work", type=Path, required=True)
    parser.add_argument("--extra-binary", type=Path)
    args = parser.parse_args()
    for name in BINARIES:
        if not (args.binary_dir / name).is_file():
            parser.error(f"missing {args.binary_dir / name}")
    if not (args.ui_dir / "index.html").is_file():
        parser.error(f"missing {args.ui_dir / 'index.html'}")
    if args.work.exists():
        parser.error(f"work directory already exists: {args.work}")
    args.work.mkdir(parents=True)
    with tarfile.open(args.base_oci) as archive:
        # The base archive is a trusted, locally exported containerd image.
        archive.extractall(args.work)

    index_path = args.work / "index.json"
    index = json.loads(index_path.read_text())
    if len(index["manifests"]) != 1:
        parser.error("base archive must contain one linux/amd64 manifest")
    manifest = read_blob(args.work, index["manifests"][0])
    if manifest.get("mediaType") == "application/vnd.oci.image.index.v1+json":
        selected = next(
            (
                entry
                for entry in manifest["manifests"]
                if entry.get("platform") == {"architecture": "amd64", "os": "linux"}
            ),
            None,
        )
        if selected is None:
            parser.error("base archive has no linux/amd64 manifest")
        manifest = read_blob(args.work, selected)
    config = read_blob(args.work, manifest["config"])
    if config.get("architecture") != "amd64" or config.get("os") != "linux":
        parser.error("base image must be linux/amd64")

    binary_paths = {name: args.binary_dir / name for name in BINARIES}
    if args.extra_binary:
        binary_paths[args.extra_binary.name] = args.extra_binary
    libraries = set()
    for source in binary_paths.values():
        libraries.update(ldd_closure(source))
    libraries.update(Path(path) for path in NSS_MODULES if Path(path).is_file())
    libraries.update(Path(path) for path in DLOPEN_LIBRARIES if Path(path).is_file())

    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode="w") as layer:
        for name, source in binary_paths.items():
            info = tarfile.TarInfo(f"usr/local/bin/{name}")
            info.size = source.stat().st_size
            info.mode = 0o755
            with source.open("rb") as handle:
                layer.addfile(info, handle)
        for source in sorted(libraries):
            real = source.resolve()
            info = tarfile.TarInfo(str(source).lstrip("/"))
            info.size = real.stat().st_size
            info.mode = 0o755
            with real.open("rb") as handle:
                layer.addfile(info, handle)
        for source in sorted(args.ui_dir.rglob("*")):
            if not source.is_file():
                continue
            relative = source.relative_to(args.ui_dir)
            info = tarfile.TarInfo(f"opt/moondesk/ui/{relative.as_posix()}")
            info.size = source.stat().st_size
            info.mode = 0o644
            with source.open("rb") as handle:
                layer.addfile(info, handle)
    raw = buffer.getvalue()
    compressed = gzip.compress(raw, mtime=0)
    layer_descriptor = append_blob(args.work, compressed)
    layer_descriptor["mediaType"] = "application/vnd.oci.image.layer.v1.tar+gzip"
    manifest["layers"].append(layer_descriptor)
    config["rootfs"]["diff_ids"].append(f"sha256:{hashlib.sha256(raw).hexdigest()}")
    runtime = config.setdefault("config", {})
    runtime["User"] = "1000:1000"
    runtime["WorkingDir"] = "/workspace"
    runtime["Env"] = ["HOME=/workspace", "LANG=C.UTF-8"]
    runtime["Entrypoint"] = None
    runtime["Cmd"] = [
        "/usr/local/bin/moondesk", "serve", "/workspace", "--ui",
        "/opt/moondesk/ui", "--host", "0.0.0.0", "--port", "4188",
    ]

    config_descriptor = append_blob(
        args.work, json.dumps(config, separators=(",", ":")).encode()
    )
    config_descriptor["mediaType"] = "application/vnd.oci.image.config.v1+json"
    manifest["config"] = config_descriptor
    manifest_descriptor = append_blob(
        args.work, json.dumps(manifest, separators=(",", ":")).encode()
    )
    manifest_descriptor["mediaType"] = "application/vnd.oci.image.manifest.v1+json"
    manifest_descriptor["annotations"] = {
        "org.opencontainers.image.ref.name": args.tag
    }
    index["manifests"] = [manifest_descriptor]
    index_path.write_text(json.dumps(index, separators=(",", ":")))

    with tarfile.open(args.output, "w") as archive:
        archive.add(args.work, arcname=".")
    print(f"image={args.tag} digest={manifest_descriptor['digest']}")
    print(f"libraries={len(libraries)} archive={args.output}")


if __name__ == "__main__":
    main()
