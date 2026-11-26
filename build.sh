#!/bin/sh
# Build Zeichensatz Tabelle for the Ensemble 1.2 profile.
# Usage: SDK=/path/to/pcgeos-1-sdk-v2 ./build.sh
set -eu
cd "$(dirname "$0")"
HERE=$(pwd)
SDK=${SDK:-"$HERE/../pcgeos-1-sdk-v2"}
if [ ! -f "$SDK/sdk.pl" ]; then
    echo "SDK not found: $SDK" >&2
    echo "Set SDK to the pcgeos-1-sdk-v2 checkout." >&2
    exit 2
fi
cd "$SDK"
perl sdk.pl check --project "$HERE/app"
perl sdk.pl build --project "$HERE/app"
mkdir -p "$HERE/out"
SDK="$SDK" perl "$HERE/tools/postbuild.pl" \
    "$SDK/build/zgtab/zgtab.geo" "$HERE/out/ZGTAB.GEO" 560 450
echo "Built: $HERE/out/ZGTAB.GEO"

