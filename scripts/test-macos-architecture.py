#!/usr/bin/env python3
"""Exercise the actual shell preflight with a deterministic lipo substitute."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).with_name('macos-architecture.sh').resolve()

class ArchitectureTests(unittest.TestCase):
    def run_preflight(self, shell_arch, helper_arch):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            fake = root / 'lipo'
            fake.write_text('''#!/bin/bash
if [[ "$1" == -archs && "$2" == */Contents/MacOS/CommonCopyMac ]]; then
  printf '%s\\n' "$TEST_SHELL_ARCH"
elif [[ "$1" == */Contents/Helpers/Core/CommonCopy.DesktopBridge && "$2" == -verify_arch && "$3" == "$TEST_HELPER_ARCH" ]]; then
  exit 0
else
  exit 1
fi
''')
            fake.chmod(0o755)
            env = dict(os.environ, PATH=str(root)+os.pathsep+os.environ['PATH'], TEST_SHELL_ARCH=shell_arch, TEST_HELPER_ARCH=helper_arch)
            return subprocess.run(['bash', '-c', 'source "$1"; commoncopy_macos_architecture "$2"', 'preflight', str(SCRIPT), str(root/'Application with spaces.app')], env=env, capture_output=True, text=True)

    def test_matching_architectures(self):
        for arch in ['arm64', 'x86_64']:
            with self.subTest(arch=arch):
                result = self.run_preflight(arch, arch)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.strip(), arch)

    def test_mixed_layers_rejected(self):
        for shell, helper in [('arm64', 'x86_64'), ('x86_64', 'arm64')]:
            with self.subTest(shell=shell):
                result = self.run_preflight(shell, helper)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, '')

    def test_unsupported_or_universal_bundle_rejected(self):
        for arch in ['', 'i386', 'arm64 x86_64']:
            with self.subTest(arch=arch):
                self.assertNotEqual(self.run_preflight(arch, arch).returncode, 0)

if __name__ == '__main__':
    unittest.main()
