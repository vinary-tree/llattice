#!/usr/bin/env python3
"""Check that llattice package metadata agrees across every published surface."""

from __future__ import annotations

import json
import pathlib
import sys

import tomllib

ROOT = pathlib.Path(__file__).resolve().parents[1]


def fail(message: str) -> None:
    print(f"package metadata mismatch: {message}", file=sys.stderr)
    raise SystemExit(1)


metadata = json.loads((ROOT / "release/package-metadata.json").read_text())
cargo = tomllib.loads((ROOT / "Cargo.toml").read_text())
raku = json.loads((ROOT / "bindings/raku/META6.json").read_text())

if metadata["component"] != "llattice":
    fail(f"unexpected component {metadata['component']!r}")
if len(metadata["summary"]) > 80:
    fail("summary must be no longer than 80 characters")
if metadata["summary"].endswith("."):
    fail("summary must not end with a period")
if not metadata["description"].endswith("."):
    fail("description must end with a period")

expected = (metadata["version"], metadata["description"])
surfaces = {
    "Cargo.toml": (cargo["package"]["version"], cargo["package"]["description"]),
    "bindings/raku/META6.json": (raku["version"], raku["description"]),
}
for path, actual in surfaces.items():
    if actual != expected:
        fail(f"{path}: expected {expected!r}, found {actual!r}")

print(f"llattice package metadata agrees across {len(surfaces)} surfaces")
