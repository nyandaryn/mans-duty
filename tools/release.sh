#!/usr/bin/env bash
# Build the Linux, Windows and macOS archives of the version in
# source/project.godot and publish them as GitHub release v<version>.
#
#   tools/release.sh               build, check, publish
#   tools/release.sh --build-only  build and check, publish nothing
#   tools/release.sh --draft       publish as a draft release
#
# The game is built from the committed HEAD (git archive), not from the
# working tree, so a release always matches a commit on GitHub.
# Output: .build/release/<version>/ (archives, SHA256SUMS.txt, notes, logs).
set -euo pipefail

GODOT_VERSION=4.5.1
ROOT=$(cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

build_only=0
draft=0
for arg in "$@"; do
  case $arg in
    --build-only) build_only=1 ;;
    --draft) draft=1 ;;
    -h | --help) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "release: unknown option $arg (see --help)" >&2; exit 2 ;;
  esac
done

die() { echo "release: $*" >&2; exit 1; }
step() { printf '\n== %s\n' "$*" >&2; }

# ---------------------------------------------------------------- checks
step "Checks"
for tool in git gh python3 zip unzip tar sha256sum timeout; do
  command -v "$tool" >/dev/null || die "$tool is not installed"
done

SHA=$(git rev-parse HEAD)
VER=$(git show HEAD:source/project.godot | sed -n 's/^config\/version="\(.*\)"$/\1/p')
[[ $VER =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "no config/version in source/project.godot at HEAD"
TAG="v$VER"
echo "version $VER, commit ${SHA:0:12}" >&2

# The texts shipped in the archives must already say this version.
for f in README.txt README-macOS.txt README-Windows.txt; do
  [[ $(git show "HEAD:$f" | sed -n 1p) == *"/ $VER /"* ]] ||
    die "$f does not start with 'MANS DUTY / $VER / …' — bump it and commit"
done
CHANGELOG=$(git show HEAD:source/CHANGELOG.md)
grep -q "^## $VER " <<<"$CHANGELOG" || die "source/CHANGELOG.md has no '## $VER' section"

ORIGIN=$(git remote get-url origin) || die "no origin remote"
SLUG=$(sed -E 's#^(git@github\.com:|ssh://git@github\.com/|https://github\.com/)##; s#\.git$##' <<<"$ORIGIN")
[[ $SLUG == */* ]] || die "origin is not a GitHub repository: $ORIGIN"

if ((!build_only)); then
  [[ -z $(git status --porcelain) ]] ||
    die "uncommitted changes — commit or stash them (the build uses HEAD only)"
  git fetch -q origin
  [[ -n $(git branch -r --contains HEAD | grep '^ *origin/') ]] ||
    die "HEAD ${SHA:0:12} is not on origin — push it first"
  ! git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null ||
    die "tag $TAG already exists on origin"
  ! gh release view "$TAG" -R "$SLUG" >/dev/null 2>&1 ||
    die "release $TAG already exists on $SLUG"
  [[ $(gh api "repos/$SLUG" --jq .permissions.push) == true ]] ||
    die "the gh account for $SLUG cannot push there"
fi

# ------------------------------------------------------------- toolchain
step "Godot $GODOT_VERSION and export templates"
python3 tools/fetch_godot.py --version "$GODOT_VERSION" --build-dir .build
GODOT=$ROOT/.build/godot-$GODOT_VERSION/godot
TEMPLATES=$ROOT/.build/templates/$GODOT_VERSION.stable

W=$ROOT/.build/release/$VER
rm -rf "$W"
mkdir -p "$W"/{tree,out/linux,out/windows,out/macos,pkg,check,xdg/data,xdg/config,xdg/cache}
# Godot and the game run with private XDG dirs, so the exports and the smoke
# runs never touch the user's editor settings, templates or game saves. Only
# for them: gh and git keep the real config.
isolated() {
  XDG_DATA_HOME=$W/xdg/data XDG_CONFIG_HOME=$W/xdg/config XDG_CACHE_HOME=$W/xdg/cache "$@"
}
mkdir -p "$W/xdg/data/godot/export_templates/$GODOT_VERSION.stable"
ln -s "$TEMPLATES"/* "$W/xdg/data/godot/export_templates/$GODOT_VERSION.stable/"

git archive HEAD | tar -x -C "$W/tree"
PROJECT=$W/tree/source

# ---------------------------------------------------------------- export
check_log() { # log, what
  if grep -nE 'ERROR|SCRIPT ERROR|Cannot open file' "$1" >&2; then
    die "$2 logged errors, see $1"
  fi
}

step "Import"
isolated timeout 1200 "$GODOT" --headless --path "$PROJECT" --import >"$W/import.log" 2>&1 ||
  { tail -20 "$W/import.log" >&2; die "import failed, see $W/import.log"; }
check_log "$W/import.log" "import"

export_preset() { # preset, output path
  local log=$W/export-${1,,}.log
  step "Export $1"
  isolated timeout 1200 "$GODOT" --headless --path "$PROJECT" --export-release "$1" "$2" >"$log" 2>&1 ||
    { tail -20 "$log" >&2; die "export $1 failed, see $log"; }
  check_log "$log" "export $1"
  [[ -s $2 ]] || die "export $1 produced no $2"
}
export_preset Linux "$W/out/linux/kvartal.x86_64"
export_preset Windows "$W/out/windows/kvartal.exe"
export_preset macOS "$W/out/macos/kvartal.zip"
[[ -s $W/out/linux/kvartal.pck && -s $W/out/windows/kvartal.pck ]] || die "a pck is missing"

# --------------------------------------------------------------- package
step "Package"
T=$W/tree
DOCS=("$T/README.txt" "$T/GODOT-LICENSE.txt" "$T/GODOT-COPYRIGHT.txt" "$T"/source/assets/*-CREDITS.md)
LINUX=kvartal-$VER-linux.tar.gz
WINDOWS=kvartal-$VER-windows.zip
MACOS=kvartal-$VER-macos.zip

L=$W/pkg/kvartal-$VER-linux
mkdir "$L"
cp "$W/out/linux/kvartal.x86_64" "$W/out/linux/kvartal.pck" "$T/play.sh" "${DOCS[@]}" "$L/"
chmod 755 "$L/kvartal.x86_64" "$L/play.sh"
tar -C "$W/pkg" --owner=0 --group=0 --numeric-owner -czf "$W/$LINUX" "kvartal-$VER-linux"

zip -X -j -q "$W/$WINDOWS" "$W/out/windows/kvartal.exe" "$W/out/windows/kvartal.pck" \
  "$T/README-Windows.txt" "${DOCS[@]}"

cp "$W/out/macos/kvartal.zip" "$W/$MACOS"
zip -X -j -q "$W/$MACOS" "$T/README-macOS.txt" "${DOCS[@]}"

# ----------------------------------------------------------------- check
step "Check the archives"
smoke() { # name, command… — start the game headless for 300 frames
  local name=$1 log=$W/smoke-$1.log
  shift
  isolated timeout 180 "$@" --headless --quit-after 300 >"$log" 2>&1 ||
    { tail -20 "$log" >&2; die "smoke run $name failed, see $log"; }
  check_log "$log" "smoke run $name"
  echo "smoke $name: ok" >&2
}

unzip -tq "$W/$WINDOWS" >/dev/null || die "$WINDOWS is corrupt"
unzip -tq "$W/$MACOS" >/dev/null || die "$MACOS is corrupt"

# Linux: unpack the real archive and start it the way a player does.
tar -xzf "$W/$LINUX" -C "$W/check"
smoke linux "$W/check/kvartal-$VER-linux/play.sh"

# Windows: the exe cannot run here, so check its pack with the Linux build.
if cmp -s "$W/out/linux/kvartal.pck" "$W/out/windows/kvartal.pck"; then
  echo "windows pck: identical to linux" >&2
else
  smoke windows-pck "$W/check/kvartal-$VER-linux/kvartal.x86_64" --main-pack "$W/out/windows/kvartal.pck"
fi
WIN_LIST=$(unzip -Z1 "$W/$WINDOWS")
grep -qx 'kvartal\.exe' <<<"$WIN_LIST" || die "$WINDOWS has no kvartal.exe"

# macOS: bundle layout, version, ad-hoc signature, and the pack inside it.
MAC_LIST=$(unzip -Z1 "$W/$MACOS")
APP_PCK=$(grep -E '^[^/]+\.app/Contents/Resources/[^/]+\.pck$' <<<"$MAC_LIST" | sed -n 1p)
[[ -n $APP_PCK ]] || die "$MACOS has no .app/Contents/Resources/*.pck"
APP=${APP_PCK%%/Contents/*}
grep -qxF "$APP/Contents/_CodeSignature/CodeResources" <<<"$MAC_LIST" ||
  die "$MACOS is not signed (no CodeResources)"
grep -qF "$APP/Contents/MacOS/" <<<"$MAC_LIST" || die "$MACOS has no executable"
PLIST=$(unzip -p "$W/$MACOS" "$APP/Contents/Info.plist")
grep -A1 CFBundleShortVersionString <<<"$PLIST" | grep -qF "<string>$VER</string>" ||
  die "Info.plist in $MACOS does not say version $VER"
unzip -p "$W/$MACOS" "$APP_PCK" >"$W/check/macos.pck"
smoke macos-pck "$W/check/kvartal-$VER-linux/kvartal.x86_64" --main-pack "$W/check/macos.pck"

(cd "$W" && sha256sum "$LINUX" "$WINDOWS" "$MACOS" >SHA256SUMS.txt)

# ----------------------------------------------------------------- notes
BASE_URL=https://github.com/$SLUG/releases/download/$TAG
{
  cat <<EOF
## Download / Завантажити

| Platform / Платформа | File / Файл |
| --- | --- |
| Windows 10/11, 64-bit | [$WINDOWS]($BASE_URL/$WINDOWS) |
| macOS 11+ (Apple Silicon), 10.12+ (Intel) | [$MACOS]($BASE_URL/$MACOS) |
| Linux x86_64 | [$LINUX]($BASE_URL/$LINUX) |

**EN.** Unpack the whole archive before starting the game. The builds are not signed, so on first launch Windows shows SmartScreen (**More info → Run anyway**) and macOS blocks the app (**Control-click → Open**). Step-by-step help is in README-Windows.txt / README-macOS.txt inside the archive. On Linux run \`./play.sh\`.

**UA.** Розпакуйте архів повністю, перш ніж запускати гру. Збірки не підписані, тож під час першого запуску Windows покаже SmartScreen (**Докладніше → Усе одно запустити**), а macOS заблокує програму (**Control-клацання → Відкрити**). Покрокова інструкція — у README-Windows.txt / README-macOS.txt в архіві. На Linux запустіть \`./play.sh\`.

Checksums / контрольні суми: SHA256SUMS.txt. Godot $GODOT_VERSION.

## Що нового в $VER

EOF
  awk -v v="$VER" 'index($0, "## " v " ") == 1 { on = 1; next } on && /^## / { exit } on' <<<"$CHANGELOG"
} >"$W/notes.md"

ls -l "$W/$LINUX" "$W/$WINDOWS" "$W/$MACOS" >&2

if ((build_only)); then
  rm -rf "$W"/{tree,out,pkg,check,xdg}
  step "Built $VER in $W (--build-only: nothing published)"
  exit 0
fi

# --------------------------------------------------------------- publish
step "Publish $TAG to $SLUG"
args=(release create "$TAG" -R "$SLUG" --target "$SHA" --title "MANS DUTY $VER"
  --notes-file "$W/notes.md")
((draft)) && args+=(--draft)
gh "${args[@]}" "$W/$LINUX" "$W/$WINDOWS" "$W/$MACOS" "$W/SHA256SUMS.txt"

# Every asset must be on GitHub with the same size as here.
for f in "$LINUX" "$WINDOWS" "$MACOS" SHA256SUMS.txt; do
  remote=$(gh release view "$TAG" -R "$SLUG" --json assets \
    --jq ".assets[] | select(.name == \"$f\") | .size")
  [[ $remote == "$(stat -c %s "$W/$f")" ]] || die "asset $f on GitHub has size '${remote}'"
done
git fetch -q origin --tags
rm -rf "$W"/{tree,out,pkg,check,xdg}
step "Published: https://github.com/$SLUG/releases/tag/$TAG"
