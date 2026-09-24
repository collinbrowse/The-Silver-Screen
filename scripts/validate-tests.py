#!/usr/bin/env python3
"""Validate that the unit-test suite can be trusted.

Green CI means nothing if tests assert nothing, or if a story is marked Done
without any test change. This script makes both of those build failures.

Checks:
  1. Every `func test...` in TheSilverScreenTests has at least one assertion (or
     XCTFail / throws expectation). Empty bodies and Xcode placeholders fail.
  2. Banned placeholder names (`testExample`, `testPerformanceExample`) never
     appear in TheSilverScreenTests.
  3. On a PR (BASE_SHA set), newly checked Done boxes in Requirements/ must be
     accompanied by a change under TheSilverScreenTests/.

Run from the repo root:
  python3 scripts/validate-tests.py
  BASE_SHA=origin/main python3 scripts/validate-tests.py
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

TESTS_ROOT = Path("TheSilverScreenTests")
REQUIREMENTS_ROOT = Path("Requirements")

BANNED_NAMES = {"testExample", "testPerformanceExample"}

# A method counts as asserting if its body mentions one of these.
ASSERTION_MARKERS = re.compile(
    r"XCTAssert|XCTFail|XCTExpect|XCTUnwrap|XCTSkip|#expect\b|assert\("
)

TEST_FUNC = re.compile(
    r"func\s+(test\w+)\s*\([^)]*\)\s*(?:async\s+)?(?:throws\s+)?\{",
    re.MULTILINE,
)

DONE_CHECKED = re.compile(r"\|\s*\[x\]\s*\|", re.IGNORECASE)
DONE_UNCHECKED = re.compile(r"\|\s*\[\s*\]\s*\|")


def fail(problems: list[str], message: str) -> None:
    problems.append(message)


def method_body(source: str, brace_start: int) -> str:
    """Return the text between the opening `{` at brace_start and its match."""
    depth = 0
    i = brace_start
    while i < len(source):
        ch = source[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return source[brace_start + 1 : i]
        i += 1
    return source[brace_start + 1 :]


def check_test_bodies(problems: list[str]) -> None:
    if not TESTS_ROOT.is_dir():
        fail(problems, f"{TESTS_ROOT}/ is missing")
        return

    swift_files = sorted(TESTS_ROOT.rglob("*.swift"))
    if not swift_files:
        fail(problems, f"{TESTS_ROOT}/ has no Swift files")
        return

    test_count = 0
    for path in swift_files:
        source = path.read_text(encoding="utf-8")
        for match in TEST_FUNC.finditer(source):
            name = match.group(1)
            test_count += 1
            rel = path.as_posix()

            if name in BANNED_NAMES:
                fail(
                    problems,
                    f"{rel}: banned placeholder `{name}` — delete it; "
                    "green CI must not come from empty Xcode templates",
                )
                continue

            body = method_body(source, match.end() - 1)
            stripped = re.sub(r"//.*?$|/\*.*?\*/", "", body, flags=re.M | re.S).strip()
            if not stripped:
                fail(problems, f"{rel}: `{name}` has an empty body")
                continue
            if not ASSERTION_MARKERS.search(body):
                fail(
                    problems,
                    f"{rel}: `{name}` has no assertion "
                    "(need XCTAssert*, XCTFail, XCTUnwrap, or XCTExpect*)",
                )

    if test_count == 0:
        fail(problems, f"{TESTS_ROOT}/ defines no `func test...` methods")
    else:
        print(f"  ok  {test_count} test method(s) under {TESTS_ROOT}/")


def git_diff_names(base: str) -> list[str]:
    result = subprocess.run(
        ["git", "diff", "--name-only", f"{base}...HEAD"],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        # Fall back to merge-base form when ... is unavailable.
        result = subprocess.run(
            ["git", "diff", "--name-only", base, "HEAD"],
            capture_output=True,
            text=True,
            check=True,
        )
    return [line for line in result.stdout.splitlines() if line]


def file_at(ref: str, path: str) -> str | None:
    result = subprocess.run(
        ["git", "show", f"{ref}:{path}"],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return None
    return result.stdout


def count_checked_done(text: str) -> int:
    return len(DONE_CHECKED.findall(text))


def check_done_coupling(problems: list[str], base: str) -> None:
    changed = git_diff_names(base)
    req_changes = [p for p in changed if p.startswith("Requirements/") and p.endswith(".md")]
    if not req_changes:
        print("  ok  no Requirements/ changes; Done coupling skipped")
        return

    newly_done = 0
    for path in req_changes:
        old = file_at(base, path) or ""
        new_path = Path(path)
        new = new_path.read_text(encoding="utf-8") if new_path.exists() else ""
        gained = count_checked_done(new) - count_checked_done(old)
        if gained > 0:
            newly_done += gained
            print(f"  ..  {path}: +{gained} Done checkbox(es)")

    if newly_done == 0:
        print("  ok  Requirements changed but no new Done checks")
        return

    test_changes = [p for p in changed if p.startswith("TheSilverScreenTests/")]
    if not test_changes:
        fail(
            problems,
            f"marked {newly_done} story Done checkbox(es) without changing "
            "TheSilverScreenTests/ — Done requires unit tests for the work",
        )
        return

    print(f"  ok  Done coupling: {newly_done} check(s) with test changes {test_changes}")


def main() -> int:
    problems: list[str] = []

    print("Test bodies:")
    check_test_bodies(problems)

    base = os.environ.get("BASE_SHA", "").strip()
    print("Done coupling:")
    if base:
        check_done_coupling(problems, base)
    else:
        print("  ok  BASE_SHA unset; Done coupling skipped (PR CI sets it)")

    if problems:
        print(f"\n{len(problems)} problem(s):")
        for problem in problems:
            print(f"  - {problem}")
        return 1

    print("\nTest suite gates valid.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
