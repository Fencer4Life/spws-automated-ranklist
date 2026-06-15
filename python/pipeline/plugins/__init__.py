"""Plugin layer of the rule-driven pipeline (ADR-073 / ADR-074).

Each plugin is a thin wrapper that delegates to the existing `stages.py`
function(s) on a shared legacy `PipelineContext` (the `_legacy` bridge, see
`bridge.py`) and translates a former `HaltError` into a non-blocking
`ctx.fault` (see `remediation.py`). This is reuse-first: the new path calls the
same domain code today's stage pipeline does, so the M2 parity gate holds.
"""
