"""
TDD Cycle 2: Secret Classification by Urgency
==============================================
RED:  Write tests for classifying secrets as expired, warning, or ok.
GREEN: Implement classify_secret() using date arithmetic.
REFACTOR: Use a reference_date param for deterministic testing (no mocking date.today).

We use a fixed reference_date in all tests to ensure deterministic results
without needing to mock date.today(). This is the key testing strategy:
inject the "now" date rather than relying on the system clock.
"""
import unittest
import sys
import os
from datetime import date

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from secret_rotation_validator import (
    SecretConfig, classify_secret, EXPIRED, WARNING, OK,
)


def _make_config(
    name: str = "TEST_SECRET",
    last_rotated: str = "2026-01-01",
    rotation_policy_days: int = 90,
    required_by: list[str] | None = None,
) -> SecretConfig:
    """Test fixture helper: build a SecretConfig with sensible defaults."""
    return SecretConfig(
        name=name,
        last_rotated=date.fromisoformat(last_rotated),
        rotation_policy_days=rotation_policy_days,
        required_by=required_by or ["test-service"],
    )


class TestClassifyExpired(unittest.TestCase):
    """Secrets past their rotation deadline should be classified as EXPIRED."""

    def test_secret_expired_by_one_day(self):
        """Secret rotated 91 days ago with a 90-day policy → expired."""
        config = _make_config(last_rotated="2026-01-01", rotation_policy_days=90)
        # Reference: April 2 = 91 days after Jan 1
        result = classify_secret(config, warning_window_days=14, reference_date=date(2026, 4, 2))
        self.assertEqual(result.status, EXPIRED)
        self.assertEqual(result.days_until_expiry, -1)
        self.assertEqual(result.days_since_rotation, 91)

    def test_secret_expired_long_ago(self):
        """A secret rotated well past its deadline."""
        config = _make_config(last_rotated="2025-06-01", rotation_policy_days=30)
        result = classify_secret(config, reference_date=date(2026, 4, 1))
        self.assertEqual(result.status, EXPIRED)
        self.assertTrue(result.days_until_expiry < 0)


class TestClassifyWarning(unittest.TestCase):
    """Secrets expiring within the warning window should be classified as WARNING."""

    def test_secret_expiring_within_warning_window(self):
        """Secret expires in 10 days with 14-day warning window → warning."""
        config = _make_config(last_rotated="2026-01-01", rotation_policy_days=90)
        # 80 days after rotation → 10 days until expiry
        result = classify_secret(config, warning_window_days=14, reference_date=date(2026, 3, 22))
        self.assertEqual(result.status, WARNING)
        self.assertEqual(result.days_until_expiry, 10)

    def test_secret_expiring_exactly_on_warning_boundary(self):
        """Secret expires in exactly warning_window_days → should be WARNING (inclusive)."""
        config = _make_config(last_rotated="2026-01-01", rotation_policy_days=90)
        # 76 days after rotation → 14 days until expiry, with 14-day window
        result = classify_secret(config, warning_window_days=14, reference_date=date(2026, 3, 18))
        self.assertEqual(result.status, WARNING)
        self.assertEqual(result.days_until_expiry, 14)

    def test_secret_expiring_today(self):
        """Secret expires today (0 days until expiry) → WARNING, not expired."""
        config = _make_config(last_rotated="2026-01-01", rotation_policy_days=90)
        # Exactly 90 days after rotation
        result = classify_secret(config, warning_window_days=14, reference_date=date(2026, 4, 1))
        self.assertEqual(result.status, WARNING)
        self.assertEqual(result.days_until_expiry, 0)


class TestClassifyOk(unittest.TestCase):
    """Secrets well within their rotation period should be classified as OK."""

    def test_recently_rotated_secret(self):
        """Secret rotated 5 days ago with 90-day policy → ok."""
        config = _make_config(last_rotated="2026-03-27", rotation_policy_days=90)
        result = classify_secret(config, warning_window_days=14, reference_date=date(2026, 4, 1))
        self.assertEqual(result.status, OK)
        self.assertEqual(result.days_since_rotation, 5)
        self.assertEqual(result.days_until_expiry, 85)

    def test_secret_just_outside_warning_window(self):
        """Secret expires in 15 days with 14-day window → ok (not yet warning)."""
        config = _make_config(last_rotated="2026-01-01", rotation_policy_days=90)
        # 75 days after rotation → 15 days until expiry
        result = classify_secret(config, warning_window_days=14, reference_date=date(2026, 3, 17))
        self.assertEqual(result.status, OK)
        self.assertEqual(result.days_until_expiry, 15)


class TestClassifyEdgeCases(unittest.TestCase):
    """Edge cases for classification logic."""

    def test_custom_warning_window(self):
        """A larger warning window should classify more secrets as WARNING."""
        config = _make_config(last_rotated="2026-01-01", rotation_policy_days=90)
        # 60 days after rotation → 30 days until expiry
        # With default 14-day window → ok; with 30-day window → warning
        result_narrow = classify_secret(config, warning_window_days=14, reference_date=date(2026, 3, 2))
        result_wide = classify_secret(config, warning_window_days=30, reference_date=date(2026, 3, 2))
        self.assertEqual(result_narrow.status, OK)
        self.assertEqual(result_wide.status, WARNING)

    def test_zero_warning_window(self):
        """With a 0-day warning window, secrets go directly from OK to EXPIRED."""
        config = _make_config(last_rotated="2026-01-01", rotation_policy_days=90)
        # Expires today → with 0 window, days_until_expiry=0 is still within window (<=0)
        result = classify_secret(config, warning_window_days=0, reference_date=date(2026, 4, 1))
        self.assertEqual(result.status, WARNING)

    def test_negative_warning_window_raises_error(self):
        """Negative warning window is invalid."""
        config = _make_config(last_rotated="2026-01-01", rotation_policy_days=90)
        with self.assertRaises(ValueError):
            classify_secret(config, warning_window_days=-1, reference_date=date(2026, 4, 1))

    def test_secret_config_preserved_in_status(self):
        """The original SecretConfig should be accessible from the SecretStatus."""
        config = _make_config(name="MY_KEY")
        result = classify_secret(config, reference_date=date(2026, 2, 1))
        self.assertIs(result.config, config)
        self.assertEqual(result.config.name, "MY_KEY")


if __name__ == "__main__":
    unittest.main()
