#!/usr/bin/env python3
"""Select one or all trusted Linux build rows without editing the workflow."""
import json
import sys
from pathlib import Path

ROWS = json.loads(Path(__file__).with_name("matrix.json").read_text())
TARGETS = ("el9", "el10", "deb13", "ubuntu2404", "ubuntu2604")
assert tuple(row["target"] for row in ROWS) == TARGETS


def main() -> int:
    if len(sys.argv) not in (2, 3) or (len(sys.argv) == 3 and sys.argv[2] != "--fields"):
        print("usage: select-matrix.py <all|target> [--fields]", file=sys.stderr)
        return 2
    selection = sys.argv[1]
    if selection != "all" and selection not in TARGETS:
        print(f"Unknown target: {selection}; available: all, {', '.join(TARGETS)}", file=sys.stderr)
        return 2
    rows = ROWS if selection == "all" else [row for row in ROWS if row["target"] == selection]
    if len(sys.argv) == 3:
        if len(rows) != 1:
            print("--fields requires a single target", file=sys.stderr)
            return 2
        print(*(rows[0][field] for field in ("target", "base_image", "containerfile", "os_id", "version")), sep="\t")
    else:
        print(json.dumps({"include": rows}, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    sys.exit(main())
