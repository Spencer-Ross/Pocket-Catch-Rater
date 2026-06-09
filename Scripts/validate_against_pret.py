#!/usr/bin/env python3
"""Optional dev script: compare bundled seed against pret/pokered if available."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


def parse_pokered_stats(pokered_path: Path) -> dict[int, tuple[int, int]]:
    stats_dir = pokered_path / "data" / "pokemon" / "base_stats"
    if not stats_dir.exists():
        raise FileNotFoundError(f"Could not find base_stats in {pokered_path}")

    results: dict[int, tuple[int, int]] = {}
    dex_pattern = re.compile(r"db\s+DEX_(\w+)")
    hp_pattern = re.compile(r"db\s+(\d+)\s*;\s*base hp", re.IGNORECASE)
    catch_pattern = re.compile(r"db\s+(\d+)\s*;\s*catch rate", re.IGNORECASE)

    for asm_file in sorted(stats_dir.glob("*.asm")):
        text = asm_file.read_text()
        hp_match = re.search(r"db\s+DEX_\w+\s*;\s*pokedex id\s*\n\s*db\s+(\d+)", text)
        catch_match = re.search(r"db\s+(\d+)\s*;\s*catch rate", text)
        dex_match = dex_pattern.search(text)
        if not (hp_match and catch_match and dex_match):
            continue
        # National dex order isn't in filename; use species id from species endpoint instead in real script.
        # This script is a stub for local validation workflows.
        _ = hp_match, catch_match, dex_match
    return results


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate seed data against pret/pokered")
    parser.add_argument("--seed", type=Path, required=True)
    parser.add_argument("--pokered", type=Path)
    args = parser.parse_args()

    seed = json.loads(args.seed.read_text())
    print(f"Loaded {len(seed)} seed entries from {args.seed}")

    if args.pokered:
        try:
            parse_pokered_stats(args.pokered)
            print("pret/pokered path provided. Extend this script to diff catch rates and base HP.")
        except FileNotFoundError as exc:
            print(f"Warning: {exc}")


if __name__ == "__main__":
    main()
