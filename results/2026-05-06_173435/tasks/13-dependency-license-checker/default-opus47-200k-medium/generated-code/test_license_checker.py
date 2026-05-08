"""Unit tests for license_checker, written red/green TDD style.

Each test was written before its corresponding production code. The license
lookup is mocked so tests are fast and deterministic.
"""
import json
import os
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from license_checker import (
    parse_manifest,
    check_license,
    build_report,
    load_config,
    LicenseLookupError,
    main,
)


class TestParseManifest(unittest.TestCase):
    """Parse a dependency manifest into (name, version) pairs."""

    def test_parse_package_json(self):
        manifest = {
            "name": "demo",
            "dependencies": {"left-pad": "1.3.0", "lodash": "^4.17.21"},
            "devDependencies": {"jest": "29.0.0"},
        }
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
            json.dump(manifest, f)
            path = f.name
        try:
            deps = parse_manifest(path)
        finally:
            os.unlink(path)
        self.assertIn(("left-pad", "1.3.0"), deps)
        self.assertIn(("lodash", "^4.17.21"), deps)
        self.assertIn(("jest", "29.0.0"), deps)

    def test_parse_requirements_txt(self):
        contents = "requests==2.31.0\nflask>=2.0\n# a comment\n\nnumpy~=1.24"
        with tempfile.NamedTemporaryFile(
            "w", suffix=".txt", delete=False
        ) as f:
            f.write(contents)
            path = f.name
        try:
            deps = parse_manifest(path)
        finally:
            os.unlink(path)
        self.assertIn(("requests", "2.31.0"), deps)
        self.assertIn(("flask", ">=2.0"), deps)
        self.assertIn(("numpy", "~=1.24"), deps)
        self.assertEqual(len(deps), 3)  # comments/blank lines skipped

    def test_parse_missing_file_raises(self):
        with self.assertRaises(FileNotFoundError):
            parse_manifest("/nonexistent/path.json")

    def test_parse_unsupported_extension_raises(self):
        with tempfile.NamedTemporaryFile(
            "w", suffix=".xyz", delete=False
        ) as f:
            f.write("anything")
            path = f.name
        try:
            with self.assertRaises(ValueError):
                parse_manifest(path)
        finally:
            os.unlink(path)


class TestCheckLicense(unittest.TestCase):
    """Classify a license string given allow/deny lists."""

    def test_approved_license(self):
        self.assertEqual(
            check_license("MIT", allow=["MIT", "Apache-2.0"], deny=["GPL-3.0"]),
            "approved",
        )

    def test_denied_license(self):
        self.assertEqual(
            check_license("GPL-3.0", allow=["MIT"], deny=["GPL-3.0"]),
            "denied",
        )

    def test_unknown_license_not_in_either_list(self):
        self.assertEqual(
            check_license("WeirdLicense", allow=["MIT"], deny=["GPL-3.0"]),
            "unknown",
        )

    def test_none_license_is_unknown(self):
        self.assertEqual(
            check_license(None, allow=["MIT"], deny=["GPL-3.0"]),
            "unknown",
        )

    def test_deny_takes_precedence_over_allow(self):
        # If the same license appears in both, denial wins (safer default).
        self.assertEqual(
            check_license("MIT", allow=["MIT"], deny=["MIT"]),
            "denied",
        )


class TestBuildReport(unittest.TestCase):
    """Compose the final compliance report with the lookup function injected."""

    def test_build_report_classifies_each_dep(self):
        deps = [("left-pad", "1.3.0"), ("evil-lib", "0.1.0"), ("mystery", "9")]
        # Mocked lookup: returns a predictable license per package.
        fake_db = {
            "left-pad": "MIT",
            "evil-lib": "GPL-3.0",
            # "mystery" intentionally absent -> unknown
        }
        config = {"allow": ["MIT", "Apache-2.0"], "deny": ["GPL-3.0"]}
        report = build_report(deps, config, lookup=fake_db.get)

        by_name = {row["name"]: row for row in report}
        self.assertEqual(by_name["left-pad"]["status"], "approved")
        self.assertEqual(by_name["left-pad"]["license"], "MIT")
        self.assertEqual(by_name["left-pad"]["version"], "1.3.0")

        self.assertEqual(by_name["evil-lib"]["status"], "denied")
        self.assertEqual(by_name["evil-lib"]["license"], "GPL-3.0")

        self.assertEqual(by_name["mystery"]["status"], "unknown")
        self.assertIsNone(by_name["mystery"]["license"])

    def test_build_report_handles_lookup_errors_gracefully(self):
        deps = [("flaky", "1.0")]
        config = {"allow": ["MIT"], "deny": []}

        def boom(_name):
            raise LicenseLookupError("network down")

        report = build_report(deps, config, lookup=boom)
        self.assertEqual(report[0]["status"], "unknown")
        self.assertIn("network down", report[0]["error"])


class TestLoadConfig(unittest.TestCase):
    def test_load_config_reads_allow_and_deny(self):
        with tempfile.NamedTemporaryFile(
            "w", suffix=".json", delete=False
        ) as f:
            json.dump({"allow": ["MIT"], "deny": ["GPL-3.0"]}, f)
            path = f.name
        try:
            cfg = load_config(path)
        finally:
            os.unlink(path)
        self.assertEqual(cfg["allow"], ["MIT"])
        self.assertEqual(cfg["deny"], ["GPL-3.0"])

    def test_load_config_defaults_missing_keys(self):
        with tempfile.NamedTemporaryFile(
            "w", suffix=".json", delete=False
        ) as f:
            json.dump({}, f)
            path = f.name
        try:
            cfg = load_config(path)
        finally:
            os.unlink(path)
        self.assertEqual(cfg["allow"], [])
        self.assertEqual(cfg["deny"], [])


class TestMainCli(unittest.TestCase):
    """Smoke test the CLI end-to-end with the mock lookup."""

    def test_main_prints_report_and_exits_nonzero_on_denied(self):
        manifest = {"dependencies": {"bad": "1.0", "good": "2.0"}}
        with tempfile.TemporaryDirectory() as tmp:
            mpath = os.path.join(tmp, "package.json")
            with open(mpath, "w") as f:
                json.dump(manifest, f)
            cpath = os.path.join(tmp, "licenses.json")
            with open(cpath, "w") as f:
                json.dump({"allow": ["MIT"], "deny": ["GPL-3.0"]}, f)

            fake = {"bad": "GPL-3.0", "good": "MIT"}
            with patch("license_checker._default_lookup", side_effect=fake.get):
                rc, output = main(
                    ["--manifest", mpath, "--config", cpath, "--mock"]
                )
            self.assertEqual(rc, 1)  # denied dep -> nonzero
            self.assertIn("denied", output)
            self.assertIn("approved", output)
            self.assertIn("bad", output)
            self.assertIn("good", output)

    def test_main_returns_zero_when_all_clean(self):
        manifest = {"dependencies": {"good": "2.0"}}
        with tempfile.TemporaryDirectory() as tmp:
            mpath = os.path.join(tmp, "package.json")
            with open(mpath, "w") as f:
                json.dump(manifest, f)
            cpath = os.path.join(tmp, "licenses.json")
            with open(cpath, "w") as f:
                json.dump({"allow": ["MIT"], "deny": ["GPL-3.0"]}, f)

            with patch(
                "license_checker._default_lookup", side_effect={"good": "MIT"}.get
            ):
                rc, output = main(
                    ["--manifest", mpath, "--config", cpath, "--mock"]
                )
            self.assertEqual(rc, 0)
            self.assertIn("approved", output)


if __name__ == "__main__":
    unittest.main()
