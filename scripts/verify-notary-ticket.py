#!/usr/bin/env python3
"""Require restored native code hashes to match Apple's accepted ticket."""
import json
from pathlib import Path
import re
import subprocess
import sys


def ticket_entries(log):
    if log.get('status') != 'Accepted':
        raise ValueError('The notarization log is not Accepted.')
    entries = set()
    for entry in log.get('ticketContents') or []:
        path = entry.get('path', '')
        marker = 'CommonCopy.app'
        start = path.find(marker)
        if start >= 0 and (start == 0 or path[start - 1] == '/'):
            relative = path[start + len(marker):].lstrip('/')
            entries.add((relative, entry.get('arch'), entry.get('cdhash', '').lower()))
    if not entries:
        raise ValueError('No CommonCopy code hashes found in the accepted ticket.')
    return entries


def require_covered(actual, approved):
    missing = set(actual) - approved
    if missing:
        raise ValueError('Restored code does not match Apple approval: ' +
                         ', '.join(path or 'CommonCopy.app' for path, arch, digest in sorted(missing)))


def inspect_code(app):
    app = Path(app)
    targets = [(app, '')]
    for file in app.rglob('*'):
        if file.is_file() and not file.is_symlink():
            kind = subprocess.check_output(['/usr/bin/file', '-b', str(file)], text=True)
            if 'Mach-O' in kind:
                targets.append((file, str(file.relative_to(app))))
    actual = set()
    for target, relative in targets:
        executable = app / 'Contents/MacOS/CommonCopyMac' if target == app else target
        architectures = subprocess.check_output(['lipo', '-archs', str(executable)], text=True).split()
        for arch in architectures:
            result = subprocess.run(['codesign', '--display', '--arch', arch, '--verbose=4', str(target)],
                                    text=True, capture_output=True, check=True)
            match = re.search(r'^CDHash=([0-9a-fA-F]+)$', result.stderr, re.MULTILINE)
            if not match:
                raise ValueError('Could not read CDHash for ' + str(target))
            actual.add((relative, arch, match.group(1).lower()))
    return actual


if __name__ == '__main__':
    try:
        approved = ticket_entries(json.loads(Path(sys.argv[2]).read_text()))
        actual = inspect_code(sys.argv[1])
        require_covered(actual, approved)
        print('All restored native code hashes match Apple approval.')
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        raise SystemExit(str(error))
