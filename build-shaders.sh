#!/bin/sh
# Recompiles shaders/*.frag into the .qsb bundles Qt 6 loads. Needs qsb from
# qt6-shadertools. Run after editing any .frag file.
set -eu
cd "$(dirname "$0")/shared/shaders"
QSB=${QSB:-/usr/lib/qt6/bin/qsb}
for f in *.frag; do
    "$QSB" --glsl "300es,330" --hlsl 50 --msl 12 -o "$f.qsb" "$f"
    echo "built $f.qsb"
done
