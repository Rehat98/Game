#!/usr/bin/env python3
"""Validate the puzzle JSON file: schema, duplicates, distribution."""
import json
import sys
import collections

REQUIRED_FIELDS = {"id", "date", "emoji", "answer", "category", "subcategory", "difficulty"}
VALID_CATEGORIES = {"Movie", "Song", "Book", "Brand", "Celeb"}
VALID_DIFFICULTIES = {"medium", "hard"}


def main(path: str) -> int:
    with open(path) as f:
        puzzles = json.load(f)

    errors: list[str] = []

    if not isinstance(puzzles, list):
        return _fail([f"Top-level JSON must be a list, got {type(puzzles).__name__}"])

    for i, p in enumerate(puzzles):
        missing = REQUIRED_FIELDS - p.keys()
        if missing:
            errors.append(f"#{i} ({p.get('id','?')}): missing fields {sorted(missing)}")
        if p.get("category") not in VALID_CATEGORIES:
            errors.append(f"#{i} ({p.get('id','?')}): invalid category {p.get('category')!r}")
        if p.get("difficulty") not in VALID_DIFFICULTIES:
            errors.append(f"#{i} ({p.get('id','?')}): invalid difficulty {p.get('difficulty')!r}")
        answer = p.get("answer", "")
        if answer and not all(c.isupper() or not c.isalpha() for c in answer):
            errors.append(f"#{i} ({p.get('id','?')}): answer must be UPPERCASE: {answer!r}")
        if not p.get("emoji"):
            errors.append(f"#{i} ({p.get('id','?')}): emoji empty")

    ids = [p["id"] for p in puzzles if "id" in p]
    for dup, n in collections.Counter(ids).items():
        if n > 1:
            errors.append(f"duplicate id: {dup} (x{n})")

    answers = [p["answer"] for p in puzzles if "answer" in p]
    for dup, n in collections.Counter(answers).items():
        if n > 1:
            errors.append(f"duplicate answer: {dup!r} (x{n})")

    emojis = [p["emoji"] for p in puzzles if "emoji" in p]
    for dup, n in collections.Counter(emojis).items():
        if n > 1:
            errors.append(f"duplicate emoji pattern: {dup!r} (x{n})")

    cat_counts = collections.Counter(p["category"] for p in puzzles if "category" in p)
    diff_counts = collections.Counter(p["difficulty"] for p in puzzles if "difficulty" in p)
    print(f"Total: {len(puzzles)} puzzles")
    print(f"Categories: {dict(cat_counts)}")
    print(f"Difficulties: {dict(diff_counts)}")

    if errors:
        return _fail(errors)
    print("OK: all checks passed.")
    return 0


def _fail(errs: list[str]) -> int:
    print("FAILED:", file=sys.stderr)
    for e in errs:
        print(f"  - {e}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "puzzles.json"))
