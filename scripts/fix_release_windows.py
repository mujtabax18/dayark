#!/usr/bin/env python3
"""Apply a targeted Windows command-launch fix to DayArk's release.py.

Runs from scripts/ under a DayArk checkout; preserves all other release logic.
Creates a backup in the ignored dist/script_backups/ directory.
"""
from __future__ import annotations

from pathlib import Path
import re
import shutil
import sys

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "release.py"
START_MARKER = "# DAYARK_WINDOWS_BATCH_LAUNCH_V2"

REPLACEMENT = '''def run(*args: str, cwd: Path = ROOT, capture: bool = False) -> str:
    # DAYARK_WINDOWS_BATCH_LAUNCH_V2
    if not args:
        raise ValueError("run() requires an executable")
    command = [str(arg) for arg in args]
    original = command[0]
    executable = shutil.which(original)
    if not executable and Path(original).is_file():
        executable = original
    if not executable:
        raise RuntimeError(
            f"Cannot find {original!r} on PATH. On Windows run 'where.exe flutter' "
            "and 'py -3 -c \\\"import shutil; print(shutil.which(\\\"flutter\\\"))\\\"'."
        )
    command[0] = str(executable)

    # .bat/.cmd launch via cmd.exe on Windows; normal executables run directly.
    # Only the commands defined in this release tool are used here.
    is_batch = (platform.system() == "Windows" and
                Path(executable).suffix.lower() in (".bat", ".cmd"))
    invocation = subprocess.list2cmdline(command) if is_batch else command
    print("+", " ".join(str(arg) for arg in args), flush=True)
    if is_batch:
        print("  Windows batch launcher:", executable, flush=True)

    try:
        result = subprocess.run(
            invocation, cwd=cwd, text=True, shell=is_batch,
            stdout=subprocess.PIPE if capture else None,
            stderr=subprocess.PIPE if capture else None,
        )
    except OSError as exc:
        raise RuntimeError(
            f"Unable to launch {original!r} (resolved to {executable!r}): "
            f"{exc}. Check PATH and the Windows command processor."
        ) from exc

    if result.returncode:
        detail = (result.stderr or result.stdout or "").strip()
        raise RuntimeError(
            f"Command failed ({result.returncode}): {original} {detail[:500]}"
        )
    return (result.stdout or "").strip()


'''


def apply() -> int:
    if not SCRIPT.is_file():
        print(f"ERROR: Missing {SCRIPT}. Extract this patch into the DayArk project root.", file=sys.stderr)
        return 1
    content = SCRIPT.read_text(encoding="utf-8")
    if START_MARKER in content:
        print("Windows batch launch fix already applied:", SCRIPT)
        return 0
    pattern = re.compile(r"(?ms)^def run\(.*?(?=^def require_tool\()")
    match = pattern.search(content)
    if not match:
        print("ERROR: Expected run() and require_tool() functions not found. "
              "No files changed.", file=sys.stderr)
        return 1
    backup_dir = ROOT / "dist" / "script_backups"
    backup_dir.mkdir(parents=True, exist_ok=True)
    backup = backup_dir / "release.py.before_windows_launch_v2.bak"
    if not backup.exists():
        shutil.copy2(SCRIPT, backup)
    updated = content[:match.start()] + REPLACEMENT + content[match.end():]
    # Validate syntax before replacing the working file.
    compile(updated, str(SCRIPT), "exec")
    SCRIPT.write_text(updated, encoding="utf-8")
    print("Updated:", SCRIPT)
    print("Backup:", backup)
    print("Run: python3 scripts/release.py --platform windows --android no --no-upload")
    return 0


if __name__ == "__main__":
    sys.exit(apply())
