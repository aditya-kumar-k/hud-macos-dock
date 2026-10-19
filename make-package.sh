#!/usr/bin/env bash
# Build dist/com.aadi.huddock.plasmoid from ./package
set -euo pipefail
cd "$(dirname "$0")"
id=$(python3 -c "import json; print(json.load(open('package/metadata.json'))['KPlugin']['Id'])")
mkdir -p dist
rm -f "dist/${id}.plasmoid"
(cd package && zip -qr "../dist/${id}.plasmoid" . -x '*.pyc' -x '__pycache__/*')
echo "Built dist/${id}.plasmoid"
