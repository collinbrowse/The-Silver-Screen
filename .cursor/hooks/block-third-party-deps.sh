#!/usr/bin/env bash
# beforeShellExecution: deny SPM / CocoaPods / Carthage additions. Allow xcodebuild.

set -u

INPUT="$(cat || true)"

HOOK_STDIN="$INPUT" python3 - <<'PY'
import json, os, re, sys

raw = os.environ.get("HOOK_STDIN", "")
try:
    data = json.loads(raw) if raw.strip() else {}
except Exception:
    data = {}

command = data.get("command") or ""
normalized = " ".join(command.strip().split())

def allow():
    print(json.dumps({"permission": "allow"}))
    sys.exit(0)

def deny(message):
    print(json.dumps({
        "permission": "deny",
        "user_message": message,
        "agent_message": message,
    }))
    sys.exit(0)

if re.search(r"\bxcodebuild\b", normalized):
    allow()

denials = [
    (r"\bpod\s+(install|init|update|add)\b", "CocoaPods is not allowed (no 3rd-party dependencies)."),
    (r"\bswift\s+package\b", "Swift Package Manager is not allowed (no 3rd-party dependencies)."),
    (r"\bcarthage\b", "Carthage is not allowed (no 3rd-party dependencies)."),
]

for pattern, message in denials:
    if re.search(pattern, normalized, re.IGNORECASE):
        deny(message)

mentions_manifest = re.search(r"(?:^|[\s/])(Podfile|Package\.swift)\b", normalized, re.IGNORECASE)
write_like = re.search(r"(?:\btouch\b|\btee\b|\bcp\b|\bmv\b|\bcat\b|[>]{1,2})", normalized)
if mentions_manifest and write_like:
    deny("Do not add Podfile or Package.swift (no 3rd-party dependencies).")

allow()
PY

exit 0
