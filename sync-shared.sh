#!/usr/bin/env bash
# The vault template and the skills are the same on both platforms, and each
# installer folder carries its own copy so it can be shipped standalone. macOS
# is the source of truth. Run this after changing either, then commit both.
set -euo pipefail
cd "$(dirname "$0")"

for part in template skills; do
  rm -rf "Windows/$part"
  cp -R "MacOS/$part" "Windows/$part"
done

if diff -r MacOS/template Windows/template >/dev/null && diff -r MacOS/skills Windows/skills >/dev/null; then
  echo "MacOS and Windows copies of template/ and skills/ now match."
else
  echo "Copies still differ — something is wrong." >&2
  exit 1
fi
