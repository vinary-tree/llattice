#!/usr/bin/env python3
"""Validate that a release dispatch targets the exact Cargo version tag."""

from __future__ import annotations

import argparse
import sys
import tomllib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def cargo_version() -> str:
    with (ROOT / "Cargo.toml").open("rb") as manifest:
        return str(tomllib.load(manifest)["package"]["version"])


def validate_release_ref(ref_type: str, ref_name: str, version: str) -> str:
    if ref_type != "tag":
        raise ValueError(f"release dispatch requires a tag ref, received {ref_type!r}")

    expected = f"v{version}"
    if ref_name != expected:
        raise ValueError(
            f"release ref {ref_name!r} does not match Cargo version tag {expected!r}"
        )
    return expected


def self_test() -> None:
    assert validate_release_ref("tag", "v0.1.0", "0.1.0") == "v0.1.0"
    assert validate_release_ref("tag", "v2.0.0-rc.3", "2.0.0-rc.3") == (
        "v2.0.0-rc.3"
    )

    rejected = [
        ("branch", "master", "0.1.0"),
        ("tag", "0.1.0", "0.1.0"),
        ("tag", "v0.1.1", "0.1.0"),
        ("tag", "v0.1.0-release.1", "0.1.0"),
    ]
    for ref_type, ref_name, version in rejected:
        try:
            validate_release_ref(ref_type, ref_name, version)
        except ValueError:
            continue
        raise AssertionError(
            f"expected rejection for {ref_type=}, {ref_name=}, {version=}"
        )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ref-type")
    parser.add_argument("--ref-name")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        self_test()
        print("release-ref authority self-test passed")
        return 0

    if not args.ref_type or not args.ref_name:
        parser.error("--ref-type and --ref-name are required outside --self-test")

    try:
        expected = validate_release_ref(args.ref_type, args.ref_name, cargo_version())
    except ValueError as error:
        print(f"release-ref error: {error}", file=sys.stderr)
        return 1

    print(f"release ref agrees with {expected}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
