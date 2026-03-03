"""
Export / Import scoring config via Supabase RPC.

Usage:
  python -m python.calibration.calibrate_config export --season 1 --output scoring_config.json
  python -m python.calibration.calibrate_config import --input scoring_config.json
"""

import argparse
import json
import os
from pathlib import Path

from supabase import create_client

SUPABASE_URL = os.environ.get("SUPABASE_URL", "")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY", "")

sb = create_client(SUPABASE_URL, SUPABASE_KEY) if SUPABASE_URL and SUPABASE_KEY else None


def export_config(season_id: int, output_path: Path) -> None:
    """Export scoring config for a season to a local JSON file."""
    result = sb.rpc("fn_export_scoring_config", {"p_id_season": season_id}).execute()
    config = result.data
    output_path.write_text(json.dumps(config, indent=2, ensure_ascii=False))
    print(f"Exported config for season {season_id} → {output_path}")


def import_config(input_path: Path) -> None:
    """Import a local JSON config file into the database."""
    config = json.loads(input_path.read_text())
    sb.rpc("fn_import_scoring_config", {"p_config": config}).execute()
    print(f"Imported config from {input_path} → season {config['id_season']}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Scoring config export/import")
    sub = parser.add_subparsers(dest="command")

    exp = sub.add_parser("export")
    exp.add_argument("--season", type=int, required=True, help="Season ID")
    exp.add_argument("--output", type=Path, default=Path("scoring_config.json"))

    imp = sub.add_parser("import")
    imp.add_argument("--input", type=Path, default=Path("scoring_config.json"))

    args = parser.parse_args()
    if args.command == "export":
        export_config(args.season, args.output)
    elif args.command == "import":
        import_config(args.input)
