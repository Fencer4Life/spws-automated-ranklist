"""Rule engine of the plugin pipeline (ADR-073).

Plan-time layer: Flow / FlowParams / Step / Rule, the PLUGINS registry and the
RULEBOOK of domestic flows, and the RuleEngine that resolves a FlowParams into
a DAG-validated, inspectable ExecutionPlan before any execution.
"""
