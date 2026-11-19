#!/usr/bin/env bash
# Builds dist/catlog.koplugin.zip, ready to unzip into koreader/plugins/
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p dist
rm -f dist/catlog.koplugin.zip
zip -r dist/catlog.koplugin.zip catlog.koplugin -x "*.DS_Store"
echo "Built dist/catlog.koplugin.zip"
