#!/usr/bin/env python3
"""DayArk cross-platform release builder: packages locally, optionally uploads to a DRAFT.

Linux:   python3 scripts/release.py
Windows: py -3 scripts/release.py
CI:      python scripts/release.py --platform linux --android no --upload
No dependencies beyond Python 3.10+, Flutter, and optional GitHub CLI / packagers.
"""
from __future__ import annotations

import argparse
import hashlib
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_REPO = "mujtabax18/dayark"


def get_version(pubspec: Path = ROOT / "pubspec.yaml") -> str:
    content = pubspec.read_text(encoding="utf-8")
    match = re.search(r"(?m)^version:\s*(\d+\.\d+\.\d+)(?:\+\d+)?\s*$", content)
    if not match:
        raise RuntimeError(f"A release version is missing from {pubspec}")
    return match.group(1)


def ask_yes_no(question: str, default: bool = False) -> bool:
    hint = "Y/n" if default else "y/N"
    reply = input(f"{question} [{hint}]: ").strip().lower()
    if not reply:
        return default
    return reply in ("y", "yes")


def run(*args: str, cwd: Path = ROOT, capture: bool = False) -> str:
    print("+", " ".join(str(a) for a in args), flush=True)
    result = subprocess.run([str(a) for a in args], cwd=cwd, text=True,
                            stdout=subprocess.PIPE if capture else None,
                            stderr=subprocess.PIPE if capture else None)
    if result.returncode:
        detail = (result.stderr or result.stdout or "").strip()
        raise RuntimeError(f"Command failed ({result.returncode}): {args[0]} {detail[:500]}")
    return (result.stdout or "").strip()


def require_tool(cmd: str) -> None:
    if not shutil.which(cmd):
        raise RuntimeError(f"Required executable not found on PATH: {cmd}")


