"""Promote as a verified replay (ADR-108).

CERT starts every domestic ingestion from PROD's master data with identical
fencer ids; promote then replays the verified CERT run on PROD in one
transaction. This package holds the Python half: the identity comparison, the
refresh, the gate and the lifecycle rule.
"""
