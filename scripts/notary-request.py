#!/usr/bin/env python3
"""Persist a submission ID before waiting; resume without duplicate uploads."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import uuid


def decode_result(stdout, stderr):
    for value in (stdout, stderr):
        try:
            result = json.loads(value)
            if isinstance(result, dict):
                return result
        except (ValueError, TypeError):
            pass
    return None


def request(file, label, record, profile, existing_id=None):
    record = Path(record)
    record.mkdir(parents=True, exist_ok=True)

    def invoke(verb, *args):
        result = subprocess.run(
            ['xcrun', 'notarytool', verb, *args, '--keychain-profile', profile,
             '--output-format', 'json'], text=True, capture_output=True)
        (record / (label + '-' + verb + '-stdout.txt')).write_text(result.stdout)
        (record / (label + '-' + verb + '-stderr.txt')).write_text(result.stderr)
        return result, decode_result(result.stdout, result.stderr)

    id_path = record / (label + '.id')
    saved = id_path.read_text().strip() if id_path.exists() else None
    if existing_id and saved and existing_id != saved:
        raise RuntimeError('Existing submission ID conflicts with the saved ID.')
    submission = saved or existing_id
    if submission is None:
        if not Path(file).is_file():
            raise RuntimeError('Submission archive does not exist.')
        result, data = invoke('submit', str(file))  # No wait: persist ID immediately.
        submission = data.get('id') if data else None
        if not submission:
            raise RuntimeError('Upload did not return an ID. Inspect saved output before any retry.')
        uuid.UUID(submission)
        id_path.write_text(submission + '\n')
        if result.returncode:
            raise RuntimeError('An ID was received with an upload error. Check its status before retrying.')
    else:
        uuid.UUID(submission)
        id_path.write_text(submission + '\n')
    print('Apple submission:', submission, flush=True)

    def status():
        result, data = invoke('info', submission)
        if result.returncode or not data or data.get('id') != submission:
            raise RuntimeError('Could not read submission status; the ID and files are preserved.')
        (record / (label + '.json')).write_text(json.dumps(data, indent=2) + '\n')
        return data.get('status')

    state = status()
    if state == 'In Progress':
        print('Apple is processing. Waiting up to 30 minutes; all files are preserved.', flush=True)
        invoke('wait', submission, '--timeout', '30m')
        # Timeout diagnostics can be on stderr with no stdout. Always ask info
        # for the current authoritative status instead of parsing wait output.
        state = status()
    print('Apple status:', state, flush=True)
    if state == 'In Progress':
        print('Still processing. Resume this workspace later; do not upload again.', flush=True)
        return 2
    log_path = record / (label + '-log.json')
    result = subprocess.run(
        ['xcrun', 'notarytool', 'log', submission, '--keychain-profile', profile, str(log_path)],
        text=True, capture_output=True)
    (record / (label + '-log-output.txt')).write_text(result.stdout + result.stderr)
    if state != 'Accepted':
        raise RuntimeError('Apple has not accepted this submission. See the saved notarization log.')
    if result.returncode or not log_path.is_file():
        raise RuntimeError('Accepted, but the notarization log could not be saved. Resume to retry retrieval.')
    log = json.loads(log_path.read_text())
    if log.get('status') != 'Accepted' or log.get('jobId') != submission:
        raise RuntimeError('The saved log does not match the accepted submission.')
    return 0


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('file')
    parser.add_argument('label', choices=['application', 'installer'])
    parser.add_argument('record')
    parser.add_argument('profile')
    parser.add_argument('--existing-id')
    args = parser.parse_args()
    try:
        sys.exit(request(args.file, args.label, args.record, args.profile, args.existing_id))
    except (RuntimeError, ValueError, OSError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
