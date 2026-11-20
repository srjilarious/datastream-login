#!/bin/sh
# Recompiles every .frag into the .qsb bundle Qt 6 loads, for both sets
# (shared/shaders and acidburn/shared/shaders). Needs qsb from
# qt6-shadertools. Run after editing any .frag file.
set -eu
root=$(cd "$(dirname "$0")" && pwd)
QSB=${QSB:-/usr/lib/qt6/bin/qsb}
for dir in "$root/shared/shaders" "$root/acidburn/shared/shaders"; do
    for f in "$dir"/*.frag; do
        "$QSB" --glsl "300es,330" --hlsl 50 --msl 12 -o "$f.qsb" "$f"
        echo "built ${f#"$root"/}.qsb"
    done
done
