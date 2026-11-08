#!/usr/bin/env python3
"""Validate Dart library parts and the one-time behavior-preserving split.

Usage (from the extracted archive root):
  python3 tool/verify_refactor.py
  python3 tool/verify_refactor.py --verify-snapshot

The optional snapshot test reassembles each changed Dart library into the
original sequence and compares its SHA-256. This is for verifying the initial
refactor; it will fail after intentional code modifications.
"""

import argparse
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
DART = ROOT / 'lib'
PART_RE = re.compile(r"(?m)^part\s+(['\"])([^'\"]+)\1\s*;")
PART_OF_RE = re.compile(r"(?m)^part\s+of\s+(['\"])([^'\"]+)\1\s*;")


def validate_parts():
    failures = []
    seen = {}
    sources = list(DART.rglob('*.dart'))
    for source in sources:
        data = source.read_text(encoding='utf-8')
        if PART_OF_RE.search(data):
            continue
        for match in PART_RE.finditer(data):
            destination = (source.parent / match.group(2)).resolve()
            if not destination.is_file():
                failures.append(f'Missing part: {source.relative_to(ROOT)} -> {match.group(2)}')
                continue
            seen.setdefault(destination, set()).add(source.resolve())
            child = destination.read_text(encoding='utf-8')
            owner = PART_OF_RE.search(child)
            if not owner or (destination.parent / owner.group(2)).resolve() != source.resolve():
                failures.append(f'Incorrect part-of owner: {destination.relative_to(ROOT)}')
            if re.search(r'(?m)^(?:import|export|library)\b', child):
                failures.append(f'Invalid directive inside part: {destination.relative_to(ROOT)}')
    for part in sources:
        if PART_OF_RE.search(part.read_text(encoding='utf-8')) and part.resolve() not in seen:
            failures.append(f'Orphan part-of file: {part.relative_to(ROOT)}')
    for part, owners in seen.items():
        if len(owners) != 1:
            failures.append(f'A part belongs to multiple libraries: {part.relative_to(ROOT)}')
    return failures, len(seen)


def verify_snapshot():
    failures = []
    entries = json.loads((ROOT / 'tool' / 'refactor_manifest.json').read_text(encoding='utf-8'))
    for entry in entries:
        filename = ROOT / entry['original_file']
        data = filename.read_text(encoding='utf-8')
        injected = '\n\n' + '\n'.join(f"part 'parts/{Path(n).name}';" for n in entry['parts'])
        if data.count(injected) != 1:
            failures.append(f'Injected directives changed: {entry["original_file"]}')
            continue
        original = data.replace(injected, '', 1)
        for name in entry['parts']:
            part = (ROOT / name).read_text(encoding='utf-8')
            marker = f"part of '../{filename.name}';\n\n"
            if not part.startswith(marker):
                failures.append(f'Unexpected part header: {name}')
                continue
            original += part[len(marker):]
        if hashlib.sha256(original.encode('utf-8')).hexdigest() != entry['sha256_original']:
            failures.append(f'Original Dart source was altered: {entry["original_file"]}')
    return failures, len(entries)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--verify-snapshot', action='store_true')
    args = parser.parse_args()
    failures, count = validate_parts()
    print(f'Library references: {count} part files checked')
    if args.verify_snapshot:
        snapshot_failures, libraries = verify_snapshot()
        failures.extend(snapshot_failures)
        print(f'Lossless extraction: {libraries} original files checked')
    for failure in failures:
        print('FAIL: ' + failure)
    if failures:
        raise SystemExit(1)
    print('PASS')


if __name__ == '__main__':
    main()
