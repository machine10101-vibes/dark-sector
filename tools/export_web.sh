#!/usr/bin/env bash
# Export Dark Sector Online as a single-thread Godot 4.7 HTML5 build for GitHub Pages.
# Pages cannot send Cross-Origin-Isolation headers, so threads stay off.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

GODOT="${GODOT:-}"
if [[ -z "$GODOT" ]]; then
	for candidate in godot godot4 /home/ubuntu/.local/bin/godot /tmp/godot-install/Godot_v4.7.2-stable_linux.x86_64; do
		if command -v "$candidate" >/dev/null 2>&1; then
			GODOT="$(command -v "$candidate")"
			break
		elif [[ -x "$candidate" ]]; then
			GODOT="$candidate"
			break
		fi
	done
fi

if [[ -z "${GODOT}" || ! -x "${GODOT}" ]]; then
	echo "Need Godot 4.7.x on PATH, or set GODOT=/path/to/godot" >&2
	exit 1
fi

VERSION="$("$GODOT" --version 2>/dev/null | head -n1 || true)"
echo "Using $GODOT ($VERSION)"
if [[ "$VERSION" != 4.7.* ]]; then
	echo "Warning: project expects Godot 4.7.x; export templates must match the editor." >&2
fi

OUT="${ROOT}/export/web"
mkdir -p "$OUT"

echo "Importing project..."
"$GODOT" --headless --path "$ROOT" --import --quit

echo "Exporting Web (nothreads) to $OUT/index.html ..."
"$GODOT" --headless --path "$ROOT" --export-release "Web" "$OUT/index.html"

# Jekyll on GitHub Pages would skip underscored files; Godot does not need that processor.
touch "$OUT/.nojekyll"

# Project Pages 404s should still land on the helm.
cat >"$OUT/404.html" <<'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Dark Sector Online</title>
<meta http-equiv="refresh" content="0; url=/dark-sector/">
<link rel="canonical" href="/dark-sector/">
</head>
<body style="background:#07080c;color:#e6d7bf;font-family:sans-serif">
<p>This path is empty. Dark Sector Online is at <a href="/dark-sector/">/dark-sector/</a>. Ashen Reach is a system inside the game.</p>
</body>
</html>
HTML

echo "Exported:"
ls -lh "$OUT"

if [[ "${1:-}" != "--deploy" ]]; then
	echo "Done. Serve under the /dark-sector/ prefix (see README). Use --deploy to push gh-pages."
	exit 0
fi

REMOTE="$(git -C "$ROOT" remote get-url origin)"
SHA="$(git -C "$ROOT" rev-parse --short HEAD)"
STAGE="$(mktemp -d)"
cleanup() { rm -rf "$STAGE"; }
trap cleanup EXIT

if git -C "$ROOT" show-ref --verify --quiet refs/remotes/origin/gh-pages; then
	git clone --depth 1 --branch gh-pages "$REMOTE" "$STAGE"
	find "$STAGE" -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +
else
	git clone --depth 1 --no-checkout "$REMOTE" "$STAGE"
	git -C "$STAGE" checkout --orphan gh-pages
	find "$STAGE" -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +
fi

cp -a "$OUT"/. "$STAGE"/
git -C "$STAGE" add -A
if git -C "$STAGE" diff --cached --quiet; then
	echo "gh-pages already matches this export."
	exit 0
fi
git -C "$STAGE" -c user.email="devnull@example.com" -c user.name="dark-sector export" \
	commit -m "Publish web build from ${SHA}"
git -C "$STAGE" push origin gh-pages
echo "Pushed gh-pages from ${SHA}."
