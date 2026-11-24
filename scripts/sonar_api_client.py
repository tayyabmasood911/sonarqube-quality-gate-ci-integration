#!/usr/bin/env python3
"""
SonarQube REST API Client Utility
Interactive and automated CLI tool for querying quality gate conditions,
issues, security hotspots, and analysis status.
"""

import argparse
import json
import sys
import urllib.request
import urllib.error
import base64

def get_auth_header(token):
    encoded = base64.b64encode(f"{token}:".encode("utf-8")).decode("utf-8")
    return {"Authorization": f"Basic {encoded}"}

def query_project_status(host_url, token, project_key):
    url = f"{host_url.rstrip('/')}/api/qualitygates/project_status?projectKey={project_key}"
    req = urllib.request.Request(url, headers=get_auth_header(token))
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except Exception as e:
        print(f"[ERROR] Failed to query SonarQube API: {e}", file=sys.stderr)
        return None

def main():
    parser = argparse.ArgumentParser(description="Query SonarQube Quality Gate Status via REST API")
    parser.add_argument("--host", default="http://localhost:9000", help="SonarQube Host URL")
    parser.add_argument("--token", default="", help="SonarQube User/Project Token")
    parser.add_argument("--project-key", default="enterprise-cloud-platform", help="SonarQube Project Key")
    parser.add_argument("--mock-test", action="store_true", help="Run in mock validation mode")
    args = parser.parse_args()

    if args.mock_test:
        print("[MOCK] Testing SonarQube API client serialization...")
        mock_data = {
            "projectStatus": {
                "status": "OK",
                "conditions": [
                    {"metricKey": "new_reliability_rating", "status": "OK", "actualValue": "1", "errorThreshold": "1"},
                    {"metricKey": "new_security_rating", "status": "OK", "actualValue": "1", "errorThreshold": "1"},
                    {"metricKey": "new_coverage", "status": "OK", "actualValue": "88.5", "errorThreshold": "80.0"},
                    {"metricKey": "new_duplicated_lines_density", "status": "OK", "actualValue": "1.2", "errorThreshold": "3.0"}
                ]
            }
        }
        print(f"Mock Quality Gate Status: {mock_data['projectStatus']['status']}")
        sys.exit(0)

    if not args.token:
        print("[ERROR] --token is required when not in --mock-test mode.", file=sys.stderr)
        sys.exit(1)

    result = query_project_status(args.host, args.token, args.project_key)
    if result:
        print(json.dumps(result, indent=2))
        sys.exit(0 if result.get("projectStatus", {}).get("status") == "OK" else 1)
    sys.exit(1)

if __name__ == "__main__":
    main()
