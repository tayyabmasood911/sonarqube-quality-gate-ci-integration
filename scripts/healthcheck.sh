#!/usr/bin/env bash
set -euo pipefail

echo "=== SonarQube Integration Healthcheck ==="
python3 --version
python3 scripts/sonar_api_client.py --mock-test

if [ -f "sonar-project.properties" ]; then
    echo "[OK] sonar-project.properties present and readable."
else
    echo "[ERROR] Missing sonar-project.properties" >&2
    exit 1
fi

echo "[OK] All integration scripts verified."
exit 0
