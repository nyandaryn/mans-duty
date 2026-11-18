#!/usr/bin/env python3
"""Make sure the Godot editor and the export templates for a release exist.

    python3 tools/fetch_godot.py [--version 4.5.1] [--build-dir .build]

Puts the official Linux editor at <build-dir>/godot-<version>/godot and the
templates at <build-dir>/templates/<version>.stable/. Only missing files are
downloaded. Templates are read straight out of the official .tpz with HTTP
range requests, so the 1.3 GB archive is never downloaded whole.
"""

import argparse
import io
import os
import shutil
import sys
import tempfile
import urllib.request
import zipfile

BASE = "https://github.com/godotengine/godot/releases/download/{v}-stable/"
UA = {"User-Agent": "godot-release-fetch"}
TEMPLATES = [
    "linux_release.x86_64",
    "windows_release_x86_64.exe",
    "windows_release_x86_64_console.exe",
    "macos.zip",
    "version.txt",
]
EXECUTABLE = {"linux_release.x86_64"}


class HttpFile(io.RawIOBase):
    """Read-only seekable file over HTTP range requests."""

    def __init__(self, url):
        req = urllib.request.Request(url, method="HEAD", headers=UA)
        with urllib.request.urlopen(req, timeout=60) as r:
            self.url = r.geturl()
            self.size = int(r.headers["Content-Length"])
        self.pos = 0

    def readable(self):
        return True

    def seekable(self):
        return True

    def tell(self):
        return self.pos

    def seek(self, offset, whence=io.SEEK_SET):
        base = {io.SEEK_SET: 0, io.SEEK_CUR: self.pos, io.SEEK_END: self.size}[whence]
        self.pos = max(0, base + offset)
        return self.pos

    def readinto(self, buf):
        n = min(len(buf), self.size - self.pos)
        if n <= 0:
            return 0
        headers = dict(UA, Range=f"bytes={self.pos}-{self.pos + n - 1}")
        req = urllib.request.Request(self.url, headers=headers)
        with urllib.request.urlopen(req, timeout=120) as r:
            if r.status != 206:
                raise OSError(f"server ignored the Range header (HTTP {r.status})")
            data = r.read()
        buf[: len(data)] = data
        self.pos += len(data)
        return len(data)


def install(src, dest, executable=False):
    """Copy a file object to dest through a temp file and an atomic rename."""
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(dest), prefix=".fetch-")
    try:
        with os.fdopen(fd, "wb") as out:
            shutil.copyfileobj(src, out, 4 << 20)
        os.chmod(tmp, 0o755 if executable else 0o644)
        os.replace(tmp, dest)
    except BaseException:
        os.unlink(tmp)
        raise


def fetch_editor(version, build_dir):
    dest = os.path.join(build_dir, f"godot-{version}", "godot")
    if os.path.isfile(dest):
        return
    name = f"Godot_v{version}-stable_linux.x86_64"
    print(f"fetch: {name}.zip", file=sys.stderr)
    remote = io.BufferedReader(HttpFile(BASE.format(v=version) + name + ".zip"), 8 << 20)
    with zipfile.ZipFile(remote) as z, z.open(name) as src:
        install(src, dest, executable=True)


def fetch_templates(version, build_dir):
    tdir = os.path.join(build_dir, "templates", f"{version}.stable")
    missing = [t for t in TEMPLATES if not os.path.isfile(os.path.join(tdir, t))]
    if not missing:
        return
    url = BASE.format(v=version) + f"Godot_v{version}-stable_export_templates.tpz"
    remote = io.BufferedReader(HttpFile(url), 8 << 20)
    with zipfile.ZipFile(remote) as z:
        for t in missing:
            print(f"fetch: templates/{t}", file=sys.stderr)
            with z.open(f"templates/{t}") as src:
                install(src, os.path.join(tdir, t), executable=t in EXECUTABLE)


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--version", default="4.5.1")
    ap.add_argument("--build-dir", default=".build")
    args = ap.parse_args()
    fetch_editor(args.version, args.build_dir)
    fetch_templates(args.version, args.build_dir)


if __name__ == "__main__":
    main()
