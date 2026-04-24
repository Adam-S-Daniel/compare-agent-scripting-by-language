# ρ = +0.00 on language-only Tests Quality — skeptical read

**TL;DR:** not a real disagreement. Four of the five languages are in a statistical dead heat under Haiku, so the rank Spearman is being driven by sub-noise jitter in mean-Overall scores. The only signal both judges actually carry is "bash is last" — and they agree on that.

## Per-language means (Overall, complete-panel runs only)

| Language | n | Haiku mean | Haiku rank | Gemini mean | Gemini rank |
|---|---:|---:|---:|---:|---:|
| default | 60 | 2.800 | 1 | 4.200 | 4 |
| typescript-bun | 63 | 2.794 | 2 | 4.381 | 3 |
| powershell | 62 | 2.790 | 3 | 4.403 | 2 |
| powershell-tool | 47 | 2.787 | 4 | 4.617 | 1 |
| bash | 63 | 2.460 | 5 | 4.127 | 5 |

## Is +0.00 genuinely surprising?

No. Haiku's top four means span **0.013 points** on a 1–5 scale; the per-language SEM is roughly **0.09–0.11**, i.e. an order of magnitude wider than the entire top-4 spread. With n=5 buckets and effectively one separable bucket per judge (bash), Spearman has only four "tie-like" positions to shuffle and no statistical power. Gemini, by contrast, spreads its top four across **0.417 points** — a real ordering. So: both judges agree bash is worst (d=0 on the rank that carries signal); the rest is coin-flipping inside Haiku's floor-compressed distribution.

## The reversals

Five of the six non-bash pairs flip. On Haiku's side, every flip has a gap **≤ 0.013** — indistinguishable from noise. On Gemini's side, four of the five flips have gaps **≥ 0.18** — real preferences. The worst is `default` vs `powershell-tool`: Haiku prefers default by 0.013; Gemini prefers powershell-tool by 0.417.

## Floor-compression contribution

Haiku hit Overall ≤ 1.5 on 8 runs (Gemini: 2). Stripping Haiku-floored runs moves ρ from +0.00 to **+0.10** — better, but still effectively zero. Missing-file hallucinations explain only a sliver of this. The dominant driver is Haiku's **narrow dynamic range on the non-bash languages** (mean ≈ 2.79 regardless of language), not the floor events themselves.

## Recommendation

Low-priority artifact of n=5 buckets plus Haiku's compressed scale — it'll almost certainly stabilize once more tasks widen the per-language means beyond Haiku's 0.01-point jitter; worth noting, not worth acting on.

*Provenance: `claude-opus-4-7[1m]` at effort `xhigh`, 2026-04-21.*
