#!/usr/bin/env python3
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


def load(name):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).with_name(name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


request = load('notary-request')
ticket = load('verify-notary-ticket')
SUBMISSION = '20af6e54-a287-4401-8676-7f872bed3152'


class RecoveryTests(unittest.TestCase):
    def test_timeout_preserves_id_and_resume_never_resubmits(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            archive = root / 'CommonCopy.zip'
            archive.write_bytes(b'test archive')
            record = root / 'records'
            calls = []
            accepted = False

            def run(command, **kwargs):
                verb = command[2]
                calls.append(verb)
                if verb == 'submit':
                    data = {'id': SUBMISSION}
                elif verb == 'info':
                    data = {'id': SUBMISSION, 'status': 'Accepted' if accepted else 'In Progress'}
                elif verb == 'wait':
                    return subprocess.CompletedProcess(command, 1, '', json.dumps({'id': SUBMISSION, 'message': 'Timeout'}))
                elif verb == 'log':
                    Path(command[-1]).write_text(json.dumps({'jobId': SUBMISSION, 'status': 'Accepted'}))
                    data = {}
                else:
                    raise AssertionError(verb)
                return subprocess.CompletedProcess(command, 0, json.dumps(data), '')

            with patch.object(request.subprocess, 'run', side_effect=run), contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(request.request(archive, 'application', record, 'profile'), 2)
                self.assertEqual((record / 'application.id').read_text().strip(), SUBMISSION)
                accepted = True
                self.assertEqual(request.request(archive, 'application', record, 'profile'), 0)
            self.assertEqual(calls.count('submit'), 1)
            self.assertTrue(archive.exists())

    def test_existing_accepted_id_does_not_require_archive_or_upload(self):
        with tempfile.TemporaryDirectory() as directory:
            def run(command, **kwargs):
                if command[2] == 'info':
                    data = {'id': SUBMISSION, 'status': 'Accepted'}
                elif command[2] == 'log':
                    Path(command[-1]).write_text(json.dumps({'jobId': SUBMISSION, 'status': 'Accepted'}))
                    data = {}
                else:
                    raise AssertionError('Must not submit or wait')
                return subprocess.CompletedProcess(command, 0, json.dumps(data), '')
            with patch.object(request.subprocess, 'run', side_effect=run), contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(request.request('missing.zip', 'application', directory, 'profile', SUBMISSION), 0)

    def test_invalid_submission_never_succeeds(self):
        with tempfile.TemporaryDirectory() as directory:
            def run(command, **kwargs):
                data = {'id': SUBMISSION, 'status': 'Invalid'}
                if command[2] == 'log':
                    Path(command[-1]).write_text(json.dumps({'jobId': SUBMISSION, 'status': 'Invalid'}))
                return subprocess.CompletedProcess(command, 0, json.dumps(data), '')
            with patch.object(request.subprocess, 'run', side_effect=run), contextlib.redirect_stdout(io.StringIO()):
                with self.assertRaisesRegex(RuntimeError, 'not accepted'):
                    request.request('missing.zip', 'application', directory, 'profile', SUBMISSION)

    def test_timeout_json_on_stderr_and_empty_output(self):
        self.assertEqual(request.decode_result('', '{"message":"Timeout"}'), {'message': 'Timeout'})
        self.assertIsNone(request.decode_result('', 'network error'))

    def test_ticket_requires_every_code_hash_and_architecture(self):
        log = {'status': 'Accepted', 'ticketContents': [
            {'path': 'CommonCopy.zip/CommonCopy.app', 'arch': 'arm64', 'cdhash': 'aaa'},
            {'path': 'CommonCopy.zip/CommonCopy.app/Contents/Helpers/Core/Bridge', 'arch': 'arm64', 'cdhash': 'bbb'}]}
        approved = ticket.ticket_entries(log)
        ticket.require_covered({('', 'arm64', 'aaa'), ('Contents/Helpers/Core/Bridge', 'arm64', 'bbb')}, approved)
        with self.assertRaisesRegex(ValueError, 'does not match'):
            ticket.require_covered({('', 'arm64', 'changed')}, approved)
        with self.assertRaises(ValueError):
            ticket.require_covered({('', 'x86_64', 'aaa')}, approved)
        with self.assertRaises(ValueError):
            ticket.ticket_entries({'status': 'Invalid', 'ticketContents': []})


if __name__ == '__main__':
    unittest.main()
