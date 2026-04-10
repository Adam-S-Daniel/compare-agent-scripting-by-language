"""Unit tests for llm_providers.py — provider registry and availability."""

import pytest

from llm_providers import (
    ClaudeCLIProvider,
    LLMProvider,
    PROVIDERS,
    DEFAULT_PROVIDER,
    get_provider,
)


class TestProviderRegistry:
    def test_claude_cli_registered(self):
        assert "claude-cli" in PROVIDERS

    def test_default_provider_is_claude_cli(self):
        assert DEFAULT_PROVIDER == "claude-cli"

    def test_get_provider_returns_instance(self):
        # This may raise RuntimeError if CLI not available, which is fine
        try:
            p = get_provider("claude-cli")
            assert isinstance(p, ClaudeCLIProvider)
            assert isinstance(p, LLMProvider)
        except RuntimeError:
            pytest.skip("claude CLI not available in this environment")

    def test_get_provider_unknown_raises(self):
        with pytest.raises(ValueError, match="Unknown provider"):
            get_provider("nonexistent-provider")

    def test_get_provider_default(self):
        try:
            p = get_provider(None)
            assert p.name == "claude-cli"
        except RuntimeError:
            pytest.skip("claude CLI not available")


class TestClaudeCLIProvider:
    def test_name(self):
        p = ClaudeCLIProvider()
        assert p.name == "claude-cli"

    def test_is_available_returns_bool(self):
        p = ClaudeCLIProvider()
        result = p.is_available()
        assert isinstance(result, bool)

    def test_provider_has_judge_method(self):
        p = ClaudeCLIProvider()
        assert callable(p.judge)


class TestLLMProviderInterface:
    def test_cannot_instantiate_base(self):
        with pytest.raises(TypeError):
            LLMProvider()

    def test_subclass_must_implement_methods(self):
        class IncompleteProvider(LLMProvider):
            name = "incomplete"

        with pytest.raises(TypeError):
            IncompleteProvider()
