#!/usr/bin/env bash
# ==============================================================================
# SonarScanner CLI Execution Engine
# Provisions scanner parameters, handles PR context, and initiates analysis.
# ==============================================================================

set -euo pipefail

SONAR_HOST_URL="${SONAR_HOST_URL:-https://sonarqube.internal.corp}"
SONAR_TOKEN="${SONAR_TOKEN:-}"
PROJECT_KEY="${SONAR_PROJECT_KEY:-enterprise-cloud-platform}"

echo "==========================================================="
echo "        SONARQUBE ENTERPRISE SCANNER INITIATION             "
echo "==========================================================="
echo "[*] Server URL:   ${SONAR_HOST_URL}"
echo "[*] Project Key:  ${PROJECT_KEY}"

if [ -z "${SONAR_TOKEN}" ]; then
  echo "[ERROR] SONAR_TOKEN environment variable is not defined!" >&2
  exit 1
fi

PR_PARAMS=()
if [ -n "${GITHUB_BASE_REF:-}" ] && [ -n "${GITHUB_HEAD_REF:-}" ]; then
  echo "[*] Detected Pull Request Context (${GITHUB_HEAD_REF} -> ${GITHUB_BASE_REF})"
  PR_NUMBER="${GITHUB_EVENT_PULL_REQUEST_NUMBER:-${PULL_REQUEST_KEY:-1}}"
  PR_PARAMS=(
    "-Dsonar.pullrequest.key=${PR_NUMBER}"
    "-Dsonar.pullrequest.branch=${GITHUB_HEAD_REF}"
    "-Dsonar.pullrequest.base=${GITHUB_BASE_REF}"
  )
elif [ -n "${GITHUB_REF_NAME:-}" ]; then
  echo "[*] Detected Branch Context: ${GITHUB_REF_NAME}"
  PR_PARAMS=("-Dsonar.branch.name=${GITHUB_REF_NAME}")
fi

mkdir -p .scannerwork

if command -v sonar-scanner &> /dev/null; then
  echo "[*] Invoking native sonar-scanner CLI..."
  sonar-scanner \
    -Dsonar.host.url="${SONAR_HOST_URL}" \
    -Dsonar.token="${SONAR_TOKEN}" \
    -Dsonar.projectKey="${PROJECT_KEY}" \
    "${PR_PARAMS[@]}"
else
  echo "[*] Invoking SonarScanner via Docker container..."
  docker run --rm \
    -e SONAR_HOST_URL="${SONAR_HOST_URL}" \
    -e SONAR_TOKEN="${SONAR_TOKEN}" \
    -v "$(pwd):/usr/src" \
    sonarsource/sonar-scanner-cli \
    -Dsonar.projectKey="${PROJECT_KEY}" \
    "${PR_PARAMS[@]}"
fi

if [ -f ".scannerwork/report-task.txt" ]; then
  echo "[SUCCESS] Analysis completed. Task report saved to .scannerwork/report-task.txt"
else
  echo "[WARN] .scannerwork/report-task.txt was not generated."
fi
