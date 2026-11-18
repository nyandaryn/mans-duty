---
name: release
description: Build MANS DUTY for Windows, macOS and Linux and publish the archives as a GitHub release on nyandaryn/mans-duty — «зроби реліз», «випусти / залий реліз на гітхаб», «задеплой реліз», «опублікуй 0.23.0», «сделай релиз», «publish a release». Runs tools/release.sh on the committed HEAD. Not for bumping the version or writing the changelog (do that first), and not for installing kvartal.pck into the local game folder.
---

# Release to GitHub

`tools/release.sh` does the whole job; this skill is about running it safely and reporting.

What the script does:
1. Takes the version from `config/version` in `source/project.godot` at `HEAD`. Checks that
   `README.txt`, `README-macOS.txt` and `README-Windows.txt` start with `MANS DUTY / <ver> /` and
   that `source/CHANGELOG.md` has a `## <ver>` section.
2. Refuses to publish when the tree is dirty, `HEAD` is not on `origin`, or tag/release `v<ver>`
   already exists.
3. Fetches Godot 4.5.1 and the export templates into `.build/` if missing
   (`tools/fetch_godot.py`, HTTP range reads from the official `.tpz`).
4. Unpacks `git archive HEAD` into `.build/release/<ver>/tree`, imports, exports the presets
   «Linux», «Windows» and «macOS» with private XDG dirs (the user's editor settings and saves are
   never touched). Any `ERROR` in a log stops it.
5. Packs `kvartal-<ver>-linux.tar.gz` (binary, pck, play.sh, docs), `kvartal-<ver>-windows.zip`
   (exe, pck, README-Windows.txt, docs), `kvartal-<ver>-macos.zip` (universal .app with ad-hoc
   signature + README-macOS.txt, docs). Docs = README.txt, GODOT-LICENSE.txt, GODOT-COPYRIGHT.txt,
   `source/assets/*-CREDITS.md`.
6. Smoke-runs the unpacked Linux archive through `play.sh` and the Windows and macOS packs through
   the Linux binary (`--headless --quit-after 300`, no `ERROR` allowed). Checks the .app layout,
   CodeResources and the Info.plist version.
7. Writes `SHA256SUMS.txt` and bilingual notes (download table + changelog section), creates
   release `v<ver>` at `HEAD` with the four files, and compares asset sizes on GitHub.

## Steps

1. Look at the state:
   ```bash
   git status --short; git log --oneline -3; git fetch -q origin; git status -sb | head -1
   sed -n 's/^config\/version="\(.*\)"$/\1/p' source/project.godot
   gh release list -R nyandaryn/mans-duty --limit 5
   ```
2. If the version is already released, stop and ask whether to bump it — a release is never
   overwritten. Bumping (project.godot, the three READMEs, CHANGELOG, `source/README.md`) is the
   development flow, not this skill.
3. Uncommitted changes: ask whether they belong in the release. Never stash or discard them on your
   own. If `main` is only ahead of `origin`, push it: the release must point at a pushed commit.
4. Run the script in the background (about 3–10 min, the upload is ~200 MB):
   ```bash
   tools/release.sh            # or --draft when the user wants to look first
   ```
   For a trial without publishing: `tools/release.sh --build-only`.
5. Report the release URL, the four assets with sizes and the SHA-256 from
   `.build/release/<ver>/SHA256SUMS.txt`, and the smoke-run results. If the user's game is running
   (`pgrep -x kvartal.x86_64`) it does not matter: the script does not touch the root install.

## When it fails

- `does not start with 'MANS DUTY / <ver>'` / no CHANGELOG section — the version bump is
  incomplete. Tell the user what is missing; fix it only if asked, then commit.
- `export … logged errors` / `Cannot open file …gdc` — look at `.build/release/<ver>/export-*.log`.
  Never export with `./kvartal.x86_64` in place: it auto-loads the `kvartal.pck` beside it.
- A smoke run fails — `.build/release/<ver>/smoke-*.log`. Do not publish around it.
- `server ignored the Range header` from fetch_godot.py — download
  `Godot_v4.5.1-stable_export_templates.tpz` once and unzip the missing `templates/*` files into
  `.build/templates/4.5.1.stable/`.
- The upload broke halfway: `gh release view v<ver> -R nyandaryn/mans-duty`; upload the missing
  files with `gh release upload v<ver> <files> -R nyandaryn/mans-duty`.
- Replacing a published release only on the user's explicit word:
  `gh release delete v<ver> -R nyandaryn/mans-duty --cleanup-tag --yes`, then run the script again.

## Notes

- The repository root is also the user's installed game (`kvartal.x86_64` is the Godot editor,
  `kvartal.pck`, `dist/`, `.build/`); the whitelist `.gitignore` keeps all of it out of git. A new
  top-level file needs a `!/<name>` line there.
- The Linux release uses the official `linux_release.x86_64` template, not the editor binary that
  sits in the local install.
- Godot version: `GODOT_VERSION` in `tools/release.sh`. Raising it means new templates and a check
  that the project still imports.
