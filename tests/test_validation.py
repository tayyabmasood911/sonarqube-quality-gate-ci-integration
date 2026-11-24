import os
import unittest
import subprocess

class TestSonarQubeIntegration(unittest.TestCase):
    def setUp(self):
        self.root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

    def test_core_files_exist(self):
        required = [
            "README.md",
            "Makefile",
            "SECURITY.md",
            ".gitattributes",
            "sonar-project.properties",
            "scripts/run_sonar_scanner.sh",
            "scripts/check_quality_gate.sh",
            "scripts/sonar_api_client.py",
            "scripts/healthcheck.sh",
            "docs/architecture.svg"
        ]
        for f in required:
            p = os.path.join(self.root, f)
            self.assertTrue(os.path.exists(p), f"Required file '{f}' must exist")

    def test_sonar_properties_content(self):
        prop_file = os.path.join(self.root, "sonar-project.properties")
        with open(prop_file, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("sonar.projectKey=", content)
        self.assertIn("sonar.sources=", content)
        self.assertIn("sonar.qualitygate.wait=true", content)
        self.assertIn("sonar.javascript.lcov.reportPaths=", content)

    def test_api_client_mock_mode(self):
        script = os.path.join(self.root, "scripts", "sonar_api_client.py")
        res = subprocess.run(["python", script, "--mock-test"], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0)
        self.assertIn("Mock Quality Gate Status: OK", res.stdout)

    def test_gitattributes_content(self):
        path = os.path.join(self.root, ".gitattributes")
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("* text=auto eol=lf", content)
        self.assertIn("Makefile linguist-vendored=true", content)

if __name__ == "__main__":
    unittest.main()
