#!/usr/bin/env python3
"""Repeatable Part 8 automated gate. Native/device acceptance remains separate."""
import argparse
import json
import platform
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--linux-build', action='store_true', help='Also compile the Linux debug bundle')
    parser.add_argument('--report', type=Path, default=ROOT / 'build/ai-release/report.json')
    args = parser.parse_args()
    checks = [
        ['flutter', 'analyze', '--no-pub', 'lib/ai', 'test/ai', 'tool/ai'],
        ['flutter', 'test', '--no-pub', 'test/ai', 'test/home_ai_feature_test.dart'],
    ]
    if args.linux_build:
        checks.append(['flutter', 'build', 'linux', '--debug', '--no-pub'])
    args.report.parent.mkdir(parents=True, exist_ok=True)
    results = []
    for index, command in enumerate(checks):
        log = args.report.parent / f'check-{index + 1}.log'
        print(f"Running {' '.join(command)}; log: {log}", flush=True)
        try:
            with log.open('w') as output:
                result = subprocess.run(command, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT)
            code = result.returncode
        except OSError as error:
            log.write_text(str(error))
            code = 127
        results.append({'command': command, 'exitCode': code, 'log': str(log)})
        print('PASS' if code == 0 else 'FAIL', flush=True)
    report = {
        'timeUtc': datetime.now(timezone.utc).isoformat(),
        'host': platform.system(),
        'automatedChecksPassed': all(check['exitCode'] == 0 for check in results),
        'checks': results,
        'releaseAccepted': False,
        'manualAcceptance': 'Pending target-device evidence; see docs/AI_PART8.md',
    }
    args.report.write_text(json.dumps(report, indent=2) + '\n')
    print(f'Report: {args.report}', flush=True)
    return 0 if report['automatedChecksPassed'] else 1


if __name__ == '__main__':
    sys.exit(main())
