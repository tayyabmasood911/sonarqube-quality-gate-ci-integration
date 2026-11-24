#!/usr/bin/env bash
# ==============================================================================
# SonarQube Quality Gate REST API Poller & Gate Enforcement
# Polls Compute Engine task status and evaluates project Quality Gate criteria.
# ==============================================================================

set -euo pipefail

TASK_FILE=".scannerwork/report-task.txt"
MAX_ATTEMPTS="${MAX_POLL_ATTEMPTS:-30}"
SLEEP_INTERVAL="${POLL_INTERVAL_SEC:-5}"
SONAR_TOKEN="${SONAR_TOKEN:-}"

echo "==========================================================="
echo "       SONARQUBE QUALITY GATE REST API EVALUATOR           "
echo "==========================================================="

if [ -f "${TASK_FILE}" ]; then
  CE_TASK_URL=$(grep "^ceTaskUrl=" "${TASK_FILE}" | cut -d'=' -f2-)
  SERVER_URL=$(grep "^serverUrl=" "${TASK_FILE}" | cut -d'=' -f2-)
  TASK_ID=$(grep "^ceTaskId=" "${TASK_FILE}" | cut -d'=' -f2-)
else
  SERVER_URL="${SONAR_HOST_URL:-http://localhost:9000}"
  TASK_ID="${CE_TASK_ID:-dummy-task-id}"
  CE_TASK_URL="${SERVER_URL}/api/ce/task?id=${TASK_ID}"
fi

echo "[*] Server URL: ${SERVER_URL}"
echo "[*] Task ID:    ${TASK_ID}"

# Poll Compute Engine Task Until Completed
ATTEMPT=1
ANALYSIS_ID=""

while [ ${ATTEMPT} -le ${MAX_ATTEMPTS} ]; do
  echo "[Attempt ${ATTEMPT}/${MAX_ATTEMPTS}] Querying Compute Engine task status..."
  
  # Fetch Task Status
  TASK_RESPONSE=$(curl -s -u "${SONAR_TOKEN}:" "${CE_TASK_URL}" || echo '{"task":{"status":"FAILED"}}')
  TASK_STATUS=$(echo "${TASK_RESPONSE}" | python3 -c "import sys, json; print(json.load(sys.stdin).get('task', {}).get('status', 'PENDING'))")

  if [ "${TASK_STATUS}" = "SUCCESS" ]; then
    ANALYSIS_ID=$(echo "${TASK_RESPONSE}" | python3 -c "import sys, json; print(json.load(sys.stdin).get('task', {}).get('analysisId', ''))")
    echo "[*] Compute Engine processing completed! Analysis ID: ${ANALYSIS_ID}"
    break
  elif [ "${TASK_STATUS}" = "FAILED" ] || [ "${TASK_STATUS}" = "CANCELED" ]; then
    echo "[ERROR] SonarQube analysis task ${TASK_STATUS}." >&2
    exit 1
  fi

  sleep ${SLEEP_INTERVAL}
  ATTEMPT=$((ATTEMPT + 1))
done

if [ -z "${ANALYSIS_ID}" ]; then
  echo "[ERROR] Timed out waiting for SonarQube compute engine task to complete." >&2
  exit 1
fi

# Query Quality Gate Status
PROJECT_STATUS_URL="${SERVER_URL}/api/qualitygates/project_status?analysisId=${ANALYSIS_ID}"
echo "[*] Fetching Quality Gate metrics from: ${PROJECT_STATUS_URL}"

STATUS_JSON=$(curl -s -u "${SONAR_TOKEN}:" "${PROJECT_STATUS_URL}")

# Parse Quality Gate Decision with Python
python3 -c "
import sys, json, os

try:
    data = json.loads('''${STATUS_JSON}''')
except Exception:
    data = {'projectStatus': {'status': 'ERROR', 'conditions': []}}

status_obj = data.get('projectStatus', {})
gate_status = status_obj.get('status', 'ERROR')
conditions = status_obj.get('conditions', [])

print('\n================ QUALITY GATE METRICS ================')
print(f'Overall Status: {gate_status}')
print('------------------------------------------------------')
print(f'{"Metric":<25} | {"Status":<8} | {"Actual":<10} | {"Threshold":<10}')
print('------------------------------------------------------')

has_failure = (gate_status != 'OK')

for c in conditions:
    metric = c.get('metricKey', 'unknown')
    status = c.get('status', 'NO_VALUE')
    actual = c.get('actualValue', 'N/A')
    comparator = c.get('comparator', '')
    error_thresh = c.get('errorThreshold', 'N/A')
    thresh_display = f'{comparator} {error_thresh}'
    
    symbol = '✅ PASS' if status == 'OK' else '❌ FAIL'
    print(f'{metric:<25} | {symbol:<8} | {actual:<10} | {thresh_display:<10}')

print('======================================================\n')

# Emit GITHUB_STEP_SUMMARY if available
summary_file = os.environ.get('GITHUB_STEP_SUMMARY')
if summary_file:
    badge = '✅ PASSED' if not has_failure else '❌ FAILED'
    with open(summary_file, 'a', encoding='utf-8') as f:
        f.write(f'## SonarQube Quality Gate Decision: {badge}\n\n')
        f.write('| Metric | Status | Actual | Threshold |\n')
        f.write('| :--- | :---: | :---: | :---: |\n')
        for c in conditions:
            f.write(f"| `{c.get('metricKey')}` | {c.get('status')} | {c.get('actualValue', 'N/A')} | {c.get('comparator','')} {c.get('errorThreshold','')} |\n")
        f.write('\n')

if has_failure:
    print('[GATE FAILED] Code analysis breached enterprise quality thresholds!')
    sys.exit(1)
else:
    print('[GATE PASSED] All quality gate metrics satisfy enterprise criteria.')
    sys.exit(0)
"
