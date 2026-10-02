#!/usr/bin/env bash
# Regenera las capturas PNG del tema. Requiere: aha, chromium, ImageMagick,
# oh-my-posh, git y un Nerd Font instalado. Solo hace falta ejecutarlo si
# cambia el tema.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME="$ROOT/simplicer.omp.json"
SHOTS="$ROOT/screenshots"
WORK="$ROOT/.shots-work"
FAKEBIN="$WORK/bin"

mkdir -p "$SHOTS" "$FAKEBIN"

# df de mentira para dibujar los tres estados del segmento de disco
cat > "$FAKEBIN/df" <<'SH'
#!/bin/sh
avail="${FAKE_FREE_KB:-47185920}"
printf '%s\n' "Filesystem 1024-blocks Used Available Capacity Mounted on"
printf '/dev/sda1 98566140 40000000 %s 45%% /\n' "$avail"
SH
chmod +x "$FAKEBIN/df"

prompt() {
  # $1 = pwd, $2 = PATH opcional, $3 = FAKE_FREE_KB opcional
  env -u POSH_SESSION_ID -u POSH_CONFIG \
    PATH="${2:-$PATH}" FAKE_FREE_KB="${3:-}" \
    oh-my-posh print primary --config "$THEME" --shell bash \
    --status 0 --execution-time 0 --pwd "$1" --escape=false | aha --no-header
}

esc() {
  printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

page() {
  # $1 = nombre del png, resto = lineas HTML del cuerpo
  local name="$1"
  shift
  local body html
  body="$(printf '%s\n' "$@")"
  html="$WORK/${name%.png}.html"
  cat > "$html" <<HTML
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>simplicer</title>
<style>
  html, body { margin: 0; background: #282a36; }
  body {
    font-family: "JetBrainsMono Nerd Font Mono", "JetBrainsMono Nerd Font", monospace;
    font-size: 21px;
    line-height: 1.6;
    padding: 24px 28px;
    color: #f8f8f2;
    width: max-content;
    -webkit-font-smoothing: antialiased;
  }
  pre { margin: 0; font: inherit; white-space: pre; }
  .cmd { color: #f8f8f2; }
  .out { color: #6272a4; }
  .cursor { color: #50fa7b; }
</style>
</head>
<body>
<pre>
$body
</pre>
</body>
</html>
HTML
  /snap/bin/chromium --headless --disable-gpu --no-sandbox \
    --hide-scrollbars --force-device-scale-factor=2 \
    --window-size=1800,600 --screenshot="$WORK/$name" "file://$html" \
    >/dev/null 2>&1
  convert "$WORK/$name" -trim +repage \
    -bordercolor '#282a36' -border 50x50 "$SHOTS/$name"
}

# --- 1. captura principal: sesion con el arbol en un estado sucio --------
P="$(prompt "$ROOT")"
mapfile -t STATUS < <(git -C "$ROOT" status -sb)
LINES=("$P<span class=\"cmd\"> git status -sb</span>")
for line in "${STATUS[@]}"; do
  LINES+=("<span class=\"out\">$(esc "$line")</span>")
done
LINES+=("$P<span class=\"cursor\">&#9608;</span>")
page simplicer.png "${LINES[@]}"

# --- 2. los tres estados del segmento de disco ---------------------------
OK="$(prompt "$ROOT" "$FAKEBIN:$PATH" 47185920)"
WARN="$(prompt "$ROOT" "$FAKEBIN:$PATH" 12582912)"
CRIT="$(prompt "$ROOT" "$FAKEBIN:$PATH" 3145728)"
page simplicer-disk.png "$OK" "$WARN" "$CRIT<span class=\"cursor\">&#9608;</span>"

identify "$SHOTS"/*.png
