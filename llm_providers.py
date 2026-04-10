"""LLM provider abstraction for benchmark evaluation tasks.

This module provides a pluggable interface for calling LLMs. The benchmark
runner (runner.py) is inherently tied to the Claude Code CLI since it tests
CLI-specific features (streaming, hooks, workspace isolation). This provider
layer is for *evaluation* tasks like the LLM-as-judge in test_quality.py,
where the LLM is used as a tool rather than being the thing under test.

CURRENT PROVIDERS
=================
- claude-cli: Uses the pre-authenticated Claude Code CLI (`claude -p`).
              No API key or additional config required — works with any
              authenticated Claude Code installation (subscription, API key,
              or OAuth).

ADDING A NEW PROVIDER
=====================
1. Create a new class that inherits from LLMProvider.
2. Implement the `judge()` method: takes a system prompt and user message,
   returns a dict with {"text": str, "cost_usd": float, "input_tokens": int,
   "output_tokens": int} or None on failure.
3. Implement the `is_available()` method: returns True if the provider can
   be used (e.g., CLI is on PATH, or API key is set).
4. Register the provider in the PROVIDERS dict at the bottom of this file.
5. Add any new dependencies to the docstring and AGENTS.md.

Example skeleton for an Anthropic API provider:

    class AnthropicAPIProvider(LLMProvider):
        name = "anthropic-api"

        def is_available(self) -> bool:
            try:
                import anthropic  # noqa: F401
                return bool(os.environ.get("ANTHROPIC_API_KEY"))
            except ImportError:
                return False

        def judge(self, system_prompt: str, user_message: str,
                  model: str = "claude-sonnet-4-6") -> dict | None:
            import anthropic
            client = anthropic.Anthropic()
            response = client.messages.create(
                model=model, max_tokens=1024, system=system_prompt,
                messages=[{"role": "user", "content": user_message}],
            )
            return {
                "text": response.content[0].text,
                "cost_usd": ...,  # compute from response.usage
                "input_tokens": response.usage.input_tokens,
                "output_tokens": response.usage.output_tokens,
            }
"""

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from abc import ABC, abstractmethod


class LLMProvider(ABC):
    """Base class for LLM providers used in evaluation tasks."""

    name: str = "base"

    @abstractmethod
    def is_available(self) -> bool:
        """Return True if this provider is ready to use."""
        ...

    @abstractmethod
    def judge(self, system_prompt: str, user_message: str,
              model: str = "sonnet") -> dict | None:
        """Send a prompt and return the response.

        Args:
            system_prompt: System-level instructions for the LLM.
            user_message: The user message (task description + code).
            model: Model alias or ID. Providers map this to their own
                   model identifiers as needed.

        Returns:
            dict with keys:
                text: str — the model's text response
                cost_usd: float — cost of this call (0 if unknown/free)
                input_tokens: int — input tokens used
                output_tokens: int — output tokens used
            or None if the call failed.
        """
        ...


class ClaudeCLIProvider(LLMProvider):
    """LLM provider using the pre-authenticated Claude Code CLI.

    Uses `claude -p` with `--output-format json`. Works with any
    authentication method the CLI supports (subscription, API key, OAuth).
    No additional configuration required.
    """

    name = "claude-cli"

    def is_available(self) -> bool:
        return shutil.which("claude") is not None

    def judge(self, system_prompt: str, user_message: str,
              model: str = "sonnet") -> dict | None:
        # Run from a temp dir to avoid CLAUDE.md auto-discovery
        judge_dir = tempfile.mkdtemp(prefix="llm-judge-")
        try:
            result = subprocess.run(
                [
                    "claude", "-p",
                    "--model", model,
                    "--system-prompt", system_prompt,
                    "--output-format", "json",
                    "--max-budget-usd", "0.50",
                ],
                input=user_message,
                capture_output=True,
                text=True,
                timeout=120,
                cwd=judge_dir,
            )
        except subprocess.TimeoutExpired:
            print(f"  [{self.name}] timed out (120s)", file=sys.stderr)
            return None
        except Exception as e:
            print(f"  [{self.name}] subprocess error: {e}", file=sys.stderr)
            return None
        finally:
            shutil.rmtree(judge_dir, ignore_errors=True)

        if result.returncode != 0:
            snippet = result.stderr[:200] if result.stderr else "(no stderr)"
            print(f"  [{self.name}] CLI failed (exit {result.returncode}): {snippet}",
                  file=sys.stderr)
            return None

        try:
            parsed = json.loads(result.stdout)
        except json.JSONDecodeError:
            print(f"  [{self.name}] non-JSON output: {result.stdout[:200]}",
                  file=sys.stderr)
            return None

        # CLI may return an array of events (stream) or a single object.
        # Extract the result event.
        if isinstance(parsed, list):
            envelope = next((e for e in parsed if e.get("type") == "result"), parsed[-1] if parsed else {})
        else:
            envelope = parsed

        if envelope.get("is_error"):
            print(f"  [{self.name}] error: {envelope.get('result', '')[:200]}",
                  file=sys.stderr)
            return None

        # Strip markdown fences if present
        raw = envelope.get("result", "")
        text = re.sub(r"^```(?:json)?\s*\n?", "", raw.strip())
        text = re.sub(r"\n?```\s*$", "", text).strip()

        usage = envelope.get("usage", {})
        return {
            "text": text,
            "cost_usd": envelope.get("total_cost_usd", 0),
            "input_tokens": usage.get("input_tokens", 0),
            "output_tokens": usage.get("output_tokens", 0),
        }


# ---------------------------------------------------------------------------
# Provider registry
# ---------------------------------------------------------------------------

PROVIDERS: dict[str, type[LLMProvider]] = {
    "claude-cli": ClaudeCLIProvider,
}

DEFAULT_PROVIDER = "claude-cli"


def get_provider(name: str | None = None) -> LLMProvider:
    """Get an LLM provider instance by name.

    Args:
        name: Provider name (key in PROVIDERS). If None, uses DEFAULT_PROVIDER.

    Returns:
        An instantiated LLMProvider.

    Raises:
        ValueError: If the provider name is unknown.
        RuntimeError: If the provider is not available.
    """
    name = name or DEFAULT_PROVIDER
    cls = PROVIDERS.get(name)
    if cls is None:
        available = ", ".join(PROVIDERS.keys())
        raise ValueError(f"Unknown provider '{name}'. Available: {available}")
    provider = cls()
    if not provider.is_available():
        raise RuntimeError(
            f"Provider '{name}' is not available. "
            f"Check that the required tools/credentials are configured."
        )
    return provider
