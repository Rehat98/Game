#!/usr/bin/env python3
"""Populate the `date` field of each puzzle sequentially from a start date.

Usage:
  python3 scripts/assign-dates.py <path-to-puzzles.json> <YYYY-MM-DD>

Mutates the file in place.
"""
import json
import sys
import datetime as dt


def main(path: str, start_iso: str) -> int:
    start = dt.date.fromisoformat(start_iso)
    with open(path) as f:
        puzzles = json.load(f)
    for i, p in enumerate(puzzles):
        p["date"] = (start + dt.timedelta(days=i)).isoformat()
    with open(path, "w") as f:
        json.dump(puzzles, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"Wrote {len(puzzles)} dates: {puzzles[0]['date']} ... {puzzles[-1]['date']}")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    sys.exit(main(sys.argv[1], sys.argv[2]))
