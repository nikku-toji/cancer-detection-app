#!/usr/bin/env python3
"""
run_app.py
----------
Automates the macOS flutter run + dylib copy workflow.

Usage:
  python run_app.py
  python run_app.py --release
  python run_app.py --dylib ~/path/to/libtensorflowlite_c.dylib
"""

import argparse
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

# ------------------------------------------------------------------ #
# Config
# ------------------------------------------------------------------ #
PROJECT_DIR = Path(__file__).parent.parent
DYLIB_NAME = 'libtensorflowlite_c-mac.dylib'
DEFAULT_DYLIB_SEARCH = [
    Path.home() / 'Downloads' / 'libtensorflowlite_c.2.17.1.dylib',
    Path.home() / 'Downloads' / 'libtensorflowlite_c.dylib',
    Path.home() / 'Downloads' / 'libtensorflowlite_c.2.14.0.dylib',
    Path('/usr/local/lib/libtensorflowlite_c.dylib'),
]


def find_dylib(override: str = None) -> Path:
    if override:
        p = Path(override)
        if not p.exists():
            print(f'ERROR: dylib not found at {p}')
            sys.exit(1)
        return p
    for p in DEFAULT_DYLIB_SEARCH:
        if p.exists():
            print(f'Found dylib: {p}')
            return p
    print('ERROR: Could not find libtensorflowlite_c dylib.')
    print('Download from: https://github.com/tphakala/tflite_c/releases')
    print('Then run: python run_app.py --dylib ~/Downloads/libtensorflowlite_c.dylib')
    sys.exit(1)


def get_app_resources(build_type: str) -> Path:
    if build_type == 'release':
        return PROJECT_DIR / 'build/macos/Build/Products/Release/cancer_detection_app.app/Contents/Resources'
    return PROJECT_DIR / 'build/macos/Build/Products/Debug/cancer_detection_app.app/Contents/Resources'


def copy_dylib(dylib_src: Path, resources_dir: Path):
    dest = resources_dir / DYLIB_NAME
    resources_dir.mkdir(parents=True, exist_ok=True)

    # Remove existing (avoids permission denied on re-copy)
    if dest.exists():
        dest.unlink()
        print(f'Removed old: {dest.name}')

    shutil.copy2(dylib_src, dest)
    dest.chmod(0o755)
    print(f'Copied dylib -> {dest}')


def flutter_clean():
    print('\nRunning flutter clean...')
    subprocess.run(['flutter', 'clean'], cwd=PROJECT_DIR, check=True)


def flutter_pub_get():
    print('\nRunning flutter pub get...')
    subprocess.run(['flutter', 'pub', 'get'], cwd=PROJECT_DIR, check=True)


def flutter_build(build_type: str):
    print(f'\nBuilding ({build_type})...')
    subprocess.run(
        ['flutter', 'build', 'macos', f'--{build_type}'],
        cwd=PROJECT_DIR,
        check=True,
    )


def flutter_run(build_type: str):
    print(f'\nLaunching app ({build_type})...')
    # Use Popen so we can inject the dylib while it runs
    proc = subprocess.Popen(
        ['flutter', 'run', '-d', 'macos', f'--{build_type}'],
        cwd=PROJECT_DIR,
    )
    return proc


def wait_for_app_bundle(resources_dir: Path, timeout: int = 60) -> bool:
    """Wait until the app bundle Resources dir exists (build complete)."""
    print(f'Waiting for app bundle...', end='', flush=True)
    for _ in range(timeout):
        if resources_dir.exists():
            print(' ready!')
            return True
        print('.', end='', flush=True)
        time.sleep(1)
    print(' timed out!')
    return False


def main():
    parser = argparse.ArgumentParser(description='Run cancer detection app on macOS')
    parser.add_argument('--release', action='store_true', help='Build in release mode')
    parser.add_argument('--clean', action='store_true', help='Run flutter clean first')
    parser.add_argument('--dylib', type=str, help='Path to libtensorflowlite_c dylib')
    parser.add_argument('--build-only', action='store_true', help='Build only, do not run')
    args = parser.parse_args()

    build_type = 'release' if args.release else 'debug'
    dylib_src = find_dylib(args.dylib)
    resources_dir = get_app_resources(build_type)

    print('\n Cancer Detection App - macOS Runner')
    print('=' * 42)
    print(f'  Project : {PROJECT_DIR}')
    print(f'  Build   : {build_type}')
    print(f'  Dylib   : {dylib_src}')
    print()

    if args.clean:
        flutter_clean()
        flutter_pub_get()

    # Strategy: build first, copy dylib, then run
    # This avoids the permission-denied race condition
    flutter_build(build_type)

    # Copy dylib into the freshly-built app bundle
    copy_dylib(dylib_src, resources_dir)

    if args.build_only:
        print('\nBuild complete. Dylib installed.')
        print(f'App: {resources_dir.parent.parent}')
        return

    # Run the app (dylib already in place, no race condition)
    print('\nStarting app (press Ctrl+C to quit)...')
    try:
        subprocess.run(
            ['flutter', 'run', '-d', 'macos', f'--{build_type}',
             '--no-pub',  # skip pub get, already done
             ],
            cwd=PROJECT_DIR,
        )
    except KeyboardInterrupt:
        print('\nStopped.')


if __name__ == '__main__':
    main()
