#!/usr/bin/env python3
"""Inspect App Group authorization in a signed IPA on macOS. Never prints profile contents."""
import argparse
import json
import plistlib
import subprocess
import tempfile
import zipfile
from pathlib import Path


def run(*args):
    result = subprocess.run(args, capture_output=True)
    if result.returncode:
        raise RuntimeError(f'{args[0]} failed (exit {result.returncode})')
    return result.stdout


def inspect_bundle(bundle):
    info = plistlib.loads((bundle / 'Info.plist').read_bytes())
    signed = plistlib.loads(run('codesign', '-d', '--entitlements', ':-', str(bundle)))
    profile_path = bundle / 'embedded.mobileprovision'
    if not profile_path.is_file():
        raise RuntimeError(f'Missing provisioning profile in {bundle.name}')
    profile = plistlib.loads(run('security', 'cms', '-D', '-i', str(profile_path)))
    expected = info.get('BloomAppGroup')
    signed_groups = signed.get('com.apple.security.application-groups', [])
    allowed_groups = profile.get('Entitlements', {}).get('com.apple.security.application-groups', [])
    return {
        'bundle': bundle.name,
        'bundle_id': info.get('CFBundleIdentifier'),
        'expected_group': expected,
        'signed_groups': signed_groups,
        'profile_groups': allowed_groups,
        'group_authorized': bool(expected) and expected in signed_groups and expected in allowed_groups,
    }


def extract(archive, destination):
    # Reject traversal and symlinks before extracting user-provided archives.
    for item in archive.infolist():
        path = destination / item.filename
        if not path.resolve().is_relative_to(destination.resolve()):
            raise RuntimeError('Unsafe archive path')
        if (item.external_attr >> 16) & 0o170000 == 0o120000:
            raise RuntimeError('Archive contains a symlink; inspect manually on macOS')
    archive.extractall(destination)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('ipa', type=Path)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='bloom-signing-audit-') as temporary:
        root = Path(temporary)
        with zipfile.ZipFile(args.ipa) as archive:
            extract(archive, root)
        apps = list((root / 'Payload').glob('*.app'))
        if len(apps) != 1:
            raise RuntimeError('Expected exactly one app in Payload')
        app = apps[0]
        extensions = list((app / 'PlugIns').glob('*.appex'))
        if len(extensions) != 1:
            raise RuntimeError('Expected exactly one embedded Share Extension')
        run('codesign', '--verify', '--deep', '--strict', str(app))
        reports = [inspect_bundle(bundle) for bundle in [app, *extensions]]
        matched = len({r['expected_group'] for r in reports}) == 1
        passed = matched and all(r['group_authorized'] for r in reports)
        print(json.dumps({'app_groups_check_passed': passed, 'bundles': reports}, indent=2))
        return 0 if passed else 1


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (RuntimeError, OSError, ValueError, zipfile.BadZipFile) as error:
        raise SystemExit(f'Audit unavailable: {error}')