def zip_directory(source: Path, destination: Path, top_folder: str = "DayArk") -> Path:
    if not source.is_dir():
        raise RuntimeError(f"Missing compiled output directory: {source}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(destination, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        count = 0
        for path in sorted(source.rglob("*")):
            if path.is_file():
                archive.write(path, f"{top_folder}/{path.relative_to(source).as_posix()}")
                count += 1
        if count == 0:
            raise RuntimeError(f"Build output directory is empty: {source}")
    return destination


def checksum(path: Path) -> str:
    sha = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            sha.update(block)
    return sha.hexdigest()


def write_checksum(files: list[Path], output: Path) -> Path:
    output.write_text("".join(f"{checksum(p)}  {p.name}\n" for p in files), encoding="utf-8")
    return output


def find_inno_setup() -> str | None:
    cmd = shutil.which("ISCC.exe") or shutil.which("ISCC")
    if cmd:
        return cmd
    for envvar in ("ProgramFiles(x86)", "ProgramFiles"):
        base = os.environ.get(envvar)
        if base:
            path = Path(base) / "Inno Setup 6" / "ISCC.exe"
            if path.is_file():
                return str(path)
    return None


def build_linux(out: Path, version: str) -> list[Path]:
    if platform.system() != "Linux":
        raise RuntimeError("Linux desktop builds must run on Linux.")
    if platform.machine().lower() not in ("x86_64", "amd64"):
        raise RuntimeError("Current Linux packaging supports x86_64 only.")
    appimage_tool = shutil.which("appimagetool")
    appimage_src = ROOT / "dist" / "DayArk-x86_64.AppImage"
    zsync_src = ROOT / "dist" / "DayArk-x86_64.AppImage.zsync"
    if appimage_tool:
        # Existing AppImage builder handles both flutter build and packaging.
        appimage_src.unlink(missing_ok=True)
        zsync_src.unlink(missing_ok=True)
        run("bash", str(ROOT / "packaging/linux/build-appimage.sh"))
    else:
        run("flutter", "build", "linux", "--release")
        print("appimagetool not installed: producing portable Linux bundle ZIP only.")
    bundle = ROOT / "build/linux/x64/release/bundle"
    files = [zip_directory(bundle, out / "DayArk-linux-x86_64.zip")]
    if appimage_tool:
        if not appimage_src.is_file():
            raise RuntimeError("AppImage packaging did not produce its expected file")
        files.append(Path(shutil.copy2(appimage_src, out / appimage_src.name)))
        if not zsync_src.is_file() or zsync_src.stat().st_size == 0:
            raise RuntimeError("AppImage created without .zsync; install zsync/zsyncmake and rebuild.")
        files.append(Path(shutil.copy2(zsync_src, out / zsync_src.name)))
    return files


def build_windows(out: Path, version: str) -> list[Path]:
    if platform.system() != "Windows":
        raise RuntimeError("Windows desktop builds must run on Windows.")
    run("flutter", "build", "windows", "--release")
    bundle = ROOT / "build/windows/x64/runner/Release"
    files = [zip_directory(bundle, out / "DayArk-windows-x64.zip")]
    iscc = find_inno_setup()
    if iscc:
        installer_src = ROOT / "dist" / "DayArk-Setup-windows-x64.exe"
        installer_src.unlink(missing_ok=True)
        run(iscc, f"/DMyAppVersion={version}", str(ROOT / "packaging/windows/dayark.iss"))
        if not installer_src.is_file():
            raise RuntimeError("Inno Setup did not produce the expected installer")
        files.append(Path(shutil.copy2(installer_src, out / installer_src.name)))
    else:
        print("Inno Setup 6 not installed: producing portable Windows bundle ZIP only.")
    return files


def check_android_signing() -> None:
    # Strict check before any release build to avoid accidental unsigned APKs.
    props = ROOT / "android/key.properties"
    if not props.is_file():
        raise RuntimeError("Missing private android/key.properties. Copy the .example and fill "
                           "your existing signing details; do NOT commit it.")
    pairs = {}
    for raw in props.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if line and not line.startswith("#") and "=" in line:
            k, value = line.split("=", 1)
            pairs[k.strip()] = value.strip()
    for key in ("storeFile", "storePassword", "keyPassword", "keyAlias"):
        if not pairs.get(key) or pairs[key].startswith("REPLACE_"):
            raise RuntimeError(f"Android signing property {key} is missing in android/key.properties")
    store = (ROOT / "android/app" / pairs["storeFile"]).resolve()
    if not store.is_file():
        raise RuntimeError(f"Android signing keystore does not exist: {store}")


def build_android(out: Path) -> list[Path]:
    if platform.system() not in ("Linux", "Windows"):
        raise RuntimeError("This script supports Android release builds on Linux or Windows.")
    check_android_signing()
    run("flutter", "build", "apk", "--release")
    apk = ROOT / "build/app/outputs/flutter-apk/app-release.apk"
    if not apk.is_file():
        raise RuntimeError(f"Flutter did not produce the expected Android APK: {apk}")
    return [Path(shutil.copy2(apk, out / "DayArk.apk"))]


def ensure_clean_pushed_checkout(repo: str) -> str:
    require_tool("git")
    status = run("git", "status", "--porcelain", capture=True)
    if status:
        raise RuntimeError("Working tree is not clean. Commit and push source changes "
                           "before attaching a binary to a release tag.")
    paths = run("git", "ls-files", capture=True).splitlines()
    tracked_secret = [p for p in paths if p.endswith(("key.properties", ".jks", ".keystore", ".p12", ".p8"))
                      or p.startswith("keys/")]
    if tracked_secret:
        raise RuntimeError("Refusing upload: sensitive files tracked by Git: " + ", ".join(tracked_secret))
    sha = run("git", "rev-parse", "HEAD", capture=True)
    # Verify this exact local revision is already present on GitHub.
    run("gh", "api", f"repos/{repo}/commits/{sha}", "--silent")
    return sha


def upload_draft(tag: str, repo: str, assets: list[Path], version: str) -> None:
    require_tool("gh")
    run("gh", "auth", "status")
    sha = ensure_clean_pushed_checkout(repo)
    view = subprocess.run(["gh", "release", "view", tag, "-R", repo,
                           "--json", "isDraft", "--jq", ".isDraft"],
                          cwd=ROOT, capture_output=True, text=True)
    if view.returncode == 0:
        if view.stdout.strip().lower() != "true":
            raise RuntimeError(f"{tag} is already PUBLISHED. Refusing to alter it.")
        print(f"Using existing DRAFT release {tag}")
    else:
        release_notes = ROOT / f"GITHUB_RELEASE_{tag}.md"
        cmd = ["gh", "release", "create", tag, "--draft", "-R", repo,
               "--title", (f"DayArk {version} — Open Source Beginning" if version == "0.0.39" else f"DayArk {version}"), "--target", sha]
        if release_notes.is_file():
            cmd += ["--notes-file", str(release_notes)]
        else:
            cmd += ["--notes", f"DayArk {tag} — draft build. Please review before publishing."]
        run(*cmd)
        draft = run("gh", "release", "view", tag, "-R", repo,
                    "--json", "isDraft", "--jq", ".isDraft", capture=True)
        if draft.lower() != "true":
            raise RuntimeError("The created GitHub release is not a draft; refusing upload.")
    # Existing drafts can be safely rebuilt; prevent duplicate asset upload failures.
    run("gh", "release", "upload", tag, *(str(asset) for asset in assets), "--clobber", "-R", repo)
    print(f"DRAFT updated: https://github.com/{repo}/releases (not published)")


def main() -> int:
    parser = argparse.ArgumentParser(description="Build DayArk assets; optional DRAFT GitHub release upload")
    parser.add_argument("--platform", choices=("auto", "linux", "windows", "android"), default="auto")
    parser.add_argument("--android", choices=("ask", "yes", "no"), default="ask")
    parser.add_argument("--upload", action="store_true", help="Create/update DRAFT release and upload assets")
    parser.add_argument("--no-upload", action="store_true", help="Skip the upload prompt and keep assets locally")
    parser.add_argument("--repo", default=os.getenv("GH_REPO", DEFAULT_REPO))
    parser.add_argument("--tag", help="Override tag (must match pubspec.yaml release version)")
    parser.add_argument("--dry-run", action="store_true", help="Show plan without building/uploading")
    args = parser.parse_args()
    version = get_version()
    tag = args.tag or f"v{version}"
    if tag != f"v{version}":
        raise RuntimeError(f"Release tag {tag} must match pubspec.yaml version v{version}")
    host = platform.system()
    desktop = args.platform if args.platform != "auto" else host.lower()
    if desktop not in ("linux", "windows", "android"):
        raise RuntimeError("Only Linux and Windows hosts supported; Android builds can run on either.")
    wants_android = (desktop == "android" or args.android == "yes" or
                     (args.android == "ask" and sys.stdin.isatty() and
                      ask_yes_no("Also build signed Android APK?", default=False)))
    upload = args.upload
    out = ROOT / "dist" / tag
    print(f"DayArk {tag} | host={host} | desktop={desktop} | Android={wants_android}")
    print(f"Output: {out}")
    if args.dry_run:
        print("DRY RUN: no Flutter build, files, GitHub release or uploads created.")
        return 0
    require_tool("flutter")
    out.mkdir(parents=True, exist_ok=True)
    run("flutter", "pub", "get")
    all_files = []
    if desktop == "linux":
        files = build_linux(out, version)
        all_files.extend(files + [write_checksum(files, out / "SHA256SUMS-linux.txt")])
    elif desktop == "windows":
        files = build_windows(out, version)
        all_files.extend(files + [write_checksum(files, out / "SHA256SUMS-windows.txt")])
    if wants_android:
        files = build_android(out)
        all_files.extend(files + [write_checksum(files, out / "SHA256SUMS-android.txt")])
    if not all_files:
        raise RuntimeError("No release assets were built")
    print("\nRelease files:")
    for p in all_files:
        print(f"  {p} ({p.stat().st_size:,} bytes)")
    if not args.no_upload and not args.upload and sys.stdin.isatty():
        upload = ask_yes_no("Upload these files to a GitHub DRAFT release?", default=False)
    if upload:
        upload_draft(tag, args.repo, all_files, version)
    else:
        print("Local packaging complete. No GitHub release was changed.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (RuntimeError, OSError, subprocess.SubprocessError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
