"""Unit tests for models.py — model definitions and pricing."""

from models import MODELS, COST_PER_MTOK


class TestModels:
    def test_models_has_opus_and_sonnet(self):
        assert "opus" in MODELS
        assert "sonnet" in MODELS

    def test_model_ids_are_strings(self):
        for short, model_id in MODELS.items():
            assert isinstance(model_id, str)
            assert len(model_id) > 0

    def test_pricing_has_all_models(self):
        for model_id in MODELS.values():
            assert model_id in COST_PER_MTOK

    def test_pricing_has_required_keys(self):
        required = {"input", "output", "cache_read", "cache_write"}
        for model_id, rates in COST_PER_MTOK.items():
            assert required.issubset(rates.keys()), f"{model_id} missing keys"

    def test_pricing_values_are_positive(self):
        for model_id, rates in COST_PER_MTOK.items():
            for key, value in rates.items():
                assert value > 0, f"{model_id}.{key} should be positive"
