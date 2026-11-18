#!/bin/sh
set -eu
KVARTAL_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec "$KVARTAL_DIR/kvartal.x86_64" --main-pack "$KVARTAL_DIR/kvartal.pck" "$@"
