#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="$project_root/build/web"

command -v godot >/dev/null 2>&1 || { echo "Godot 4 is required." >&2; exit 1; }
command -v brotli >/dev/null 2>&1 || { echo "The Brotli CLI is required." >&2; exit 1; }

mkdir -p "$project_root/build"
touch "$project_root/build/.gdignore"
rm -rf "$output_dir"
mkdir -p "$output_dir"
godot --headless --path "$project_root" --export-release Web "$output_dir/index.html"
brotli --quality=5 --force --output="$output_dir/index.wasm.br" "$output_dir/index.wasm"
mv "$output_dir/index.wasm.br" "$output_dir/index.wasm"

cat > "$output_dir/_headers" <<'HEADERS'
/index.wasm
  Content-Encoding: br
  Content-Type: application/wasm
HEADERS

echo "Web build ready at $output_dir"
