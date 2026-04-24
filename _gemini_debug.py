#!/usr/bin/env python3
"""Reproduce a single Gemini-CLI judge call end-to-end and tee ALL
output — stdout, stderr, exit code, elapsed time — to a debug log.

Picks one variant × judge × kind that's currently missing a cache file
from the targeted queue; default timeout 900s.

Usage:
    python3 _gemini_debug.py                   # auto-pick first missing
    python3 _gemini_debug.py <variant-subdir>  # pick a specific variant
"""
import json
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from test_quality import (
    JUDGE_SYSTEM_PROMPT,
    DELIVERABLE_JUDGE_SYSTEM_PROMPT,
    compute_structural_metrics,
    _build_judge_message,
    _build_deliverable_message,
    _collect_deliverable_files,
)
from _panel_targeted import _collect_work


def pick_target(want_variant: str | None):
    work = _collect_work()
    if want_variant:
        for t in work:
            if t[0].name == want_variant:
                return t
        sys.exit(f"no missing work for variant {want_variant!r}")
    if not work:
        sys.exit("no missing work to reproduce")
    # Prefer a deliverable-quality call — those are the larger inputs
    # and the ones that time out more.
    for t in work:
        if t[4] == "deliverable-quality":
            return t
    return work[0]


def build_user_message(variant_dir: Path, metrics: dict, kind: str) -> str:
    if kind == "test-quality":
        # test_quality reads impl + test code from the generated dir.
        gen_dir = variant_dir / "generated-code"
        # Fall back to direct file reads if helper unavailable.
        task_desc = metrics.get("task_description", "")
        impl_code_parts = []
        test_code_parts = []
        for p in gen_dir.rglob("*"):
            if not p.is_file():
                continue
            n = p.name.lower()
            if "test" in n:
                test_code_parts.append(f"### {p.relative_to(gen_dir)}\n```\n{p.read_text(errors='replace')}\n```")
            else:
                impl_code_parts.append(f"### {p.relative_to(gen_dir)}\n```\n{p.read_text(errors='replace')}\n```")
        impl_code = "\n\n".join(impl_code_parts)
        test_code = "\n\n".join(test_code_parts)
        return _build_judge_message(task_desc, impl_code, test_code)
    else:
        # Deliverable judge: files are collected by a helper in test_quality.
        gen_dir = variant_dir / "generated-code"
        files = _collect_deliverable_files(gen_dir)
        task_desc = metrics.get("task_description", "")
        language_mode = metrics.get("language_mode", "default")
        return _build_deliverable_message(task_desc, files, language_mode)


def main() -> int:
    want = sys.argv[1] if len(sys.argv) > 1 else None
    variant_dir, metrics, _structural, judge, kind = pick_target(want)
    print(f"REPRO TARGET: {variant_dir.name} judge={judge} kind={kind}")
    print(f"  variant_dir: {variant_dir}")

    system_prompt = (DELIVERABLE_JUDGE_SYSTEM_PROMPT
                     if kind == "deliverable-quality"
                     else JUDGE_SYSTEM_PROMPT)
    user_message = build_user_message(variant_dir, metrics, kind)
    combined = f"{system_prompt}\n\n---\n\n{user_message}"

    timeout_s = int(os.environ.get("GEMINI_CLI_TIMEOUT_S", "900"))
    model = "gemini-3.1-pro-preview"
    debug_dir = Path("logs/gemini_debug")
    debug_dir.mkdir(parents=True, exist_ok=True)
    stem = f"{variant_dir.name}__{judge}__{kind}__{int(time.time())}"
    prompt_path = debug_dir / f"{stem}.prompt.txt"
    stdout_path = debug_dir / f"{stem}.stdout.txt"
    stderr_path = debug_dir / f"{stem}.stderr.txt"
    meta_path = debug_dir / f"{stem}.meta.json"

    prompt_path.write_text(combined)
    print(f"  wrote prompt: {prompt_path} ({len(combined):,} chars)")
    print(f"  timeout: {timeout_s}s")

    run_dir = tempfile.mkdtemp(prefix="gemini-judge-debug-")
    argv = ["gemini", "-p", combined, "-m", model, "-o", "json",
            "--approval-mode", "plan"]
    t0 = time.monotonic()
    try:
        result = subprocess.run(
            argv, capture_output=True, text=True,
            timeout=timeout_s, cwd=run_dir,
        )
        elapsed = time.monotonic() - t0
        stdout_path.write_text(result.stdout)
        stderr_path.write_text(result.stderr)
        meta = {
            "elapsed_s": round(elapsed, 2),
            "exit_code": result.returncode,
            "timed_out": False,
            "model": model,
            "timeout_s": timeout_s,
            "variant": variant_dir.name,
            "judge": judge,
            "kind": kind,
            "stdout_bytes": len(result.stdout),
            "stderr_bytes": len(result.stderr),
            "prompt_chars": len(combined),
            "argv": argv[:1] + ["<prompt-elided>"] + argv[3:],
        }
        meta_path.write_text(json.dumps(meta, indent=2))
        print(f"  done: exit={result.returncode} elapsed={elapsed:.1f}s")
        print(f"  stdout: {stdout_path} ({len(result.stdout):,} bytes)")
        print(f"  stderr: {stderr_path} ({len(result.stderr):,} bytes)")
    except subprocess.TimeoutExpired as e:
        elapsed = time.monotonic() - t0
        stdout_path.write_text(e.stdout.decode() if isinstance(e.stdout, bytes)
                               else (e.stdout or ""))
        stderr_path.write_text(e.stderr.decode() if isinstance(e.stderr, bytes)
                               else (e.stderr or ""))
        meta = {
            "elapsed_s": round(elapsed, 2),
            "timed_out": True,
            "timeout_s": timeout_s,
            "variant": variant_dir.name,
            "judge": judge,
            "kind": kind,
            "prompt_chars": len(combined),
        }
        meta_path.write_text(json.dumps(meta, indent=2))
        print(f"  TIMED OUT after {elapsed:.1f}s (ceiling {timeout_s}s)")
        print(f"  partial stdout: {stdout_path}")
        print(f"  partial stderr: {stderr_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
