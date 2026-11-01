#!/usr/bin/env bash
# Erzeugt iOS/GridlineiOS.xcodeproj aus iOS/project.yml (benötigt `brew install xcodegen`).
set -euo pipefail
cd "$(dirname "$0")/../iOS"
command -v xcodegen >/dev/null || { echo "xcodegen fehlt: brew install xcodegen" >&2; exit 1; }
xcodegen generate
echo "Fertig: iOS/GridlineiOS.xcodeproj"
